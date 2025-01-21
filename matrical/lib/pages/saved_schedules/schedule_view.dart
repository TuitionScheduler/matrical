import 'dart:math';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/saved_schedule.dart';
import 'package:matrical/models/weekday.dart';
import 'package:matrical/pages/generated_schedules/course_view.dart';
import 'package:matrical/pages/generated_schedules/generated_schedules.dart';
import 'package:matrical/services/widgets_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ScheduleView extends StatelessWidget {
  final SavedSchedule schedule;

  const ScheduleView({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    var eventController = EventController();
    schedule.schedule
        .overwriteEventController(eventController, (course, section) => false);
    var scrollOffset = max(schedule.schedule.getEarliestHour() - 1, 0) * 60.0;
    var notPresencial =
        schedule.schedule.getCourseSectionPairsByModality(Modality.byagreement);
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(9, 144, 45, 1),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            AppLocalizations.of(context)!.scheduleViewWithInput(schedule.name),
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: false,
        ),
        body: Theme(
            data: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green,
              ),
            ),
            child: Column(
              children: splitWidgets(
                          notPresencial
                              .map(
                                (pair) => Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: GestureDetector(
                                        onTap: () {
                                          showDialog(
                                              useRootNavigator: false,
                                              context: context,
                                              builder: (context) => CourseView(
                                                  pair: pair, isStatic: true));
                                        },
                                        child: Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                              color: pair.getColor(),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Center(
                                            child: Text(
                                                "${pair.course.courseCode}-${pair.sectionCode}",
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                          ),
                                        ),
                                      )),
                                ),
                              )
                              .toList(),
                          2)
                      .map((e) => e as Widget)
                      .toList() +
                  [
                    if (notPresencial.isNotEmpty) const Divider(),
                    Expanded(
                      child: CalendarControllerProvider(
                        controller: eventController,
                        child: WeekView(
                          weekNumberBuilder: (_) => null,
                          weekDayBuilder: (date) =>
                              Center(child: Text(weekday[date.weekday])),
                          headerStyle: const HeaderStyle(
                            leftIconVisible: false,
                            rightIconVisible: false,
                            headerTextStyle: TextStyle(fontSize: 0),
                          ),
                          minDay: DateTime(2024, 1, 1),
                          maxDay: DateTime(2024, 1, 5),
                          showWeekends: false,
                          heightPerMinute: 1.0,
                          minuteSlotSize: MinuteSlotSize.minutes30,
                          scrollOffset: scrollOffset,
                          timeLineWidth: 56,
                          onEventTap: (events, date) {
                            final sectionData =
                                getEventDetails(events.first.description!);
                            final pair = schedule.schedule.getCourseSectionPair(
                                sectionData["courseCode"]! as String,
                                sectionData["sectionCode"]! as String)!;
                            showDialog(
                                useRootNavigator: false,
                                context: context,
                                builder: (context) => CourseView(
                                      pair: pair,
                                      isStatic: true,
                                    ));
                          },
                        ),
                      ),
                    ),
                  ],
            )));
  }
}
