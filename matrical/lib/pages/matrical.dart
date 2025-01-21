// nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:matrical/globals/scaffold.dart';
import 'package:matrical/models/matrical_cubit.dart';
import 'package:matrical/models/matrical_page.dart';
import 'package:matrical/pages/course_search/course_search.dart';
import 'package:matrical/pages/course_select/course_select.dart';
import 'package:matrical/pages/generated_schedules/generated_schedules.dart';
import 'package:matrical/pages/saved_schedules/view_saved_schedules.dart';
import 'package:matrical/widgets/bug_report.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);
const TextStyle textStyle = TextStyle(color: Colors.white);

class Matrical extends StatelessWidget {
  const Matrical({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatricalCubit, MatricalState>(
      builder: (context, state) {
        return Theme(
          data: ThemeData(colorSchemeSeed: officialColor),
          child: Scaffold(
            key: globalKey,
            appBar: AppBar(
              title: Text(
                state.page.displayName(context),
                style: textStyle,
              ),
              backgroundColor: officialColor,
              actions: [BugReport(pageName: state.page.displayName(context))],
            ),
            body: <Widget>[
              const CourseSelect(),
              const CourseSearch(),
              const ViewSavedSchedules(),
              const GeneratedSchedules(),
            ][state.page.index],
            bottomNavigationBar: BottomNavigationBar(
              showUnselectedLabels: true,
              showSelectedLabels: true,
              unselectedItemColor:
                  Colors.black54, // Add color for unselected items
              selectedItemColor: officialColor, // Add color for selected item
// Ensures the bar matches the AppBar
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: const Icon(Icons.create),
                    label: AppLocalizations.of(context)!.courseSelectIcon),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.search),
                    label: AppLocalizations.of(context)!.courseSearchIcon),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.save),
                    label: AppLocalizations.of(context)!.savedSchedulesIcon),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: AppLocalizations.of(context)!.generateSchedulesIcon),
              ],
              currentIndex: state.page.index,
              onTap: (int index) {
                final matricalCubit = BlocProvider.of<MatricalCubit>(context);
                switch (index) {
                  case 0:
                    matricalCubit.setPage(MatricalPage.courseSelect);
                    break;
                  case 1:
                    matricalCubit.setPage(MatricalPage.courseSearch);
                    break;
                  case 2:
                    matricalCubit.setPage(MatricalPage.savedSchedules);
                    break;
                  case 3:
                    if (state.selectedCourses.isNotEmpty) {
                      matricalCubit.setPage(MatricalPage.generatedSchedules);
                    } else {
                      ScaffoldMessenger.of(context)
                          .removeCurrentSnackBar(); // Use remove here to account for possible rapid user tapping
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(AppLocalizations.of(context)!
                            .addCoursesPriorToGeneratingSchedules),
                      ));
                    }
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }
}
