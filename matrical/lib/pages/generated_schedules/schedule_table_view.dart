import 'package:flutter/material.dart';
import 'package:matrical/globals/cubits.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/models/matrical_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ScheduleTableView extends StatelessWidget {
  final GeneratedSchedule schedule;

  const ScheduleTableView({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Cursos en horario:",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
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
            child: ScheduleTable(schedule: schedule),
          ),
        ),
      ),
      buttonPadding: const EdgeInsets.symmetric(horizontal: 3.0),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          onPressed: () {
            matricalCubitSingleton.updateCourses(schedule.courses
                .map(
                  (e) => CourseWithFilters.withoutFilters(
                      courseCode: e.course.courseCode,
                      sectionCode: e.sectionCode),
                )
                .toList());
            Navigator.of(context).pop(); // dismiss the modal
            matricalCubitSingleton.setPage(MatricalPage.courseSelect);
          },
          child: const Text("Editar"),
        )
      ],
    );
  }
}

class ScheduleTable extends StatelessWidget {
  final GeneratedSchedule schedule;

  const ScheduleTable({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return DataTable(
      horizontalMargin: 1,
      dataTextStyle: const TextStyle(fontSize: 12),
      dataRowMaxHeight: double.infinity,
      columnSpacing: 14,
      columns: <DataColumn>[
        DataColumn(
          label: Text(
            AppLocalizations.of(context)!.course,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text(
              AppLocalizations.of(context)!.schedule,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataColumn(
          label: Text(
            AppLocalizations.of(context)!.professors,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
        ),
      ],
      rows: schedule.courses
          .map<DataRow>((courseSection) => DataRow(
                cells: <DataCell>[
                  DataCell(Text(
                      "${courseSection.course.courseCode}-${courseSection.sectionCode}")),
                  DataCell(Text(courseSection.getSection().meetings.isNotEmpty
                      ? courseSection
                          .getSection()
                          .meetings
                          .map((e) => e.toString())
                          .join(",\n")
                      : "Por Acuerdo")),
                  DataCell(Text(courseSection
                      .getSection()
                      .professors
                      .map((e) => e.name)
                      .join(",\n"))),
                ],
              ))
          .toList(),
    );
  }
}
