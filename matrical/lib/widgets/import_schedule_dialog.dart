import 'package:flutter/material.dart';
import 'package:info_widget/info_widget.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ImportScheduleModal extends StatelessWidget {
  final TextEditingController importController = TextEditingController();

  ImportScheduleModal({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(AppLocalizations.of(context)!.importScheduleDialog),
          InfoWidget(
            infoText: AppLocalizations.of(context)!.importDialogDescription,
            iconColor: Colors.black87,
            iconData: Icons.help,
          )
        ],
      ),
      content: TextField(controller: importController),
      actions: <Widget>[
        TextButton(
          child: Text(AppLocalizations.of(context)!.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text(AppLocalizations.of(context)!.validate),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
            Navigator.of(context).pop(importController.text);
          },
        ),
      ],
    );
  }
}
