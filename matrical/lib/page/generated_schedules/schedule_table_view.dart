import 'package:flutter/material.dart';
import 'package:miuni/features/matrical/data/model/course_filters.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule.dart';

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
      actionsOverflowAlignment: OverflowBarAlignment.start,
      actionsOverflowDirection: VerticalDirection.down,
      buttonPadding: const EdgeInsets.symmetric(horizontal: 3.0),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,

      actions: [
        TextButton(
          style: TextButton.styleFrom(
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          onPressed: () => {
            Navigator.of(context).pop(schedule.courses
                .map(
                  (e) => CourseWithFilters.withoutFilters(
                      courseCode: e.course.courseCode,
                      sectionCode: e.sectionCode),
                )
                .toList())
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
      columns: const <DataColumn>[
        DataColumn(
          label: Text(
            'Curso',
            style: TextStyle(
              fontSize: 12,
            ),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text(
              'Horario',
              style: TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Profesores',
            style: TextStyle(
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
