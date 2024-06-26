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

  CourseFilters.empty(
      {this.professors = const [],
      this.earliestTime = '',
      this.latestTime = '',
      this.days = '',
      this.modality = Modality.any,
      this.rooms = const []});

  // Convert CourseFilters to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'professors': professors,
      'earliestTime': earliestTime,
      'latestTime': latestTime,
      'days': days,
      'modality': modality.toJson(),
      'rooms': rooms,
    };
  }

  // Convert JSON Map to CourseFilters
  static CourseFilters fromJson(Map<String, dynamic> json) {
    return CourseFilters(
      professors: List<String>.from(json['professors']),
      earliestTime: json['earliestTime'],
      latestTime: json['latestTime'],
      days: json['days'],
      modality: Modality.fromJson(json['modality']),
      rooms: List<String>.from(json['rooms']),
    );
  }

  CourseFilters copy() {
    return CourseFilters.fromJson(toJson());
  }
}

class CourseWithFilters {
  String courseCode;
  String sectionCode;
  CourseFilters filters;

  CourseWithFilters(
      {required this.courseCode,
      required this.sectionCode,
      required this.filters});

  CourseWithFilters.withoutFilters(
      {required this.courseCode, required this.sectionCode})
      : filters = CourseFilters.empty();

  // Convert CourseWithFilters to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'courseCode': courseCode,
      'sectionCode': sectionCode,
      'filters': filters.toJson(),
    };
  }

  // Convert JSON Map to CourseWithFilters
  static CourseWithFilters fromJson(Map<String, dynamic> json) {
    return CourseWithFilters(
      courseCode: json['courseCode'],
      sectionCode: json['sectionCode'],
      filters: CourseFilters.fromJson(json['filters']),
    );
  }
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

  const Modality({required this.displayName, required this.letterCodes});
  final String displayName;
  final List<String> letterCodes;

  // Convert Modality to JSON
  String toJson() => displayName;

  // Convert JSON to Modality
  static Modality fromJson(String json) {
    return Modality.values.firstWhere(
      (modality) => modality.displayName == json,
      orElse: () => Modality.any, // Default value if not found
    );
  }
}
