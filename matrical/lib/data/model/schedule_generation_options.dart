import 'package:collection/collection.dart';

enum Term {
  firstSummer(
      displayName: "Primer Verano",
      databaseKey: "First_Summer",
      startMonth: 6,
      durationInWeeks: 6,
      startWeek: 1),
  secondSummer(
      displayName: "Segundo Verano",
      databaseKey: "Second_Summer",
      startMonth: 7,
      durationInWeeks: 4,
      startWeek: 1),
  fall(
      displayName: "Primer Semestre",
      databaseKey: "Fall",
      startMonth: 8,
      durationInWeeks: 16,
      startWeek: 2),
  spring(
      displayName: "Segundo Semestre",
      databaseKey: "Spring",
      startMonth: 1,
      durationInWeeks: 16,
      startWeek: 2);

  const Term(
      {required this.displayName,
      required this.databaseKey,
      required this.startMonth,
      required this.durationInWeeks,
      required this.startWeek});

  final String displayName;
  final String databaseKey;
  final int startMonth;
  final int durationInWeeks;
  final int startWeek;

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

  static Term? fromString(String maybeTerm) {
    return Term.values
        .firstWhereOrNull((element) => element.databaseKey == maybeTerm);
  }
}
