import 'package:flutter/material.dart';
import 'package:matrical/globals/cubits.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:matrical/services/schedule_service.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SaveScheduleDialog extends StatefulWidget {
  final GeneratedSchedule currentSchedule;

  const SaveScheduleDialog({
    super.key,
    required this.currentSchedule,
  });

  @override
  State<SaveScheduleDialog> createState() => _SaveScheduleDialogState();
}

class _SaveScheduleDialogState extends State<SaveScheduleDialog> {
  final TextEditingController _scheduleNameController = TextEditingController();
  String scheduleName = "";

  @override
  void initState() {
    super.initState();
    _scheduleNameController.text =
        matricalCubitSingleton.state.scheduleBeingUpdated;
    _scheduleNameController.addListener(() {
      scheduleName = _scheduleNameController.text;
    });
  }

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
      title: Text(AppLocalizations.of(context)!.saveScheduleDialog),
      content: TextField(
        controller: _scheduleNameController,
        decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.scheduleNameInput),
        onSubmitted: (value) {
          FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
        },
      ),
      actions: <Widget>[
        TextButton(
          child: Text(AppLocalizations.of(context)!.cancel),
          onPressed: () {
            Navigator.of(context).pop(null);
          },
        ),
        TextButton(
          child: Text(AppLocalizations.of(context)!.save),
          onPressed: () => _attemptSave(context, scheduleName),
        ),
      ],
    );
  }

  void _attemptSave(BuildContext context, String name) {
    saveSchedule(widget.currentSchedule, name,
            allowOverwriteExisting:
                matricalCubitSingleton.state.scheduleBeingUpdated.isNotEmpty)
        .then((result) {
      Navigator.of(context).pop(result);
    });
  }
}
