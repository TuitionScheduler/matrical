import 'package:flutter/cupertino.dart';
import 'package:matrical/models/saved_schedule.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

int byNameSort(SavedSchedule a, SavedSchedule b) {
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

int mostRecentSort(SavedSchedule a, SavedSchedule b) {
  return b.lastUpdated.compareTo(a.lastUpdated);
}

int leastRecentSort(SavedSchedule a, SavedSchedule b) {
  return a.lastUpdated.compareTo(b.lastUpdated);
}

enum SortKind {
  mostRecent(sortFunction: mostRecentSort),
  leastRecent(sortFunction: leastRecentSort),
  byName(sortFunction: byNameSort);

  const SortKind({required this.sortFunction});
  final int Function(SavedSchedule, SavedSchedule) sortFunction;

  String displayName(BuildContext context) {
    switch (this) {
      case SortKind.mostRecent:
        return AppLocalizations.of(context)!.mostRecent;
      case SortKind.leastRecent:
        return AppLocalizations.of(context)!.leastRecent;
      case SortKind.byName:
        return AppLocalizations.of(context)!.byName;
    }
  }
}

class SavedSchedulesOptions {
  final TextEditingController searchController;
  Term? term;
  int? year;
  SortKind? selectedSort;

  SavedSchedulesOptions({
    required this.searchController,
    required this.term,
    required this.year,
    required this.selectedSort,
  });

  static SavedSchedulesOptions empty() {
    return SavedSchedulesOptions(
        searchController: TextEditingController(),
        term: null,
        year: null,
        selectedSort: null);
  }
}
