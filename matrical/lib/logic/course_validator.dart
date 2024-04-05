bool isCourseCode(String maybeCourseCode) {
  RegExp regex = RegExp(r'^[A-Z]{4}[0-9]{4}$');
  return regex.hasMatch(maybeCourseCode);
}

bool isSectionCode(String maybeSectionCode) {
  RegExp regex = RegExp(r'^[0-9]{2}[0-9A-Z]{1}[A-Z#]?$');
  return regex.hasMatch(maybeSectionCode);
}
