import 'dart:typed_data';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:matrical/services/storage_service.dart';

void clearQueryParameters() {
  throw UnsupportedError("You can only clear query params on web.");
}

bool downloadFileOnWeb(String fileName, List<int> bytes) {
  throw UnsupportedError('This functionality is only available on the web.');
}

Future<void> sendFeedbackEmail(
    String subject, String body, Uint8List screenshotBytes) async {
  final screenshotFilePath = await writeImageToStorage(screenshotBytes);
  final Email email = Email(
    body: body,
    subject: subject,
    recipients: ['rumtuitionscheduler@gmail.com'],
    attachmentPaths: [screenshotFilePath],
    isHTML: false,
  );
  await FlutterEmailSender.send(email);
}
