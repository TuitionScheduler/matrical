import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:icalendar/icalendar.dart';
import 'package:matrical/models/blacklist.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/department_course.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/models/generated_schedule_preferences.dart';
import 'package:matrical/models/saved_schedule.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/services/course_service.dart';
import 'package:pair/pair.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, int> dayOffsetMap = {
  "L": 0,
  "M": 1,
  "W": 2,
  "J": 3,
  "V": 4,
  "S": 5,
  "D": 6
};

int getFirstMonday(int month, int year) {
  DateTime firstDayOfMonth = DateTime(year, month, 1);
  // Calculate the day of the week for the first day of the month
  // where 1 = Monday, 2 = Tuesday, ..., 7 = Sunday
  int weekDay = firstDayOfMonth.weekday;
  // Calculate the date of the first Monday of the month
  // If the first day of the month is a Monday (1), then the first Monday is the 1st of the month
  // If the first day of the month is a Tuesday (2), then the first Monday is the 7th of the month
  int firstMonday = (weekDay == 1) ? 1 : 9 - weekDay;
  return firstMonday;
}

String? parseScheduleAsIcal(GeneratedSchedule schedule) {
  try {
    Term term = Term.fromString(schedule.term) ?? Term.getPredictedTerm();
    final year = schedule.year + term.getYearOffset();
    final ical = ICalendar(
      productIdentifier: ProductIdentifierProperty(
        "-//Matrical//Horario ${term.displayName} ${schedule.year}-${schedule.year + 1}//EN",
      ),
      version: VersionProperty(),
    );
    for (var pair in schedule.courses) {
      Course course = pair.course;
      Section section = pair.getSection();
      for (var meeting in section.meetings) {
        for (var day in meeting.days.characters) {
          List<String> startTime = meeting.startTime.split(":");
          List<String> endTime = meeting.endTime.split(":");
          DateTime startDateTime = DateTime(
              year,
              term.startMonth,
              getFirstMonday(term.startMonth, year) +
                  7 * (term.startWeek - 1) +
                  dayOffsetMap[day]!,
              int.parse(startTime[0]),
              int.parse(startTime[1]));
          DateTime endDateTime = DateTime(
              year,
              term.startMonth,
              getFirstMonday(term.startMonth, year) +
                  7 * (term.startWeek - 1) +
                  dayOffsetMap[day]!,
              int.parse(endTime[0]),
              int.parse(endTime[1]));

          ical.addComponent(
            EventComponent(
                dateTimeStamp: DateTimeStampProperty(DateTime.now()),
                uniqueIdentifier: UniqueIdentifierProperty(
                    value:
                        "Event-${course.courseCode}-${section.sectionCode}-${meeting.days}-${startDateTime.toIso8601String()}"), // Unique ID for the event
                summary: SummaryProperty(
                    "${course.courseCode}-${section.sectionCode}"),
                description: DescriptionProperty("""
                  Curso: ${course.courseName}
                  Salón: ${meeting.room}
                  Edificio: ${meeting.buildingName}
                  Profesores: ${section.professors.map((e) => e.name).join(", ")}
                  misc: ${section.misc}
                  """),
                dateTimeStart: DateTimeStartProperty(startDateTime),
                end: DateTimeEndProperty(endDateTime),
                location: LocationProperty(meeting.location ?? ""),
                recurrenceRules: [
                  RecurrenceRuleProperty(
                      frequency: RecurrenceFrequency.weekly,
                      count: term.durationInWeeks +
                          2) // Add in 2 weeks to account for possibly starting early
                ]),
          );
        }
      }
    }
    final icalText = ical.toString();
    return icalText;
  } catch (e) {
    print(e.toString()); // TODO: log
    return null;
  }
}

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

  for (var course in filteredCourses) {
    var preferencesProfessors =
        preferences.professorRankings[course.courseCode]?.value ?? [];
    preferencesProfessors.forEachIndexed((i, p) {
      preferencesProfessors[i] = Pair(p.key, false);
    });
  }
  for (var course in filteredCourses) {
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
  }

  sortCourses(filteredCourses, preferences);

  var result = await compute(generateSchedulesAux, {
    'term': term,
    'year': year,
    'filteredCourses': filteredCourses,
    'preferences': preferences,
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

List<GeneratedSchedule> generateSchedulesAux(Map<String, dynamic> params) {
  String term = params['term'];
  int year = params['year'];
  List<Course> filteredCourses = params['filteredCourses'];
  GeneratedSchedulePreferences preferences = params['preferences'];

  var schedules = <GeneratedSchedule>[];
  generateSchedulesRecursive(term, year, filteredCourses, schedules, [], 0);
  schedules.removeWhere((e) => e.courses.isEmpty);
  GeneratedSchedule.sortGeneratedSchedules(schedules, preferences);
  return schedules;
}

void generateSchedulesRecursive(
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
  for (var section in courses[index].sections) {
    final pair = CourseSectionPair(
        course: courses[index].copyWithoutSections(), section: section);
    if (pair.checkConflict(pairs)) continue;
    generateSchedulesRecursive(
        term, year, courses, schedules, pairs + [pair], index + 1);
  }
}

void sortCourses(
    List<Course> courses, GeneratedSchedulePreferences preferences) {
  for (var course in courses) {
    sortSections(course, preferences);
  }
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

Future<List<SavedSchedule>> getSavedSchedules() async {
  var cache = await SharedPreferences.getInstance();
  return await compute((_) {
    return cache
            .getStringList("MySchedules")
            ?.map((scheduleString) => SavedSchedule.fromString(scheduleString))
            .toList() ??
        [];
  }, null);
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
