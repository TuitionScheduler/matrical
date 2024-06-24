import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:matrical/models/generated_schedule_preferences.dart';
import 'package:matrical/models/matrical_cubit.dart';

class PreferencesView extends StatefulWidget {
  final GeneratedSchedulePreferences preferences;

  const PreferencesView({super.key, required this.preferences});

  @override
  State<PreferencesView> createState() => _PreferencesViewState();
}

class _PreferencesViewState extends State<PreferencesView> {
  @override
  Widget build(BuildContext context) {
    final matricalCubit = BlocProvider.of<MatricalCubit>(context);
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
                onChanged: (value) {
                  setState(() {
                    widget.preferences.preferDense = value;
                    matricalCubit.updatePreferences(widget.preferences);
                  });
                }),
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
                onChanged: (value) {
                  setState(() {
                    widget.preferences.preferOnline = value;
                    matricalCubit.updatePreferences(widget.preferences);
                  });
                }),
          ],
        ),
        DropdownMenu<double?>(
            expandedInsets: const EdgeInsets.all(0),
            initialSelection: widget.preferences.averageTime,
            requestFocusOnTap: false,
            label: const Text('Tiempo Preferido para Cursos'),
            inputDecorationTheme: const InputDecorationTheme(),
            onSelected: (time) async {
              widget.preferences.averageTime = time;
              matricalCubit.updatePreferences(widget.preferences);
            },
            dropdownMenuEntries: const [
              DropdownMenuEntry<double?>(
                value: null,
                label: "Sin Preferencia",
              ),
              DropdownMenuEntry<double?>(
                value: 8,
                label: "Mañana",
              ),
              DropdownMenuEntry<double?>(
                value: 12,
                label: "Mediodía",
              ),
              DropdownMenuEntry<double?>(
                value: 16,
                label: "Tarde",
              ),
            ])
      ],
    );
  }
}
