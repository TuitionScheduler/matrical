import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:matrical/models/blacklist.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/department_course.dart';
import 'package:matrical/models/generated_schedule_preferences.dart';
import 'package:matrical/services/course_service.dart';

import 'package:pair/pair.dart';

class CourseSectionPair {
  final Course course;
  final Section section;

  CourseSectionPair({required this.course, required this.section});

  String get sectionCode => section.sectionCode;

  Map<String, dynamic> toJson() {
    return {
      'course': course.toJson(),
      'section': section.toJson(),
    };
  }

  static CourseSectionPair fromJson(Map<String, dynamic> json) {
    return CourseSectionPair(
      course: Course.fromJson(json['course']),
      section: Section.fromJson(json['section']),
    );
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  static CourseSectionPair fromString(String jsonString) {
    return fromJson(jsonDecode(jsonString));
  }

  Section getSection() {
    return section;
  }

  bool checkConflict(List<CourseSectionPair> pairs) {
    return getSection().meetings.any((meeting) => meeting.days.characters.any(
        (day) => pairs.any((pair) => pair
            .getSection()
            .meetings
            .any((pairMeeting) => pairMeeting.days.characters.any((pairDay) {
                  if (day != pairDay) return false;
                  return meeting.intersects(pairMeeting);
                })))));
  }

  Color getColor() {
    int interpolate(int x, int oldA, int oldB, int newA, int newB) {
      double t = (x - oldA) / (oldB - oldA);
      return (newA + (newB - newA) * t).toInt();
    }

    int rangeMax = 1000000;
    int hash = (course.courseCode + sectionCode).hashCode % rangeMax;

    int low = 50;
    int high = 150;
    int fluctuation = 50;

    low = interpolate(
        hash, 0, rangeMax, max(0, low - fluctuation), low + fluctuation);
    high = interpolate(
        hash, 0, rangeMax, high - fluctuation, min(255, high + fluctuation));
    int value = interpolate(hash, 0, rangeMax, low, high);

    switch (hash % 6) {
      case 0:
        return Color.fromRGBO(value, high, low, 1);
      case 1:
        return Color.fromRGBO(high, value, low, 1);
      case 2:
        return Color.fromRGBO(high, low, value, 1);
      case 3:
        return Color.fromRGBO(value, low, high, 1);
      case 4:
        return Color.fromRGBO(low, value, high, 1);
      default:
        return Color.fromRGBO(low, high, value, 1);
    }
  }
}

class GeneratedSchedule {
  final String term;
  final int year;
  final List<CourseSectionPair> courses;

  GeneratedSchedule(
      {required this.term, required this.year, required this.courses});

  Map<String, dynamic> toJson() {
    return {
      'term': term,
      'year': year,
      'courses': courses.map((c) => c.toJson()).toList(),
    };
  }

  static GeneratedSchedule fromJson(Map<String, dynamic> json) {
    return GeneratedSchedule(
      term: json['term'],
      year: json['year'],
      courses: (json['courses'] as List)
          .map((c) => CourseSectionPair.fromJson(c))
          .toList(),
    );
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  static GeneratedSchedule fromString(String jsonString) {
    return fromJson(jsonDecode(jsonString));
  }

  void overwriteEventController(
      EventController eventController, bool Function(String, String) isLocked) {
    eventController.removeWhere((element) => true);
    for (var pair in courses) {
      Course course = pair.course;
      Section section = pair.getSection();
      for (var meeting in section.meetings) {
        for (var day in meeting.days.characters) {
          Map<String, int> dayMap = {"L": 1, "M": 2, "W": 3, "J": 4, "V": 5};
          List<String> startTime = meeting.startTime.split(":");
          List<String> endTime = meeting.endTime.split(":");
          eventController.add(CalendarEventData(
              title:
                  "${isLocked(course.courseCode, section.sectionCode) ? "🔒" : ""}${course.courseCode}-${section.sectionCode}\nRoom: ${meeting.room}",
              date: DateTime(2024, 1, dayMap[day]!),
              startTime: DateTime(2024, 1, dayMap[day]!,
                  int.parse(startTime[0]), int.parse(startTime[1])),
              endTime: DateTime(2024, 1, dayMap[day]!, int.parse(endTime[0]),
                  int.parse(endTime[1])),
              color: pair.getColor()));
        }
      }
    }
  }

  CourseSectionPair? getCourseSectionPair(
      String courseCode, String sectionCode) {
    for (final pair in courses) {
      if (pair.course.courseCode == courseCode &&
          pair.sectionCode == sectionCode) {
        return pair;
      }
    }
    return null;
  }

  List<CourseSectionPair> getCourseSectionPairsByModality(Modality modality) {
    List<CourseSectionPair> result = [];
    for (final pair in courses) {
      if (modality.letterCodes.contains(pair.getSection().modality)) {
        result.add(pair);
      }
    }
    return result;
  }

  bool matchesFilters(CourseFilters filters, Blacklist blacklist,
      Function isLocked, Function courseHasLock) {
    return !courses.any((pair) {
      var course = pair.course.copy();
      var section = pair.getSection();
      if (courseHasLock(course.courseCode)) {
        return !isLocked(course.courseCode, section.sectionCode);
      }
      course.sections = [section];
      course = applyBlacklist(applyFilters(course, filters), blacklist);
      return course.sections.isEmpty;
    });
  }

  static double getTimeAsDouble(String time) {
    return double.parse(time.substring(0, 2)) +
        double.parse(time.substring(3, 5)) / 60;
  }

  double getEarliestHour() {
    if (courses.isEmpty) return 0;
    var hour = courses.map((pair) {
      var section = pair.getSection();
      if (Modality.byagreement.letterCodes.contains(section.modality)) {
        return double.infinity;
      }
      return section.meetings
          .map((meeting) => getTimeAsDouble(meeting.startTime))
          .min;
    }).min;
    if (hour == double.infinity) return 0;
    return hour;
  }

  String toImportCode() {
    final bytes = utf8.encode(toString());
    final compressedBytes = gzip.encode(bytes);
    final base64String = base64.encode(compressedBytes);
    return base64String;
  }

  static GeneratedSchedule? fromImportCode(String code) {
    try {
      final decodedBytes = base64.decode(code);
      final decompressedBytes = gzip.decode(decodedBytes);
      final json = utf8.decode(decompressedBytes);
      return fromString(json);
    } catch (e) {
      return null;
    }
  }

  double getLatestHour() {
    if (courses.isEmpty) return 0;
    var hour = courses.map((pair) {
      var section = pair.getSection();
      if (Modality.byagreement.letterCodes.contains(section.modality)) {
        return 0;
      }
      return section.meetings
          .map((meeting) => getTimeAsDouble(meeting.endTime))
          .max;
    }).max;
    return hour.toDouble();
  }

  int getOnlineCount() {
    return courses
        .where((pair) =>
            Modality.byagreement.letterCodes.contains(pair.section.modality))
        .length;
  }

  List<List<Pair<double, double>>> getTimesPerDay() {
    return ["L", "M", "W", "J", "V"].map((day) {
      List<Pair<double, double>> schedules = [];
      courses.forEach((pair) {
        pair.section.meetings.forEach((meeting) {
          if (meeting.days.contains(day)) {
            schedules.add(Pair(getTimeAsDouble(meeting.startTime),
                getTimeAsDouble(meeting.endTime)));
          }
        });
      });
      return schedules.sorted((a, b) => a.key.compareTo(b.key));
    }).toList();
  }

  double getSparsity() {
    return 1 - getDensity();
  }

  double getDensity() {
    var timesPerDay = getTimesPerDay();
    double totalTimeInLectures = 0.0;
    double totalTimeInUniversity = 0.0;
    int daysWithoutClass = 0;
    int daysMinusOne = timesPerDay.length -
        1; // To allow max density to be achieved 1 day of presencial class
    for (var daySchedule in timesPerDay) {
      if (daySchedule.isEmpty) {
        daysWithoutClass++;
      } else {
        totalTimeInUniversity += daySchedule.last.value - daySchedule.first.key;
        totalTimeInLectures += daySchedule
            .map((courseTime) => courseTime.value - courseTime.key)
            .sum;
      }
    }
    final lectureTimeRatio = totalTimeInUniversity != 0
        ? totalTimeInLectures / totalTimeInUniversity
        : 1;
    return lectureTimeRatio * 0.6 +
        min(1, (daysWithoutClass / daysMinusOne)) * 0.4;
  }

  double getAverageTime(double? targetTime) {
    if (targetTime == null) return 0;
    var timesPerDay = getTimesPerDay();
    var averageTimes = timesPerDay.expand((day) => day.isNotEmpty
        ? [
            day
                .map((times) =>
                    (targetTime - (times.key + times.value) / 2).abs())
                .average
          ]
        : <double>[]);
    if (averageTimes.isEmpty) return 0;
    return averageTimes.average;
  }

  static void sortGeneratedSchedules(List<GeneratedSchedule> schedules,
      GeneratedSchedulePreferences preferences) {
    if (schedules.length <= 1) return;

    var maxOnlineCount = schedules.first.courses.length;
    var maxAverageTime =
        schedules.map((e) => e.getAverageTime(preferences.averageTime)).max;

    double getSortValue(GeneratedSchedule schedule) {
      return [
        1 * preferences.getDensityValue(schedule),
        2 * preferences.getAverageTimeValue(schedule, maxAverageTime),
        3 * preferences.getOnlineCountValue(schedule, maxOnlineCount),
        4 * preferences.getProfessorRankValue(schedule),
      ].sum;
    }

    schedules.sort((a, b) => getSortValue(b).compareTo(getSortValue(a)));
  }
}
