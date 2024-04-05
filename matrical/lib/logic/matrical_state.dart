import 'package:equatable/equatable.dart';

class MatricalState extends Equatable {
  /// when start or the map is press
  final bool initial;
  final bool fetchingCourses;
  final bool generationOptions;
  final bool noSchedulesFound;
  final bool viewingSchedules;
  final bool exportingSchedules;
  final bool editingSchedule;

  const MatricalState({
    required this.initial,
    required this.fetchingCourses,
    required this.generationOptions,
    required this.noSchedulesFound,
    required this.viewingSchedules,
    required this.exportingSchedules,
    required this.editingSchedule,
  });

  MatricalState copyWith({
    bool? initial,
    bool? fetchingCourses,
    bool? generationOptions,
    bool? noSchedulesFound,
    bool? viewingSchedules,
    bool? exportingSchedules,
    bool? editingSchedule,
  }) {
    return MatricalState(
      initial: initial ?? this.initial,
      fetchingCourses: fetchingCourses ?? this.fetchingCourses,
      generationOptions: generationOptions ?? this.generationOptions,
      noSchedulesFound: noSchedulesFound ?? this.noSchedulesFound,
      viewingSchedules: viewingSchedules ?? this.viewingSchedules,
      exportingSchedules: exportingSchedules ?? this.exportingSchedules,
      editingSchedule: editingSchedule ?? this.editingSchedule,
    );
  }

  @override
  List<Object?> get props => [
        initial,
        fetchingCourses,
        generationOptions,
        noSchedulesFound,
        viewingSchedules,
        exportingSchedules,
        editingSchedule,
      ];
}
