import 'package:matrical/services/platform_service.dart'
    if (dart.library.html) 'package:matrical/services/web_service.dart';

import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:matrical/firebase_options.dart';
import 'package:matrical/globals/cubits.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/internet_cubit.dart';
import 'package:matrical/models/matrical_page.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/pages/matrical.dart';
import 'package:sizer/sizer.dart';

Future<void> main() async {
  await setUp();
  runApp(const BetterFeedback(child: MainApp()));
}

Future<void> setUp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    // If we are on web, we want to check if the user opened a share link and
    // take them to Course Select with the courses in the link
    if (kIsWeb) {
      _tryToImportSchedule();
    }
  }

  // imports the schedule included in the URL query params if the schedule is valid
  // and the path is /share. Clears the path and query params if successful.
  // Does nothing otherwise.
  void _tryToImportSchedule() {
    final uri = Uri.base;
    final queryParams = uri.queryParameters;

    final termRegex = RegExp(r'^[a-zA-Z]+$');
    final yearRegex = RegExp(r'^\d+$');
    final courseListRegex = RegExp(
        r'^([A-Z]{4}\d{4}(?:-[A-Za-z0-9]{1,5})?)(?:\+[A-Z]{4}\d{4}(?:-[A-Za-z0-9]{1,5})?)*$');

    if (uri.path == "/share" &&
        queryParams.containsKey('term') &&
        queryParams.containsKey('year') &&
        queryParams.containsKey('courses')) {
      final term = queryParams['term'];
      final year = queryParams['year'];
      final courses = queryParams['courses'];

      if (termRegex.hasMatch(term!) &&
          yearRegex.hasMatch(year!) &&
          courseListRegex.hasMatch(courses!)) {
        // All parameters are valid, update the state
        final parsedTerm = Term.fromString(term) ?? Term.getPredictedTerm();
        final parsedYear = int.parse(year);
        final coursesWithSections = courses.split('+');

        matricalCubitSingleton.updateTerm(parsedTerm);
        matricalCubitSingleton.updateYear(parsedYear);
        matricalCubitSingleton
            .updateCourses(coursesWithSections.map((String cString) {
          List<String> courseAndSection = cString.split("-");
          final courseCode = courseAndSection[0];
          final sectionCode =
              courseAndSection.length > 1 ? courseAndSection[1] : "";
          return CourseWithFilters.withoutFilters(
              courseCode: courseCode, sectionCode: sectionCode);
        }).toList());
        matricalCubitSingleton.setPage(MatricalPage.generatedSchedules);
        clearShareUrl();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: matricalCubitSingleton),
              BlocProvider.value(value: InternetCubit())
            ],
            child: const Matrical(),
          ),
        );
      },
    );
  }
}
