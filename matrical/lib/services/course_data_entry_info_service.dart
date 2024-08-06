import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matrical/services/connection_service.dart';
import 'package:pair/pair.dart';

class CourseDataEntryInfoService {
  static final CourseDataEntryInfoService _instance =
      CourseDataEntryInfoService._internal();

  static CourseDataEntryInfoService getInstance() {
    return _instance;
  }

  CourseDataEntryInfoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _initialized = false;
  Map<String, Pair<DateTime, Set<String>>> _termYearScrapeInfo = {};

  // Method to initialize data from Firestore
  Future<void> _initializeData() async {
    try {
      DocumentSnapshot snapshot = await _firestore
          .collection('DataEntryInformation')
          .doc('DepartmentCourses')
          .get();
      if (snapshot.exists) {
        _termYearScrapeInfo = Map<String, Pair<DateTime, Set<String>>>.from(
            ((snapshot.data() as Map<String, dynamic>)['termYearScrapeInfo'] ??
                    {})
                .map((key, value) => MapEntry(
                    key as String,
                    Pair<DateTime, Set<String>>(value['lastUpdated'].toDate(),
                        Set.from(value['departments'])))));
      }
      _initialized = true;
      _firestore
          .collection('DataEntryInformation')
          .doc('DepartmentCourses')
          .snapshots()
          .skip(1)
          .listen((snapshot) {
        if (snapshot.exists) {
          _termYearScrapeInfo = Map<String, Pair<DateTime, Set<String>>>.from(
              (snapshot.data()?['termYearScrapeInfo'] ?? {}).map((key, value) =>
                  MapEntry(
                      key as String,
                      Pair<DateTime, Set<String>>(value['lastUpdated'].toDate(),
                          Set.from(value['departments'])))));
        }
      });
    } catch (e) {
      // TODO: log errors
      _initialized = false;
      print(e.toString());
    }
  }

  // Attempts reinitialization if needed
  Future<void> _attemptReInitialization() async {
    bool isConnected = await ConnectionService.isConnectedToInternet();
    if (!isConnected || _initialized) return;
    await _initializeData();
  }

  Future<Set<String>> getDepartments(String term, int year) async {
    await _attemptReInitialization();
    return _termYearScrapeInfo["$term:$year"]?.value ?? {};
  }

  Future<DateTime> getLastUpdated(String term, int year) async {
    await _attemptReInitialization();
    return _termYearScrapeInfo["$term:$year"]?.key ?? DateTime.now();
  }

  bool get initialized {
    return _initialized;
  }

  Future<List<String>> autocompleteQuery(
      String query, String term, int year) async {
    final sanitizedQuery = query.replaceAll(" ", "").toUpperCase();
    final departments = await getDepartments(term, year);
    return departments.where((dept) => dept.contains(sanitizedQuery)).toList();
  }
}
