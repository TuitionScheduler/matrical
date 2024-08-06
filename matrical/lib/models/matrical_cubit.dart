import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:matrical/models/blacklist.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/generated_schedule_preferences.dart';
import 'package:matrical/models/matrical_page.dart';
import 'package:matrical/models/saved_schedules_options.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/services/course_service.dart';

class MatricalCubit extends Cubit<MatricalState> {
  MatricalCubit()
      : super(MatricalState(
          selectedCourses: const [],
          term: Term.getPredictedTerm(),
          year: Term.getPredictedYear(),
          preferences: GeneratedSchedulePreferences.getDefault(),
          pageIndex: 0,
          pageTitle: "Selección de Cursos",
          courseController: TextEditingController(),
          sectionController: TextEditingController(),
          searchFilters: CourseFilters.empty(),
          lastSearch: null,
          savedSchedulesOptions: SavedSchedulesOptions.empty(),
          blacklist: Blacklist.empty(),
          generatedSchedulesFilters: CourseFilters.empty(),
          generatedSchedulesEditMode: false,
          generatedSchedulesCurrentPreferencesTab: 0,
        ));

  /// Initialize with default values
  void initialize(
      List<CourseWithFilters> courses,
      Term term,
      int year,
      GeneratedSchedulePreferences preferences,
      int pageIndex,
      String pageTitle,
      TextEditingController courseController,
      TextEditingController sectionController,
      CourseFilters searchFilters,
      String? lastSearch,
      SavedSchedulesOptions savedSchedulesOptions,
      Blacklist blacklist,
      CourseFilters generatedSchedulesFilters,
      bool generatedSchedulesEditMode,
      int generatedSchedulesCurrentPreferencesTab) {
    emit(MatricalState(
      selectedCourses: courses,
      term: term,
      year: year,
      preferences: preferences,
      pageIndex: pageIndex,
      pageTitle: pageTitle,
      courseController: courseController,
      sectionController: sectionController,
      searchFilters: searchFilters,
      lastSearch: lastSearch,
      savedSchedulesOptions: savedSchedulesOptions,
      blacklist: blacklist,
      generatedSchedulesFilters: generatedSchedulesFilters,
      generatedSchedulesEditMode: generatedSchedulesEditMode,
      generatedSchedulesCurrentPreferencesTab:
          generatedSchedulesCurrentPreferencesTab,
    ));
  }

  void updateCourses(List<CourseWithFilters> newCourses) {
    emit(state.copyWith(selectedCourses: newCourses));
  }

  // Adds new courses to the existing list
  void addCourse(String courseCode, String sectionCode,
      {CourseFilters? filters}) {
    final copy = List.of(state.selectedCourses);
    final courseWithFilters = CourseWithFilters(
        courseCode: courseCode,
        sectionCode: sectionCode,
        filters: filters?.copy() ?? CourseFilters.empty());
    for (final (i, element) in copy.indexed) {
      if (element.courseCode == courseCode) {
        bool isLab = sectionCode.isNotEmpty &&
            sectionCode.length > 3 &&
            sectionCode.endsWith("L");
        bool otherIsLab = element.sectionCode.isNotEmpty &&
            element.sectionCode.length > 3 &&
            element.sectionCode.endsWith("L");
        if (isLab == otherIsLab) {
          copy[i] = courseWithFilters;
          emit(state.copyWith(selectedCourses: copy));
          return;
        }
      }
    }
    copy.add(courseWithFilters);
    emit(state.copyWith(selectedCourses: copy));
  }

  // Clears courses and sections that do not belong to the new term/year
  Future<bool> onTermYearChanged() async {
    final courses = <CourseWithFilters>[];
    bool removedAny = false;
    final courseService = CourseService.getInstance();
    for (var c in state.selectedCourses) {
      final course = await courseService.getCourse(
          c.courseCode, state.term.databaseKey, state.year);
      if (course == null) {
        removedAny = true;
      } else if (c.sectionCode.isNotEmpty &&
          !course.sections.any((s) => c.sectionCode == s.sectionCode)) {
        courses.add(CourseWithFilters(
            courseCode: c.courseCode, sectionCode: "", filters: c.filters));
        removedAny = true;
      } else {
        courses.add(c);
      }
    }
    emit(state.copyWith(selectedCourses: courses));
    return removedAny;
  }

  void removeCourse(int index) {
    final copy = List.of(state.selectedCourses);
    copy.removeAt(index);
    emit(state.copyWith(selectedCourses: copy));
  }

  void removeSection(int index) {
    final copy = List.of(state.selectedCourses);
    copy[index] = CourseWithFilters(
        courseCode: copy[index].courseCode,
        sectionCode: "",
        filters: copy[index].filters);
    emit(state.copyWith(selectedCourses: copy));
  }

  // Updates the term
  void updateTerm(Term newTerm) {
    emit(state.copyWith(term: newTerm));
  }

  // Updates the year
  void updateYear(int newYear) {
    emit(state.copyWith(year: newYear));
  }

  // Updates the preferences
  void updatePreferences(GeneratedSchedulePreferences newPreferences) {
    emit(state.copyWith(preferences: newPreferences));
  }

  void setPage(MatricalPage page) {
    emit(state.copyWith(pageIndex: page.index, pageTitle: page.displayName));
  }

  void setLastSearch(String? search) {
    emit(state.copyWith(lastSearch: search));
  }

  void updateBlacklist(Blacklist newBlacklist) {
    emit(state.copyWith(blacklist: newBlacklist));
  }

  void setGeneratedSchedulesEditMode(bool editMode) {
    emit(state.copyWith(generatedSchedulesEditMode: editMode));
  }

  void setGeneratedSchedulesCurrentPreferencesTab(int currentPreferencesTab) {
    emit(state.copyWith(
        generatedSchedulesCurrentPreferencesTab: currentPreferencesTab));
  }
}

class MatricalState extends Equatable {
  final List<CourseWithFilters> selectedCourses;
  final Term term;
  final int year;
  final GeneratedSchedulePreferences preferences;
  final int pageIndex;
  final String pageTitle;
  final TextEditingController courseController;
  final TextEditingController sectionController;
  final CourseFilters searchFilters;
  final String? lastSearch;
  final SavedSchedulesOptions savedSchedulesOptions;
  final Blacklist blacklist;
  final CourseFilters generatedSchedulesFilters;
  final bool generatedSchedulesEditMode;
  final int generatedSchedulesCurrentPreferencesTab;

  const MatricalState({
    required this.selectedCourses,
    required this.term,
    required this.year,
    required this.preferences,
    required this.pageIndex,
    required this.pageTitle,
    required this.courseController,
    required this.sectionController,
    required this.searchFilters,
    required this.lastSearch,
    required this.savedSchedulesOptions,
    required this.blacklist,
    required this.generatedSchedulesFilters,
    required this.generatedSchedulesEditMode,
    required this.generatedSchedulesCurrentPreferencesTab,
  });

  MatricalState copyWith({
    List<CourseWithFilters>? selectedCourses,
    Term? term,
    int? year,
    GeneratedSchedulePreferences? preferences,
    int? pageIndex,
    String? pageTitle,
    TextEditingController? courseController,
    TextEditingController? sectionController,
    CourseFilters? searchFilters,
    String? lastSearch,
    SavedSchedulesOptions? savedSchedulesOptions,
    Blacklist? blacklist,
    CourseFilters? generatedSchedulesFilters,
    bool? generatedSchedulesEditMode,
    int? generatedSchedulesCurrentPreferencesTab,
  }) {
    return MatricalState(
      selectedCourses: selectedCourses ?? this.selectedCourses,
      term: term ?? this.term,
      year: year ?? this.year,
      preferences: preferences ?? this.preferences,
      pageIndex: pageIndex ?? this.pageIndex,
      pageTitle: pageTitle ?? this.pageTitle,
      courseController: courseController ?? this.courseController,
      sectionController: sectionController ?? this.sectionController,
      searchFilters: searchFilters ?? this.searchFilters,
      lastSearch: lastSearch ?? this.lastSearch,
      savedSchedulesOptions:
          savedSchedulesOptions ?? this.savedSchedulesOptions,
      blacklist: blacklist ?? this.blacklist,
      generatedSchedulesFilters:
          generatedSchedulesFilters ?? this.generatedSchedulesFilters,
      generatedSchedulesEditMode:
          generatedSchedulesEditMode ?? this.generatedSchedulesEditMode,
      generatedSchedulesCurrentPreferencesTab:
          generatedSchedulesCurrentPreferencesTab ??
              this.generatedSchedulesCurrentPreferencesTab,
    );
  }

  @override
  List<Object?> get props => [
        selectedCourses,
        term,
        year,
        preferences,
        pageIndex,
        pageTitle,
        courseController,
        sectionController,
        searchFilters,
        lastSearch,
        savedSchedulesOptions,
        blacklist,
        generatedSchedulesFilters,
        generatedSchedulesEditMode,
        generatedSchedulesCurrentPreferencesTab,
      ];
}
