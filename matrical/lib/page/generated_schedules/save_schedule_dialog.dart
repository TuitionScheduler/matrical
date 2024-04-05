import 'package:flutter/material.dart';
import 'package:miuni/features/matrical/data/model/generated_schedule.dart';
import 'package:miuni/features/matrical/Logic/save_schedule.dart';

class SaveScheduleDialog extends StatelessWidget {
  final GeneratedSchedule currentSchedule;
  final TextEditingController _scheduleNameController = TextEditingController();

  SaveScheduleDialog({
    super.key,
    required this.currentSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text('Guardar Horario'),
      content: TextField(
        controller: _scheduleNameController,
        decoration: const InputDecoration(hintText: "Nombre del horario"),
        onSubmitted: (value) {
          FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
        },
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () {
            // Just pop false indicating the save was not executed
            Navigator.of(context).pop(null);
          },
        ),
        TextButton(
          child: const Text('Guardar'),
          onPressed: () => _attemptSave(context, _scheduleNameController.text),
        ),
      ],
    );
  }

  void _attemptSave(BuildContext context, String name) {
    saveSchedule(currentSchedule, name).then((result) {
      Navigator.of(context).pop(result);
    });
  }
}
