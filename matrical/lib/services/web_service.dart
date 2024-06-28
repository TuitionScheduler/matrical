import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

bool downloadFileOnWeb(String fileName, List<int> bytes) {
  final b64bytes = base64Encode(bytes);
  final uri = Uri.parse("data:application/octet-stream;base64,$b64bytes");
  final anchor = html.AnchorElement(href: uri.toString())
    ..setAttribute("download", fileName)
    ..click();
  anchor.remove();
  return true;
}

Future<void> sendFeedbackEmail(
    String subject, String body, Uint8List screenshotBytes) async {
  final screenshotBase64 = base64Encode(screenshotBytes);
  final uri = Uri(
    scheme: 'mailto',
    path: 'rumtuitionscheduler@gmail.com',
    query: 'subject=$subject&body=$body\n\nScreenshot:\n$screenshotBase64',
  );
  html.window.open(uri.toString(), '_blank');
}
