import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:info_widget/info_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/models/internet_cubit.dart';
import 'package:matrical/models/matrical_cubit.dart';
import 'package:matrical/models/matrical_page.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/pages/generated_schedules/preferences_view.dart';
import 'package:matrical/services/course_service.dart';
import 'package:matrical/services/formatter_service.dart';
import 'package:matrical/services/stored_preferences.dart';
import 'package:matrical/widgets/course_filters.dart';
import 'package:matrical/widgets/import_schedule_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_browser_detect/web_browser_detect.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);

class CourseSelect extends StatefulWidget {
  const CourseSelect({super.key});

  @override
  State<CourseSelect> createState() => _CourseSelectState();
}

class _CourseSelectState extends State<CourseSelect> {
  TextStyle textStyle = const TextStyle(color: Colors.white, fontSize: 20);
  static List<int> years = getAcademicYears();
  TextEditingController? courseController;
  TextEditingController? sectionController;
  final termController = TextEditingController();
  final yearController = TextEditingController();

  Future<void> _addCourse(BuildContext context, String term, int year,
      InternetState internetState) async {
    FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // This should never be null as the controller is populated by the autocomplete at build time
    if (courseController == null) {
      return;
    }
    var courseCode = courseController?.text ?? "";
    var sectionCode = sectionController?.text ?? "";
    final matricalCubit = BlocProvider.of<MatricalCubit>(context);
    if (!isCourseCode(courseCode)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.invalidCourseFormat),
      ));
      return;
    }
    if (sectionCode.isNotEmpty && !isSectionCode(sectionCode)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.invalidSectionFormat),
      ));
      return;
    }
    var course = await CourseService().getCourse(courseCode, term, year);
    if (internetState.connected) {
      if (course == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.courseNotAvailable),
        ));
        return;
      }
      if (sectionCode.isNotEmpty &&
          course.sections.none((s) => s.sectionCode == sectionCode)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.sectionNotAvailable),
        ));
        return;
      }

      matricalCubit.addCourse(courseCode, sectionCode);
    } else {
      if (course == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.courseNotInLocalMemory),
        ));
        return;
      }
      if (sectionCode.isNotEmpty &&
          course.sections.none((s) => s.sectionCode == sectionCode)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.sectionNotInLocalMemory),
        ));
        return;
      }
      matricalCubit.addCourse(courseCode, sectionCode);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final matricalCubit = BlocProvider.of<MatricalCubit>(context);
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
                              label: Text(AppLocalizations.of(context)!.term),
                              onSelected: (term) async {
                                if (term != null) {
                                  await setSelectedAcademicTerm(term);
                                  matricalCubit.updateTerm(term);
                                  final removedAny =
                                      await matricalCubit.onTermYearChanged();
                                  if (removedAny) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(SnackBar(
                                        content: Text(
                                            AppLocalizations.of(context)!
                                                .removedCoursesWarning),
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
                              label: Text(AppLocalizations.of(context)!.year),
                              onSelected: (year) async {
                                if (year != null) {
                                  await setSelectedAcademicYear(
                                      int.parse(year));
                                  matricalCubit.updateYear(int.parse(year));
                                  final removedAny =
                                      await matricalCubit.onTermYearChanged();
                                  if (removedAny) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(SnackBar(
                                        content: Text(
                                            AppLocalizations.of(context)!
                                                .removedCoursesWarning),
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
                                  Text(
                                    AppLocalizations.of(context)!.addCourses,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (!kIsWeb) // Hide import button on web since web uses URL imports
                                    Text(AppLocalizations.of(context)!.o,
                                        style: const TextStyle(fontSize: 14)),
                                  if (!kIsWeb) // Hide import button on web since web uses URL imports
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
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              AppLocalizations.of(
                                                                      context)!
                                                                  .invalidCode)));
                                                }
                                                final newTerm = Term.fromString(
                                                        decodedSchedule.term) ??
                                                    Term.getPredictedTerm();
                                                matricalCubit
                                                    .updateTerm(newTerm);

                                                matricalCubit.updateYear(
                                                    decodedSchedule.year);
                                                termController.text =
                                                    newTerm.displayName;
                                                yearController.text =
                                                    decodedSchedule.year
                                                        .toString();
                                                matricalCubit.updateCourses(
                                                    decodedSchedule.courses.map(
                                                        (courseWithSection) {
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
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .successfullyImportedSchedule)));
                                              }
                                            });
                                          },
                                          child: Text(
                                              AppLocalizations.of(context)!
                                                  .import,
                                              style: TextStyle(
                                                  color: Colors.green[900],
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                  decoration: TextDecoration
                                                      .underline)),
                                        ))
                                ],
                              ),
                              FocusScope(
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: TypeAheadField<String>(
                                      suggestionsCallback: (search) async {
                                        if (search.isEmpty) {
                                          return [];
                                        }
                                        final cs = CourseService.getInstance();
                                        return await cs.autocompleteQuery(
                                            search,
                                            matricalState.term.databaseKey,
                                            matricalState.year);
                                      },
                                      builder:
                                          (context, controller, focusNode) {
                                        courseController = controller;
                                        return TextField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            decoration: InputDecoration(
                                              labelText:
                                                  AppLocalizations.of(context)!
                                                      .requiredCourseInput,
                                              hintText: 'e.g. CIIC3015',
                                            ),
                                            textCapitalization:
                                                TextCapitalization.characters,
                                            keyboardType:
                                                TextInputType.visiblePassword,
                                            inputFormatters: [
                                              UpperCaseTextFormatter()
                                            ],
                                            textInputAction:
                                                TextInputAction.next,
                                            onSubmitted: (maybeCourse) async {
                                              if (maybeCourse.length == 4) {
                                                matricalCubit
                                                    .setLastSearch(maybeCourse);
                                                matricalCubit.setPage(
                                                    MatricalPage.courseSearch);
                                              } else {
                                                // clear section controller when course changes
                                                // to trigger autocomplete refresh
                                                sectionController?.text = "";
                                              }
                                            });
                                      },
                                      itemBuilder: (context, suggestion) {
                                        return ListTile(
                                          title: Text(suggestion),
                                        );
                                      },
                                      errorBuilder: (context, error) => Text(
                                          AppLocalizations.of(context)!
                                              .courseAutocompleteError),
                                      emptyBuilder: (context) =>
                                          const SizedBox.shrink(),
                                      onSelected: (suggestion) {
                                        courseController?.text = suggestion;
                                        // clear section controller when course changes
                                        // to trigger autocomplete refresh
                                        sectionController?.text = "";
                                      },
                                    )),
                                    const Text("  —  "),
                                    Expanded(
                                        child: TypeAheadField<String>(
                                            suggestionsCallback:
                                                (search) async {
                                              if (courseController == null ||
                                                  search.isEmpty) {
                                                return [];
                                              }
                                              final courseCode =
                                                  courseController?.text ?? "";

                                              final cs =
                                                  CourseService.getInstance();
                                              return await cs
                                                  .autocompleteSections(
                                                      courseCode,
                                                      search,
                                                      matricalState
                                                          .term.databaseKey,
                                                      matricalState.year);
                                            },
                                            itemBuilder: (context, suggestion) {
                                              return ListTile(
                                                title: Text(suggestion),
                                              );
                                            },
                                            errorBuilder: (context, error) =>
                                                Text(AppLocalizations.of(
                                                        context)!
                                                    .sectionAutocompleteError),
                                            emptyBuilder: (context) =>
                                                const SizedBox.shrink(),
                                            onSelected: (suggestion) {
                                              sectionController?.text =
                                                  suggestion;
                                              _addCourse(
                                                  innerContext,
                                                  matricalState
                                                      .term.databaseKey,
                                                  matricalState.year,
                                                  internetState);
                                            },
                                            builder: (context, controller,
                                                focusNode) {
                                              sectionController = controller;
                                              return TextField(
                                                controller: controller,
                                                focusNode: focusNode,
                                                decoration: InputDecoration(
                                                  hintText: 'e.g. 070, 001D',
                                                  labelText:
                                                      AppLocalizations.of(
                                                              context)!
                                                          .section,
                                                ),
                                                textCapitalization:
                                                    TextCapitalization
                                                        .characters,
                                                keyboardType: TextInputType
                                                    .visiblePassword,
                                                inputFormatters: [
                                                  UpperCaseTextFormatter()
                                                ],
                                                textInputAction:
                                                    TextInputAction.done,
                                                onSubmitted: (value) =>
                                                    _addCourse(
                                                        innerContext,
                                                        matricalState
                                                            .term.databaseKey,
                                                        matricalState.year,
                                                        internetState),
                                              );
                                            })),
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
                            onPressed: () {
                              if (courseController?.text.length == 4) {
                                matricalCubit
                                    .setLastSearch(courseController?.text);
                                matricalCubit
                                    .setPage(MatricalPage.courseSearch);
                              } else {
                                _addCourse(
                                    innerContext,
                                    matricalState.term.databaseKey,
                                    matricalState.year,
                                    internetState);
                              }
                            },
                            child: const Icon(Icons.add)),
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
                                                  matricalCubit
                                                      .removeSection(i);
                                                },
                                                icon: const Icon(Icons.undo)),
                                          IconButton(
                                              onPressed: () {
                                                matricalCubit.removeCourse(i);
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
                      if (kIsWeb) // Only show share courses on web
                        Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ElevatedButton(
                                onPressed: () async {
                                  if (matricalState
                                      .selectedCourses.isNotEmpty) {
                                    await _shareCourses(
                                        context,
                                        matricalState.term,
                                        matricalState.year,
                                        matricalState.selectedCourses);
                                  } else {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(SnackBar(
                                        content: Text(
                                            AppLocalizations.of(context)!
                                                .addCoursesToShare),
                                      ));
                                  }
                                },
                                child: const Icon(Icons.share_rounded))),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: FilledButton(
                            onPressed: () {
                              if (matricalState.selectedCourses.isNotEmpty) {
                                matricalCubit
                                    .setPage(MatricalPage.generatedSchedules);
                              } else {
                                ScaffoldMessenger.of(innerContext)
                                    .hideCurrentSnackBar(); // don't need remove here since snackbar blocks button
                                ScaffoldMessenger.of(innerContext)
                                    .showSnackBar(SnackBar(
                                  content: Text(AppLocalizations.of(context)!
                                      .addCoursesPriorToGeneratingSchedules),
                                ));
                              }
                            },
                            child: Text(
                                AppLocalizations.of(context)!
                                    .generateSchedulesButton,
                                textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
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
                                              Expanded(
                                                child: Text(AppLocalizations.of(
                                                        context)!
                                                    .schedulePreferences),
                                              ),
                                              _preferencesHelp(context)
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

Future<void> _shareCourses(BuildContext context, Term term, int year,
    List<CourseWithFilters> courses) async {
  final browser = Browser.detectOrNull(); // Always null when not on web
  /*
      On browsers with access to the webshare API, 
      use that to share the URL or Text code. Otherwise, fall back to
      writing the URL to the clipboard.
      Exceptions: FireFox has WebShare but text isn't properly copied onto it

    */
  final queryParams = {
    "term": term.databaseKey,
    "year": year.toString(),
    "courses": courses.map((cs) {
      String courseString = cs.courseCode;
      if (cs.sectionCode != "") {
        courseString += "-${cs.sectionCode}";
      }
      return courseString;
    }).join(",")
  };
  final shareURL = Uri.base.replace(queryParameters: queryParams).toString();
  if (browser != null) {
    switch (browser.browserAgent) {
      case BrowserAgent.Chrome:
      case BrowserAgent.Edge:
      case BrowserAgent.EdgeChromium:
      case BrowserAgent.Safari:
        await Share.share(shareURL);
        return; // exit early after a successful share
      default:
        break;
    }
  }

  await Clipboard.setData(ClipboardData(text: shareURL));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text(AppLocalizations.of(context)!.scheduleLinkCopiedToClipboard),
      ));
  }
}

Widget _preferencesHelp(BuildContext context) {
  return InfoWidget(
      infoText: [
        AppLocalizations.of(context)!.preferencesHelpOverview,
        AppLocalizations.of(context)!.preferencesHelpSparseDense,
        AppLocalizations.of(context)!.preferencesHelpModality,
        AppLocalizations.of(context)!.preferencesHelpTime
      ].join("\n\n"),
      iconData: Icons.help,
      iconColor: Colors.black87);
}
