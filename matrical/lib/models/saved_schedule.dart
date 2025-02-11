import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SavedSchedule {
  final String name;
  final DateTime dateCreated;
  final DateTime lastUpdated;
  final GeneratedSchedule schedule;

  SavedSchedule(
      {required this.name,
      required this.dateCreated,
      required this.lastUpdated,
      required this.schedule});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dateCreated': dateCreated.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'schedule': schedule.toJson(),
    };
  }

  static SavedSchedule fromJson(Map<String, dynamic> json) {
    return SavedSchedule(
      name: json['name'],
      dateCreated: DateTime.parse(json['dateCreated']),
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? json['dateCreated']),
      schedule: GeneratedSchedule.fromJson(json['schedule']),
    );
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  static SavedSchedule fromString(String jsonString) {
    return fromJson(jsonDecode(jsonString));
  }
}

enum SaveScheduleResult {
  success,
  hitScheduleLimit,
  failedWrite,
  overwriteExisting,
  alreadyExists,
  emptyName;

  String message(BuildContext context) {
    switch (this) {
      case SaveScheduleResult.success:
        return AppLocalizations.of(context)!.saveScheduleSuccess;
      case SaveScheduleResult.hitScheduleLimit:
        return AppLocalizations.of(context)!.saveScheduleHitLimit;
      case SaveScheduleResult.failedWrite:
        return AppLocalizations.of(context)!.saveScheduleFailedWrite;
      case SaveScheduleResult.alreadyExists:
        return AppLocalizations.of(context)!.saveScheduleAlreadyExists;
      case SaveScheduleResult.overwriteExisting:
        return AppLocalizations.of(context)!.saveScheduleOverwriteExisting;
      case SaveScheduleResult.emptyName:
        return AppLocalizations.of(context)!.saveScheduleEmptyName;
    }
  }
}
