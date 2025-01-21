import 'dart:convert';
import 'dart:core';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Department {
  String department;
  String term;
  int year;
  Map<String, Course> courses;
  Department(
      {required this.department,
      required this.term,
      required this.year,
      required this.courses});

  static Department fromJson(Map<String, dynamic> json) => Department(
      department: json["department"],
      term: json["term"],
      year: json["year"],
      courses: Map<String, Course>.from(json["courses"]
          .map((name, course) => MapEntry(name, Course.fromJson(course)))));

  Map<String, dynamic> toJson() => {
        "department": department,
        "term": term,
        "year": year,
        "courses":
            courses.map((name, course) => MapEntry(name, course.toJson())),
      };

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  static Department deserialize(String source) {
    return Department.fromJson(jsonDecode(source));
  }

  Department copy() {
    return Department.fromJson(toJson());
  }
}

class Course {
  String courseCode;
  String term;
  int year;
  String courseName;
  String department;
  String prerequisites;
  String corequisites;
  int credits;
  bool hasIntegratedLab;
  String division;
  List<Section> sections;

  Course({
    required this.courseCode,
    required this.year,
    required this.term,
    required this.courseName,
    required this.department,
    required this.prerequisites,
    required this.corequisites,
    required this.credits,
    required this.hasIntegratedLab,
    required this.division,
    required this.sections,
  });

  static Course fromJson(Map<String, dynamic> json) => Course(
        courseCode: json['courseCode'],
        year: json['year'],
        term: json['term'],
        courseName: json['courseName'],
        department: json['department'],
        prerequisites: json['prerequisites'],
        corequisites: json['corequisites'],
        credits: json['credits'],
        hasIntegratedLab: json['hasIntegratedLab'],
        division: json['division'],
        sections: json['sections']
            .map((section) => Section.fromJson(section))
            .toList()
            .cast<Section>(),
      );

  Map<String, dynamic> toJson() => {
        'courseCode': courseCode,
        'year': year,
        'term': term,
        'courseName': courseName,
        'department': department,
        'prerequisites': prerequisites,
        'corequisites': corequisites,
        'credits': credits,
        'hasIntegratedLab': hasIntegratedLab,
        'division': division,
        'sections': sections.map((section) => section.toJson()).toList(),
      };

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  static Course deserialize(String source) {
    return Course.fromJson(jsonDecode(source));
  }

  Course copy() {
    return Course.fromJson(toJson());
  }

  Course copyWithoutSections() {
    return Course(
      courseCode: courseCode,
      year: year,
      term: term,
      courseName: courseName,
      department: department,
      prerequisites: prerequisites,
      corequisites: corequisites,
      credits: credits,
      hasIntegratedLab: hasIntegratedLab,
      division: division,
      sections: [],
    );
  }
}

class Section {
  String sectionCode;
  List<Meeting> meetings;
  String modality;
  int capacity;
  int usage;
  bool reserved;
  List<Professor> professors;
  String misc;

  Section({
    required this.sectionCode,
    required this.meetings,
    required this.modality,
    required this.capacity,
    required this.usage,
    required this.reserved,
    required this.professors,
    required this.misc,
  });

  static Section fromJson(Map<String, dynamic> json) => Section(
        sectionCode: json['sectionCode'],
        meetings: json['meetings']
            .map((schedule) => Meeting.parseMeeting(schedule))
            .toList()
            .cast<Meeting>(),
        //(Schedule.parseSchedule(json['meetings']) as List).cast<Schedule>(),
        modality: json['modality'],
        capacity: json['capacity'],
        usage: json['usage'],
        reserved: json['reserved'],
        professors: json['professors']
            .map((professor) => Professor.fromJson(professor))
            .toList()
            .cast<Professor>(),
        misc: json['misc'],
      );

  Map<String, dynamic> toJson() => {
        'sectionCode': sectionCode,
        'meetings': meetings.map((schedule) => schedule.toString()).toList(),
        'modality': modality,
        'capacity': capacity,
        'usage': usage,
        'reserved': reserved,
        'professors':
            professors.map((professor) => professor.toJson()).toList(),
        'misc': misc,
      };
}

class Meeting {
  String startTime;
  String endTime;
  String days;
  String room;

  Meeting(
      {required this.startTime,
      required this.endTime,
      required this.days,
      required this.room});

  static const codeToBuilding = {
    "AE": [
      "Administración de Empresas",
      "https://goo.gl/maps/uS2sHKErq9muJFx6A"
    ],
    "B": ["Edificio de Biología", "https://goo.gl/maps/zpv6MvfdXoqa7rgk8"],
    "CM": [
      "Coliseo Rafael A. Mangual",
      "https://goo.gl/maps/baEHaSvSh26HCUhE7"
    ],
    "SH": ["Edificio Sánchez Hidalgo", "https://goo.gl/maps/8iS2bC8soAaMoBLa7"],
    "CH": ["Edificio Chardón", "https://goo.gl/maps/ddVvr6hn7ruASTyq5"],
    "P": ["Edificio Jesus T. Piñero", "https://goo.gl/maps/R6svtNVmXsYARLzg8"],
    "C": [
      "Edificio Luis de Celis (Admisiones, Decanato de Artes y Ciencias, Estudios Graduados)",
      "https://goo.gl/maps/XZx55dhZyMqDPWod8"
    ],
    "M": ["Edificio Luis Monzón", "https://goo.gl/maps/a9NSqMrefSYTd9FT7"],
    "S": ["Edificio Luis Stefani", "https://goo.gl/maps/2HMQ8G7x7mKHxhzUA"],
    "EE": [
      "Edificio Josefina Torres Torres (Enfermería)",
      "https://goo.gl/maps/YMycT3STYfGJmLnc6"
    ],
    "T": [
      "Edificio Terrats (Finanzas y Pagaduría)",
      "https://goo.gl/maps/1ELvbbPMCCDCKxvEA"
    ],
    "AZ": ["Finca Alzamora", "https://goo.gl/maps/3WfKd3Bj7rCXdBHT6"],
    "F": [
      "Física, Geología y Ciencias Marinas",
      "https://goo.gl/maps/LMNsrKzhhRJQ1ew9A"
    ],
    "GE": ["Gimnasio Ángel F. Espada", "https://goo.gl/maps/2CMaZ8948wqkYVJw5"],
    "II": [
      "Edificio de Ingeniería Industrial",
      "https://goo.gl/maps/7a9BEDauP18CeF7e7"
    ],
    "CI": [
      "Edificio de Ingeniería Civil",
      "https://goo.gl/maps/FMMqC4aSRPwTFr5n9"
    ],
    "L": ["Edificio Antonio Luchetti", "https://goo.gl/maps/FQq3U97Ujf9CGMJz5"],
    "IQ": [
      "Edificio de Ingeniería Química",
      "https://goo.gl/maps/aunAi3yfDsh1VbQt6"
    ],
    "Q": ["Edificio de Química", "https://goo.gl/maps/ufTZdT6q52i4bTAy9"],
    "SA": ["ROTC", "https://goo.gl/maps/tqmxZpN2g138SMma8"],
  };
  String? get buildingName {
    return codeToBuilding[room.split(" ").firstOrNull]?[0];
  }

  String? get location {
    return codeToBuilding[room.split(" ").firstOrNull]?[1];
  }

  static Meeting parseMeeting(String input) {
    RegExpMatch? match =
        RegExp(r'(\d+:\d+ [apm]{2}) - (\d+:\d+ [apm]{2}) (\w+)')
            .firstMatch(input);

    if (match == null) {
      return Meeting(startTime: "", endTime: "", days: "", room: "");
    }

    String startTime = convertTo24HourFormat(match.group(1)!);
    String endTime = convertTo24HourFormat(match.group(2)!);
    String days = match.group(3)!;
    String room = "";

    match = RegExp(r'(\w+ \d+)').firstMatch(input);
    if (match != null) {
      room = match.group(1)!;
    }

    return Meeting(
        startTime: startTime, endTime: endTime, days: days, room: room);
  }

  static String convertTo24HourFormat(String time) {
    // Split the time into hours, minutes, and am/pm
    List<String> parts = time.split(' ');
    List<String> timeParts = parts[0].split(':');

    // Convert to 24-hour format
    int hours = int.parse(timeParts[0]);
    int minutes = int.parse(timeParts[1]);

    if (parts[1].toLowerCase() == 'pm' && hours < 12) {
      hours += 12;
    } else if (parts[1].toLowerCase() == 'am' && hours == 12) {
      hours = 0;
    }

    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
  }

  @override
  String toString() {
    if (startTime == "" && endTime == "") {
      return ""; // TODO: Add logging because this implies a scraping issue.
    }
    // Convert start and end times from 24-hour to 12-hour format
    String startTime12Hour = convertTo12HourFormat(startTime);
    String endTime12Hour = convertTo12HourFormat(endTime);

    // Format the meeting string
    // Assuming room might be empty and should be appended only if present
    String meetingString = "$startTime12Hour - $endTime12Hour $days";
    if (room.isNotEmpty) {
      meetingString += " $room";
    }

    return meetingString;
  }

  static String convertTo12HourFormat(String time24Hour) {
    // Split the time into hours and minutes
    List<String> parts = time24Hour.split(':');
    int hours = int.parse(parts[0]);
    String minutes = parts[1];
    String meridian = 'am';

    if (hours >= 12) {
      meridian = 'pm';
      if (hours > 12) {
        hours -= 12;
      }
    } else if (hours == 0) {
      hours = 12;
    }

    return "$hours:$minutes $meridian";
  }

  static int compareTime(String time, String other) {
    return time.compareTo(other);
  }

  bool intersects(Meeting other) {
    return compareTime(startTime, other.startTime) >= 0 &&
            compareTime(startTime, other.endTime) <= 0 ||
        compareTime(other.startTime, startTime) >= 0 &&
            compareTime(other.startTime, endTime) <= 0;
  }
}

class Professor {
  String name;
  String url;

  Professor({required this.name, required this.url});

  Map<String, dynamic> toJson() => {
        "name": name,
        "url": url,
      };

  static Professor fromJson(Map<String, dynamic> json) => Professor(
        name: json["name"],
        url: json["url"],
      );

  @override
  bool operator ==(other) {
    if (other is! Professor) return false;
    return name == other.name;
  }

  @override
  int get hashCode => name.hashCode;
}

enum Division {
  lowerDivision(databaseValue: "LowerDivsion"),
  upperDivision(databaseValue: "UpperDivison"),
  graduate(databaseValue: "Graduate");

  const Division({required this.databaseValue});
  final String databaseValue;

  String displayName(BuildContext context) {
    switch (this) {
      case Division.lowerDivision:
        return AppLocalizations.of(context)!.divisionLower;
      case Division.upperDivision:
        return AppLocalizations.of(context)!.divisionUpper;
      case Division.graduate:
        return AppLocalizations.of(context)!.divisionGraduate;
    }
  }

  static Division fromDatabase(String div) {
    return Division.values
            .firstWhereOrNull((element) => element.databaseValue == div) ??
        Division.lowerDivision;
  }
}
