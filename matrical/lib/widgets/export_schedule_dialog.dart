import 'package:flutter/services.dart';
import 'package:matrical/services/platform_service.dart'
    if (dart.library.html) 'package:matrical/services/web_service.dart';
import "package:universal_io/io.dart";
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:typed_data';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:info_widget/info_widget.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/models/weekday.dart';
import 'package:matrical/services/schedule_service.dart';
import 'package:matrical/services/widgets_service.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

class ExportScheduleDialog extends StatelessWidget {
  final List<CourseSectionPair> notPresencialCourses;
  final GeneratedSchedule schedule;
  final String? scheduleName;
  const ExportScheduleDialog(
      {super.key,
      required this.notPresencialCourses,
      required this.schedule,
      this.scheduleName});

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
                              saveFuture: exportScheduleAsImage(
                            notPresencialCourses,
                            schedule,
                            scheduleName ?? 'horario',
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
            exportScheduleAsIcal(schedule,
                scheduleName ?? "horario"); // Call the method to export as ical
          },
        ),
        _exportTextOrLinkButton(context, schedule)
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

Future<bool> exportScheduleAsImage(
  List<CourseSectionPair> notPresencial,
  GeneratedSchedule schedule,
  String scheduleName,
  BuildContext context,
) async {
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

  final imageName = "$scheduleName-${schedule.term}-${schedule.year}.png";
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
                          weekNumberBuilder: (_) => null,
                          weekDayBuilder: (date) =>
                              Center(child: Text(weekday[date.weekday])),
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
  if (kIsWeb) {
    return downloadFileOnWeb(imageName, pngBytes);
  }
  if (Platform.isAndroid) {
    return await saveScheduleToGallery(imageName, pngBytes, context);
  }
  return false;
}

Future<bool> saveScheduleToGallery(
    String fileName, Uint8List pngBytes, BuildContext context) async {
  try {
    final hasAccess = await Gal.requestAccess();
    if (!hasAccess) {
      return false;
    }
    if (!context.mounted) {
      return false;
    }
    final tempDir = await getTemporaryDirectory();
    final imagePath = "${tempDir.path}/$fileName";
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

Future<bool> exportScheduleAsIcal(
    GeneratedSchedule currentSchedule, String scheduleName) async {
  String? icsContent = parseScheduleAsIcal(currentSchedule);
  if (icsContent == null) {
    return false;
  }

  final term = Term.fromString(currentSchedule.term) ?? Term.getPredictedTerm();
  final year = currentSchedule.year;
  final icsName = "$scheduleName-${term.displayName}-$year.ics";
  if (kIsWeb) {
    return downloadFileOnWeb(icsName, icsContent.codeUnits);
  } else if (Platform.isAndroid) {
    final tempDir = await getTemporaryDirectory();

    final icsPath = "${tempDir.path}/$icsName";
    File icsFile = File(icsPath);
    await icsFile.create();
    await icsFile.writeAsString(icsContent);
    final result = await OpenFile.open(icsPath, type: "text/calendar");
    return result.type == ResultType.done;
  }
  return false;
}

Widget _exportHelp() {
  return InfoWidget(
      infoText:
          "Imagen: Guarda una imagen del horario en la galería de tu dispositivo\n\nCalendario: Crea y abre un archivo \".ics\" con tu horario. Los archivos \".ics\" pueden ser abiertos por Google Calendar, Outlook, etc. para añadir tus clases a tu calendario.\n\n${kIsWeb ? 'Enlace' : 'Código'}: ${kIsWeb ? 'Genera un enlace que otros usuarios pueden acceder para ver el horario.' : 'Te permite enviar un código con las secciones en este horario. Otros usuarios pueden copiar el código e importarlo en la aplicación mediante la página de Selección de Cursos o la de Horarios Guardados.'}",
      iconData: Icons.help,
      iconColor: Colors.black87);
}

Widget _exportTextOrLinkButton(
    BuildContext context, GeneratedSchedule schedule) {
  final browser = Browser.detectOrNull(); // Always null when not on web
  return TextButton(
    child: Text(browser != null ? 'Enlace' : 'Texto',
        style: const TextStyle(fontSize: 15), textAlign: TextAlign.end),
    onPressed: () async {
      if (browser == null) {
        // TODO(poggecci): share deeplinks when running native on mobile devices instead of Import codes
        Share.share(schedule.toImportCode()).then((_) {
          Navigator.of(context).pop();
        });
      } else {
        /*
            On browsers with access to the webshare API, 
            use that to share the URL or Text code. Otherwise, fall back to
            writing the URL to the clipboard.
            Exceptions: FireFox has WebShare but text isn't properly copied onto it

          */
        final shareURL = Uri.base
            .replace(queryParameters: schedule.toQueryParams())
            .toString();

        switch (browser.browserAgent) {
          case BrowserAgent.Chrome:
          case BrowserAgent.Edge:
          case BrowserAgent.EdgeChromium:
          case BrowserAgent.Safari:
            await Share.share(shareURL);
          default:
            await Clipboard.setData(ClipboardData(text: shareURL));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  content:
                      Text('Enlace con tu horario copiado a tu dispositivo.'),
                ));
            }
            break;
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    },
  );
}
