import 'package:flutter/material.dart';
import 'package:info_widget/info_widget.dart';

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
          const Text("Importar horario"),
          InfoWidget(
            infoText:
                "Si te envían un código de horario, puedes copiarlo en esta entrada de texto para importarlo. Puedes exportar códigos de horario la opción de \"Texto\" cuando presionas \"Exportar\" en un horario generado o guardado.",
            iconColor: Colors.black87,
            iconData: Icons.help,
          )
        ],
      ),
      content: TextField(controller: importController),
      actions: <Widget>[
        TextButton(
          child: const Text('Cerrar'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Comprobar'),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
            Navigator.of(context).pop(importController.text);
          },
        ),
      ],
    );
  }
}
