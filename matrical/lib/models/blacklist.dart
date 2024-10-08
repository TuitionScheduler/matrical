import 'department_course.dart';

class Blacklist {
  final List<Professor> professors;
  final Map<String, List<String>> sections;

  const Blacklist({required this.professors, required this.sections});

  Blacklist copy() {
    Map<String, List<String>> newSections = {};
    sections.forEach((key, value) {
      newSections[key] =
          List<String>.from(value); // Creates a new list with copied elements
    });
    return Blacklist(professors: List.of(professors), sections: newSections);
  }

  static Blacklist empty() {
    // Will list and map will be mutated later on, so avoid `const`
    // ignore: prefer_const_constructors
    return Blacklist(professors: [], sections: {});
  }
}
