import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:matrical/models/department_course.dart';
import 'package:matrical/models/generated_schedule.dart';

import 'package:pair/pair.dart';

class GeneratedSchedulePreferences {
  bool preferDense;
  bool preferOnline;
  double? averageTime;
  Map<String, Pair<bool, List<Pair<Professor, bool>>>> professorRankings;

  GeneratedSchedulePreferences(
      {this.preferDense = true,
      this.preferOnline = true,
      this.averageTime,
      required this.professorRankings});

  double getDensityValue(GeneratedSchedule schedule) {
    var densityValue =
        preferDense ? schedule.getDensity() : schedule.getSparsity();
    return densityValue;
  }

  double getOnlineCountValue(GeneratedSchedule schedule, num maxOnlineCount) {
    if (maxOnlineCount == 0) return 0;
    var onlineCountRatio = schedule.getOnlineCount() / maxOnlineCount;
    var onlineCountValue =
        preferOnline ? onlineCountRatio : 1 - onlineCountRatio;
    return onlineCountValue;
  }

  double getAverageTimeValue(GeneratedSchedule schedule, num maxAverageTime) {
    if (averageTime == null || maxAverageTime == 0) return 0;
    var averageTimeRatio =
        schedule.getAverageTime(averageTime!) / maxAverageTime;
    return 1 - averageTimeRatio;
  }

  double getProfessorRankValue(GeneratedSchedule schedule) {
    var ranks = schedule.courses.expand((pair) =>
        professorRankings[pair.course.courseCode]!.key &&
                professorRankings[pair.course.courseCode]!.value.length > 1
            ? [
                1 -
                    pair.section.professors
                            .map((professor) =>
                                professorRankings[pair.course.courseCode]!
                                    .value
                                    .indexWhere((p) => p.key == professor))
                            .min /
                        (professorRankings[pair.course.courseCode]!
                                .value
                                .length -
                            1)
              ]
            : <double>[]);

    if (ranks.isEmpty) return 0;
    return ranks.average;
  }

  GeneratedSchedulePreferences copy() {
    return GeneratedSchedulePreferences(
        preferDense: preferDense,
        preferOnline: preferOnline,
        averageTime: averageTime,
        professorRankings: professorRankings.map((key, value) =>
            MapEntry(key, Pair(value.key, List.from(value.value)))));
  }

  void updateWith(GeneratedSchedulePreferences other) {
    preferDense = other.preferDense;
    preferOnline = other.preferOnline;
    averageTime = other.averageTime;
    professorRankings = other.professorRankings;
  }

  static Map<String, dynamic> serializePair(
      Pair<bool, List<Pair<Professor, bool>>> pair) {
    return {
      'active': pair.key,
      'professors': pair.value
          .map((prof) => {'name': prof.key.toJson(), 'active': prof.value})
          .toList(),
    };
  }

  static Pair<bool, List<Pair<Professor, bool>>> deserializePair(
      Map<String, dynamic> json) {
    bool key = json['active'];
    List<Pair<Professor, bool>> value = (json['professors']
            as List<Map<String, dynamic>>)
        .map((p) => Pair(Professor.fromJson(p['name']), p['active'] as bool))
        .toList();
    return Pair(key, value);
  }

  Map<String, dynamic> toJson() {
    return {
      'preferDense': preferDense,
      'preferOnline': preferOnline,
      'averageTime': averageTime,
      'professorRankings': professorRankings
          .map((key, value) => MapEntry(key, serializePair(value))),
    };
  }

  static GeneratedSchedulePreferences fromJson(Map<String, dynamic> json) {
    Map<String, Pair<bool, List<Pair<Professor, bool>>>> professorRankings =
        (json['professorRankings'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, deserializePair(value)));
    return GeneratedSchedulePreferences(
      preferDense: json['preferDense'],
      preferOnline: json['preferOnline'],
      averageTime: json['averageTime'],
      professorRankings: professorRankings,
    );
  }

  String serialize() {
    return jsonEncode(toJson());
  }

  static GeneratedSchedulePreferences deserialize(String jsonEncoded) {
    return fromJson(jsonDecode(jsonEncoded));
  }

  GeneratedSchedulePreferences.getDefault()
      : preferDense = true,
        preferOnline = true,
        averageTime = null,
        professorRankings = {};

  GeneratedSchedulePreferences copyWithoutRankings() {
    return GeneratedSchedulePreferences(
        preferDense: preferDense,
        preferOnline: preferOnline,
        averageTime: averageTime,
        professorRankings: {});
  }

  int? getProfessorRank(String courseCode, Professor professor) {
    var rank = 1;
    for (var p
        in professorRankings[courseCode]?.value ?? <Pair<Professor, bool>>[]) {
      if (p.value) {
        if (p.key == professor) {
          return rank;
        }
        rank++;
      }
    }
    return null;
  }

  int getMaxProfessorRank(String courseCode) {
    var rank = 0;
    for (var p
        in professorRankings[courseCode]?.value ?? <Pair<Professor, bool>>[]) {
      if (p.value) rank++;
    }
    return rank;
  }
}
