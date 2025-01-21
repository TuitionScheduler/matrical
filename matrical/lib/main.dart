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
import 'package:matrical/models/matrical_page.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/pages/matrical.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> main() async {
  await setUp();
  runApp(const BetterFeedback(child: MainApp()));
}

Future<void> setUp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  internetCubitSingleton.initialState();
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

  // imports the schedule included in the URL query params if the schedule is valid.
  // Clears the query params if successful.
  // Does nothing otherwise.
  void _tryToImportSchedule() {
    final uri = Uri.base;
    final queryParams = uri.queryParameters;
    try {
      final termRegex = RegExp(r'^[a-zA-Z]+$');
      final yearRegex = RegExp(r'^\d+$');
      if (queryParams.containsKey('term') &&
          queryParams.containsKey('year') &&
          queryParams.containsKey('courses')) {
        print("Attempting to import schedule from $uri");
        final term = queryParams['term']!;
        final year = queryParams['year']!;
        final courses = queryParams['courses']!;

        if (termRegex.hasMatch(term) && yearRegex.hasMatch(year)) {
          // All parameters are valid, update the state
          final parsedTerm = Term.fromString(term) ?? Term.getPredictedTerm();
          final parsedYear = int.parse(year);
          // + is kept for legacy reasons. Current separator is ,
          final courseDelimiter = RegExp(r',|\+');
          final coursesWithSections = courses.split(courseDelimiter);
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
          print("Successfully imported schedule from $uri");
        }
      }
    } catch (e) {
      print(
          "Encountered error while importing schedule from URL:$uri . Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('en'), // English
            Locale('es'), // Spanish
          ],
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: matricalCubitSingleton),
              BlocProvider.value(value: internetCubitSingleton)
            ],
            child: const Matrical(),
          ),
        );
      },
    );
  }
}
