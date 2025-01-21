import 'package:flutter/material.dart';
import 'package:matrical/models/blacklist.dart';
import 'package:matrical/models/department_course.dart';
import 'package:matrical/models/generated_schedule.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CourseView extends StatelessWidget {
  final CourseSectionPair pair;
  final Blacklist? blacklist;
  final Function? regenerateSchedules;
  final Function? isLocked;
  final Function? applyLock;
  final Function? removeLock;
  final bool isStatic;

  const CourseView(
      {super.key,
      required this.pair,
      this.blacklist,
      this.regenerateSchedules,
      this.isLocked,
      this.applyLock,
      this.removeLock,
      this.isStatic = false});

  @override
  Widget build(BuildContext context) {
    final Course course = pair.course;
    final Section section = pair.getSection();
    const textSpacing = 4.0;

    return Center(
        child: FractionallySizedBox(
      widthFactor: 0.8,
      heightFactor: 0.6,
      child: Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Material(
              color: Colors.transparent,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${course.courseName} (${course.courseCode}-${section.sectionCode})",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (!isStatic) const SizedBox(width: 8),
                        if (!isStatic)
                          Row(
                            children: [
                              const Icon(Icons.lock),
                              Switch(
                                  value: isLocked!(
                                      course.courseCode, section.sectionCode),
                                  onChanged: (value) {
                                    value
                                        ? applyLock!(course.courseCode,
                                            section.sectionCode)
                                        : removeLock!(course.courseCode,
                                            section.sectionCode);
                                    regenerateSchedules!();
                                    Navigator.of(context).pop();
                                  })
                            ],
                          )
                      ],
                    ),
                    const Divider(),
                    Expanded(
                        child: SingleChildScrollView(
                            child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            Text(AppLocalizations.of(context)!
                                .creditsWithInput(course.credits)),
                            SizedBox.fromSize(
                                size: const Size.fromHeight(textSpacing)),
                            Text(
                              AppLocalizations.of(context)!
                                  .prerequisitesWithInput(
                                      course.prerequisites.isNotEmpty
                                          ? course.prerequisites
                                          : "N/A"),
                            ),
                            SizedBox.fromSize(
                                size: const Size.fromHeight(textSpacing)),
                            Text(
                              AppLocalizations.of(context)!
                                  .corequisitesWithInput(
                                      course.corequisites.isNotEmpty
                                          ? course.corequisites
                                          : "N/A"),
                            ),
                            SizedBox.fromSize(
                                size: const Size.fromHeight(textSpacing)),
                            Text(AppLocalizations.of(context)!.levelInput(
                                Division.fromDatabase(course.division)
                                    .displayName(context))),
                            SizedBox.fromSize(
                                size: const Size.fromHeight(textSpacing)),
                            Text(AppLocalizations.of(context)!.hasIntegratedLab(
                                course.hasIntegratedLab ? "✔" : "✖")),
                            SizedBox.fromSize(
                                size: const Size.fromHeight(textSpacing)),
                            Text(AppLocalizations.of(context)!.meetings(section
                                    .meetings.isNotEmpty
                                ? section.meetings.join("\n\t\t")
                                : AppLocalizations.of(context)!.byAgreement)),
                            SizedBox.fromSize(
                                size: const Size.fromHeight(textSpacing)),
                            Text(AppLocalizations.of(context)!.professors),
                          ] +
                          section.professors
                              .map((professor) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        professor.url.isEmpty
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
                                        if (!isStatic)
                                          InkWell(
                                            onTap: () {
                                              blacklist?.professors
                                                  .add(professor);
                                              regenerateSchedules!();
                                              Navigator.of(context).pop();
                                            },
                                            customBorder: const CircleBorder(),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4.0),
                                              child:
                                                  Icon(Icons.close, size: 16),
                                            ),
                                          )
                                      ],
                                    ),
                                  ))
                              .toList(),
                    ))),
                    if (!isStatic &&
                        !isLocked!(course.courseCode, section.sectionCode))
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                              onPressed: () {
                                if (blacklist?.sections[course.courseCode] ==
                                    null) {
                                  blacklist?.sections[course.courseCode] = [];
                                }
                                blacklist?.sections[course.courseCode]
                                    ?.add(section.sectionCode);
                                regenerateSchedules!();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.delete)),
                        ],
                      )
                  ]),
            ),
          )),
    ));
  }
}
