import 'package:flutter/material.dart';
import 'package:miuni/features/matrical/data/model/department_course.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule.dart';
import 'package:icalendar/icalendar.dart';
import 'package:miuni/features/matrical/data/model/schedule_generation_options.dart';

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

String parseScheduleAsIcal(GeneratedSchedule schedule) {
  Term term = Term.fromString(schedule.term) ?? Term.getPredictedTerm();
  final year = schedule.year + term.getYearOffset();
  final ical = ICalendar(
    productIdentifier: ProductIdentifierProperty(
      "-//MiUni//Horario ${term.displayName} ${schedule.year}-${schedule.year + 1}//EN",
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
}
