import 'package:matrical/models/generated_schedule_preferences.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> getAcademicYears() {
  return [(DateTime.now().year - 1), DateTime.now().year];
}

Future<Term> getSelectedAcademicTerm() async {
  final cache = await SharedPreferences.getInstance();
  final maybeTermString = cache.getString("SelectedAcademicTerm");
  return maybeTermString == null
      ? Term.getPredictedTerm()
      : Term.fromString(maybeTermString)!;
}

Future<bool> setSelectedAcademicTerm(Term newTerm) async {
  final cache = await SharedPreferences.getInstance();
  return cache.setString("SelectedAcademicTerm", newTerm.databaseKey);
}

Future<int> getSelectedAcademicYear() async {
  final cache = await SharedPreferences.getInstance();
  return cache.getInt("SelectedAcademicYear") ?? Term.getPredictedYear();
}

Future<bool> setSelectedAcademicYear(int newYear) async {
  if (!getAcademicYears().contains(newYear)) return false;
  final cache = await SharedPreferences.getInstance();
  return cache.setInt("SelectedAcademicYear", newYear);
}

Future<GeneratedSchedulePreferences> getSchedulePreferences() async {
  final prefs = await SharedPreferences.getInstance();
  final maybeSerializedPreferences = prefs.getString("SchedulePreferences");
  return maybeSerializedPreferences == null
      ? GeneratedSchedulePreferences.getDefault()
      : GeneratedSchedulePreferences.deserialize(maybeSerializedPreferences);
}

// This setter discards the professor ranking as this must be recreated anyway
// every time that schedule generation is triggered.
Future<bool> setSchedulePreferences(
    GeneratedSchedulePreferences newPrefs) async {
  final cache = await SharedPreferences.getInstance();

  return cache.setString(
      "SchedulePreferences", newPrefs.copyWithoutRankings().serialize());
}
