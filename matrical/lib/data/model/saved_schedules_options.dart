import 'package:flutter/cupertino.dart';
import 'package:miuni/features/matrical/data/model/schedule_generation_options.dart';

class SavedSchedulesOptions {
  final TextEditingController searchController;
  Term? term;
  int? year;
  final TextEditingController sortingController;

  SavedSchedulesOptions({
    required this.searchController,
    required this.term,
    required this.year,
    required this.sortingController,
  });

  static SavedSchedulesOptions empty() {
    return SavedSchedulesOptions(
        searchController: TextEditingController(),
        term: null,
        year: null,
        sortingController: TextEditingController());
  }
}
