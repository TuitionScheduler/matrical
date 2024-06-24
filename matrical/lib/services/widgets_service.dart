import 'package:flutter/material.dart';

List<Row> splitWidgets(List<Widget> widgets, int n) {
  var rows = <Row>[];
  var currentRow = <Widget>[];
  for (var (i, widget) in widgets.indexed) {
    currentRow.add(widget);
    if (i % n == n - 1) {
      rows.add(Row(children: currentRow));
      currentRow = [];
    }
  }
  if (currentRow.isNotEmpty) {
    rows.add(Row(
      children: currentRow,
    ));
  }
  return rows;
}
