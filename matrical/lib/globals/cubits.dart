import 'package:matrical/models/matrical_cubit.dart';

/* You shouldn't reference this singleton directly unless you have really good reason to
it is provided to the root Matrical component and so any child of it should just
call BlocProvider.of<MatricalCubit>(context) to retrieve the instance. The only 
allowed instances right now are when you need to access the state prior to
having access to a widget's context (ie. declaration of a StatefulWidget)
*/
final matricalCubitSingleton = MatricalCubit();
