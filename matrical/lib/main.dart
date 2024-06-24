import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

final GoRouter router = GoRouter(
  initialLocation: "/matrical",
  routes: <RouteBase>[
    GoRoute(
      name: 'Matrical',
      path: '/matrical',
      builder: (BuildContext context, GoRouterState state) {
        return MultiBlocProvider(providers: [
          BlocProvider.value(value: matricalCubitSingleton),
          BlocProvider.value(value: InternetCubit())
        ], child: const Matrical());
      },
    ),
  ],
);

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.noScaling, boldText: false),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        );
      },
    );
  }
}
