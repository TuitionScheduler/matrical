import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CourseFilters {
  List<String> professors;
  String earliestTime;
  String latestTime;
  String days;
  Modality modality;
  List<String> rooms;

  CourseFilters(
      {required this.professors,
      required this.earliestTime,
      required this.latestTime,
      required this.days,
      required this.modality,
      required this.rooms});

  CourseFilters.empty(
      {this.professors = const [],
      this.earliestTime = '',
      this.latestTime = '',
      this.days = '',
      this.modality = Modality.any,
      this.rooms = const []});

  // Convert CourseFilters to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'professors': professors,
      'earliestTime': earliestTime,
      'latestTime': latestTime,
      'days': days,
      'modality': modality.toJson(),
      'rooms': rooms,
    };
  }

  // Convert JSON Map to CourseFilters
  static CourseFilters fromJson(Map<String, dynamic> json) {
    return CourseFilters(
      professors: List<String>.from(json['professors']),
      earliestTime: json['earliestTime'],
      latestTime: json['latestTime'],
      days: json['days'],
      modality: Modality.fromJson(json['modality']),
      rooms: List<String>.from(json['rooms']),
    );
  }

  CourseFilters copy() {
    return CourseFilters.fromJson(toJson());
  }
}

class CourseWithFilters {
  String courseCode;
  String sectionCode;
  CourseFilters filters;

  CourseWithFilters(
      {required this.courseCode,
      required this.sectionCode,
      required this.filters});

  CourseWithFilters.withoutFilters(
      {required this.courseCode, required this.sectionCode})
      : filters = CourseFilters.empty();

  // Convert CourseWithFilters to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'courseCode': courseCode,
      'sectionCode': sectionCode,
      'filters': filters.toJson(),
    };
  }

  // Convert JSON Map to CourseWithFilters
  static CourseWithFilters fromJson(Map<String, dynamic> json) {
    return CourseWithFilters(
      courseCode: json['courseCode'],
      sectionCode: json['sectionCode'],
      filters: CourseFilters.fromJson(json['filters']),
    );
  }
}

enum Modality {
  remoteSynchronous(databaseName: "Remoto Sincrónico", letterCodes: ["E"]),
  remoteAsynchronous(databaseName: "Remoto Asincrónico", letterCodes: ["D"]),
  hybrid(databaseName: "Híbrido", letterCodes: ["H"]),
  inperson(databaseName: "Presencial", letterCodes: ["", "L"]),
  byagreement(databaseName: "Por Acuerdo", letterCodes: ["P", "R", "#", "D"]),
  any(
      databaseName: "Cualquiera",
      letterCodes: ["E", "D", "H", "", "P", "R", "#", "L"]);

  const Modality({required this.databaseName, required this.letterCodes});
  final String
      databaseName; // TODO(poggecci): make the db name something neater rather than just the spanish display name
  final List<String> letterCodes;

  // Convert Modality to JSON
  String toJson() => databaseName;

  // Convert JSON to Modality
  static Modality fromJson(String json) {
    return Modality.values.firstWhere(
      (modality) => modality.databaseName == json,
      orElse: () => Modality.any, // Default value if not found
    );
  }

  // Get the display name for the modality (differs from db name due to intl)
  String displayName(BuildContext context) {
    switch (this) {
      case Modality.remoteSynchronous:
        return AppLocalizations.of(context)!.remoteSynchronous;
      case Modality.remoteAsynchronous:
        return AppLocalizations.of(context)!.remoteAsynchronous;
      case Modality.hybrid:
        return AppLocalizations.of(context)!.hybrid;
      case Modality.inperson:
        return AppLocalizations.of(context)!.inperson;
      case Modality.byagreement:
        return AppLocalizations.of(context)!.byagreement;
      case Modality.any:
        return AppLocalizations.of(context)!.any;
    }
  }
}
