import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:matrical/firebase_options.dart';
import 'package:matrical/globals/cubits.dart';
import 'package:matrical/models/internet_cubit.dart';
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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          home: MultiBlocProvider(providers: [
            BlocProvider.value(value: matricalCubitSingleton),
            BlocProvider.value(value: InternetCubit())
          ], child: const Matrical()),
        );
      },
    );
  }
}
