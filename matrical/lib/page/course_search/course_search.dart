import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:miuni/features/matrical/data/model/course_filters.dart';
import 'package:miuni/features/matrical/data/model/department_course.dart';
import 'package:miuni/features/matrical/data/model/schedule_generation_options.dart';
import 'package:miuni/features/matrical/logic/get_data.dart';
import 'package:miuni/features/matrical/page/shared/bug_report.dart';
import 'package:miuni/features/matrical/page/shared/course_filters.dart';
import 'package:miuni/Global/matrical/uppercase_formatter.dart';
import 'package:pair/pair.dart';
import 'package:url_launcher/url_launcher.dart';

const officialColor = Color.fromRGBO(9, 144, 45, 1);

class CourseSearch extends StatefulWidget {
  final Function addSection;
  final Function clearSections;
  final List<String> years;
  final Term initialTerm;
  final String initialYear;

  const CourseSearch(
      {super.key,
      required this.addSection,
      required this.clearSections,
      required this.years,
      required this.initialTerm,
      required this.initialYear});

  @override
  State<CourseSearch> createState() => _CourseSearchState();
}

class _CourseSearchState extends State<CourseSearch> {
  var searchController = TextEditingController();
  Future<List<Course>> searchFuture = Future<List<Course>>.value([]);
  CourseFilters filters = CourseFilters.empty();
  Term? currentTerm;
  String? currentYear;

  void search() {
    FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
    setState(() {
      searchFuture = getCourseSearch(
          searchController.text,
          (currentTerm ?? widget.initialTerm).databaseKey,
          int.parse(currentYear ?? widget.initialYear),
          filters);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(Pair<Term, String>(
                      currentTerm ?? widget.initialTerm,
                      currentYear ?? widget.initialYear))),
              title: const Text(
                "Búsqueda de Cursos",
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: officialColor,
              actions: const [BugReport(pageName: "Course Search")]),
          body: PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (!didPop) {
                Navigator.of(context).pop(Pair<Term, String>(
                    currentTerm ?? widget.initialTerm,
                    currentYear ?? widget.initialYear));
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
                            initialSelection: widget.initialTerm,
                            requestFocusOnTap: false,
                            label: const Text('Término'),
                            onSelected: (e) {
                              currentTerm = e ?? widget.initialTerm;
                              widget.clearSections();
                            },
                            dropdownMenuEntries: Term.values
                                .map<DropdownMenuEntry<Term>>((term) {
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
                            initialSelection: widget.initialYear,
                            requestFocusOnTap: false,
                            label: const Text('Año'),
                            onSelected: (e) {
                              currentYear = e ?? widget.initialYear;
                              widget.clearSections();
                            },
                            dropdownMenuEntries: widget.years
                                .map<DropdownMenuEntry<String>>((year) {
                              return DropdownMenuEntry<String>(
                                value: year,
                                label: year,
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
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'Buscar Curso or Departamento',
                          hintText: 'ie. CIIC3015, INSO',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => search(),
                      )),
                      IconButton(
                          onPressed: () {
                            showDialog(
                                useRootNavigator: false,
                                context: context,
                                builder: (context) =>
                                    CourseFilterPopup(filters: filters));
                          },
                          icon: const Icon(Icons.filter_alt)),
                      ElevatedButton(
                        onPressed: search,
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
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("${snapshot.error}"),
                          ));
                          setState(() {
                            searchFuture = Future.value([]);
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
                                            addSection: widget.addSection,
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
        ));
  }
}

class CourseSections extends StatefulWidget {
  final Course course;
  final Function addSection;
  final bool startExpanded;

  const CourseSections(
      {super.key,
      required this.course,
      required this.addSection,
      required this.startExpanded});

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
                        widget.addSection(widget.course.courseCode, "")),
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
                              widget.addSection(widget.course.courseCode,
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
