import 'package:flutter/material.dart';

class InfoWrapper extends StatelessWidget {
  final Widget child;
  final String title;
  final String content;

  const InfoWrapper({
    super.key,
    required this.child,
    required this.title,
    required this.content,
  });

  void _showDialog(BuildContext context) {
    showDialog(
      useRootNavigator: false,
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(title),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          children: <Widget>[
            Text(content),
            const Text(""),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showDialog(context),
      child: child,
    );
  }
}
