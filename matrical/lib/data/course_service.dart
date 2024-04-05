import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:miuni/features/matrical/data/model/course_data_entry_info_service.dart';
import 'package:miuni/features/matrical/data/model/department_course.dart';
import 'package:miuni/features/matrical/data/connection_service.dart';
import 'package:miuni/Global/Cache/Models/cache_service.dart';
import 'package:miuni/Global/Cache/shared_preferences_cache_service.dart';

class CourseService {
  final ConnectionService connectionService;
  final CourseDataEntryInfoService dataEntryInfoService;
  final SharedPreferencesCacheService _cacheService;

  static final CourseService _instance = CourseService._privateConstructor();

  // Private constructor
  CourseService._privateConstructor()
      : connectionService = ConnectionService(),
        dataEntryInfoService = CourseDataEntryInfoService(),
        _cacheService = SharedPreferencesCacheService.getInstance();

  // Public factory method to return the instance
  factory CourseService() {
    return _instance;
  }

  // Static method to access the singleton instance
  static CourseService getInstance() {
    return _instance;
  }

  Future<CacheResult<Department>> _getDepartmentFromCache(
      String department, String term, int year) async {
    // Look first in in-memory map
    String cacheKey = "$department:$term:$year";
    bool online = await connectionService.isConnected();
    if (dataEntryInfoService.initialized || online) {
      DateTime dataLastUpdated =
          await dataEntryInfoService.getLastUpdated(term, year);
      CacheResult<Department> diskCacheResult = await _cacheService.retrieve(
          cacheKey, Department.deserialize,
          expiration: dataLastUpdated, clearWhenExpired: true);
      return diskCacheResult;
    } else {
      CacheResult<Department> diskCacheResult =
          await _cacheService.retrieve(cacheKey, Department.deserialize);
      return diskCacheResult;
    }
  }

  Future<Department?> getDepartment(
      String department, String term, int year) async {
    if (department.length != 4) {
      return null;
    }
    String documentKey = "$department:$term:$year";
    CacheResult<Department> deptCacheResult =
        await _getDepartmentFromCache(department, term, year);
    switch (deptCacheResult.type) {
      case CacheResultType.foundData:
      case CacheResultType.foundOffline:
        return deptCacheResult.data;
      case CacheResultType.foundExpired:
        final document = await FirebaseFirestore.instance
            .collection("Department Courses")
            .doc(documentKey)
            .get();
        if (document.exists) {
          final data = document.data() as Map<String, dynamic>;
          Department department = Department.fromJson(data);
          await _cacheDepartment(department);
          return department;
        }
        return deptCacheResult.data;
      case CacheResultType.keyNotFound:
        bool online = await connectionService.isConnected();
        if (online) {
          Set<String> departments =
              await dataEntryInfoService.getDepartments(term, year);
          if (departments.contains(department)) {
            final document = await FirebaseFirestore.instance
                .collection("Department Courses")
                .doc(documentKey)
                .get();

            if (document.exists) {
              final data = document.data() as Map<String, dynamic>;
              Department department = Department.fromJson(data);
              await _cacheDepartment(department);
              return department;
            }
            return null;
          }
        }
        return null;
    }
  }

  Future<Course?> getCourse(String courseCode, String term, int year) async {
    if (courseCode.length != 8) {
      return null;
    }
    String department = courseCode.substring(0, 4);
    String documentKey = "$department:$term:$year";
    CacheResult<Department> deptCacheResult =
        await _getDepartmentFromCache(department, term, year);
    switch (deptCacheResult.type) {
      case CacheResultType.foundData:
        return deptCacheResult.data.courses[courseCode]?.copy();
      case CacheResultType.foundOffline:
        return deptCacheResult.data.courses[courseCode]?.copy();
      case CacheResultType.foundExpired:
        final document = await FirebaseFirestore.instance
            .collection("Department Courses")
            .doc(documentKey)
            .get();
        if (document.exists) {
          final data = document.data() as Map<String, dynamic>;
          Department department = Department.fromJson(data);
          await _cacheDepartment(department);
          return department.courses[courseCode]?.copy();
        }
        return deptCacheResult.data.courses[courseCode];
      case CacheResultType.keyNotFound:
        bool online = await connectionService.isConnected();
        if (online) {
          Set<String> departments =
              await dataEntryInfoService.getDepartments(term, year);
          if (departments.contains(department)) {
            final document = await FirebaseFirestore.instance
                .collection("Department Courses")
                .doc(documentKey)
                .get();

            if (document.exists) {
              final data = document.data() as Map<String, dynamic>;
              Department department = Department.fromJson(data);
              await _cacheDepartment(department);
              return department.courses[courseCode]?.copy();
            }
            return null;
          }
        }
        return null;
    }
  }

  Future<void> _cacheDepartment(Department department) async {
    DateTime dataDate = DateTime.fromMillisecondsSinceEpoch(0);
    String cacheKey =
        "${department.department}:${department.term}:${department.year}";
    bool online = await connectionService.isConnected();
    if (dataEntryInfoService.initialized || online) {
      dataDate = await dataEntryInfoService.getLastUpdated(
          department.term, department.year);
    }
    _cacheService.store(cacheKey, department, dateObtained: dataDate);
  }
}
