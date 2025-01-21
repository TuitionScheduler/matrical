import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum Term {
  fall(databaseKey: "Fall", startMonth: 8, durationInWeeks: 16, startWeek: 2),
  spring(
      databaseKey: "Spring", startMonth: 1, durationInWeeks: 16, startWeek: 2),
  firstSummer(
      databaseKey: "FirstSummer",
      startMonth: 6,
      durationInWeeks: 4,
      startWeek: 1),
  secondSummer(
      databaseKey: "SecondSummer",
      startMonth: 7,
      durationInWeeks: 4,
      startWeek: 1),
  extendedSummer(
      databaseKey: "ExtendedSummer",
      startMonth: 6,
      durationInWeeks: 6,
      startWeek: 1);

  const Term(
      {required this.databaseKey,
      required this.startMonth,
      required this.durationInWeeks,
      required this.startWeek});

  final String databaseKey;
  final int startMonth;
  final int durationInWeeks;
  final int startWeek;

  String displayName(BuildContext context) {
    switch (this) {
      case Term.fall:
        return AppLocalizations.of(context)!.termFall;
      case Term.spring:
        return AppLocalizations.of(context)!.termSpring;
      case Term.firstSummer:
        return AppLocalizations.of(context)!.termFirstSummer;
      case Term.secondSummer:
        return AppLocalizations.of(context)!.termSecondSummer;
      case Term.extendedSummer:
        return AppLocalizations.of(context)!.termExtendedSummer;
    }
  }

  int getYearOffset() {
    return databaseKey == Term.spring.databaseKey ? 1 : 0;
  }

  static Term getCurrent() {
    DateTime currentDate = DateTime.now();
    int month = currentDate.month;
    if (month > 7) {
      return Term.fall;
    }
    if (month == 7) {
      return Term.secondSummer;
    }
    if (month == 6) {
      return Term.firstSummer;
    }
    return Term.spring;
  }

  static Term getPredictedTerm() {
    DateTime currentDate = DateTime.now();
    int month = currentDate.month;
    if (month <= 3 || month >= 11) {
      return Term.spring;
    }
    if (month == 6) {
      return Term.firstSummer;
    }
    if (month == 7) {
      return Term.secondSummer;
    }
    return Term.fall;
  }

  static int getPredictedYear() {
    DateTime currentDate = DateTime.now();
    int month = currentDate.month;
    if (month >= 4) {
      return currentDate.year;
    }
    return currentDate.year - 1;
  }

  static Term? fromString(String maybeTerm) {
    return Term.values
        .firstWhereOrNull((element) => element.databaseKey == maybeTerm);
  }
}
