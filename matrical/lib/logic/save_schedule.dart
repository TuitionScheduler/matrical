import 'dart:isolate';

import 'package:miuni/features/matrical/data/model/generated_schedule.dart';
import 'package:miuni/features/matrical/data/model/saved_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<SavedSchedule>> getSavedSchedules() async {
  var cache = await SharedPreferences.getInstance();
  return await Isolate.run(() =>
      cache
          .getStringList("MySchedules")
          ?.map((scheduleString) => SavedSchedule.fromString(scheduleString))
          .toList() ??
      []);
}

Future<SaveScheduleResult> writeSavedSchedules(
    List<SavedSchedule> schedules) async {
  var cache = await SharedPreferences.getInstance();
  try {
    bool success = await cache.setStringList(
        "MySchedules", schedules.map((s) => s.toString()).toList());
    return success
        ? SaveScheduleResult.success
        : SaveScheduleResult.failedWrite;
  } catch (e) {
    return SaveScheduleResult.failedWrite;
  }
}

Future<SaveScheduleResult> deleteSavedSchedule(String name) async {
  var schedules = await getSavedSchedules();
  schedules.removeWhere((element) => element.name == name);
  return await writeSavedSchedules(schedules);
}

Future<SaveScheduleResult> saveSchedule(
    GeneratedSchedule schedule, String name) async {
  var mySchedules = await getSavedSchedules();
  if (mySchedules.length >= 300) {
    return SaveScheduleResult.hitScheduleLimit;
  }
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    return SaveScheduleResult.emptyName;
  }
  SavedSchedule newSchedule = SavedSchedule(
      name: trimmedName, dateCreated: DateTime.now(), schedule: schedule);
  if (mySchedules.any((element) => element.name == trimmedName)) {
    return SaveScheduleResult.alreadyExists;
  }
  mySchedules.add(newSchedule);
  return await writeSavedSchedules(mySchedules);
}
