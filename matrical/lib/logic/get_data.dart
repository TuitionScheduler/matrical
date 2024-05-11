import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:miuni/features/matrical/data/model/course_filters.dart';
import 'package:miuni/features/matrical/data/model/department_course.dart';
import 'package:miuni/features/matrical/data/course_service.dart';
import 'package:miuni/features/matrical/data/model/blacklist.dart';

Future<List<Course>> getCourseSearch(
    String search, String term, int year, CourseFilters filters) async {
  final CourseService cs = CourseService.getInstance();
  var coursesOrDepts = search.split(",");
  var courses = <Course>[];
  for (var courseOrDept in coursesOrDepts) {
    var formatted = courseOrDept.trim().toUpperCase();
    switch (formatted.length) {
      case 0:
        //Empty string was passed in
        break;
      case 4:
        var dept = await cs.getDepartment(formatted, term, year);
        if (dept != null) {
          courses.addAll(dept.courses.values);
        }
        break;
      case 8:
        var course = await cs.getCourse(formatted, term, year);
        if (course != null) {
          courses.add(course);
        }
        break;
      default:
        throw Exception("Value is not course or department");
    }
  }
  return await Isolate.run(() {
    return applyFiltersToAll(courses, filters);
  });
}

List<Course> applyFiltersToAll(List<Course> courses, CourseFilters filters) {
  List<Course> result =
      courses.map((course) => applyFilters(course, filters)).toList();
  result.removeWhere((course) => course.sections.isEmpty);
  return result;
}

Course applyFilters(Course course, CourseFilters filters) {
  var copy = course.copy();
  var sections = <Section>[];
  for (var section in course.sections) {
    if (!filters.modality.letterCodes.any((code) => code == section.modality)) {
      continue;
    }
    if (filters.professors.isNotEmpty &&
        !filters.professors.any((filterProfessor) => section.professors.any(
            (sectionProfessor) => sectionProfessor.name
                .toLowerCase()
                .replaceAll(" ", "")
                .contains(
                    filterProfessor.toLowerCase().replaceAll(" ", ""))))) {
      continue;
    }
    if (filters.rooms.isNotEmpty &&
        !filters.rooms.any((room) => section.meetings.any((meeting) => meeting
            .room
            .toLowerCase()
            .replaceAll(" ", "")
            .startsWith(room.toLowerCase().replaceAll(" ", ""))))) {
      continue;
    }
    var satisfies = true;
    for (var meeting in section.meetings) {
      if (filters.earliestTime != "" &&
          meeting.startTime != "" &&
          meeting.startTime.compareTo(filters.earliestTime) < 0) {
        satisfies = false;
        break;
      }
      if (filters.latestTime != "" &&
          meeting.endTime != "" &&
          meeting.endTime.compareTo(filters.latestTime) > 0) {
        satisfies = false;
        break;
      }
      if (filters.days != "" && meeting.days != "") {
        var acceptedDays = <String>{};
        acceptedDays.addAll(filters.days.characters);
        if (!acceptedDays.containsAll(meeting.days.characters)) {
          satisfies = false;
          break;
        }
      }
    }
    if (satisfies) sections.add(section);
  }
  copy.sections = sections;
  return copy;
}

Course applyBlacklist(Course course, Blacklist blacklist) {
  var copy = course.copy();
  copy.sections.removeWhere((section) => section.professors.any((professor) =>
      blacklist.professors
          .any((blockedProfessor) => professor.name == blockedProfessor.name)));
  if (blacklist.sections[copy.courseCode] != null) {
    copy.sections.removeWhere((section) =>
        blacklist.sections[copy.courseCode]!.contains(section.sectionCode));
  }
  return copy;
}
