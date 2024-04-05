import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:info_widget/info_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miuni/core/network/internet_cubit.dart';
import 'package:miuni/features/matrical/data/course_service.dart';
import 'package:miuni/features/matrical/data/model/course_filters.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule_preferences.dart';
import 'package:miuni/features/matrical/data/model/schedule_generation_options.dart';
import 'package:miuni/features/matrical/logic/course_validator.dart';
import 'package:miuni/features/matrical/page/generated_schedules/preferences_view.dart';
import 'package:miuni/features/matrical/page/shared/import_schedule_dialog.dart';
import 'package:miuni/features/matrical/page/shared/bug_report.dart';
import 'package:miuni/features/matrical/page/shared/course_filters.dart';
import 'package:miuni/features/matrical/page/generated_schedules/generated_schedules.dart';
import 'package:miuni/features/matrical/page/course_search/course_search.dart';
import 'package:miuni/features/matrical/page/saved_schedules/view_saved_schedules.dart';
import 'package:miuni/Global/matrical/uppercase_formatter.dart';
import 'package:pair/pair.dart';
import 'data/model/course_data_entry_info_service.dart';
import 'data/model/generated_schedule.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);

class Matrical extends StatefulWidget {
  const Matrical({super.key});

  @override
  State<Matrical> createState() => _MatricalState();
}

class _MatricalState extends State<Matrical> {
  TextStyle textStyle = const TextStyle(color: Colors.white, fontSize: 20);
  List<CourseWithFilters> coursesList = [];
  static List<String> years = [
    (DateTime.now().year - 1).toString(),
    DateTime.now().year.toString()
  ];
  var courseCodeController = TextEditingController();
  var courseSectionController = TextEditingController();
  final termController = TextEditingController();
  final yearController = TextEditingController();
  var selectedTerm = Term.getCurrent();
  var selectedYear = DateTime.now().month <= 5 ? years.first : years.last;
  var dataEntryInfoService = CourseDataEntryInfoService();
  var preferences = GeneratedSchedulePreferences(professorRankings: {});

  void addCourse(String course, String section) {
    final courseWithFilters = CourseWithFilters.withoutFilters(
      courseCode: course,
      sectionCode: section,
    );
    for (final (i, element) in coursesList.indexed) {
      if (element.courseCode == course) {
        bool isLab =
            section.isNotEmpty && section.length > 3 && section.endsWith("L");
        bool otherIsLab = element.sectionCode.isNotEmpty &&
            element.sectionCode.length > 3 &&
            element.sectionCode.endsWith("L");
        if (isLab == otherIsLab) {
          coursesList[i] = courseWithFilters;
          return;
        }
      }
    }
    coursesList.add(courseWithFilters);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InternetCubit, InternetState>(
      builder: (_, state) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
          ),
        ),
        child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: FittedBox(
                fit: BoxFit.fitWidth,
                child: Text(
                  "Selección de Cursos",
                  style: textStyle,
                ),
              ),
              backgroundColor: officialColor,
              actions: [
                const BugReport(pageName: "Course Selection"),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) =>
                            const ViewSavedSchedules(),
                      ),
                    ).then((schedule) {
                      if (schedule != null && schedule is GeneratedSchedule) {
                        setState(() {
                          selectedYear = schedule.year.toString();
                          selectedTerm = (Term.fromString(schedule.term) ??
                              Term.getCurrent());
                          coursesList = schedule.courses
                              .map(
                                (e) => CourseWithFilters.withoutFilters(
                                    courseCode: e.course.courseCode,
                                    sectionCode: e.sectionCode),
                              )
                              .toList();
                        });
                      }
                    });
                  },
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all(const CircleBorder()),
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                  ),
                  child: const Icon(Icons.calendar_month),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<Pair<Term, String>>(
                          builder: (BuildContext context) => CourseSearch(
                            addSection: (course, section) {
                              addCourse(course, section);
                            },
                            clearSections: () {
                              coursesList.clear();
                            },
                            years: years,
                            initialTerm: selectedTerm,
                            initialYear: selectedYear,
                          ),
                        ),
                      ).then((termYear) {
                        if (termYear != null) {
                          var (updatedTerm, updatedYear) = termYear();
                          setState(() {
                            selectedTerm = updatedTerm;
                            selectedYear = updatedYear;
                            termController.text = updatedTerm.displayName;
                            yearController.text = updatedYear;
                          });
                        }
                      });
                    },
                    style: ButtonStyle(
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    ),
                    child: const Icon(Icons.search),
                  ),
                ),
              ],
            ),
            body: Builder(builder: (innerContext) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: DropdownMenu<Term>(
                              controller: termController,
                              expandedInsets: const EdgeInsets.all(0),
                              initialSelection: selectedTerm,
                              requestFocusOnTap: false,
                              label: const Text('Término'),
                              onSelected: (term) {
                                setState(() {
                                  selectedTerm = term ?? Term.getCurrent();
                                  coursesList.clear();
                                });
                              },
                              dropdownMenuEntries: Term.values.map((term) {
                                return DropdownMenuEntry<Term>(
                                  value: term,
                                  label: term.displayName,
                                );
                              }).toList()),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: DropdownMenu<String>(
                              controller: yearController,
                              expandedInsets: const EdgeInsets.all(0),
                              initialSelection: DateTime.now().month <= 5
                                  ? years.firstOrNull
                                  : years.lastOrNull,
                              requestFocusOnTap: false,
                              label: const Text('Año'),
                              onSelected: (year) {
                                setState(() {
                                  selectedYear = year ?? years.first;
                                  coursesList.clear();
                                });
                              },
                              dropdownMenuEntries:
                                  years.map<DropdownMenuEntry<String>>((year) {
                                return DropdownMenuEntry<String>(
                                  value: year,
                                  label: year,
                                );
                              }).toList()),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "Añadir Cursos o ",
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 0.0),
                                      child: InkWell(
                                        onTap: () async {
                                          showDialog<String?>(
                                                  useRootNavigator: false,
                                                  context: innerContext,
                                                  builder: (innerContext) =>
                                                      ImportScheduleModal())
                                              .then((encodedSchedule) {
                                            if (encodedSchedule != null) {
                                              GeneratedSchedule?
                                                  decodedSchedule =
                                                  GeneratedSchedule
                                                      .fromImportCode(
                                                          encodedSchedule);
                                              if (decodedSchedule == null) {
                                                return ScaffoldMessenger.of(
                                                        innerContext)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            "El código entrado tiene un formato inválido.")));
                                              }
                                              setState(() {
                                                selectedTerm = Term.fromString(
                                                        decodedSchedule.term) ??
                                                    Term.getCurrent();
                                                selectedYear = decodedSchedule
                                                    .year
                                                    .toString();
                                                termController.text =
                                                    selectedTerm.displayName;
                                                yearController.text =
                                                    selectedYear;
                                                coursesList = decodedSchedule
                                                    .courses
                                                    .map((courseWithSection) {
                                                  return CourseWithFilters
                                                      .withoutFilters(
                                                          courseCode:
                                                              courseWithSection
                                                                  .course
                                                                  .courseCode,
                                                          sectionCode:
                                                              courseWithSection
                                                                  .sectionCode);
                                                }).toList();
                                              });
                                              return ScaffoldMessenger.of(
                                                      innerContext)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          "Horario importado exitosamente.")));
                                            }
                                          });
                                        },
                                        child: Text("Importar",
                                            style: TextStyle(
                                                color: Colors.green[900],
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                                decoration:
                                                    TextDecoration.underline)),
                                      ))
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                      child: TextField(
                                    controller: courseCodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Curso',
                                      hintText: 'ie. CIIC3015',
                                    ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [UpperCaseTextFormatter()],
                                  )),
                                  const Text("  —  "),
                                  Expanded(
                                      child: TextField(
                                    controller: courseSectionController,
                                    decoration: const InputDecoration(
                                      hintText: 'ie. 070, 001D',
                                      labelText: 'Sección',
                                    ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [UpperCaseTextFormatter()],
                                  )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            FocusManager.instance.primaryFocus
                                ?.unfocus(); // close keyboard
                            if (!isCourseCode(courseCodeController.text)) {
                              ScaffoldMessenger.of(innerContext)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Curso no tiene el formato esperado (DEPT####).'),
                              ));
                              return;
                            }
                            if (courseSectionController.text.isNotEmpty &&
                                !isSectionCode(courseSectionController.text)) {
                              ScaffoldMessenger.of(innerContext)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Sección no tiene el formato esperado.'),
                              ));
                              return;
                            }

                            var courseCode = courseCodeController.text;
                            final term = selectedTerm.databaseKey;
                            final year = selectedYear;
                            var course = await CourseService()
                                .getCourse(courseCode, term, int.parse(year));
                            if (state.connected!) {
                              if (course == null) {
                                ScaffoldMessenger.of(innerContext)
                                    .showSnackBar(const SnackBar(
                                  content: Text(
                                      'Curso no disponible para este semestre según nuestra base de datos.'),
                                ));
                                return;
                              }
                              final section = courseSectionController.text;
                              if (section.isNotEmpty &&
                                  course.sections
                                      .none((s) => s.sectionCode == section)) {
                                ScaffoldMessenger.of(innerContext)
                                    .showSnackBar(const SnackBar(
                                  content: Text(
                                      'Sección no disponible para este semestre según nuestra base de datos.'),
                                ));
                                return;
                              }
                              setState(() {
                                addCourse(courseCodeController.text,
                                    courseSectionController.text);
                              });
                            } else {
                              if (course == null) {
                                ScaffoldMessenger.of(innerContext)
                                    .showSnackBar(const SnackBar(
                                  content: Text(
                                      'No se pudo encontrar el curso en la memoria local. Intente otra vez una vez esté conectado al Internet.'),
                                ));
                                return;
                              }
                              final section = courseSectionController.text;
                              if (section.isNotEmpty &&
                                  course.sections
                                      .none((s) => s.sectionCode == section)) {
                                ScaffoldMessenger.of(innerContext)
                                    .showSnackBar(const SnackBar(
                                  content: Text(
                                      'No se pudo encontrar esa sección para el curso en la memoria local. Intente otra vez una vez esté conectado al Internet.'),
                                ));
                                return;
                              }
                              setState(() {
                                addCourse(courseCodeController.text,
                                    courseSectionController.text);
                              });
                            }
                          },
                          child: const Icon(Icons.add),
                        ),
                      )
                    ],
                  ),
                  const Divider(
                    thickness: 2,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: coursesList
                                .mapIndexed((i, e) => Column(children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "\t\t\u2022 ${e.courseCode}${e.sectionCode == "" ? "" : "-${e.sectionCode}"}",
                                              style:
                                                  const TextStyle(fontSize: 15),
                                            ),
                                          ),
                                          if (e.sectionCode == "")
                                            IconButton(
                                                onPressed: () {
                                                  showDialog(
                                                      useRootNavigator: false,
                                                      context: context,
                                                      builder: (context) =>
                                                          CourseFilterPopup(
                                                              filters:
                                                                  e.filters));
                                                },
                                                icon: const Icon(
                                                    Icons.filter_alt)),
                                          if (e.sectionCode != "" &&
                                              !(e.sectionCode.length > 3 &&
                                                  e.sectionCode.endsWith("L")))
                                            IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    e.sectionCode = "";
                                                  });
                                                },
                                                icon: const Icon(Icons.undo)),
                                          IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  coursesList.removeAt(i);
                                                });
                                              },
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red)),
                                        ],
                                      ),
                                      if (i < coursesList.length - 1)
                                        const Divider()
                                    ]))
                                .toList(),
                          ),
                        )),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                              onPressed: () {
                                if (coursesList.isNotEmpty) {
                                  preferences.professorRankings = {
                                    for (var e in coursesList)
                                      // we will add professors later
                                      // ignore: prefer_const_constructors
                                      e.courseCode: Pair(false, [])
                                  };
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (BuildContext context) =>
                                          GeneratedSchedules(
                                        courses: coursesList
                                            .map((e) => CourseWithFilters(
                                                courseCode: e.courseCode,
                                                sectionCode: e.sectionCode,
                                                filters: e.filters))
                                            .toList(),
                                        term: selectedTerm.databaseKey,
                                        year: int.parse(selectedYear),
                                        preferences: preferences,
                                      ),
                                    ),
                                  ).then((result) {
                                    if (result != null) {
                                      switch (result.runtimeType) {
                                        case const (List<CourseWithFilters>):
                                          setState(() {
                                            coursesList = result;
                                          });
                                          break;
                                        case const (GeneratedSchedule):
                                          setState(() {
                                            coursesList = result.courses
                                                .map(
                                                  (e) => CourseWithFilters
                                                      .withoutFilters(
                                                          courseCode: e.course
                                                              .courseCode,
                                                          sectionCode:
                                                              e.sectionCode),
                                                )
                                                .toList()
                                                .cast<CourseWithFilters>();
                                            selectedTerm =
                                                Term.fromString(result.term) ??
                                                    Term.getCurrent();
                                            selectedYear =
                                                result.year.toString();
                                          });
                                          break;
                                      }
                                    }
                                  });
                                }
                              },
                              child: const Text("Generar Matrículas")),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                  useRootNavigator: false,
                                  context: context,
                                  builder: (BuildContext innerContext) {
                                    return StatefulBuilder(
                                        builder: (stfContext, stfSetState) {
                                      return Theme(
                                        data: ThemeData(
                                            colorSchemeSeed: Colors.green),
                                        child: AlertDialog(
                                          backgroundColor: Colors.white,
                                          surfaceTintColor: Colors.white,
                                          title: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                  "Preferencias de Horario "),
                                              _preferencesHelp()
                                            ],
                                          ),
                                          content: PreferencesView(
                                              preferences: preferences),
                                        ),
                                      );
                                    });
                                  });
                            },
                            child: const Icon(Icons.settings)),
                      )
                    ],
                  )
                ],
              );
            })),
      ),
    );
  }
}

Widget _preferencesHelp() {
  return InfoWidget(
      infoText:
          "Aquí puedes controlar cuales horarios serán mostrados primeros basados en tus preferencias.\n\nEsparcido / Denso - Controla si las secciones deben tener espacio entremedio o no.\nPresencial / Por Acuerdo - Modalidad preferida.\nHora promedio - Seleccionar hora preferida para cursos. ",
      iconData: Icons.help,
      iconColor: Colors.black87);
}
