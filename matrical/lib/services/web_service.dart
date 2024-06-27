import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool downloadFileOnWeb(String fileName, List<int> bytes) {
  final b64bytes = base64Encode(bytes);
  final uri = Uri.parse("data:application/octet-stream;base64,$b64bytes");
  final anchor = html.AnchorElement(href: uri.toString())
    ..setAttribute("download", fileName)
    ..click();
  anchor.remove();
  return true;
}
