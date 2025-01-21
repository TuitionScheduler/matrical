import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:matrical/globals/cubits.dart';
import 'package:matrical/models/course_filters.dart';
import 'package:matrical/models/course_filters_popup_response.dart';
import 'package:matrical/models/department_course.dart';
import 'package:matrical/models/matrical_cubit.dart';
import 'package:matrical/models/schedule_generation_options.dart';
import 'package:matrical/services/course_service.dart';
import 'package:matrical/services/formatter_service.dart';
import 'package:matrical/services/stored_preferences.dart';
import 'package:matrical/widgets/course_filters.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  TextEditingController? searchController;

  void search(String? query) {
    FocusManager.instance.primaryFocus?.unfocus(); // close keyboard
    if (query == null) return;
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
      search(matricalCubit.state.lastSearch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matricalCubit = BlocProvider.of<MatricalCubit>(context);
    return BlocBuilder<MatricalCubit, MatricalState>(
      builder: (BuildContext context, MatricalState matricalState) => Column(
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
                      label: Text(AppLocalizations.of(context)!.term),
                      onSelected: (term) async {
                        if (term != null) {
                          matricalCubit.updateTerm(term);
                          currentTerm = term;
                          final removedAny =
                              await matricalCubit.onTermYearChanged();
                          if (removedAny) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(
                                content: Text(AppLocalizations.of(context)!
                                    .removedCoursesWarning),
                              ));
                          }
                          search(matricalState.lastSearch);
                        }
                      },
                      dropdownMenuEntries:
                          Term.values.map<DropdownMenuEntry<Term>>((term) {
                        return DropdownMenuEntry<Term>(
                          value: term,
                          label: term.displayName(context),
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
                      label: Text(AppLocalizations.of(context)!.year),
                      onSelected: (year) async {
                        if (year != null) {
                          matricalCubit.updateYear(int.parse(year));
                          currentYear = int.parse(year);
                          final removedAny =
                              await matricalCubit.onTermYearChanged();
                          if (removedAny) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(
                                content: Text(AppLocalizations.of(context)!
                                    .removedCoursesWarning),
                              ));
                          }
                          search(matricalState.lastSearch);
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                    child: TypeAheadField<String>(
                  suggestionsCallback: (search) async {
                    if (search.isEmpty) {
                      return [];
                    }
                    final cs = CourseService.getInstance();
                    return await cs.autocompleteQuery(
                        search, currentTerm.databaseKey, currentYear);
                  },
                  builder: (context, controller, focusNode) {
                    if (controller.text.isEmpty &&
                        (matricalState.lastSearch?.isNotEmpty ?? false)) {
                      controller.text = matricalState.lastSearch!;
                    }
                    searchController = controller;
                    return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: false,
                        decoration: InputDecoration(
                          labelText:
                              AppLocalizations.of(context)!.courseSearchInput,
                          hintText: 'e.g. CIIC3015, INSO',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        textInputAction: TextInputAction.search,
                        keyboardType: TextInputType.visiblePassword,
                        onSubmitted: (query) => search(query));
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion),
                    );
                  },
                  errorBuilder: (context, error) => Text(
                      AppLocalizations.of(context)!
                          .departmentAutoCompleteError),
                  emptyBuilder: (context) => const SizedBox.shrink(),
                  onSelected: (suggestion) {
                    search(suggestion);
                  },
                )),
                IconButton(
                    onPressed: () async {
                      CourseFilterPopupResponse? response =
                          await showDialog<CourseFilterPopupResponse>(
                              useRootNavigator: false,
                              context: context,
                              builder: (context) => CourseFilterPopup(
                                  filters: matricalState.searchFilters));
                      if (response == CourseFilterPopupResponse.deleted ||
                          response == CourseFilterPopupResponse.saved) {
                        search(matricalState.lastSearch);
                      }
                    },
                    icon: const Icon(Icons.filter_alt)),
                ElevatedButton(
                  onPressed: () => search(searchController?.text),
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
                  snapshot.data!
                      .sort((a, b) => a.courseCode.compareTo(b.courseCode));
                  return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: snapshot.data!
                            .map<Widget>((course) => Column(
                                  children: [
                                    CourseSections(
                                      course: course,
                                      startExpanded: snapshot.data!.length <= 1,
                                      filters: matricalState.searchFilters,
                                    ),
                                    if (course != snapshot.data!.last)
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
    );
  }
}

class CourseSections extends StatefulWidget {
  final Course course;
  final bool startExpanded;
  final CourseFilters? filters;

  const CourseSections(
      {super.key,
      required this.course,
      required this.startExpanded,
      this.filters});

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
    return BlocBuilder<MatricalCubit, MatricalState>(builder: (context, state) {
      return ExpansionTile(
          title: Text(
              "${widget.course.courseName} (${widget.course.courseCode})",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text([
            AppLocalizations.of(context)!
                .creditsWithInput(widget.course.credits),
            // ${widget.course.prerequisites.isNotEmpty ? widget.course.prerequisites : "N/A"}
            AppLocalizations.of(context)!.prerequisitesWithInput(
                widget.course.prerequisites.isNotEmpty
                    ? widget.course.prerequisites
                    : "N/A"),

            AppLocalizations.of(context)!.corequisitesWithInput(
                widget.course.corequisites.isNotEmpty
                    ? widget.course.corequisites
                    : "N/A")
          ].join("\n")),
          trailing: expanded
              ? const Icon(Icons.arrow_drop_up)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      icon: Icon(state.selectedCourses.any((c) =>
                              c.courseCode == widget.course.courseCode &&
                              (c.sectionCode.length <= 3 ||
                                  !c.sectionCode.endsWith("L")))
                          ? Icons.check
                          : Icons.add),
                      onPressed: state.selectedCourses.any((c) =>
                              c.courseCode == widget.course.courseCode &&
                              (c.sectionCode.length <= 3 ||
                                  !c.sectionCode.endsWith("L")))
                          ? null
                          : () => matricalCubit.addCourse(
                              widget.course.courseCode, "",
                              filters: widget.filters)),
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
                                  Text(AppLocalizations.of(context)!
                                      .sectionWithInput(section.sectionCode)),
                                  Text(
                                      AppLocalizations.of(context)!.professors),
                                ] +
                                section.professors
                                    .map((professor) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: professor.url.isEmpty
                                              ? Text(professor.name)
                                              : InkWell(
                                                  onTap: () async {
                                                    await launchUrl(Uri.parse(
                                                        professor.url));
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
                              onPressed: state.selectedCourses.any((c) =>
                                      c.courseCode ==
                                          widget.course.courseCode &&
                                      c.sectionCode == section.sectionCode)
                                  ? () {
                                      setState(() {
                                        final selectedCourses =
                                            state.selectedCourses;
                                        for (var i = 0;
                                            i < selectedCourses.length;
                                            i++) {
                                          final c = selectedCourses[i];
                                          if (c.courseCode ==
                                                  widget.course.courseCode &&
                                              c.sectionCode ==
                                                  section.sectionCode) {
                                            if (c.sectionCode.length > 3 &&
                                                c.sectionCode.endsWith("L")) {
                                              selectedCourses.removeAt(i--);
                                            } else {
                                              selectedCourses[i] =
                                                  CourseWithFilters(
                                                      courseCode: c.courseCode,
                                                      sectionCode: "",
                                                      filters: c.filters);
                                            }
                                          }
                                        }
                                        matricalCubit
                                            .updateCourses(selectedCourses);
                                      });
                                    }
                                  : () {
                                      matricalCubit.addCourse(
                                          widget.course.courseCode,
                                          section.sectionCode);
                                    },
                              child: Icon(state.selectedCourses.any((c) =>
                                      c.courseCode ==
                                          widget.course.courseCode &&
                                      c.sectionCode == section.sectionCode)
                                  ? Icons.undo
                                  : Icons.add)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: section.meetings.isEmpty
                              ? [
                                  Text(
                                      AppLocalizations.of(context)!.byAgreement)
                                ]
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
    });
  }
}
