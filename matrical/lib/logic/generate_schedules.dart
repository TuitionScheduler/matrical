import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule_preferences.dart';
import 'package:miuni/features/matrical/logic/get_data.dart';
import 'package:pair/pair.dart';

import '../data/model/blacklist.dart';
import '../data/model/course_filters.dart';
import '../data/model/department_course.dart';
import '../data/model/generated_schedule.dart';
import '../data/course_service.dart';

Future<List<GeneratedSchedule>> generateSchedules(
    List<CourseWithFilters> courses,
    String term,
    int year,
    Blacklist blacklist,
    CourseFilters globalFilters,
    GeneratedSchedulePreferences preferences) async {
  final CourseService cs = CourseService.getInstance();

  var filteredCourses =
      await Future.wait(courses.map((courseWithFilters) async {
    Course? course =
        await cs.getCourse(courseWithFilters.courseCode, term, year);
    if (course == null) {
      throw Exception("Course ${courseWithFilters.courseCode} does not exist");
    }
    return courseWithFilters.sectionCode.isEmpty
        ? applyBlacklist(
            applyFilters(
                applyFilters(course, courseWithFilters.filters), globalFilters),
            blacklist)
        : filterCourseBySection(course, courseWithFilters.sectionCode);
  }).toList());

  await gatherIntegratedLabs(filteredCourses, cs, term, year);

  filteredCourses = filteredCourses
      .map((course) => course.sections.length > 1 &&
              course.sections.any((section) => section.modality == "L")
          ? applyBlacklist(applyFilters(course, globalFilters), blacklist)
          : course)
      .toList();

  filteredCourses.forEach((course) {
    var preferencesProfessors =
        preferences.professorRankings[course.courseCode]?.value ?? [];
    preferencesProfessors.forEachIndexed((i, p) {
      preferencesProfessors[i] = Pair(p.key, false);
    });
  });
  filteredCourses.forEach((course) {
    var preferencesProfessors =
        preferences.professorRankings[course.courseCode]?.value ?? [];
    var courseProfessors = course.sections.expand((e) => e.professors).toSet();
    preferencesProfessors.forEachIndexed((i, p) {
      if (courseProfessors.any((e) => e == p.key)) {
        preferencesProfessors[i] = Pair(p.key, true);
      }
    });
    preferencesProfessors.addAll(courseProfessors.expand((e) =>
        !preferencesProfessors.any((p) => p.key == e) ? [Pair(e, true)] : []));
  });

  sortCourses(filteredCourses, preferences);

  var result = await Isolate.run(() {
    var schedules = <GeneratedSchedule>[];
    generateSchedulesAux(term, year, filteredCourses, schedules, [], 0);
    schedules.removeWhere((e) => e.courses.isEmpty);
    GeneratedSchedule.sortGeneratedSchedules(schedules, preferences);
    return schedules;
  });
  return result;
}

Course filterCourseBySection(Course course, String sectionCode) {
  course.sections.removeWhere((section) => section.sectionCode != sectionCode);
  return course;
}

Future<void> gatherIntegratedLabs(
    List<Course> courses, CourseService cs, String term, int year) async {
  final Map<String, List<int?>> labMap = {};
  for (final (i, course) in courses.indexed) {
    if (course.hasIntegratedLab) {
      if (!labMap.containsKey(course.courseCode)) {
        labMap[course.courseCode] = [null, null];
      }
      if (course.sections.any((element) => element.modality != "L")) {
        labMap[course.courseCode]?[0] = i;
      } else {
        labMap[course.courseCode]?[1] = i;
      }
    }
  }
  for (final entry in labMap.entries) {
    final courseCode = entry.key;
    final cIndex = entry.value[0];
    final lIndex = entry.value[1];
    if (cIndex == null) {
      throw Exception(
          "Course $courseCode lab cannot be taken without main course");
    }
    if (lIndex == null) {
      Course tempCourse;
      if (courses[cIndex].sections.length == 1) {
        tempCourse = (await cs.getCourse(courseCode, term, year))!.copy();
        tempCourse.sections.removeWhere((element) => element.modality != "L");
      } else {
        tempCourse = courses[cIndex].copy();
        courses[cIndex]
            .sections
            .removeWhere((element) => element.modality == "L");
        tempCourse.sections.removeWhere((element) => element.modality != "L");
      }
      courses.add(tempCourse);
    } else {
      if (courses[cIndex].sections.length != 1) {
        courses[cIndex]
            .sections
            .removeWhere((element) => element.modality == "L");
      }
    }
  }
}

void generateSchedulesAux(
    String term,
    int year,
    List<Course> courses,
    List<GeneratedSchedule> schedules,
    List<CourseSectionPair> pairs,
    int index) {
  if (schedules.length >= 2500) return;
  if (index == courses.length) {
    schedules.add(GeneratedSchedule(term: term, year: year, courses: pairs));
    return;
  }
  courses[index].sections.forEach((section) {
    final pair = CourseSectionPair(
        course: courses[index].copyWithoutSections(), section: section);
    if (pair.checkConflict(pairs)) return;
    generateSchedulesAux(
        term, year, courses, schedules, pairs + [pair], index + 1);
  });
}

void sortCourses(
    List<Course> courses, GeneratedSchedulePreferences preferences) {
  courses.forEach((course) => sortSections(course, preferences));
  courses.sort((a, b) {
    var sectionCountCompare = a.sections.length.compareTo(b.sections.length);
    if (sectionCountCompare != 0) return sectionCountCompare;
    return a.courseCode.compareTo(b.courseCode);
  });
}

void sortSections(Course course, GeneratedSchedulePreferences preferences) {
  double getAverageTime(Section section) {
    if (preferences.averageTime == null || section.meetings.isEmpty) return 0;
    return (preferences.averageTime! -
            section.meetings
                .map((meeting) => [
                      GeneratedSchedule.getTimeAsDouble(meeting.startTime),
                      GeneratedSchedule.getTimeAsDouble(meeting.endTime)
                    ].average)
                .average)
        .abs();
  }

  var sections = course.sections;
  if (sections.isEmpty) return;
  var maxAverageTime = sections.map(getAverageTime).max;
  var professorRankings = preferences.professorRankings[course.courseCode];

  double getSortValue(Section section) {
    final averageTimeScore =
        (preferences.averageTime != null && section.meetings.isNotEmpty)
            ? 1 - getAverageTime(section) / maxAverageTime
            : 0.0;
    final modalityScore =
        (preferences.preferOnline && section.meetings.isEmpty) ||
                (!preferences.preferOnline && section.meetings.isNotEmpty)
            ? 1.0
            : 0.0;
    final professorScore = ((professorRankings?.key ?? false) &&
            professorRankings!.value.length > 1)
        ? 2 *
            (1 -
                section.professors
                        .map((e) => professorRankings.value
                            .indexWhere((p) => p.key == e))
                        .min /
                    (professorRankings.value.length - 1))
        : 0.0;

    return [averageTimeScore, modalityScore, professorScore].sum;
  }

  sections.sort((a, b) => getSortValue(b).compareTo(getSortValue(a)));
}
