import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:matrical/services/storage_service.dart';

class BugReport extends StatelessWidget {
  final String pageName;
  const BugReport({super.key, required this.pageName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.feedback, color: Colors.white),
      onPressed: () {
        BetterFeedback.of(context).show((UserFeedback feedback) async {
          final screenshotFilePath =
              await writeImageToStorage(feedback.screenshot);
          final Email email = Email(
            body: feedback.text,
            subject: '[Matrical] $pageName Feedback',
            recipients: ['rumtuitionscheduler@gmail.com'],
            attachmentPaths: [screenshotFilePath],
            isHTML: false,
          );
          await FlutterEmailSender.send(email);
        });
      },
    );
  }
}
