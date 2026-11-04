import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistake_loop/main.dart';

void main() {
  testWidgets('opens offline journal shell', (tester) async {
    await tester.pumpWidget(const MistakeLoopApp());
    expect(find.text('Mistake Loop'), findsOneWidget);
    expect(find.text('Offline Study Mistake Journal'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
