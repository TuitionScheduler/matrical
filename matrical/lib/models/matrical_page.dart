// Don't change enum value order without updating widget order in Matrical scaffold body accordingly
enum MatricalPage {
  courseSelect(displayName: "Selección de Cursos"),
  courseSearch(displayName: "Búsqueda de Cursos"),
  savedSchedules(displayName: "Mis Horarios"),
  generatedSchedules(displayName: "Horarios Generados");

  const MatricalPage({required this.displayName});
  final String displayName;
}
