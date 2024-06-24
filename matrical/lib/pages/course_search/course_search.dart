import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:matrical/globals/cubits.dart';
import 'package:matrical/models/department_course.dart';
import 'package:matrical/models/matrical_cubit.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/services/course_service.dart';
import 'package:matrical/services/formatter_service.dart';
import 'package:matrical/services/stored_preferences.dart';
import 'package:matrical/widgets/course_filters.dart';
import 'package:url_launcher/url_launcher.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);

class CourseSearch extends StatefulWidget {
  const CourseSearch({super.key});

  @override
  State<CourseSearch> createState() => _CourseSearchState();
}

class _CourseSearchState extends State<CourseSearch> {
  Future<List<Course>> searchFuture = Future<List<Course>>.value([]);
  Term currentTerm = matricalCubitSingleton.state.term;
  int currentYear = matricalCubitSingleton.state.year;

  void search(String query) {
    FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
    setState(() {
      final matricalCubit = BlocProvider.of<MatricalCubit>(context);
      searchFuture = getCourseSearch(query, currentTerm.databaseKey,
          currentYear, matricalCubit.state.searchFilters);
      matricalCubit.setLastSearch(query);
    });
  }

  @override
  void initState() {
    super.initState();
    final matricalCubit = BlocProvider.of<MatricalCubit>(context);
    if (matricalCubit.state.lastSearch?.isNotEmpty ?? false) {
      search(matricalCubit.state.lastSearch ?? "");
    }
  }

  @override
  Widget build(BuildContext context) {
    final matricalCubit = BlocProvider.of<MatricalCubit>(context);
    return BlocBuilder<MatricalCubit, MatricalState>(
      builder: (BuildContext context, MatricalState matricalState) => PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            Navigator.of(context).pop();
          }
        },
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DropdownMenu<Term>(
                        expandedInsets: const EdgeInsets.all(0),
                        initialSelection: matricalState.term,
                        requestFocusOnTap: false,
                        label: const Text('Término'),
                        onSelected: (term) {
                          if (term != null) {
                            matricalCubit.updateTerm(term);
                            currentTerm = term;
                            matricalCubit.clearCourses();
                          }
                        },
                        dropdownMenuEntries:
                            Term.values.map<DropdownMenuEntry<Term>>((term) {
                          return DropdownMenuEntry<Term>(
                            value: term,
                            label: term.displayName,
                          );
                        }).toList()),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DropdownMenu<String>(
                        expandedInsets: const EdgeInsets.all(0),
                        initialSelection: matricalState.year.toString(),
                        requestFocusOnTap: false,
                        label: const Text('Año'),
                        onSelected: (year) {
                          if (year != null) {
                            matricalCubit.updateYear(int.parse(year));
                            currentYear = int.parse(year);
                            matricalCubit.clearCourses();
                          }
                        },
                        dropdownMenuEntries: getAcademicYears()
                            .map<DropdownMenuEntry<String>>((year) {
                          return DropdownMenuEntry<String>(
                            value: year.toString(),
                            label: "$year-${year + 1}",
                          );
                        }).toList()),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                    controller: matricalState.searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar Curso o Departamento',
                      hintText: 'ie. CIIC3015, INSO',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) =>
                        search(matricalState.searchController.text),
                  )),
                  IconButton(
                      onPressed: () {
                        showDialog(
                            useRootNavigator: false,
                            context: context,
                            builder: (context) => CourseFilterPopup(
                                filters: matricalState.searchFilters));
                      },
                      icon: const Icon(Icons.filter_alt)),
                  ElevatedButton(
                    onPressed: () =>
                        search(matricalState.searchController.text),
                    child: const Icon(Icons.search),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 3),
            Expanded(
              child: FutureBuilder(
                future: searchFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.none) {
                    return const Text("");
                  } else if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    // While waiting for the Future to complete, show a loading indicator
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // If an error occurred, display an error message
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("${snapshot.error}"),
                      ));
                      setState(() {
                        searchFuture = Future.value([]);
                        matricalCubit.setLastSearch(null);
                      });
                    });
                    return const Center(child: CircularProgressIndicator());
                  } else {
                    // If the Future completed successfully, display the data
                    return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: snapshot.data!
                              .sorted((a, b) =>
                                  a.courseCode.compareTo(b.courseCode))
                              .map<Widget>((course) => Column(
                                    children: [
                                      CourseSections(
                                        course: course,
                                        startExpanded:
                                            snapshot.data!.length <= 1,
                                      ),
                                      // Add a Divider widget here
                                      const Divider(
                                        thickness: 3,
                                      ),
                                    ],
                                  ))
                              .toList(),
                        ));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CourseSections extends StatefulWidget {
  final Course course;
  final bool startExpanded;

  const CourseSections(
      {super.key, required this.course, required this.startExpanded});

  @override
  State<CourseSections> createState() => _CourseSectionsState();
}

class _CourseSectionsState extends State<CourseSections> {
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    expanded = widget.startExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final matricalCubit = BlocProvider.of<MatricalCubit>(context);
    return ExpansionTile(
        title: Text("${widget.course.courseName} (${widget.course.courseCode})",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Créditos: ${widget.course.credits}\n"
            "Pre-requisitos: ${widget.course.prerequisites.isNotEmpty ? widget.course.prerequisites : "N/A"}\n"
            "Co-requisitos: ${widget.course.corequisites.isNotEmpty ? widget.course.corequisites : "N/A"}"),
        trailing: expanded
            ? const Icon(Icons.arrow_drop_up)
            : Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () =>
                        matricalCubit.addCourse(widget.course.courseCode, "")),
                const Icon(Icons.arrow_drop_down),
              ]),
        initiallyExpanded: widget.startExpanded,
        shape: const Border(),
        onExpansionChanged: (value) {
          setState(() {
            expanded = value;
          });
        },
        children: widget.course.sections.mapIndexed((i, section) {
          // Check if the section is not the first one to add a Divider before it
          bool isFirstSection = i == 0;
          return Column(
            children: [
              Divider(
                thickness: isFirstSection ? 2 : 1,
                height: 2,
              ), // Add a Divider here with thickness of 2
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                                Text("Sección: ${section.sectionCode}"),
                                const Text("Profesores:"),
                              ] +
                              section.professors
                                  .map((professor) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: professor.url.isEmpty
                                            ? Text(professor.name)
                                            : InkWell(
                                                onTap: () async {
                                                  await launchUrl(
                                                      Uri.parse(professor.url));
                                                },
                                                child: Text(professor.name,
                                                    style: TextStyle(
                                                        color:
                                                            Colors.green[900],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        decoration:
                                                            TextDecoration
                                                                .underline)),
                                              ),
                                      ))
                                  .toList(),
                        ),
                        ElevatedButton(
                            onPressed: () {
                              matricalCubit.addCourse(widget.course.courseCode,
                                  section.sectionCode);
                            },
                            child: const Icon(Icons.add)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: section.meetings.isEmpty
                            ? [const Text("Por Acuerdo")]
                            : section.meetings
                                .map((schedule) => Text(schedule.toString()))
                                .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList());
  }
}
