import 'package:flutter/material.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/services/schedule_service.dart';

import 'package:flutter/material.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/services/schedule_service.dart';

class SaveScheduleDialog extends StatefulWidget {
  final GeneratedSchedule currentSchedule;

  SaveScheduleDialog({
    super.key,
    required this.currentSchedule,
  });

  @override
  _SaveScheduleDialogState createState() => _SaveScheduleDialogState();
}

class _SaveScheduleDialogState extends State<SaveScheduleDialog> {
  final TextEditingController _scheduleNameController = TextEditingController();
  String scheduleName = "";

  @override
  void dispose() {
    _scheduleNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text('Guardar Horario'),
      content: TextField(
        controller: _scheduleNameController,
        decoration: const InputDecoration(hintText: "Nombre del horario"),
        onChanged: (value) {
          setState(() {
            scheduleName = value;
          });
        },
        onSubmitted: (value) {
          FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
        },
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () {
            Navigator.of(context).pop(null);
          },
        ),
        TextButton(
          child: const Text('Guardar'),
          onPressed: () => _attemptSave(context, scheduleName),
        ),
      ],
    );
  }

  void _attemptSave(BuildContext context, String name) {
    saveSchedule(widget.currentSchedule, name).then((result) {
      Navigator.of(context).pop(result);
    });
  }
}
