import 'dart:convert';
import 'package:miuni/features/matrical/data/model/generated_schedule.dart';

//TODO: migrate away from Generated Schedule to reduce memory footprint
class SavedSchedule {
  final String name;
  final DateTime dateCreated;
  final GeneratedSchedule schedule;

  SavedSchedule(
      {required this.name, required this.dateCreated, required this.schedule});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dateCreated': dateCreated.toIso8601String(),
      'schedule': schedule.toJson(),
    };
  }

  static SavedSchedule fromJson(Map<String, dynamic> json) {
    return SavedSchedule(
      name: json['name'],
      dateCreated: DateTime.parse(json['dateCreated']),
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
  success("Horario guardado exitosamente!"),
  hitScheduleLimit(
      "Límite de horarios alcanzado (300).\nBorra algunos horarios."),
  failedWrite("Hubo un problema guardando el horario.\nIntente otra vez."),
  alreadyExists("Ya hay un horario con este nombre."),
  emptyName("Horario debe tener un nombre.");

  final String message;

  const SaveScheduleResult(this.message);
}
