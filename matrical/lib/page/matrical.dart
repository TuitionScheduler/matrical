// nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miuni/config/injection_dependecies.dart';

import 'package:miuni/features/matrical/logic/matrical_cubit.dart';
import 'package:miuni/features/matrical/page/course_select/course_select.dart';
import 'package:miuni/features/matrical/page/course_search/course_search.dart';
import 'package:miuni/features/matrical/page/generated_schedules/generated_schedules.dart';
import 'package:miuni/features/matrical/page/saved_schedules/view_saved_schedules.dart';
import 'package:miuni/features/matrical/page/shared/bug_report.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);
const TextStyle textStyle = TextStyle(color: Colors.white);

// Don't change order without updating widget order in scaffold body accordingly
enum MatricalPage {
  courseSelect(displayName: "Selección de Cursos"),
  courseSearch(displayName: "Búsqueda de Cursos"),
  savedSchedules(displayName: "Mis Horarios"),
  generatedSchedules(displayName: "Horarios Generados");

  const MatricalPage({required this.displayName});
  final String displayName;
}

class Matrical extends StatelessWidget {
  const Matrical({super.key});

  _popInvoked(context) async {
    bool response = await showDialog<bool>(
            useRootNavigator: false,
            context: context,
            builder: (context) {
              return Theme(
                data: ThemeData(colorSchemeSeed: officialColor),
                child: AlertDialog(
                  title: const Text("Salir de Matrical?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text("Sí")),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("No"))
                  ],
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                ),
              );
            }) ??
        false;
    if (response) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (popped) async {
        if (popped) return;
        _popInvoked(context);
      },
      child: BlocBuilder<MatricalCubit, MatricalState>(
        builder: (innerContext, state) {
          return Theme(
            data: ThemeData(colorSchemeSeed: officialColor),
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    _popInvoked(context);
                  },
                ),
                title: Text(
                  state.pageTitle,
                  style: textStyle,
                ),
                backgroundColor: officialColor,
                actions: [BugReport(pageName: state.pageTitle)],
              ),
              body: <Widget>[
                const CourseSelect(),
                const CourseSearch(),
                const ViewSavedSchedules(),
                const GeneratedSchedules(),
              ][state.pageIndex],
              bottomNavigationBar: BottomNavigationBar(
                showUnselectedLabels: true,
                showSelectedLabels: true,
                unselectedItemColor:
                    Colors.black54, // Add color for unselected items
                selectedItemColor: officialColor, // Add color for selected item
                // Ensures the bar matches the AppBar
                items: const <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                      icon: Icon(Icons.create), label: 'Crear'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.search), label: 'Cursos'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.save), label: 'Mis Horarios'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_month_outlined),
                      label: 'Generar'),
                ],
                currentIndex: state.pageIndex,
                onTap: (int index) {
                  switch (index) {
                    case 0:
                      sl<MatricalCubit>().setPage(MatricalPage.courseSelect);
                      break;
                    case 1:
                      sl<MatricalCubit>().setPage(MatricalPage.courseSearch);
                      break;
                    case 2:
                      sl<MatricalCubit>().setPage(MatricalPage.savedSchedules);
                      break;
                    case 3:
                      if (state.selectedCourses.isNotEmpty) {
                        sl<MatricalCubit>()
                            .setPage(MatricalPage.generatedSchedules);
                      } else {
                        ScaffoldMessenger.of(innerContext)
                            .removeCurrentSnackBar(); // Use remove here to account for possible rapid user tapping
                        ScaffoldMessenger.of(innerContext)
                            .showSnackBar(const SnackBar(
                          content: Text('Añade cursos antes de generar.'),
                        ));
                      }
                      break;
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
