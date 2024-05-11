import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:info_widget/info_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miuni/config/injection_dependecies.dart';
import 'package:miuni/core/network/internet_cubit.dart';
import 'package:miuni/features/matrical/data/course_service.dart';
import 'package:miuni/features/matrical/data/model/course_filters.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule_preferences.dart';
import 'package:miuni/features/matrical/data/model/schedule_generation_options.dart';
import 'package:miuni/features/matrical/logic/course_validator.dart';
import 'package:miuni/features/matrical/data/stored_preferences.dart';
import 'package:miuni/features/matrical/logic/matrical_cubit.dart';
import 'package:miuni/features/matrical/page/generated_schedules/preferences_view.dart';
import 'package:miuni/features/matrical/page/matrical.dart';
import 'package:miuni/features/matrical/page/shared/import_schedule_dialog.dart';
import 'package:miuni/features/matrical/page/shared/bug_report.dart';
import 'package:miuni/features/matrical/page/shared/course_filters.dart';
import 'package:miuni/features/matrical/page/generated_schedules/generated_schedules.dart';
import 'package:miuni/Global/matrical/uppercase_formatter.dart';
import 'package:pair/pair.dart';
import '../../data/model/course_data_entry_info_service.dart';
import '../../data/model/generated_schedule.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);

class CourseSelect extends StatefulWidget {
  const CourseSelect({super.key});

  @override
  State<CourseSelect> createState() => _CourseSelectState();
}

class _CourseSelectState extends State<CourseSelect> {
  TextStyle textStyle = const TextStyle(color: Colors.white, fontSize: 20);
  static List<int> years = getAcademicYears();
  final termController = TextEditingController();
  final yearController = TextEditingController();
  var dataEntryInfoService = CourseDataEntryInfoService();

  Future<void> _addCourse(BuildContext context, MatricalState matricalState,
      InternetState internetState) async {
    FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (!isCourseCode(matricalState.courseController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Curso no tiene el formato esperado (DEPT####).'),
      ));
      return;
    }
    if (matricalState.sectionController.text.isNotEmpty &&
        !isSectionCode(matricalState.sectionController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sección no tiene el formato esperado.'),
      ));
      return;
    }

    var courseCode = matricalState.courseController.text;
    final term = matricalState.term.databaseKey;
    final year = matricalState.year;
    var course = await CourseService().getCourse(courseCode, term, year);
    if (internetState.connected!) {
      if (course == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Curso no disponible para este semestre según nuestra base de datos.'),
        ));
        return;
      }
      final section = matricalState.sectionController.text;
      if (section.isNotEmpty &&
          course.sections.none((s) => s.sectionCode == section)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Sección no disponible para este semestre según nuestra base de datos.'),
        ));
        return;
      }

      sl<MatricalCubit>().addCourse(matricalState.courseController.text,
          matricalState.sectionController.text);
    } else {
      if (course == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No se pudo encontrar el curso en la memoria local. Intente otra vez una vez esté conectado al Internet.'),
        ));
        return;
      }
      final section = matricalState.sectionController.text;
      if (section.isNotEmpty &&
          course.sections.none((s) => s.sectionCode == section)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No se pudo encontrar esa sección para el curso en la memoria local. Intente otra vez una vez esté conectado al Internet.'),
        ));
        return;
      }
      sl<MatricalCubit>().addCourse(matricalState.courseController.text,
          matricalState.sectionController.text);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InternetCubit, InternetState>(
      builder: (_, internetState) => BlocBuilder<MatricalCubit, MatricalState>(
        builder: (_, matricalState) => Theme(
            data: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green,
              ),
            ),
            child: Builder(builder: (innerContext) {
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
                              initialSelection: matricalState.term,
                              requestFocusOnTap: false,
                              label: const Text('Término'),
                              onSelected: (term) async {
                                if (term != null) {
                                  await setSelectedAcademicTerm(term);
                                  sl<MatricalCubit>().updateTerm(term);
                                  final removedAny = await sl<MatricalCubit>()
                                      .onTermYearChanged();
                                  if (removedAny) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(const SnackBar(
                                        content: Text(
                                            'Algunos cursos y/o secciones no pertenecen a este término y/o año.'),
                                      ));
                                  }
                                  setState(() {});
                                }
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
                              initialSelection: matricalState.year.toString(),
                              requestFocusOnTap: false,
                              label: const Text('Año'),
                              onSelected: (year) async {
                                if (year != null) {
                                  await setSelectedAcademicYear(
                                      int.parse(year));
                                  sl<MatricalCubit>()
                                      .updateYear(int.parse(year));
                                  final removedAny = await sl<MatricalCubit>()
                                      .onTermYearChanged();
                                  if (removedAny) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(const SnackBar(
                                        content: Text(
                                            'Algunos cursos y/o secciones no pertenecen a este término y/o año.'),
                                      ));
                                  }
                                  setState(() {});
                                }
                              },
                              dropdownMenuEntries:
                                  years.map<DropdownMenuEntry<String>>((year) {
                                return DropdownMenuEntry<String>(
                                  value: year.toString(),
                                  label: "$year-${year + 1}",
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
                                                ScaffoldMessenger.of(context)
                                                    .hideCurrentSnackBar();
                                                return ScaffoldMessenger.of(
                                                        innerContext)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            "El código entrado tiene un formato inválido.")));
                                              }
                                              final newTerm = Term.fromString(
                                                      decodedSchedule.term) ??
                                                  Term.getPredictedTerm();
                                              sl<MatricalCubit>()
                                                  .updateTerm(newTerm);

                                              sl<MatricalCubit>().updateYear(
                                                  decodedSchedule.year);
                                              termController.text =
                                                  newTerm.displayName;
                                              yearController.text =
                                                  decodedSchedule.year
                                                      .toString();
                                              sl<MatricalCubit>().updateCourses(
                                                  decodedSchedule.courses
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
                                              }).toList());
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
                              FocusScope(
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: TextField(
                                      controller:
                                          matricalState.courseController,
                                      decoration: const InputDecoration(
                                        labelText: 'Curso*',
                                        hintText: 'ie. CIIC3015',
                                      ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      keyboardType:
                                          TextInputType.visiblePassword,
                                      inputFormatters: [
                                        UpperCaseTextFormatter()
                                      ],
                                      textInputAction: TextInputAction.next,
                                    )),
                                    const Text("  —  "),
                                    Expanded(
                                        child: TextField(
                                      controller:
                                          matricalState.sectionController,
                                      decoration: const InputDecoration(
                                        hintText: 'ie. 070, 001D',
                                        labelText: 'Sección',
                                      ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      keyboardType:
                                          TextInputType.visiblePassword,
                                      inputFormatters: [
                                        UpperCaseTextFormatter()
                                      ],
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (value) => _addCourse(
                                          innerContext,
                                          matricalState,
                                          internetState),
                                    )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () => _addCourse(
                              innerContext, matricalState, internetState),
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
                            children: matricalState.selectedCourses
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
                                                  sl<MatricalCubit>()
                                                      .removeSection(i);
                                                },
                                                icon: const Icon(Icons.undo)),
                                          IconButton(
                                              onPressed: () {
                                                sl<MatricalCubit>()
                                                    .removeCourse(i);
                                              },
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red)),
                                        ],
                                      ),
                                      if (i <
                                          matricalState.selectedCourses.length -
                                              1)
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
                                if (matricalState.selectedCourses.isNotEmpty) {
                                  sl<MatricalCubit>()
                                      .setPage(MatricalPage.generatedSchedules);
                                } else {
                                  ScaffoldMessenger.of(innerContext)
                                      .hideCurrentSnackBar(); // don't need remove here since snackbar blocks button
                                  ScaffoldMessenger.of(innerContext)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('Añade cursos antes de generar.'),
                                  ));
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
                                              const Expanded(
                                                child: Text(
                                                    "Preferencias de Horario "),
                                              ),
                                              _preferencesHelp()
                                            ],
                                          ),
                                          content: PreferencesView(
                                              preferences:
                                                  matricalState.preferences),
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
          "Aquí puedes controlar cuales horarios serán mostrados primeros basados en tus preferencias.\n\nEsparcido / Denso - Controla si las secciones deben tener espacio entremedio o no.\nPresencial / Por Acuerdo - Modalidad preferida.\nTiempo Preferido para Cursos - Selecciona cuándo tomar los cursos durante el día.",
      iconData: Icons.help,
      iconColor: Colors.black87);
}
