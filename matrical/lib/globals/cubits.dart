import 'package:matrical/models/internet_cubit.dart';
import 'package:matrical/models/matrical_cubit.dart';

/* This is provided to the root Matrical component and so children of it should just
call BlocProvider.of<MatricalCubit>(context) to retrieve the instance. The only 
allowed instances right now are when you need to access the state prior to
having access to a widget's context (ie. declaration of a StatefulWidget) or instances
where the original codebase utilized it. 
*/
final matricalCubitSingleton = MatricalCubit();

final internetCubitSingleton = InternetCubit();
