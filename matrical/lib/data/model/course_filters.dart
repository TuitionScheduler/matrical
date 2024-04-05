class CourseFilters {
  List<String> professors;
  String earliestTime;
  String latestTime;
  String days;
  Modality modality;
  List<String> rooms;

  CourseFilters(
      {required this.professors,
      required this.earliestTime,
      required this.latestTime,
      required this.days,
      required this.modality,
      required this.rooms});

  CourseFilters.empty({
    this.professors = const [],
    this.earliestTime = '',
    this.latestTime = '',
    this.days = '',
    this.modality = Modality.any,
    this.rooms = const [],
  });
}

class CourseWithFilters {
  String courseCode;
  String sectionCode;
  CourseFilters filters;
  CourseWithFilters({
    required this.courseCode,
    required this.sectionCode,
    required this.filters,
  });
  CourseWithFilters.withoutFilters(
      {required this.courseCode, required this.sectionCode})
      : filters = CourseFilters.empty();
}

enum Modality {
  remoteSynchronous(displayName: "Remoto Sincrónico", letterCodes: ["E"]),
  remoteAsynchronous(displayName: "Remoto Asincrónico", letterCodes: ["D"]),
  hybrid(displayName: "Híbrido", letterCodes: ["H"]),
  inperson(displayName: "Presencial", letterCodes: ["", "L"]),
  byagreement(displayName: "Por Acuerdo", letterCodes: ["P", "R", "#", "D"]),
  any(
      displayName: "Cualquiera",
      letterCodes: ["E", "D", "H", "", "P", "R", "#", "L"]);

  const Modality({
    required this.displayName,
    required this.letterCodes,
  });

  final String displayName;
  final List<String> letterCodes;
}
