import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:info_widget/info_widget.dart';
import 'package:matrical/models/course_filters.dart';

class CourseFilterPopup extends StatefulWidget {
  const CourseFilterPopup({super.key, required this.filters});
  final CourseFilters filters;

  @override
  State<CourseFilterPopup> createState() => _CourseFilterPopupState();
}

class _CourseFilterPopupState extends State<CourseFilterPopup> {
  final List<bool> days = List.generate(5, (_) => false);
  final String daysString = "LMWJV";
  TextEditingController earliestTimeController = TextEditingController();
  TextEditingController latestTimeController = TextEditingController();
  TextEditingController professorsController = TextEditingController();
  TextEditingController roomsController = TextEditingController();
  Modality modality = Modality.any;

  @override
  void initState() {
    super.initState();
    daysString.split("").forEachIndexed((index, day) {
      days[index] = widget.filters.days.contains(day);
    });
    earliestTimeController.text = widget.filters.earliestTime;
    latestTimeController.text = widget.filters.latestTime;
    professorsController.text = widget.filters.professors.join(", ");
    roomsController.text = widget.filters.rooms.join(", ");
    modality = widget.filters.modality;
  }

  Future<void> _selectTime(
      BuildContext context, TextEditingController controller) async {
    List<int?> hourAndMinute =
        controller.text.split(":").map(int.tryParse).toList();
    int? hour = hourAndMinute.firstOrNull;
    int? minute = hourAndMinute.lastOrNull;
    final TimeOfDay? picked = await showTimePicker(
      useRootNavigator: false,
      context: context,
      initialTime: (hour != null && minute != null)
          ? TimeOfDay(hour: hour, minute: minute)
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
      )),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filtros'),
              InfoWidget(
                infoText:
                    "Los filtros de cursos limitan qué secciones se utilizan para la generación de horarios.",
                iconColor: Colors.black87,
                iconData: Icons.help,
              )
            ],
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: earliestTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Comienza Después de',
                    hintText: 'HH:MM ie. 13:20',
                  ),
                  readOnly: true,
                  onTap: () => _selectTime(context, earliestTimeController),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: latestTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Acaba Antes de',
                    hintText: 'HH:MM ie. 13:20',
                  ),
                  readOnly: true,
                  onTap: () => _selectTime(context, latestTimeController),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: ToggleButtons(
                    onPressed: (int index) {
                      setState(() {
                        days[index] = !days[index];
                      });
                    },
                    isSelected: days,
                    children: const <Widget>[
                      Text('L'),
                      Text('M'),
                      Text('W'),
                      Text('J'),
                      Text('V'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: professorsController,
                  decoration: const InputDecoration(
                    labelText: 'Profesor(es)',
                    hintText: 'ie. Juan Pedro, Don Quijote de La Mancha',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: roomsController,
                  decoration: const InputDecoration(
                    labelText: 'Salon(es)',
                    hintText: 'ie. S 113, CH 403, I 202',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownMenu<Modality>(
                    expandedInsets: const EdgeInsets.all(0),
                    initialSelection: widget.filters.modality,
                    requestFocusOnTap: false,
                    label: const Text('Modalidad'),
                    onSelected: (value) => {modality = value ?? Modality.any},
                    dropdownMenuEntries: Modality.values.map((term) {
                      return DropdownMenuEntry<Modality>(
                        value: term,
                        label: term.displayName,
                      );
                    }).toList()),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red),
                      onPressed: () {
                        widget.filters.professors = [];
                        widget.filters.earliestTime = "";
                        widget.filters.latestTime = "";
                        widget.filters.days = "";
                        widget.filters.modality = Modality.any;
                        Navigator.pop(context);
                      },
                      child: const Text('Borrar Filtros'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.filters.professors = professorsController.text
                            .split(",")
                            .map((s) => s.trim())
                            .where((element) => element.isNotEmpty)
                            .toList();
                        widget.filters.rooms = roomsController.text
                            .split(",")
                            .map((s) => s.trim())
                            .where((element) => element.isNotEmpty)
                            .toList();
                        widget.filters.earliestTime =
                            earliestTimeController.text;
                        widget.filters.latestTime = latestTimeController.text;
                        widget.filters.days = days
                            .mapIndexed((index, daySelected) =>
                                daySelected ? daysString[index] : "")
                            .join();
                        widget.filters.modality = modality;
                        Navigator.pop(context);
                      },
                      child: const Text('Guardar Filtros'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
