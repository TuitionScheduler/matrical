import 'dart:isolate';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:matrical/models/blacklist.dart';
import 'package:matrical/models/cache_service.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/department_course.dart';
import 'package:matrical/services/connection_service.dart';
import 'package:matrical/services/course_data_entry_info_service.dart';
import 'package:matrical/services/shared_preferences_cache_service.dart';

class CourseService {
  final CourseDataEntryInfoService dataEntryInfoService;
  final SharedPreferencesCacheService _cacheService;

  static final CourseService _instance = CourseService._privateConstructor();

  // Private constructor
  CourseService._privateConstructor()
      : dataEntryInfoService = CourseDataEntryInfoService(),
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
    bool online = await ConnectionService.isConnectedToInternet();
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
            .collection("DepartmentCourses")
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
        bool online = await ConnectionService.isConnectedToInternet();
        if (online) {
          Set<String> departments =
              await dataEntryInfoService.getDepartments(term, year);
          if (departments.contains(department)) {
            final document = await FirebaseFirestore.instance
                .collection("DepartmentCourses")
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
            .collection("DepartmentCourses")
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
        bool online = await ConnectionService.isConnectedToInternet();
        if (online) {
          Set<String> departments =
              await dataEntryInfoService.getDepartments(term, year);
          if (departments.contains(department)) {
            final document = await FirebaseFirestore.instance
                .collection("DepartmentCourses")
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
    bool online = await ConnectionService.isConnectedToInternet();
    if (dataEntryInfoService.initialized || online) {
      dataDate = await dataEntryInfoService.getLastUpdated(
          department.term, department.year);
    }
    _cacheService.store(cacheKey, department, dateObtained: dataDate);
  }
}

Future<List<Course>> getCourseSearch(
    String search, String term, int year, CourseFilters filters) async {
  final CourseService cs = CourseService.getInstance();
  var coursesOrDepts = search.split(",");
  var courses = <Course>[];
  for (var courseOrDept in coursesOrDepts) {
    var formatted = courseOrDept.trim().toUpperCase();
    switch (formatted.length) {
      case 0:
        //Empty string was passed in
        break;
      case 4:
        var dept = await cs.getDepartment(formatted, term, year);
        if (dept != null) {
          courses.addAll(dept.courses.values);
        }
        break;
      case 8:
        var course = await cs.getCourse(formatted, term, year);
        if (course != null) {
          courses.add(course);
        }
        break;
      default:
        throw Exception("Value is not course or department");
    }
  }
  return await Isolate.run(() {
    return applyFiltersToAll(courses, filters);
  });
}

List<Course> applyFiltersToAll(List<Course> courses, CourseFilters filters) {
  List<Course> result =
      courses.map((course) => applyFilters(course, filters)).toList();
  result.removeWhere((course) => course.sections.isEmpty);
  return result;
}

Course applyFilters(Course course, CourseFilters filters) {
  var copy = course.copy();
  var sections = <Section>[];
  for (var section in course.sections) {
    if (!filters.modality.letterCodes.any((code) => code == section.modality)) {
      continue;
    }
    if (filters.professors.isNotEmpty &&
        !filters.professors.any((filterProfessor) => section.professors.any(
            (sectionProfessor) => sectionProfessor.name
                .toLowerCase()
                .replaceAll(" ", "")
                .contains(
                    filterProfessor.toLowerCase().replaceAll(" ", ""))))) {
      continue;
    }
    if (filters.rooms.isNotEmpty &&
        !filters.rooms.any((room) => section.meetings.any((meeting) => meeting
            .room
            .toLowerCase()
            .replaceAll(" ", "")
            .startsWith(room.toLowerCase().replaceAll(" ", ""))))) {
      continue;
    }
    var satisfies = true;
    for (var meeting in section.meetings) {
      if (filters.earliestTime != "" &&
          meeting.startTime != "" &&
          meeting.startTime.compareTo(filters.earliestTime) < 0) {
        satisfies = false;
        break;
      }
      if (filters.latestTime != "" &&
          meeting.endTime != "" &&
          meeting.endTime.compareTo(filters.latestTime) > 0) {
        satisfies = false;
        break;
      }
      if (filters.days != "" && meeting.days != "") {
        var acceptedDays = <String>{};
        acceptedDays.addAll(filters.days.characters);
        if (!acceptedDays.containsAll(meeting.days.characters)) {
          satisfies = false;
          break;
        }
      }
    }
    if (satisfies) sections.add(section);
  }
  copy.sections = sections;
  return copy;
}

Course applyBlacklist(Course course, Blacklist blacklist) {
  var copy = course.copy();
  copy.sections.removeWhere((section) => section.professors.any((professor) =>
      blacklist.professors
          .any((blockedProfessor) => professor.name == blockedProfessor.name)));
  if (blacklist.sections[copy.courseCode] != null) {
    copy.sections.removeWhere((section) =>
        blacklist.sections[copy.courseCode]!.contains(section.sectionCode));
  }
  return copy;
}

bool isCourseCode(String maybeCourseCode) {
  RegExp regex = RegExp(r'^[A-Z]{4}[0-9]{4}$');
  return regex.hasMatch(maybeCourseCode);
}

bool isSectionCode(String maybeSectionCode) {
  RegExp regex = RegExp(r'^[0-9]{2}[0-9A-Z]{1}[A-Z#]?$');
  return regex.hasMatch(maybeSectionCode);
}
