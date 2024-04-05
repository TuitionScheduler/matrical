import 'dart:io';
import 'dart:typed_data';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:info_widget/info_widget.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule.dart';
import 'package:miuni/features/matrical/data/model/schedule_generation_options.dart';
import 'package:miuni/features/matrical/logic/generate_schedule_ics.dart';
import 'package:miuni/features/matrical/logic/screenshot.dart';
import 'package:miuni/features/matrical/logic/split_widgets.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportScheduleDialog extends StatelessWidget {
  final List<CourseSectionPair> notPresencialCourses;
  final GeneratedSchedule schedule;
  const ExportScheduleDialog(
      {super.key, required this.notPresencialCourses, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Exportar como:',
          ),
          _exportHelp()
        ],
      ),
      actions: [
        TextButton(
            child: const Text(
              'Imagen',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.end,
            ),
            onPressed: () {
              showDialog(
                      context: context,
                      builder: (innerContext) => SaveAsImageProgressDialog(
                              saveFuture: saveScheduleToGallery(
                            notPresencialCourses,
                            schedule,
                            innerContext,
                          )),
                      useRootNavigator: false)
                  .then((_) {
                Navigator.of(context).pop();
              });
            }),
        TextButton(
          child: const Text('Calendario',
              style: TextStyle(fontSize: 15), textAlign: TextAlign.end),
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
            exportScheduleAsIcal(schedule); // Call the method to export as ical
          },
        ),
        TextButton(
          child: const Text('Texto',
              style: TextStyle(fontSize: 15), textAlign: TextAlign.end),
          onPressed: () {
            Share.share(schedule.toImportCode()).then((_) {
              Navigator.of(context).pop();
            });
          },
        )
      ],
    );
  }
}

class SaveAsImageProgressDialog extends StatefulWidget {
  final Future<bool> saveFuture;

  const SaveAsImageProgressDialog({super.key, required this.saveFuture});

  @override
  State<SaveAsImageProgressDialog> createState() =>
      _SaveAsImageProgressDialogState();
}

class _SaveAsImageProgressDialogState extends State<SaveAsImageProgressDialog> {
  late Future<bool> saveToGalleryFuture;

  @override
  void initState() {
    super.initState();
    saveToGalleryFuture = widget.saveFuture;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      content: FutureBuilder<bool>(
        future: saveToGalleryFuture,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.done:
              bool success = snapshot.data == true && !snapshot.hasError;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Icon(
                      success ? Icons.check : Icons.close,
                      size: 60,
                      color: snapshot.data == true ? Colors.green : Colors.red,
                    ),
                  ),
                  Text(
                      success
                          ? "Imagen guardada exitosamente!"
                          : "Imagen no pudo ser guardada.",
                      style: const TextStyle(fontSize: 18))
                ],
              );
            case ConnectionState.active:
            case ConnectionState.waiting:
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ),
                  Text("Generando y guardando imagen...",
                      style: TextStyle(fontSize: 18)),
                ],
              );
          }
        },
      ),
      actions: <Widget>[
        if (Navigator.of(context).canPop())
          TextButton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

Future<bool> saveScheduleToGallery(List<CourseSectionPair> notPresencial,
    GeneratedSchedule schedule, BuildContext context) async {
  const calendarWidth = 600.0;
  final copiedController = EventController();
  const scheduleHeaderHeight = 60.0;
  const minuteHeight = 1.0;
  final scrollOffset = schedule.getEarliestHour().floor() * minuteHeight * 60;
  final hoursBetweenFirstAndLastCourse =
      schedule.getLatestHour().ceil() - schedule.getEarliestHour().floor();
  final double calendarHeight =
      minuteHeight * 60 * hoursBetweenFirstAndLastCourse + scheduleHeaderHeight;

  bool neverLock(String course, String section) {
    return false;
  }

  schedule.overwriteEventController(copiedController, neverLock);

  try {
    final hasAccess = await Gal.requestAccess();
    if (!hasAccess) {
      return false;
    }
    if (!context.mounted) {
      return false;
    }
    Uint8List pngBytes = await ScreenshotController().captureFromLongWidget(
        MediaQuery(
          data: MediaQuery.of(context),
          child: Material(
            child: CalendarControllerProvider(
              controller: copiedController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[] +
                    splitWidgets(
                            notPresencial
                                .map((pair) => Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                              color: pair.getColor(),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Center(
                                            child: Text(
                                                "${pair.course.courseCode}-${pair.sectionCode}",
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white)),
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                            3)
                        .map<Widget>(
                            (row) => SizedBox(width: calendarWidth, child: row))
                        .toList() +
                    <Widget>[
                      SizedBox(
                        width: calendarWidth,
                        height: calendarHeight,
                        child: WeekView(
                            scrollOffset: scrollOffset,
                            controller: copiedController,
                            minDay: DateTime(2024, 1, 1),
                            maxDay: DateTime(2024, 1, 5),
                            headerStyle: const HeaderStyle(
                              leftIconVisible: false,
                              rightIconVisible: false,
                              headerTextStyle: TextStyle(fontSize: 0),
                            ),
                            showWeekends: false,
                            heightPerMinute: minuteHeight,
                            minuteSlotSize: MinuteSlotSize.minutes30,
                            timeLineWidth: 56),
                      ),
                    ],
              ),
            ),
          ),
        ),
        pixelRatio: 3.0,
        delay: const Duration(seconds: 1));
    final tempDir = await getTemporaryDirectory();
    final imagePath =
        "${tempDir.path}/horario-${schedule.term}-${schedule.year}.png";
    File file = File(imagePath);
    await file.create();
    await file.writeAsBytes(pngBytes);
    bool gallerySaveResult = false;
    try {
      await Gal.putImage(imagePath);
      gallerySaveResult = true;
    } catch (e) {
      gallerySaveResult = false;
    }
    await file.delete();
    return gallerySaveResult;
  } catch (e) {
    print(e.toString()); //TODO: replace with error logging
    return false;
  }
}

Future<bool> exportScheduleAsIcal(GeneratedSchedule currentSchedule) async {
  String icsContent = parseScheduleAsIcal(currentSchedule);
  final tempDir = await getTemporaryDirectory();
  final term = Term.fromString(currentSchedule.term) ?? Term.getCurrent();
  final year = currentSchedule.year;
  final icsPath = "${tempDir.path}/horario-${term.displayName}-$year.ics";
  File icsFile = File(icsPath);
  await icsFile.create();
  await icsFile.writeAsString(icsContent);
  final result = await OpenFile.open(icsPath, type: "text/calendar");
  return result.type == ResultType.done;
}

Widget _exportHelp() {
  return InfoWidget(
      infoText:
          "Imagen: Guarda una imagen del horario en la galería de tu dispositivo\n\nCalendario: Crea y abre un archivo \".ics\" con tu horario. Los archivos \".ics\" pueden ser abiertos por Google Calendar, Outlook, etc. para añadir tus clases a tu calendario.\n\nTexto: Te permite enviar un código con las secciones en este horario. Otros usuarios pueden copiar el código e importarlo en la aplicación mediante la página de Selección de Cursos o la de Horarios Guardados.",
      iconData: Icons.help,
      iconColor: Colors.black87);
}
