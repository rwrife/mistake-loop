import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mistake_loop/journal_store.dart';
import 'package:mistake_loop/main.dart';
import 'package:mistake_loop/mistake_journal.dart';

void main() {
  testWidgets('empty shell and loaded summary', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MistakeLoopHome()));
    expect(find.text('Offline Study Mistake Journal'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: MistakeLoopHome(
          journal: MistakeJournal(
            subjects: [Subject(id: 's1', name: 'Math')],
            mistakes: [
              Mistake(
                id: 'm1',
                subjectId: 's1',
                sourceLocator: 'p. 10',
                wrongAnswer: '2',
                correctedAnswer: '4',
                causes: ['concept'],
                createdAt: DateTime.utc(2026, 1, 1),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Unresolved: 1 • Resolved: 0'), findsOneWidget);
  });

  testWidgets('capture, edit, reveal, resolve and explicitly reopen', (
    tester,
  ) async {
    var saved = MistakeJournal(subjects: [], mistakes: []);
    await tester.pumpWidget(
      MaterialApp(
        home: MistakeLoopHome(
          journal: saved,
          onSave: (next) async => saved = next,
        ),
      ),
    );
    await tester.tap(find.text('New subject'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('subject-name')), 'Math');
    await tester.tap(find.text('Save subject'));
    await tester.pumpAndSettle();
    expect(saved.subjects.single.name, 'Math');
    await tester.tap(find.text('Record mistake'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('source-locator')),
      'Book p. 2',
    );
    await tester.enterText(find.byKey(const Key('wrong-answer')), '2');
    await tester.enterText(find.byKey(const Key('corrected-answer')), '4');
    await tester.enterText(find.byKey(const Key('cause-tags')), 'rushed');
    await tester.tap(find.text('Save mistake'));
    await tester.pumpAndSettle();
    expect(saved.unresolved.single.wrongAnswer, '2');
    await tester.tap(find.text('Book p. 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wrong-answer')), '3');
    await tester.tap(find.text('Save mistake'));
    await tester.pumpAndSettle();
    expect(saved.unresolved.single.wrongAnswer, '3');
    await tester.tap(find.text('Revisit'));
    await tester.pumpAndSettle();
    expect(find.text('Correction: 4'), findsNothing);
    await tester.enterText(find.byKey(const Key('revisit-answer')), '4');
    await tester.tap(find.text('Reveal correction'));
    await tester.pumpAndSettle();
    expect(find.text('Correction: 4'), findsOneWidget);
    await tester.tap(find.text('I answered correctly'));
    await tester.pumpAndSettle();
    expect(saved.resolvedCount, 1);
    await tester.tap(find.text('Show resolved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book p. 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();
    expect(saved.unresolved.single.events.length, 2);
  });

  test('private store survives reopen in application directory', () async {
    final dir = await Directory.systemTemp.createTemp('private-journal-');
    try {
      var store = await openPrivateJournal(directory: dir);
      final first = MistakeJournal(
        subjects: [Subject(id: 'math', name: 'Math')],
        mistakes: [
          Mistake(
            id: '1',
            subjectId: 'math',
            sourceLocator: 'p. 10',
            wrongAnswer: '2',
            correctedAnswer: '4',
            causes: ['concept'],
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      await store.save(first);
      await store.close();
      store = await openPrivateJournal(directory: dir);
      final restored = await store.load();
      expect(restored.unresolved.single.wrongAnswer, '2');
      expect(restored.subjects.single.name, 'Math');
      await store.close();
      expect(
        await File('${dir.path}${Platform.pathSeparator}journal.sqlite')
            .exists(),
        isTrue,
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
