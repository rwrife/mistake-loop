import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mistake_loop/journal_store.dart';
import 'package:mistake_loop/mistake_journal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('journal-store-');
    path = '${dir.path}/journal.sqlite';
  });
  tearDown(() => dir.delete(recursive: true));

  final start = DateTime.utc(2026, 1, 1);
  Mistake seed() => Mistake(
    id: 'm1',
    subjectId: 's1',
    sourceLocator: 'Chapter 2',
    wrongAnswer: '12',
    correctedAnswer: '24',
    causes: ['arithmetic'],
    createdAt: start,
  );
  Subject subject() => Subject(id: 's1', name: 'Math');

  test('round-trip history survives close/reopen and later reopen', () async {
    var store = await JournalStore.open(path, factory: databaseFactoryFfi);
    final successful = seed().revisit(
      at: start.add(const Duration(minutes: 1)),
      answer: '24',
      successful: true,
    );
    await store.save(
      MistakeJournal(subjects: [subject()], mistakes: [successful]),
    );
    await store.close();
    store = await JournalStore.open(path, factory: databaseFactoryFfi);
    final loaded = await store.load();
    expect(loaded.subjects.single.name, 'Math');
    expect(loaded.mistakes.single.events.single.answer, '24');
    expect(loaded.resolvedCount, 1);
    final reopened = loaded.mistakes.single.reopen(
      at: start.add(const Duration(minutes: 2)),
    );
    await store.save(
      MistakeJournal(subjects: loaded.subjects, mistakes: [reopened]),
    );
    await store.close();
    store = await JournalStore.open(path, factory: databaseFactoryFfi);
    expect((await store.load()).unresolved.single.events.length, 2);
    await store.close();
  });

  test('failed write rolls back old journal', () async {
    final store = await JournalStore.open(path, factory: databaseFactoryFfi);
    await store.save(MistakeJournal(subjects: [subject()], mistakes: [seed()]));
    final valid = MistakeJournal(
      subjects: [subject()],
      mistakes: [
        seed(),
        Mistake(
          id: 'm2',
          subjectId: 's1',
          sourceLocator: 'Chapter 3',
          wrongAnswer: 'a',
          correctedAnswer: 'b',
          causes: ['logic'],
          createdAt: start,
        ),
      ],
    );
    final outsider = await databaseFactoryFfi.openDatabase(path);
    await outsider.execute(
      "CREATE TRIGGER reject_m2 BEFORE INSERT ON mistakes WHEN NEW.id = 'm2' BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );
    await outsider.close();
    await expectLater(store.save(valid), throwsA(isA<Exception>()));
    await store.close();
    final reopened = await JournalStore.open(path, factory: databaseFactoryFfi);
    expect((await reopened.load()).mistakes.map((m) => m.id), ['m1']);
    await reopened.close();
  });

  test('migrates v1 database without deleting rows', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE subjects (id TEXT PRIMARY KEY, name TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE mistakes (id TEXT PRIMARY KEY, subject_id TEXT NOT NULL REFERENCES subjects(id), source_locator TEXT NOT NULL, wrong_answer TEXT NOT NULL, corrected_answer TEXT NOT NULL, prompt TEXT, causes TEXT NOT NULL, created_at TEXT NOT NULL)',
          );
          await db.insert('subjects', {'id': 's1', 'name': 'Math'});
          await db.insert('mistakes', {
            'id': 'm1',
            'subject_id': 's1',
            'source_locator': 'Chapter 2',
            'wrong_answer': '12',
            'corrected_answer': '24',
            'prompt': null,
            'causes': 'arithmetic',
            'created_at': start.toIso8601String(),
          });
        },
      ),
    );
    await legacy.close();
    final store = await JournalStore.open(path, factory: databaseFactoryFfi);
    expect((await store.load()).unresolved.single.wrongAnswer, '12');
    await store.save(
      MistakeJournal(
        subjects: [subject()],
        mistakes: [
          seed().revisit(
            at: start.add(const Duration(days: 1)),
            answer: '24',
            successful: true,
          ),
        ],
      ),
    );
    expect((await store.load()).resolvedCount, 1);
    await store.close();
  });

  test('corrupt saved history fails closed without changing file', () async {
    final store = await JournalStore.open(path, factory: databaseFactoryFfi);
    await store.save(MistakeJournal(subjects: [subject()], mistakes: [seed()]));
    await store.close();
    final db = await databaseFactoryFfi.openDatabase(path);
    await db.insert('events', {
      'mistake_id': 'm1',
      'ordinal': 1,
      'at': start.add(const Duration(minutes: 1)).toIso8601String(),
      'kind': 'unknown',
      'answer': 'x',
    });
    await db.close();
    final again = await JournalStore.open(path, factory: databaseFactoryFfi);
    await expectLater(again.load(), throwsA(isA<FormatException>()));
    await again.close();
    final finalOpen = await JournalStore.open(
      path,
      factory: databaseFactoryFfi,
    );
    await expectLater(finalOpen.load(), throwsA(isA<FormatException>()));
    await finalOpen.close();
  });
}
