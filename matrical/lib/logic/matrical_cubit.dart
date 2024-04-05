import 'package:bloc/bloc.dart';
import 'package:miuni/features/matrical/Logic/matrical_state.dart';

class MatricalCubit extends Cubit<MatricalState> {
  MatricalCubit()
      : super(const MatricalState(
          initial: true,
          fetchingCourses: false,
          generationOptions: false,
          noSchedulesFound: false,
          viewingSchedules: false,
          exportingSchedules: false,
          editingSchedule: false,
        ));

  ///initial state
  void initial({required bool homePage}) {
    emit(state.copyWith(
      initial: true,
      fetchingCourses: false,
      generationOptions: false,
      noSchedulesFound: false,
      viewingSchedules: false,
      exportingSchedules: false,
      editingSchedule: false,
    ));
  }
}
