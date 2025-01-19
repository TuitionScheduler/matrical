import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:matrical/globals/cubits.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/models/matrical_cubit.dart';
import 'package:matrical/models/matrical_page.dart';
import 'package:matrical/models/saved_schedule.dart';
import 'package:matrical/models/saved_schedules_options.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/pages/generated_schedules/save_schedule_dialog.dart';
import 'package:matrical/pages/generated_schedules/schedule_table_view.dart';
import 'package:matrical/pages/saved_schedules/schedule_view.dart';
import 'package:matrical/services/schedule_service.dart';
import 'package:matrical/widgets/export_schedule_dialog.dart';
import 'package:matrical/widgets/import_schedule_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

List<Widget> splitScheduleCards(List<SavedScheduleCard> cards, int cols,
    int Function(SavedSchedule, SavedSchedule) sort) {
  List<SavedScheduleCard> getMinColumn(List<List<SavedScheduleCard>> columns) {
    return minBy(
        columns,
        (p0) => p0.isNotEmpty
            ? p0
                .map((card) =>
                    card.schedule.schedule.courses.length +
                    (card.schedule.name.length ~/ 12 + 1) +
                    2)
                .sum
            : 0)!;
  }

  List<List<SavedScheduleCard>> columns = [];
  for (var i = 0; i < cols; i++) {
    columns.add([]);
  }

  cards.sorted((a, b) => sort(a.schedule, b.schedule)).forEach((card) {
    var column = getMinColumn(columns);
    column.add(card);
  });

  return columns
      .map((e) => Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: e,
            ),
          ))
      .toList();
}

class ViewSavedSchedules extends StatefulWidget {
  const ViewSavedSchedules({super.key});

  @override
  State<ViewSavedSchedules> createState() => _ViewSavedSchedulesState();
}

class _ViewSavedSchedulesState extends State<ViewSavedSchedules> {
  Future<List<SavedSchedule>> schedules = Future.value([]);
  List<int> years = [(DateTime.now().year - 1), DateTime.now().year];
  Map<String, int Function(SavedSchedule, SavedSchedule)> sorting = {
    "Más Reciente": (a, b) => b.dateCreated.compareTo(a.dateCreated),
    "Por Nombre": (a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    "Menos Reciente": (a, b) => a.dateCreated.compareTo(b.dateCreated),
  };

  late SavedSchedulesOptions options;

  @override
  void initState() {
    super.initState();
    options =
        BlocProvider.of<MatricalCubit>(context).state.savedSchedulesOptions;
    schedules = getSavedSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: schedules,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While waiting for the Future to complete, show a loading indicator
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // If an error occurred, display an error message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("${snapshot.error}"),
              ));
            });
            return const Center(child: CircularProgressIndicator());
          } else {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.scheduleNameInput,
                          ),
                          controller: options.searchController,
                          onChanged: (text) {
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    if (!kIsWeb) // Hide import button on web as it uses URL imports
                      IconButton(
                        iconSize: 30,
                        icon: const Icon(Icons.save_alt),
                        onPressed: () {
                          showDialog<String?>(
                              context: context,
                              useRootNavigator: false,
                              builder: (innerContext) =>
                                  ImportScheduleModal()).then(
                              (encodedSchedule) => saveImportedSchedule(
                                  context, encodedSchedule));
                        },
                      ),
                    IconButton(
                      iconSize: 30,
                      onPressed: () {
                        showDialog(
                            context: context,
                            useRootNavigator: false,
                            builder: (context) {
                              return AlertDialog(
                                contentPadding:
                                    const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                backgroundColor: Colors.white,
                                surfaceTintColor: Colors.white,
                                title: const Text("Opciones"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Divider(),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: DropdownMenu<Term?>(
                                          expandedInsets:
                                              const EdgeInsets.all(0),
                                          initialSelection: options.term,
                                          requestFocusOnTap: false,
                                          label: Text(
                                              AppLocalizations.of(context)!
                                                  .term),
                                          onSelected: (term) {
                                            setState(() {
                                              options.term = term;
                                            });
                                          },
                                          dropdownMenuEntries: [
                                                const DropdownMenuEntry<Term?>(
                                                  value: null,
                                                  label: "Cualquiera",
                                                )
                                              ] +
                                              Term.values.map((term) {
                                                return DropdownMenuEntry<Term?>(
                                                  value: term,
                                                  label: term.displayName,
                                                );
                                              }).toList()),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: DropdownMenu<int?>(
                                          expandedInsets:
                                              const EdgeInsets.all(0),
                                          initialSelection: options.year,
                                          requestFocusOnTap: false,
                                          label: Text(
                                              AppLocalizations.of(context)!
                                                  .year),
                                          onSelected: (year) {
                                            setState(() {
                                              options.year = year;
                                            });
                                          },
                                          dropdownMenuEntries: [
                                                const DropdownMenuEntry<int?>(
                                                  value: null,
                                                  label: "Cualquiera",
                                                )
                                              ] +
                                              years
                                                  .map<DropdownMenuEntry<int?>>(
                                                      (year) {
                                                return DropdownMenuEntry<int?>(
                                                  value: year,
                                                  label: "$year-${year + 1}",
                                                );
                                              }).toList()),
                                    ),
                                    const Divider(),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: DropdownMenu<String>(
                                          expandedInsets:
                                              const EdgeInsets.all(0),
                                          initialSelection: options
                                                  .sortingController
                                                  .text
                                                  .isNotEmpty
                                              ? options.sortingController.text
                                              : sorting.keys.first,
                                          requestFocusOnTap: false,
                                          label: Text(
                                              AppLocalizations.of(context)!
                                                  .orderBy),
                                          controller: options.sortingController,
                                          onSelected: (sort) {
                                            setState(() {});
                                          },
                                          dropdownMenuEntries: sorting.keys
                                              .map<DropdownMenuEntry<String>>(
                                                  (sort) {
                                            return DropdownMenuEntry<String>(
                                              value: sort,
                                              label: sort,
                                            );
                                          }).toList()),
                                    )
                                  ],
                                ),
                              );
                            });
                      },
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: splitScheduleCards(
                            snapshot.data!
                                .where((element) =>
                                    element.name
                                        .trim()
                                        .toLowerCase()
                                        .startsWith(options
                                            .searchController.text
                                            .trim()
                                            .toLowerCase()) &&
                                    (options.term == null ||
                                        element.schedule.term ==
                                            options.term?.databaseKey) &&
                                    (options.year == null ||
                                        element.schedule.year == options.year))
                                .map((e) => SavedScheduleCard(
                                      schedule: e,
                                      deleteSchedule: (name) {
                                        deleteSavedSchedule(name).then((value) {
                                          setState(() {
                                            schedules = getSavedSchedules();
                                          });
                                        });
                                      },
                                    ))
                                .toList(),
                            2,
                            sorting[options.sortingController.text] ??
                                sorting.values.first),
                      )
                    ]),
                  ),
                ),
              ],
            );
          }
        });
  }

  void saveImportedSchedule(BuildContext context, String? encodedSchedule) {
    if (encodedSchedule == null) {
      return; // This means import modal was never submitted
    }
    final parsedSchedule = GeneratedSchedule.fromImportCode(encodedSchedule);
    if (parsedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Código inválido no pudo ser importado.")));
      return;
    }
    showDialog<SaveScheduleResult?>(
        context: context,
        useRootNavigator: false,
        builder: (innerContext) => SaveScheduleDialog(
              currentSchedule: parsedSchedule,
            )).then((result) {
      if (result != null && result == SaveScheduleResult.success) {
        setState(() {
          schedules = getSavedSchedules();
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Horario guardado exitosamente.")));
        });
      }
    });
  }
}

class SavedScheduleCard extends StatelessWidget {
  final SavedSchedule schedule;
  final Function deleteSchedule;

  const SavedScheduleCard(
      {super.key, required this.schedule, required this.deleteSchedule});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          showDialog(
              context: context,
              useRootNavigator: false,
              builder: (context) {
                return _savedScheduleModal(context, schedule);
              }).then((value) {
            if (value != null && value is GeneratedSchedule) {
              Navigator.of(context).pop(value);
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  blurRadius: 5.0,
                  spreadRadius: 1.0,
                  color: Colors.grey.shade400)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(schedule.name,
                                  style: const TextStyle(fontSize: 16))),
                          Material(
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => deleteSchedule(schedule.name),
                              child: const Icon(Icons.close, size: 20.0),
                            ),
                          ),
                        ],
                      ),
                      Text(
                          "${Term.fromString(schedule.schedule.term)?.displayName ?? ''}, ${schedule.schedule.year}",
                          style: const TextStyle(fontSize: 12)),
                      Text(
                          "Total de Créditos: ${schedule.schedule.getTotalCredits()}",
                          style: const TextStyle(fontSize: 12)),
                      Text(
                          "Fecha: ${schedule.dateCreated.day}/${schedule.dateCreated.month}/${schedule.dateCreated.year}",
                          style: const TextStyle(fontSize: 12)),
                      const Divider(),
                    ] +
                    schedule.schedule.courses
                        .map((pair) => Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                    color: pair.getColor(),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Center(
                                  child: Text(
                                      "${pair.course.courseCode}-${pair.sectionCode}",
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                              ),
                            ))
                        .toList()),
          ),
        ),
      ),
    );
  }
}

Widget _savedScheduleModal(BuildContext context, SavedSchedule schedule) {
  return AlertDialog(
    title: const Text(
      "Cursos en horario:",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    // shape: RoundedRectangleBorder(),
    content: Container(
      decoration: BoxDecoration(
          border: Border.symmetric(
              horizontal: BorderSide(
                  color: DividerTheme.of(context).color ??
                      Theme.of(context).dividerColor))),
      child: FractionallySizedBox(
        heightFactor: 0.6,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: ScheduleTable(schedule: schedule.schedule),
        ),
      ),
    ),
    buttonPadding: const EdgeInsets.symmetric(horizontal: 3.0),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    actions: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: TextButton(
              style: TextButton.styleFrom(
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ScheduleView(schedule: schedule)));
              },
              child: const Text("Ver en Semana"),
            ),
          ),
          Flexible(
            child: TextButton(
              style: TextButton.styleFrom(
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                matricalCubitSingleton.updateCourses(schedule.schedule.courses
                    .map((csp) => CourseWithFilters.withoutFilters(
                        courseCode: csp.course.courseCode,
                        sectionCode: csp.sectionCode))
                    .toList());
                matricalCubitSingleton
                    .updateTerm(Term.fromString(schedule.schedule.term)!);
                matricalCubitSingleton.updateYear(schedule.schedule.year);
                matricalCubitSingleton.setPage(MatricalPage.courseSelect);
              },
              child: const Text("Editar"),
            ),
          ),
          Flexible(
            child: TextButton(
              style: TextButton.styleFrom(
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                showDialog(
                  useRootNavigator: false,
                  context: context,
                  builder: (BuildContext innerContext) {
                    return ExportScheduleDialog(
                      notPresencialCourses: schedule.schedule
                          .getCourseSectionPairsByModality(
                              Modality.byagreement),
                      schedule: schedule.schedule,
                      scheduleName: schedule.name,
                    );
                  },
                );
              },
              child: const Text("Exportar"),
            ),
          ),
        ],
      ),
    ],
  );
}
