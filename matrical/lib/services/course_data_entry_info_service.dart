import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matrical/services/connection_service.dart';
import 'package:pair/pair.dart';

class CourseDataEntryInfoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _initialized = false; // Now private to prevent external modifications

  // Private fields
  Map<String, Pair<DateTime, Set<String>>> _termYearScrapeInfo = {};

  // Constructor
  CourseDataEntryInfoService() {
    _initializeData();
  }

  // Method to initialize data from Firestore
  Future<void> _initializeData() async {
    try {
      _firestore
          .collection('Data Entry Information')
          .doc('Department Course')
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          _termYearScrapeInfo = Map<String, Pair<DateTime, Set<String>>>.from(
              (snapshot.data()?['termYearScrapeInfo'] ?? {}).map((key, value) =>
                  MapEntry(
                      key as String,
                      Pair<DateTime, Set<String>>(value['lastUpdated'].toDate(),
                          Set.from(value['departments'])))));
          _initialized = true;
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

  // Public getters with reinitialization attempt
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
}
