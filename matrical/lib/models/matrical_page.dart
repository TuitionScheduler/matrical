// Don't change enum value order without updating widget order in Matrical scaffold body accordingly
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum MatricalPage {
  courseSelect,
  courseSearch,
  savedSchedules,
  generatedSchedules;

  String displayName(BuildContext context) {
    switch (this) {
      case MatricalPage.courseSelect:
        return AppLocalizations.of(context)!.courseSelect;
      case MatricalPage.courseSearch:
        return AppLocalizations.of(context)!.courseSearch;
      case MatricalPage.savedSchedules:
        return AppLocalizations.of(context)!.savedSchedules;
      case MatricalPage.generatedSchedules:
        return AppLocalizations.of(context)!.generatedSchedules;
    }
  }
}
