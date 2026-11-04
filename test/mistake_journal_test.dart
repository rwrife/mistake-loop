import 'package:flutter_test/flutter_test.dart';
import 'package:mistake_loop/mistake_journal.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  final t1 = t0.add(const Duration(minutes: 1));
  final t2 = t0.add(const Duration(minutes: 2));
  final t3 = t0.add(const Duration(minutes: 3));

  Mistake entry({String id = 'm1', DateTime? createdAt}) => Mistake(
    id: id,
    subjectId: 'math',
    sourceLocator: 'Textbook p. 12, exercise 4',
    wrongAnswer: '3',
    correctedAnswer: '4',
    causes: ['arithmetic', 'rushed'],
    createdAt: createdAt ?? t0,
  );
  MistakeJournal journal(List<Mistake> mistakes) => MistakeJournal(
    subjects: [Subject(id: 'math', name: 'Math')],
    mistakes: mistakes,
  );

  test('failed revisit remains unresolved; success resolves; reopen requires explicit action', () {
    final original = entry();
    final failed = original.revisit(at: t1, answer: '2', successful: false);
    expect(failed.resolved, isFalse);
    expect(original.events, isEmpty);
    expect(failed.events.single.answer, '2');
    final resolved = failed.revisit(at: t2, answer: '4', successful: true);
    expect(resolved.resolved, isTrue);
    expect(journal([resolved]).resolvedCount, 1);
    expect(
      () => resolved.revisit(at: t3, answer: '4', successful: true),
      throwsStateError,
    );
    final reopened = resolved.reopen(at: t3);
    expect(reopened.resolved, isFalse);
    expect(reopened.events.map((e) => e.kind), [
      JournalEventKind.failedRevisit,
      JournalEventKind.successfulRevisit,
      JournalEventKind.reopened,
    ]);
    expect(journal([reopened]).unresolvedCauseCounts, {
      'arithmetic': 1,
      'rushed': 1,
    });
    expect(
      () => reopened.reopen(at: t3.add(const Duration(minutes: 1))),
      throwsStateError,
    );
  });

  test('rejects blank inputs, duplicate ids and unknown subjects', () {
    expect(() => Subject(id: ' ', name: 'Math'), throwsArgumentError);
    expect(() => entry(id: ' '), throwsArgumentError);
    expect(
      () => Mistake(
        id: 'm',
        subjectId: 'math',
        sourceLocator: ' ',
        wrongAnswer: '3',
        correctedAnswer: '4',
        causes: ['rushed'],
        createdAt: t0,
      ),
      throwsArgumentError,
    );
    expect(
      () => Mistake(
        id: 'm',
        subjectId: 'math',
        sourceLocator: 'p. 1',
        wrongAnswer: '3',
        correctedAnswer: '4',
        causes: [],
        createdAt: t0,
      ),
      throwsArgumentError,
    );
    expect(
      () => Mistake(
        id: 'm',
        subjectId: 'math',
        sourceLocator: 'p. 1',
        wrongAnswer: '3',
        correctedAnswer: '4',
        causes: ['rushed', 'rushed'],
        createdAt: t0,
      ),
      throwsArgumentError,
    );
    expect(
      () => entry().revisit(at: t1, answer: ' ', successful: true),
      throwsArgumentError,
    );
    expect(
      () => entry().revisit(at: t0, answer: '4', successful: true),
      throwsArgumentError,
    );
    expect(() => journal([entry(), entry()]), throwsArgumentError);
    expect(
      () => MistakeJournal(
        subjects: [
          Subject(id: 'math', name: 'Math'),
          Subject(id: 'math', name: 'Again'),
        ],
        mistakes: [],
      ),
      throwsArgumentError,
    );
    expect(
      () => MistakeJournal(subjects: [], mistakes: [entry()]),
      throwsArgumentError,
    );
  });

  test('unresolved queue orders by UTC creation then id; cause counts ignore resolved', () {
    final earlyA = entry(id: 'a');
    final earlyB = entry(id: 'b');
    final late = entry(id: 'c', createdAt: t1);
    final resolved = entry(id: 'd')
        .revisit(at: t2, answer: '4', successful: true);
    final result = journal([late, resolved, earlyB, earlyA]);
    expect(result.unresolved.map((m) => m.id), ['a', 'b', 'c']);
    expect(result.resolvedCount, 1);
    expect(result.unresolvedCauseCounts, {'arithmetic': 3, 'rushed': 3});
    expect(() => result.unresolved.clear(), throwsUnsupportedError);
    expect(() => earlyA.causes.clear(), throwsUnsupportedError);
  });
}
