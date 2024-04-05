import 'package:flutter/material.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule_preferences.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule.dart';

class PreferencesView extends StatefulWidget {
  final GeneratedSchedulePreferences preferences;

  const PreferencesView({super.key, required this.preferences});

  @override
  State<PreferencesView> createState() => _PreferencesViewState();
}

class _PreferencesViewState extends State<PreferencesView> {
  var averageTimeController = TextEditingController(text: "");

  Future<void> _selectTime(
      BuildContext context, TextEditingController controller) async {
    List<int?> hourAndMinute =
        controller.text.split(":").map(int.tryParse).toList();
    int? hour = hourAndMinute.firstOrNull;
    int? minute = hourAndMinute.lastOrNull;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      useRootNavigator: false,
      initialTime: (hour != null && minute != null)
          ? TimeOfDay(hour: hour, minute: minute)
          : TimeOfDay(hour: TimeOfDay.now().hour, minute: 0),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  String fromTimeValue(double? time) {
    if (time == null) return "";
    var timeAsSeconds = time * 60;
    int hour = timeAsSeconds ~/ 60;
    int minute = (timeAsSeconds % 60).toInt();
    return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    averageTimeController.text = fromTimeValue(widget.preferences.averageTime);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: RichText(
                    text: TextSpan(
                        style: const TextStyle(color: Colors.black),
                        children: [
                      TextSpan(
                          text: "Esparcido",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: !widget.preferences.preferDense
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      const TextSpan(text: " / "),
                      TextSpan(
                          text: "Denso",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: widget.preferences.preferDense
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ])),
              ),
            ),
            Switch(
                value: widget.preferences.preferDense,
                onChanged: (value) => setState(() {
                      widget.preferences.preferDense = value;
                    })),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: RichText(
                    text: TextSpan(
                        style: const TextStyle(color: Colors.black),
                        children: [
                      TextSpan(
                          text: "Presencial",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: !widget.preferences.preferOnline
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      const TextSpan(text: " / "),
                      TextSpan(
                          text: "Por Acuerdo",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: widget.preferences.preferOnline
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ])),
              ),
            ),
            Switch(
                value: widget.preferences.preferOnline,
                onChanged: (value) => setState(() {
                      widget.preferences.preferOnline = value;
                    })),
          ],
        ),
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text("Hora promedio:  ",
                  style: TextStyle(
                    fontSize: 18,
                  )),
            ),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  hintText: 'HH:MM',
                ),
                controller: averageTimeController,
                readOnly: true,
                onTap: () =>
                    _selectTime(context, averageTimeController).then((value) {
                  widget.preferences.averageTime =
                      averageTimeController.text.isNotEmpty
                          ? GeneratedSchedule.getTimeAsDouble(
                              averageTimeController.text)
                          : null;
                }),
              ),
            ),
            IconButton(
                onPressed: () => setState(() {
                      averageTimeController.text = "";
                      widget.preferences.averageTime = null;
                    }),
                icon: const Icon(Icons.rotate_left))
          ],
        )
      ],
    );
  }
}
