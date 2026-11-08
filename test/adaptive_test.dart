import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'package:mistake_loop/adaptive.dart';
import 'package:mistake_loop/main.dart';
import 'package:mistake_loop/mistake_journal.dart';

MistakeJournal _testJournal() => MistakeJournal(
  subjects: [
    Subject(id: 'math', name: 'Math'),
    Subject(id: 'sci', name: 'Science'),
  ],
  mistakes: [
    Mistake(
      id: 'm1',
      subjectId: 'math',
      sourceLocator: 'Calculus Ch 1',
      wrongAnswer: 'e^x + C',
      correctedAnswer: 'x e^x',
      causes: ['sign error'],
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  ],
);

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    for (final size in [
      const Size(390, 844), // Phone
      const Size(820, 1180), // Tablet
      const Size(1280, 800), // Desktop
    ]) {
      testWidgets(
        'Renders properly on ${platform.name} at ${size.width}x${size.height}',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          try {
            await tester.pumpWidget(
              AdaptiveApp(home: MistakeLoopHome(journal: _testJournal())),
            );
            await tester.pumpAndSettle();

            if (platform != TargetPlatform.windows) {
              expect(find.text('Mistake Loop'), findsOneWidget);
            }
            expect(find.text('Calculus Ch 1'), findsOneWidget);
            expect(find.text('New subject'), findsOneWidget);

            if (platform == TargetPlatform.iOS) {
              expect(find.byType(cupertino.CupertinoApp), findsOneWidget);
              expect(find.byType(material.MaterialApp), findsNothing);
              expect(find.byType(fluent.FluentApp), findsNothing);
            } else if (platform == TargetPlatform.windows) {
              expect(find.byType(fluent.FluentApp), findsOneWidget);
              expect(find.byType(material.MaterialApp), findsNothing);
              expect(find.byType(cupertino.CupertinoApp), findsNothing);
            } else {
              expect(find.byType(material.MaterialApp), findsOneWidget);
              expect(find.byType(cupertino.CupertinoApp), findsNothing);
              expect(find.byType(fluent.FluentApp), findsNothing);
            }
          } finally {
            debugDefaultTargetPlatformOverride = null;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.windows]) {
    testWidgets('${platform.name} new subject and capture dialogs', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      var saved = MistakeJournal(subjects: [], mistakes: []);
      try {
        await tester.pumpWidget(
          AdaptiveApp(
            home: MistakeLoopHome(
              journal: saved,
              onSave: (next) async => saved = next,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('New subject'));
        await tester.pumpAndSettle();
        expect(find.byType(AdaptiveDialog), findsOneWidget);
        await tester.enterText(find.byKey(const Key('subject-name')), 'Math');
        await tester.tap(find.text('Save subject'));
        await tester.pumpAndSettle();
        expect(saved.subjects.single.name, 'Math');
        await tester.tap(find.text('Record mistake'));
        await tester.pumpAndSettle();
        expect(find.byType(AdaptiveDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  }

  testWidgets('Keyboard traversal and focus navigation flow', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    try {
      await tester.pumpWidget(
        AdaptiveApp(home: MistakeLoopHome(journal: _testJournal())),
      );
      await tester.pumpAndSettle();

      // Tab through controls
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('Accessible text scaling (3.0x) does not crash or overflow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.platformDispatcher.textScaleFactorTestValue = 3.0;

    try {
      await tester.pumpWidget(
        AdaptiveApp(home: MistakeLoopHome(journal: _testJournal())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mistake Loop'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.platformDispatcher.clearTextScaleFactorTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}
