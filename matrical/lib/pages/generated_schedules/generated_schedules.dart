import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:info_widget/info_widget.dart';
import 'package:matrical/globals/cubits.dart';
import 'package:matrical/globals/scaffold.dart';
import 'package:matrical/models/blacklist.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/department_course.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/models/generated_schedule_preferences.dart';
import 'package:matrical/models/matrical_cubit.dart';
import 'package:matrical/models/matrical_page.dart';
import 'package:matrical/models/saved_schedule.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/models/weekday.dart';
import 'package:matrical/pages/generated_schedules/course_view.dart';
import 'package:matrical/pages/generated_schedules/preferences_view.dart';
import 'package:matrical/pages/generated_schedules/save_schedule_dialog.dart';
import 'package:matrical/pages/generated_schedules/schedule_table_view.dart';
import 'package:matrical/services/schedule_service.dart';
import 'package:matrical/services/widgets_service.dart';
import 'package:matrical/widgets/export_schedule_dialog.dart';
import 'package:matrical/widgets/info_wrapper.dart';
import 'package:pair/pair.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);
const TextStyle textStyle = TextStyle(color: Colors.white);

enum RegeneratedSchedulesCause { defaultCause, preferenceChanged }

class GeneratedSchedules extends StatefulWidget {
  const GeneratedSchedules({super.key});

  @override
  State<GeneratedSchedules> createState() => _GeneratedSchedulesState();
}

class _GeneratedSchedulesState extends State<GeneratedSchedules> {
  // used to automatically dismiss the saved schedules banner after 3 seconds
  Timer? _savedScheduleBannerTimer;
  Future<List<GeneratedSchedule>> schedules =
      Future.value(<GeneratedSchedule>[]);
  int currentSchedule = 0;
  var eventController = EventController();
  var weekViewKey = GlobalKey<WeekViewState>();
  var scrollOffset = 0.0;
  var mappings = <String>["L", "M", "W", "J", "V"];

  // Track generated filters vars
  var regeneratedSchedules = false;
  var oldScheduleCodes = <Map<String, String>>[];
  var oldSchedulesLength = 0;
  var regeneratedSchedulesCause = RegeneratedSchedulesCause.defaultCause;

  late Term term;
  late int year;
  late List<CourseWithFilters> courses;
  late GeneratedSchedulePreferences preferences;
  late Blacklist blacklist;
  late CourseFilters filters;
  late bool editMode;
  late int currentPreferencesTab;
  late RangeValues dayRangeValues;
  late RangeValues timeRangeValues;

  @override
  void initState() {
    final MatricalState state = matricalCubitSingleton.state;
    term = state.term;
    year = state.year;
    courses = state.selectedCourses;
    preferences = state.preferences;
    for (var e in courses) {
      if (preferences.professorRankings[e.courseCode] == null) {
        // Empty list will be mutated later
        // ignore: prefer_const_constructors
        preferences.professorRankings[e.courseCode] = Pair(false, []);
      }
    }
    blacklist = state.blacklist;
    filters = state.generatedSchedulesFilters;
    editMode = state.generatedSchedulesEditMode;
    currentPreferencesTab = state.generatedSchedulesCurrentPreferencesTab;
    timeRangeValues = RangeValues(
        filters.earliestTime.isNotEmpty
            ? GeneratedSchedule.getTimeAsDouble(filters.earliestTime)
            : 0,
        filters.latestTime.isNotEmpty
            ? GeneratedSchedule.getTimeAsDouble(filters.latestTime)
            : 23);
    dayRangeValues = filters.days.isNotEmpty
        ? RangeValues(
            mappings.indexOf(filters.days.characters.first).toDouble(),
            mappings.indexOf(filters.days.characters.last).toDouble())
        : const RangeValues(0, 4);

    schedules = generateSchedules(
        courses, term.databaseKey, year, blacklist, filters, preferences);
    schedules.then((value) {
      if (value.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "No encontramos horarios válidos con tus cursos y preferencias.")));
      }
    });
    currentSchedule = 0;
    super.initState();
  }

  void _nextSchedule(int scheduleCount) {
    setState(() {
      if (currentSchedule < scheduleCount - 1) {
        currentSchedule++;
      }
    });
  }

  void _previousSchedule() {
    setState(() {
      if (currentSchedule > 0) currentSchedule--;
    });
  }

  bool isLocked(String courseCode, String sectionCode) {
    return courses
        .any((e) => e.courseCode == courseCode && e.sectionCode == sectionCode);
  }

  @override
  Widget build(BuildContext context) {
    final matricalCubit = BlocProvider.of<MatricalCubit>(context);
    return PopScope(
        onPopInvoked: (popped) {
          _savedScheduleBannerTimer?.cancel();
          if (popped) ScaffoldMessenger.of(context).clearMaterialBanners();
        },
        child: FutureBuilder(
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
                  setState(() {
                    schedules = Future.value([]);
                  });
                });
                return const Center(child: CircularProgressIndicator());
              } else {
                void regenerateSchedules(
                    {RegeneratedSchedulesCause cause =
                        RegeneratedSchedulesCause.defaultCause}) {
                  setState(() {
                    regeneratedSchedules = true;
                    regeneratedSchedulesCause = cause;

                    oldSchedulesLength = snapshot.data!.length;
                    if (snapshot.data!.isNotEmpty) {
                      oldScheduleCodes = snapshot.data![currentSchedule].courses
                          .map((e) => {
                                "courseCode": e.course.courseCode,
                                "sectionCode": e.sectionCode
                              })
                          .toList();
                    }

                    schedules = generateSchedules(courses, term.databaseKey,
                        year, blacklist, filters, preferences);
                    schedules.then((value) {
                      if (value.isEmpty) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                "No encontramos horarios válidos con tus cursos y preferencias.")));
                      }
                    });
                  });
                }

                void applyLock(String courseCode, String sectionCode) {
                  if (sectionCode.length > 3 && sectionCode.endsWith("L")) {
                    courses.add(CourseWithFilters(
                        courseCode: courseCode,
                        sectionCode: sectionCode,
                        filters: CourseFilters.empty()));
                    return;
                  }
                  for (var course in courses) {
                    if (course.courseCode == courseCode) {
                      course.sectionCode = sectionCode;
                      return;
                    }
                  }
                }

                void removeLock(String courseCode, String sectionCode) {
                  if (sectionCode.length > 3 && sectionCode.endsWith("L")) {
                    courses.removeWhere((e) =>
                        e.courseCode == courseCode &&
                        e.sectionCode == sectionCode);
                    return;
                  }
                  for (var course in courses) {
                    if (course.courseCode == courseCode) {
                      course.sectionCode = "";
                      return;
                    }
                  }
                }

                double getScrollOffset() => snapshot.data!.isNotEmpty
                    ? max(snapshot.data![currentSchedule].getEarliestHour() - 1,
                            0) *
                        60.0
                    : 0;

                var notPresencial = <CourseSectionPair>[];

                if (snapshot.data!.isEmpty) {
                  currentSchedule = -1;
                  eventController = EventController();
                  scrollOffset = 0;
                } else {
                  if (currentSchedule == -1) currentSchedule = 0;

                  if (regeneratedSchedules) {
                    if (oldSchedulesLength == 0) {
                      currentSchedule = 0;
                    } else {
                      currentSchedule = snapshot.data!.indexWhere((schedule) =>
                          !schedule.courses.any((pair) => !oldScheduleCodes.any(
                              (e) =>
                                  pair.course.courseCode == e["courseCode"] &&
                                  pair.sectionCode == e["sectionCode"])));
                      if (currentSchedule == -1) {
                        currentSchedule =
                            snapshot.data!.length > oldSchedulesLength
                                ? snapshot.data!.length - 1
                                : 0;
                      }
                    }
                    switch (regeneratedSchedulesCause) {
                      case RegeneratedSchedulesCause.preferenceChanged:
                        currentSchedule = 0;
                        break;
                      case RegeneratedSchedulesCause.defaultCause:
                        break;
                    }
                    regeneratedSchedules = false;
                  }

                  snapshot.data![currentSchedule]
                      .overwriteEventController(eventController, isLocked);

                  scrollOffset = getScrollOffset();

                  notPresencial = snapshot.data![currentSchedule]
                      .getCourseSectionPairsByModality(Modality.byagreement);
                }

                return CalendarControllerProvider(
                    controller: eventController,
                    child: Column(
                      children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Flexible(
                                      child: SizedBox(
                                    height: 45,
                                    width: 120,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.all(10),
                                          textStyle: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15.0),
                                          )),
                                      onPressed: snapshot.data == null ||
                                              snapshot.data!.isEmpty
                                          ? null
                                          : () {
                                              showDialog(
                                                useRootNavigator: false,
                                                context: context,
                                                builder: (BuildContext
                                                    innerContext) {
                                                  return ExportScheduleDialog(
                                                    notPresencialCourses:
                                                        notPresencial,
                                                    schedule: snapshot
                                                        .data![currentSchedule],
                                                  );
                                                },
                                              );
                                            },
                                      child: const Text("Exportar"),
                                    ),
                                  )),
                                  Flexible(
                                      child: SizedBox(
                                    height: 45,
                                    width: 120,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.all(10),
                                          textStyle: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15.0),
                                          )),
                                      onPressed: snapshot.data == null ||
                                              snapshot.data!.isEmpty
                                          ? null
                                          : () {
                                              showDialog(
                                                  useRootNavigator: false,
                                                  context: context,
                                                  builder: (innerContext) =>
                                                      ScheduleTableView(
                                                          schedule: snapshot
                                                                  .data![
                                                              currentSchedule]));
                                            },
                                      child: const Text("Vista"),
                                    ),
                                  )),
                                  Flexible(
                                      child: SizedBox(
                                    height: 45,
                                    width: 120,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.all(10),
                                          textStyle: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15.0),
                                          )),
                                      onPressed: snapshot.data == null ||
                                              snapshot.data!.isEmpty
                                          ? null
                                          : () {
                                              showDialog<SaveScheduleResult?>(
                                                context: context,
                                                useRootNavigator: false,
                                                builder: (BuildContext
                                                    innerContext) {
                                                  return SaveScheduleDialog(
                                                    currentSchedule: snapshot
                                                            .data![
                                                        currentSchedule], // Make sure to pass the actual current schedule object
                                                  );
                                                },
                                              ).then((result) {
                                                if (result == null) return;
                                                final icon = result ==
                                                        SaveScheduleResult
                                                            .success
                                                    ? const Icon(
                                                        Icons.check,
                                                        color: Colors.green,
                                                      )
                                                    : const Icon(
                                                        Icons.close,
                                                        color: Colors.red,
                                                      );
                                                ScaffoldMessenger.of(context)
                                                    .showMaterialBanner(
                                                        MaterialBanner(
                                                  content: Row(
                                                    children: [
                                                      Text(result.message,
                                                          softWrap: true,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      15)),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .fromLTRB(
                                                                8, 0, 8, 0),
                                                        child: icon,
                                                      )
                                                    ],
                                                  ),
                                                  actions: [
                                                    if (result ==
                                                        SaveScheduleResult
                                                            .success)
                                                      TextButton(
                                                        onPressed: () {
                                                          _savedScheduleBannerTimer
                                                              ?.cancel();
                                                          ScaffoldMessenger.of(
                                                                  globalKey
                                                                      .currentContext!)
                                                              .hideCurrentMaterialBanner();
                                                          matricalCubit.setPage(
                                                            MatricalPage
                                                                .savedSchedules,
                                                          );
                                                        },
                                                        child: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .view),
                                                      ),
                                                    TextButton(
                                                      onPressed: () {
                                                        ScaffoldMessenger.of(
                                                                globalKey
                                                                    .currentContext!)
                                                            .hideCurrentMaterialBanner();
                                                      },
                                                      child: Text(
                                                          AppLocalizations.of(
                                                                  context)!
                                                              .dismiss),
                                                    ),
                                                  ],
                                                ));
                                                _savedScheduleBannerTimer
                                                    ?.cancel();
                                                // Start a new timer
                                                _savedScheduleBannerTimer =
                                                    Timer(
                                                        const Duration(
                                                            seconds: 3),
                                                        () async {
                                                  ScaffoldMessenger.of(globalKey
                                                          .currentContext!)
                                                      .hideCurrentMaterialBanner();
                                                });
                                              });
                                            },
                                      child: const Text("Guardar"),
                                    ),
                                  )),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 0, 30, 0),
                                  child: IconButton(
                                    onPressed: () {
                                      showDialog<
                                              SchedulePreferencesDialogStateModel?>(
                                          useRootNavigator: false,
                                          context: context,
                                          builder: (context) =>
                                              SchedulePreferencesDialog(
                                                currentPreferencesTab:
                                                    currentPreferencesTab,
                                                oldPreferences: preferences,
                                                oldBlacklist: blacklist,
                                                currentCourseCodes: courses
                                                    .map((e) => e.courseCode)
                                                    .toList(),
                                              )).then((state) {
                                        if (state != null) {
                                          setState(() {
                                            currentPreferencesTab =
                                                state.currentPreferencesTab;
                                            matricalCubit
                                                .setGeneratedSchedulesCurrentPreferencesTab(
                                                    currentPreferencesTab);
                                            if (state.hadUpdate) {
                                              matricalCubit.updatePreferences(
                                                  state.preferences);
                                              matricalCubit.updateBlacklist(
                                                  state.blacklist);
                                              preferences = state.preferences;
                                              blacklist = state.blacklist;
                                              regenerateSchedules(
                                                  cause:
                                                      RegeneratedSchedulesCause
                                                          .preferenceChanged);
                                            }
                                          });
                                        }
                                      });
                                    },
                                    icon: const Icon(Icons.settings),
                                  ),
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          currentSchedule =
                                              snapshot.data!.isNotEmpty
                                                  ? 0
                                                  : -1;
                                          weekViewKey
                                              .currentState?.scrollController
                                              .jumpTo(getScrollOffset());
                                        });
                                      },
                                      customBorder: const CircleBorder(),
                                      child: const Icon(
                                        Icons
                                            .keyboard_double_arrow_left_outlined,
                                        size: 40,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        _previousSchedule();
                                        weekViewKey
                                            .currentState?.scrollController
                                            .jumpTo(getScrollOffset());
                                      },
                                      customBorder: const CircleBorder(),
                                      child: const Icon(
                                        Icons.arrow_left_outlined,
                                        size: 40,
                                      ),
                                    ),
                                    Text(
                                        "${currentSchedule + 1}/${snapshot.data!.length}"),
                                    InkWell(
                                      onTap: () {
                                        _nextSchedule(snapshot.data!.length);
                                        weekViewKey
                                            .currentState?.scrollController
                                            .jumpTo(getScrollOffset());
                                      },
                                      customBorder: const CircleBorder(),
                                      child: const Icon(
                                        Icons.arrow_right_outlined,
                                        size: 40,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          currentSchedule =
                                              snapshot.data!.length - 1;
                                          weekViewKey
                                              .currentState?.scrollController
                                              .jumpTo(getScrollOffset());
                                        });
                                      },
                                      customBorder: const CircleBorder(),
                                      child: const Icon(
                                        Icons
                                            .keyboard_double_arrow_right_outlined,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                                InfoWrapper(
                                  title: "Filtros de Horario",
                                  content:
                                      "Al activarlos, puedes limitar el rango de horas y días donde quieres tener clase.",
                                  child: Row(
                                    children: [
                                      const Icon(Icons.filter_alt),
                                      Switch(
                                          value: editMode,
                                          onChanged: (bool value) {
                                            setState(() {
                                              editMode = value;
                                              matricalCubit
                                                  .setGeneratedSchedulesEditMode(
                                                      editMode);
                                            });
                                          }),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 8),
                            if (editMode)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month),
                                    Expanded(
                                      child: RangeSlider(
                                          values: dayRangeValues,
                                          max: 4,
                                          divisions: 4,
                                          labels: RangeLabels(
                                            mappings[
                                                dayRangeValues.start.round()],
                                            mappings[
                                                dayRangeValues.end.round()],
                                          ),
                                          onChanged: (RangeValues values) {
                                            setState(() {
                                              dayRangeValues = values;
                                            });
                                          },
                                          onChangeEnd: (RangeValues values) {
                                            filters.days = mappings
                                                .sublist(
                                                    dayRangeValues.start
                                                        .round(),
                                                    dayRangeValues.end.round() +
                                                        1)
                                                .join("");
                                            regenerateSchedules();
                                          }),
                                    ),
                                  ],
                                ),
                              ),
                            if (editMode) const Divider(),
                          ] +
                          splitWidgets(
                              notPresencial
                                  .map((pair) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                    useRootNavigator: false,
                                                    context: context,
                                                    builder: (context) =>
                                                        CourseView(
                                                            pair: pair,
                                                            blacklist:
                                                                blacklist,
                                                            regenerateSchedules:
                                                                regenerateSchedules,
                                                            isLocked: isLocked,
                                                            applyLock:
                                                                applyLock,
                                                            removeLock:
                                                                removeLock));
                                              },
                                              child: Container(
                                                height: 32,
                                                decoration: BoxDecoration(
                                                    color: pair.getColor(),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                child: Center(
                                                  child: Text(
                                                      "${isLocked(pair.course.courseCode, pair.sectionCode) ? "🔒" : ""}${pair.course.courseCode}-${pair.sectionCode}",
                                                      style: const TextStyle(
                                                          color: Colors.white)),
                                                ),
                                              )),
                                        ),
                                      ))
                                  .toList(),
                              2) +
                          <Widget>[
                            if (notPresencial.isNotEmpty)
                              const Divider(height: 8),
                            Expanded(
                              child: GestureDetector(
                                onHorizontalDragEnd: (dragEndDetails) {
                                  if ((dragEndDetails.primaryVelocity ?? 0) <
                                      0) {
                                    _nextSchedule(snapshot.data!.length);
                                  } else if ((dragEndDetails.primaryVelocity ??
                                          0) >
                                      0) {
                                    _previousSchedule();
                                  }
                                  weekViewKey.currentState?.scrollController
                                      .jumpTo(getScrollOffset());
                                },
                                child: WeekView(
                                  key: weekViewKey,
                                  minDay: DateTime(2024, 1, 1),
                                  maxDay: DateTime(2024, 1, 5),
                                  weekNumberBuilder: (_) => null,
                                  weekDayBuilder: (date) => Center(
                                      child: Text(weekday[date.weekday])),
                                  headerStyle: const HeaderStyle(
                                    leftIconVisible: false,
                                    rightIconVisible: false,
                                    headerTextStyle: TextStyle(fontSize: 0),
                                  ),
                                  showWeekends: false,
                                  heightPerMinute: 1.0,
                                  onEventTap: (events, date) {
                                    final sectionData = getEventDetails(
                                        events.first.description!);
                                    final pair = snapshot.data![currentSchedule]
                                        .getCourseSectionPair(
                                            sectionData["courseCode"]!
                                                as String,
                                            sectionData["sectionCode"]!
                                                as String)!;
                                    showDialog(
                                        useRootNavigator: false,
                                        context: context,
                                        builder: (context) => CourseView(
                                            pair: pair,
                                            blacklist: blacklist,
                                            regenerateSchedules:
                                                regenerateSchedules,
                                            isLocked: isLocked,
                                            applyLock: applyLock,
                                            removeLock: removeLock));
                                  },
                                  minuteSlotSize: MinuteSlotSize.minutes30,
                                  scrollOffset: scrollOffset,
                                  timeLineWidth: 56,
                                ),
                              ),
                            ),
                            if (editMode) const Divider(),
                            if (editMode)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time),
                                    Expanded(
                                      child: RangeSlider(
                                          values: timeRangeValues,
                                          max: 23,
                                          divisions: 23,
                                          labels: RangeLabels(
                                            Meeting.convertTo12HourFormat(
                                                "${timeRangeValues.start.round().toString().padLeft(2, '0')}:00"),
                                            Meeting.convertTo12HourFormat(
                                                "${timeRangeValues.end.round().toString().padLeft(2, '0')}:00"),
                                          ),
                                          onChanged: (RangeValues values) {
                                            setState(() {
                                              timeRangeValues = values;
                                            });
                                          },
                                          onChangeEnd: (RangeValues values) {
                                            filters.earliestTime =
                                                "${timeRangeValues.start.round().toString().padLeft(2, '0')}:00";
                                            filters.latestTime =
                                                "${timeRangeValues.end.round().toString().padLeft(2, '0')}:00";
                                            regenerateSchedules();
                                          }),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                    ));
              }
            }));
  }
}

Map<String, dynamic> getEventDetails(String event) {
  final decodedEvent = jsonDecode(event) as Map<String, dynamic>;
  assert(decodedEvent.containsKey("courseCode"));
  assert(decodedEvent.containsKey("sectionCode"));
  assert(decodedEvent.containsKey("room"));
  return decodedEvent;
}

class SchedulePreferencesDialogStateModel {
  bool hadUpdate;
  int currentPreferencesTab;
  GeneratedSchedulePreferences preferences;
  Blacklist blacklist;

  SchedulePreferencesDialogStateModel(
      {required this.hadUpdate,
      required this.currentPreferencesTab,
      required this.preferences,
      required this.blacklist});
}

class SchedulePreferencesDialog extends StatefulWidget {
  final int currentPreferencesTab;
  final GeneratedSchedulePreferences oldPreferences;
  final Blacklist oldBlacklist;
  final List<String> currentCourseCodes;

  const SchedulePreferencesDialog({
    super.key,
    required this.currentPreferencesTab,
    required this.oldPreferences,
    required this.oldBlacklist,
    required this.currentCourseCodes,
  });

  @override
  State<SchedulePreferencesDialog> createState() =>
      _SchedulePreferencesDialogState();
}

class _SchedulePreferencesDialogState extends State<SchedulePreferencesDialog> {
  late SchedulePreferencesDialogStateModel state;

  @override
  void initState() {
    super.initState();

    state = SchedulePreferencesDialogStateModel(
        hadUpdate: false,
        currentPreferencesTab: widget.currentPreferencesTab,
        preferences: widget.oldPreferences.copy(),
        blacklist: widget.oldBlacklist.copy());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.of(context).pop(state);
      },
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Expanded(child: Text("Preferencias de Horario")),
          InfoWidget(
            infoText:
                "Aquí puedes controlar cuales horarios serán mostrados primeros basados en tus preferencias.\n\nEsparcido / Denso - Controla si las secciones deben tener espacio entremedio o no.\nPresencial / Por Acuerdo - Modalidad preferida.\nTiempo Preferido para Cursos - Selecciona cuándo tomar los cursos durante el día.\n\nRanking de Profesores - Ordena profesores basado en tus gustos. Presiona en un curso para activar ranking de ese curso.\n\nProfesores Excluídos - Ver y/o incluír de vuelta profesores.\n\nSecciones Excluidas - Ver y/o incluír de vuelta secciones.",
            iconColor: Colors.black87,
            iconData: Icons.help,
          )
        ]),
        content: SizedBox(
            height: 45.h,
            width: 70.w,
            child: DefaultTabController(
                initialIndex: widget.currentPreferencesTab,
                length: 4,
                child: Column(children: [
                  TabBar(
                      onTap: (index) {
                        state.currentPreferencesTab = index;
                      },
                      tabs: const [
                        Tab(icon: Icon(Icons.toggle_on, size: 32)),
                        Tab(icon: Icon(Icons.format_list_numbered, size: 32)),
                        Tab(icon: Icon(Icons.contacts, size: 24)),
                        Tab(icon: Icon(Icons.onetwothree, size: 48)),
                      ]),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        PreferencesView(preferences: state.preferences),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(0, 8.0, 0, 12.0),
                              child: Text("Ranking de Profesores:",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: state
                                        .preferences.professorRankings.entries
                                        .sorted(
                                            (a, b) => a.key.compareTo(b.key))
                                        .expand((e) => widget.currentCourseCodes
                                                .contains(e.key)
                                            ? [
                                                ExpansionTile(
                                                  shape: const Border(),
                                                  expandedCrossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  title: Text(
                                                    e.key,
                                                    style: const TextStyle(
                                                        fontSize: 18),
                                                  ),
                                                  trailing: Icon(e.value.key
                                                      ? Icons.rotate_left
                                                      : Icons
                                                          .format_list_numbered_rtl),
                                                  initiallyExpanded:
                                                      e.value.key,
                                                  onExpansionChanged: (value) {
                                                    setState(() {
                                                      state.preferences
                                                              .professorRankings[
                                                          e
                                                              .key] = Pair(
                                                          value, e.value.value);
                                                    });
                                                  },
                                                  children: e.value.value
                                                      .expandIndexed(
                                                          (i, p) => !p.value
                                                              ? <Widget>[]
                                                              : [
                                                                  Column(
                                                                    children: [
                                                                      Divider(
                                                                        thickness: state.preferences.getProfessorRank(e.key, p.key) ==
                                                                                1
                                                                            ? 2
                                                                            : 1,
                                                                      ),
                                                                      Row(
                                                                        children: [
                                                                          Text(
                                                                              "#${state.preferences.getProfessorRank(e.key, p.key)}:"),
                                                                          Expanded(
                                                                              child: Padding(
                                                                            padding:
                                                                                const EdgeInsets.symmetric(horizontal: 12.0),
                                                                            child: p.key.url.isEmpty
                                                                                ? Text(p.key.name)
                                                                                : InkWell(
                                                                                    onTap: () async {
                                                                                      await launchUrl(Uri.parse(p.key.url));
                                                                                    },
                                                                                    child: Text(p.key.name, style: TextStyle(color: Colors.green[900], fontStyle: FontStyle.italic, decoration: TextDecoration.underline)),
                                                                                  ),
                                                                          )),
                                                                          InkWell(
                                                                              onTap: () {
                                                                                setState(() {
                                                                                  state.blacklist.professors.add(p.key);
                                                                                  state.preferences.professorRankings.forEach((key, value) {
                                                                                    value.value.forEachIndexed((index, element) {
                                                                                      if (element.key == p.key) {
                                                                                        value.value[index] = Pair(p.key, false);
                                                                                      }
                                                                                    });
                                                                                  });
                                                                                });
                                                                              },
                                                                              customBorder: const CircleBorder(),
                                                                              child: const Padding(
                                                                                padding: EdgeInsets.all(8.0),
                                                                                child: Icon(Icons.close, size: 24),
                                                                              )),
                                                                          InkWell(
                                                                              onTap: () {
                                                                                setState(() {
                                                                                  if (state.preferences.getProfessorRank(e.key, p.key) == state.preferences.getMaxProfessorRank(e.key)) {
                                                                                    return;
                                                                                  }
                                                                                  for (var j = i + 1; j < e.value.value.length; j++) {
                                                                                    var temp = e.value.value[j];
                                                                                    e.value.value[j] = e.value.value[j - 1];
                                                                                    e.value.value[j - 1] = temp;
                                                                                    if (temp.value) break;
                                                                                  }
                                                                                });
                                                                              },
                                                                              customBorder: const CircleBorder(),
                                                                              child: const Padding(
                                                                                padding: EdgeInsets.all(8.0),
                                                                                child: Icon(Icons.arrow_downward, size: 24),
                                                                              )),
                                                                          InkWell(
                                                                              onTap: () {
                                                                                setState(() {
                                                                                  if (state.preferences.getProfessorRank(e.key, p.key) == 1) {
                                                                                    return;
                                                                                  }
                                                                                  for (var j = i - 1; j >= 0; j--) {
                                                                                    var temp = e.value.value[j];
                                                                                    e.value.value[j] = e.value.value[j + 1];
                                                                                    e.value.value[j + 1] = temp;
                                                                                    if (temp.value) break;
                                                                                  }
                                                                                });
                                                                              },
                                                                              customBorder: const CircleBorder(),
                                                                              child: const Padding(
                                                                                padding: EdgeInsets.all(8.0),
                                                                                child: Icon(Icons.arrow_upward, size: 24),
                                                                              )),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  )
                                                                ])
                                                      .toList(),
                                                ),
                                                if (e.key !=
                                                    state
                                                        .preferences
                                                        .professorRankings
                                                        .entries
                                                        .sorted((a, b) => a.key
                                                            .compareTo(b.key))
                                                        .where((entry) => widget
                                                            .currentCourseCodes
                                                            .contains(
                                                                entry.key))
                                                        .last
                                                        .key)
                                                  const Divider(
                                                    thickness: 3,
                                                  )
                                              ]
                                            : <Widget>[])
                                        .toList()),
                              ),
                            ),
                          ],
                        ),
                        SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          "Profesores Excluidos:",
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      if (state.blacklist.professors.isEmpty)
                                        const Text(
                                            "Ningún profesor ha sido excluido")
                                    ] +
                                    state.blacklist.professors
                                        .map((professor) => Material(
                                              color: Colors.transparent,
                                              child: Row(
                                                children: [
                                                  professor.url.isEmpty
                                                      ? Text(professor.name,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 16))
                                                      : InkWell(
                                                          onTap: () async {
                                                            await launchUrl(
                                                                Uri.parse(
                                                                    professor
                                                                        .url));
                                                          },
                                                          child: Text(
                                                              professor.name,
                                                              style: TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                          .green[
                                                                      900],
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                  decoration:
                                                                      TextDecoration
                                                                          .underline)),
                                                        ),
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        state.blacklist
                                                            .professors
                                                            .remove(professor);
                                                        state.preferences
                                                            .professorRankings
                                                            .forEach(
                                                                (key, value) {
                                                          value.value
                                                              .forEachIndexed(
                                                                  (index,
                                                                      element) {
                                                            if (element.key ==
                                                                professor) {
                                                              value.value[
                                                                      index] =
                                                                  Pair(
                                                                      professor,
                                                                      true);
                                                            }
                                                          });
                                                        });
                                                      });
                                                    },
                                                    customBorder:
                                                        const CircleBorder(),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(4.0),
                                                      child: Icon(Icons.add,
                                                          size: 16),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ))
                                        .toList())),
                        SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(
                                        "Secciones Excluidas:",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    if (state.blacklist.sections.values
                                        .every((e) => e.isEmpty))
                                      const Text(
                                          "Ninguna sección ha sido excluida")
                                  ] +
                                  state.blacklist.sections.keys
                                      .map((key) => state
                                          .blacklist.sections[key]!
                                          .map((value) => Row(
                                                children: [
                                                  Text("$key-$value",
                                                      style: const TextStyle(
                                                          fontSize: 16)),
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        state.blacklist
                                                            .sections[key]!
                                                            .remove(value);
                                                      });
                                                    },
                                                    customBorder:
                                                        const CircleBorder(),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(4.0),
                                                      child: Icon(Icons.add,
                                                          size: 16),
                                                    ),
                                                  )
                                                ],
                                              )))
                                      .flattened
                                      .toList(),
                            ))
                      ],
                    ),
                  )
                ]))),
        actions: [
          TextButton(
              onPressed: () {
                state.hadUpdate = false;
                Navigator.of(context).pop(state);
              },
              child: const Text("Cancelar")),
          TextButton(
              onPressed: () => setState(() {
                    state.hadUpdate = true;
                    Navigator.of(context).pop(state);
                  }),
              child: const Text("Aplicar"))
        ],
      ),
    );
  }
}
