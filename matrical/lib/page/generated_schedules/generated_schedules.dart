import 'dart:async';
import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:info_widget/info_widget.dart';
import 'package:miuni/features/matrical/data/model/course_filters.dart';
import 'package:miuni/features/matrical/data/model/department_course.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule_preferences.dart';
import 'package:miuni/features/matrical/data/model/saved_schedule.dart';
import 'package:miuni/features/matrical/logic/generate_schedules.dart';
import 'package:miuni/features/matrical/logic/split_widgets.dart';
import 'package:miuni/features/matrical/page/generated_schedules/course_view.dart';
import 'package:miuni/features/matrical/page/generated_schedules/preferences_view.dart';
import 'package:miuni/features/matrical/page/saved_schedules/view_saved_schedules.dart';
import 'package:miuni/features/matrical/page/shared/bug_report.dart';
import 'package:miuni/features/matrical/page/generated_schedules/save_schedule_dialog.dart';
import 'package:miuni/features/matrical/page/generated_schedules/schedule_table_view.dart';
import 'package:miuni/features/matrical/page/shared/export_schedule_dialog.dart';
import 'package:miuni/features/matrical/page/shared/info_wrapper.dart';
import 'package:pair/pair.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);
const TextStyle textStyle = TextStyle(color: Colors.white);

enum RegeneratedSchedulesCause { defaultCause, preferenceChanged }

class GeneratedSchedules extends StatefulWidget {
  final List<CourseWithFilters> courses;
  final String term;
  final int year;
  final GeneratedSchedulePreferences preferences;

  const GeneratedSchedules(
      {super.key,
      required this.courses,
      required this.term,
      required this.year,
      required this.preferences});

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
  var professorBlacklist = <Professor>[];
  var sectionBlackList = <String, List<String>>{};
  var filters = CourseFilters.empty();
  var weekViewKey = GlobalKey<WeekViewState>();
  var scrollOffset = 0.0;
  var dayRangeValues = const RangeValues(0, 4);
  var timeRangeValues = const RangeValues(0, 23);
  var mappings = <String>["L", "M", "W", "J", "V"];
  var editMode = false;
  var currentPreferencesTab = 0;

  // Track generated filters vars
  var regeneratedSchedules = false;
  var oldScheduleCodes = <Map<String, String>>[];
  var oldSchedulesLength = 0;
  var regeneratedSchedulesCause = RegeneratedSchedulesCause.defaultCause;

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
    return widget.courses
        .any((e) => e.courseCode == courseCode && e.sectionCode == sectionCode);
  }

  @override
  void initState() {
    super.initState();
    schedules = generateSchedules(widget.courses, widget.term, widget.year,
        professorBlacklist, sectionBlackList, filters, widget.preferences);
    currentSchedule = 0;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (popped) {
        _savedScheduleBannerTimer?.cancel();
        if (popped) ScaffoldMessenger.of(context).clearMaterialBanners();
      },
      child: Theme(
          data: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                title: const Text(
                  "Horarios de Matrícula",
                  style: textStyle,
                ),
                backgroundColor: officialColor,
                actions: const [
                  BugReport(pageName: "Generated Schedules Page")
                ]),
            body: FutureBuilder(
                future: schedules,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // While waiting for the Future to complete, show a loading indicator
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // If an error occurred, display an error message
                    WidgetsBinding.instance.addPostFrameCallback((_) {
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
                          oldScheduleCodes = snapshot
                              .data![currentSchedule].courses
                              .map((e) => {
                                    "courseCode": e.course.courseCode,
                                    "sectionCode": e.sectionCode
                                  })
                              .toList();
                        }

                        schedules = generateSchedules(
                            widget.courses,
                            widget.term,
                            widget.year,
                            professorBlacklist,
                            sectionBlackList,
                            filters,
                            widget.preferences);
                      });
                    }

                    void applyLock(String courseCode, String sectionCode) {
                      if (sectionCode.length > 3 && sectionCode.endsWith("L")) {
                        widget.courses.add(CourseWithFilters(
                            courseCode: courseCode,
                            sectionCode: sectionCode,
                            filters: CourseFilters.empty()));
                        return;
                      }
                      for (var course in widget.courses) {
                        if (course.courseCode == courseCode) {
                          course.sectionCode = sectionCode;
                          return;
                        }
                      }
                    }

                    void removeLock(String courseCode, String sectionCode) {
                      if (sectionCode.length > 3 && sectionCode.endsWith("L")) {
                        widget.courses.removeWhere((e) =>
                            e.courseCode == courseCode &&
                            e.sectionCode == sectionCode);
                        return;
                      }
                      for (var course in widget.courses) {
                        if (course.courseCode == courseCode) {
                          course.sectionCode = "";
                          return;
                        }
                      }
                    }

                    double getScrollOffset() => snapshot.data!.isNotEmpty
                        ? max(
                                snapshot.data![currentSchedule]
                                        .getEarliestHour() -
                                    1,
                                0) *
                            60.0
                        : 0;

                    var notPresencial = <CourseSectionPair>[];

                    if (snapshot.data!.isEmpty) {
                      currentSchedule = -1;
                      eventController = EventController();
                      scrollOffset = 0;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                "No encontramos horarios válidos con tus cursos y preferencias. Considera eliminar algunos filtros.")));
                      });
                    } else {
                      if (currentSchedule == -1) currentSchedule = 0;

                      if (regeneratedSchedules) {
                        if (oldSchedulesLength == 0) {
                          currentSchedule = 0;
                        } else {
                          currentSchedule = snapshot.data!.indexWhere(
                              (schedule) => !schedule.courses.any((pair) =>
                                  !oldScheduleCodes.any((e) =>
                                      pair.course.courseCode ==
                                          e["courseCode"] &&
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
                          .getCourseSectionPairsByModality(
                              Modality.byagreement);
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
                                                                .data![
                                                            currentSchedule],
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
                                                                  currentSchedule])).then(
                                                      (courses) {
                                                    if (courses != null) {
                                                      Navigator.of(context)
                                                          .pop(courses);
                                                    }
                                                  });
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
                                                  showDialog<
                                                      SaveScheduleResult?>(
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
                                                    var controller =
                                                        ScaffoldMessenger.of(
                                                                context)
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
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .hideCurrentMaterialBanner();
                                                              Navigator.of(
                                                                      context)
                                                                  .push(MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              const ViewSavedSchedules()))
                                                                  .then(
                                                                      (value) {
                                                                if (value !=
                                                                        null &&
                                                                    value
                                                                        is GeneratedSchedule) {
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(
                                                                          value);
                                                                }
                                                              });
                                                            },
                                                            child: const Text(
                                                                'Ver'),
                                                          ),
                                                        TextButton(
                                                          onPressed: () {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .hideCurrentMaterialBanner();
                                                          },
                                                          child: const Text(
                                                              'Despedir'),
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
                                                      try {
                                                        controller.close();
                                                      } catch (e) {
                                                        //TODO: Work on cleaner solution to this. currently it places pressure on dev to remember to kill the timer every time they dismiss the modal.
                                                        print(
                                                            "Frror while closing saved schedule banner. Likely means the timer was not canceled after the banner was dismissed by other means. Exception: ${e.toString()}");
                                                      }
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 0, 30, 0),
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
                                                      oldPreferences:
                                                          widget.preferences,
                                                      oldProfessorBlacklist:
                                                          professorBlacklist,
                                                      oldSectionBlacklist:
                                                          sectionBlackList)).then(
                                              (state) {
                                            if (state != null) {
                                              setState(() {
                                                currentPreferencesTab =
                                                    state.currentPreferencesTab;
                                                if (state.hadUpdate) {
                                                  widget.preferences.updateWith(
                                                      state.preferences);
                                                  professorBlacklist =
                                                      state.professorBlacklist;
                                                  sectionBlackList =
                                                      state.sectionBlacklist;
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
                                              weekViewKey.currentState
                                                  ?.scrollController
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
                                            _nextSchedule(
                                                snapshot.data!.length);
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
                                              weekViewKey.currentState
                                                  ?.scrollController
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
                                                mappings[dayRangeValues.start
                                                    .round()],
                                                mappings[
                                                    dayRangeValues.end.round()],
                                              ),
                                              onChanged: (RangeValues values) {
                                                setState(() {
                                                  dayRangeValues = values;
                                                });
                                              },
                                              onChangeEnd:
                                                  (RangeValues values) {
                                                filters.days = mappings
                                                    .sublist(
                                                        dayRangeValues.start
                                                            .round(),
                                                        dayRangeValues.end
                                                                .round() +
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
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: GestureDetector(
                                                  onTap: () {
                                                    showDialog(
                                                        useRootNavigator: false,
                                                        context: context,
                                                        builder: (context) => CourseView(
                                                            pair: pair,
                                                            professorBlacklist:
                                                                professorBlacklist,
                                                            sectionBlacklist:
                                                                sectionBlackList,
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
                                                            BorderRadius
                                                                .circular(8)),
                                                    child: Center(
                                                      child: Text(
                                                          "${isLocked(pair.course.courseCode, pair.sectionCode) ? "🔒" : ""}${pair.course.courseCode}-${pair.sectionCode}",
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white)),
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
                                      if ((dragEndDetails.primaryVelocity ??
                                              0) <
                                          0) {
                                        _nextSchedule(snapshot.data!.length);
                                      } else if ((dragEndDetails
                                                  .primaryVelocity ??
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
                                      headerStyle: const HeaderStyle(
                                        leftIconVisible: false,
                                        rightIconVisible: false,
                                        headerTextStyle: TextStyle(fontSize: 0),
                                      ),
                                      showWeekends: false,
                                      heightPerMinute: 1,
                                      onEventTap: (events, date) {
                                        final sectionData =
                                            splitEvent(events.first.title);
                                        final pair = snapshot
                                            .data![currentSchedule]
                                            .getCourseSectionPair(
                                                sectionData["courseCode"]!,
                                                sectionData["sectionCode"]!)!;
                                        showDialog(
                                            useRootNavigator: false,
                                            context: context,
                                            builder: (context) => CourseView(
                                                pair: pair,
                                                professorBlacklist:
                                                    professorBlacklist,
                                                sectionBlacklist:
                                                    sectionBlackList,
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
                                              onChangeEnd:
                                                  (RangeValues values) {
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
                }),
          )),
    );
  }
}

Map<String, String> splitEvent(event) {
  RegExpMatch? match =
      RegExp(r"(\w+)-(\w+)\nRoom:((\s*\w+)*)").firstMatch(event);
  String courseCode = "";
  String sectionCode = "";
  String room = "";

  if (match != null) {
    // Extract the parts of the course information
    courseCode = match.group(1)!;
    sectionCode = match.group(2)!;
    room = match.group(3) ?? ""; // Use "" if roomCode is not matched
  }

  return {
    "courseCode": courseCode,
    "sectionCode": sectionCode,
    "room": room,
  };
}

class SchedulePreferencesDialogStateModel {
  bool hadUpdate;
  int currentPreferencesTab;
  GeneratedSchedulePreferences preferences;
  List<Professor> professorBlacklist;
  Map<String, List<String>> sectionBlacklist;

  SchedulePreferencesDialogStateModel(
      {required this.hadUpdate,
      required this.currentPreferencesTab,
      required this.preferences,
      required this.professorBlacklist,
      required this.sectionBlacklist});
}

class SchedulePreferencesDialog extends StatefulWidget {
  final int currentPreferencesTab;
  final GeneratedSchedulePreferences oldPreferences;
  final List<Professor> oldProfessorBlacklist;
  final Map<String, List<String>> oldSectionBlacklist;

  const SchedulePreferencesDialog({
    super.key,
    required this.currentPreferencesTab,
    required this.oldPreferences,
    required this.oldProfessorBlacklist,
    required this.oldSectionBlacklist,
  });

  @override
  State<SchedulePreferencesDialog> createState() =>
      _SchedulePreferencesDialogState();
}

class _SchedulePreferencesDialogState extends State<SchedulePreferencesDialog> {
  late SchedulePreferencesDialogStateModel state;
  final Map<Professor, List<String>> deletedProfessors = {};

  @override
  void initState() {
    super.initState();
    Map<String, List<String>> newSectionBlacklist = {};
    widget.oldSectionBlacklist.forEach((key, value) {
      newSectionBlacklist[key] =
          List<String>.from(value); // Creates a new list with copied elements
    });
    state = SchedulePreferencesDialogStateModel(
        hadUpdate: false,
        currentPreferencesTab: widget.currentPreferencesTab,
        preferences: widget.oldPreferences.copy(),
        professorBlacklist: List.of(widget.oldProfessorBlacklist),
        sectionBlacklist: newSectionBlacklist);
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
          const Text("Preferencias de Horario"),
          InfoWidget(
            infoText:
                "Aquí puedes controlar cuales horarios serán mostrados primeros basados en tus preferencias.\n\nEsparcido / Denso - Controla si las secciones deben tener espacio entremedio o no.\nPresencial / Por Acuerdo - Modalidad preferida.\nHora promedio - Seleccionar hora preferida para cursos.\n\nRanking de Profesores - Ordena profesores basado en tus gustos. Presiona en un curso para activar ranking de ese curso.\n\nProfesores Excluídos - Ver y/o incluír de vuelta profesores.\n\nSecciones Excluidas - Ver y/o incluír de vuelta secciones.",
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
                                    children:
                                        state.preferences.professorRankings
                                            .entries
                                            .expand((e) => [
                                                  ExpansionTile(
                                                    shape: const Border(),
                                                    expandedCrossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
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
                                                    onExpansionChanged:
                                                        (value) {
                                                      setState(() {
                                                        state.preferences
                                                                .professorRankings[
                                                            e
                                                                .key] = Pair(
                                                            value,
                                                            e.value.value);
                                                      });
                                                    },
                                                    children: e.value.value
                                                        .mapIndexed(
                                                            (i, p) => Column(
                                                                  children: [
                                                                    Divider(
                                                                      thickness:
                                                                          p == e.value.value.first
                                                                              ? 2
                                                                              : 1,
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        Text(
                                                                            "#${i + 1}:"),
                                                                        Expanded(
                                                                            child:
                                                                                Padding(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              horizontal: 12.0),
                                                                          child: p.url.isEmpty
                                                                              ? Text(p.name)
                                                                              : InkWell(
                                                                                  onTap: () async {
                                                                                    await launchUrl(Uri.parse(p.url));
                                                                                  },
                                                                                  child: Text(p.name, style: TextStyle(color: Colors.green[900], fontStyle: FontStyle.italic, decoration: TextDecoration.underline)),
                                                                                ),
                                                                        )),
                                                                        InkWell(
                                                                            onTap:
                                                                                () {
                                                                              setState(() {
                                                                                if (!state.professorBlacklist.contains(p)) {
                                                                                  state.professorBlacklist.add(p);
                                                                                  deletedProfessors[p] = state.preferences.professorRankings.entries.expand((entry) {
                                                                                    if (!entry.value.value.contains(p)) return <String>[];
                                                                                    entry.value.value.remove(p);
                                                                                    return [
                                                                                      entry.key
                                                                                    ];
                                                                                  }).toList();
                                                                                }
                                                                              });
                                                                            },
                                                                            customBorder:
                                                                                const CircleBorder(),
                                                                            child:
                                                                                const Padding(
                                                                              padding: EdgeInsets.all(8.0),
                                                                              child: Icon(Icons.close, size: 24),
                                                                            )),
                                                                        InkWell(
                                                                            onTap:
                                                                                () {
                                                                              setState(() {
                                                                                if (i == e.value.value.length - 1) return;
                                                                                var temp = e.value.value[i];
                                                                                e.value.value[i] = e.value.value[i + 1];
                                                                                e.value.value[i + 1] = temp;
                                                                              });
                                                                            },
                                                                            customBorder:
                                                                                const CircleBorder(),
                                                                            child:
                                                                                const Padding(
                                                                              padding: EdgeInsets.all(8.0),
                                                                              child: Icon(Icons.arrow_downward, size: 24),
                                                                            )),
                                                                        InkWell(
                                                                            onTap:
                                                                                () {
                                                                              setState(() {
                                                                                if (i == 0) return;
                                                                                var temp = e.value.value[i];
                                                                                e.value.value[i] = e.value.value[i - 1];
                                                                                e.value.value[i - 1] = temp;
                                                                              });
                                                                            },
                                                                            customBorder:
                                                                                const CircleBorder(),
                                                                            child:
                                                                                const Padding(
                                                                              padding: EdgeInsets.all(8.0),
                                                                              child: Icon(Icons.arrow_upward, size: 24),
                                                                            )),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ))
                                                        .toList(),
                                                  ),
                                                  if (e.key !=
                                                      state
                                                          .preferences
                                                          .professorRankings
                                                          .entries
                                                          .last
                                                          .key)
                                                    const Divider(
                                                      thickness: 3,
                                                    )
                                                ])
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
                                      if (state.professorBlacklist.isEmpty)
                                        const Text(
                                            "Ningún profesor ha sido excluido")
                                    ] +
                                    state.professorBlacklist
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
                                                  const SizedBox(width: 4),
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        state.professorBlacklist
                                                            .remove(professor);
                                                        if (deletedProfessors
                                                            .containsKey(
                                                                professor)) {
                                                          deletedProfessors
                                                              .remove(professor)
                                                              ?.forEach(
                                                                  (course) {
                                                            state
                                                                .preferences
                                                                .professorRankings[
                                                                    course]!
                                                                .value
                                                                .add(professor);
                                                          });
                                                        }
                                                      });
                                                    },
                                                    child: const Icon(Icons.add,
                                                        size: 16),
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
                                    if (state.sectionBlacklist.values
                                        .every((e) => e.isEmpty))
                                      const Text(
                                          "Ninguna sección ha sido excluida")
                                  ] +
                                  state.sectionBlacklist.keys
                                      .map((key) => state.sectionBlacklist[key]!
                                          .map((value) => Row(
                                                children: [
                                                  Text("$key-$value",
                                                      style: const TextStyle(
                                                          fontSize: 16)),
                                                  const SizedBox(width: 4),
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        state.sectionBlacklist[
                                                                key]!
                                                            .remove(value);
                                                      });
                                                    },
                                                    child: const Icon(Icons.add,
                                                        size: 16),
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
