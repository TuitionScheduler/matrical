import 'package:collection/collection.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule.dart';
import 'package:miuni/features/matrical/data/model/department_course.dart';
import 'package:pair/pair.dart';

class GeneratedSchedulePreferences {
  bool preferDense;
  bool preferOnline;
  double? averageTime;
  Map<String, Pair<bool, List<Professor>>> professorRankings;

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
                                    .indexOf(professor))
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
}
