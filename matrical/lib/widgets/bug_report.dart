import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:matrical/services/platform_service.dart'
    if (dart.library.html) 'package:matrical/services/web_service.dart';

class BugReport extends StatelessWidget {
  final String pageName;
  const BugReport({super.key, required this.pageName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.feedback, color: Colors.white),
      onPressed: () {
        BetterFeedback.of(context).show((UserFeedback feedback) async {
          sendFeedbackEmail('[Matrical] $pageName Feedback', feedback.text,
              feedback.screenshot);
        });
      },
    );
  }
}
