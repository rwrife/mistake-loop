import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mistake_journal.dart';

/// Private, transactional SQLite storage. Caller supplies app-private path.
class JournalStore {
  JournalStore._(this._db);

  final Database _db;

  static Future<JournalStore> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    if (factory == null && (Platform.isLinux || Platform.isWindows)) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    }
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE subjects (id TEXT PRIMARY KEY, name TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE mistakes (id TEXT PRIMARY KEY, subject_id TEXT NOT NULL REFERENCES subjects(id), source_locator TEXT NOT NULL, wrong_answer TEXT NOT NULL, corrected_answer TEXT NOT NULL, prompt TEXT, causes TEXT NOT NULL, created_at TEXT NOT NULL)',
          );
          await _createEvents(db);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await _createEvents(db);
        },
      ),
    );
    return JournalStore._(db);
  }

  static Future<void> _createEvents(DatabaseExecutor db) => db.execute(
    'CREATE TABLE events (mistake_id TEXT NOT NULL REFERENCES mistakes(id) ON DELETE CASCADE, ordinal INTEGER NOT NULL, at TEXT NOT NULL, kind TEXT NOT NULL, answer TEXT, PRIMARY KEY (mistake_id, ordinal))',
  );

  Future<void> close() => _db.close();

  Future<MistakeJournal> load() async {
    final subjects = <Subject>[
      for (final row in await _db.query('subjects', orderBy: 'rowid'))
        Subject(id: row['id'] as String, name: row['name'] as String),
    ];
    final events = await _db.query('events', orderBy: 'mistake_id, ordinal');
    final byMistake = <String, List<Map<String, Object?>>>{};
    for (final row in events) {
      (byMistake[row['mistake_id'] as String] ??= []).add(row);
    }
    final mistakes = <Mistake>[];
    for (final row in await _db.query('mistakes', orderBy: 'rowid')) {
      final id = row['id'] as String;
      final causes = (row['causes'] as String).split('\n');
      // Newlines are forbidden in cause tags at the database boundary.
      if (causes.any((cause) => cause.isEmpty || cause.contains('\r'))) {
        throw FormatException('Corrupt cause tags for $id');
      }
      var mistake = Mistake(
        id: id,
        subjectId: row['subject_id'] as String,
        sourceLocator: row['source_locator'] as String,
        wrongAnswer: row['wrong_answer'] as String,
        correctedAnswer: row['corrected_answer'] as String,
        prompt: row['prompt'] as String?,
        causes: causes,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
      var ordinal = 0;
      for (final event
          in byMistake.remove(id) ?? const <Map<String, Object?>>[]) {
        if (event['ordinal'] != ordinal++) {
          throw FormatException('Corrupt event order for $id');
        }
        final at = DateTime.parse(event['at'] as String);
        switch (event['kind']) {
          case 'failedRevisit':
          case 'successfulRevisit':
            mistake = mistake.revisit(
              at: at,
              answer: event['answer'] as String,
              successful: event['kind'] == 'successfulRevisit',
            );
          case 'reopened':
            if (event['answer'] != null) {
              throw FormatException('Corrupt reopen event for $id');
            }
            mistake = mistake.reopen(at: at);
          default:
            throw FormatException('Unknown event kind for $id');
        }
      }
      mistakes.add(mistake);
    }
    if (byMistake.isNotEmpty) throw const FormatException('Orphan events');
    return MistakeJournal(subjects: subjects, mistakes: mistakes);
  }

  /// Validate whole snapshot before any write; rollback preserves prior state.
  Future<void> save(MistakeJournal journal) async {
    for (final mistake in journal.mistakes) {
      if (mistake.causes.any(
        (cause) => cause.contains('\n') || cause.contains('\r'),
      )) {
        throw ArgumentError('Cause tags cannot contain newlines');
      }
      var previous = mistake.createdAt;
      var resolved = false;
      for (final event in mistake.events) {
        if (!event.at.isAfter(previous) ||
            (event.kind == JournalEventKind.reopened) !=
                (event.answer == null) ||
            (event.kind == JournalEventKind.reopened && !resolved) ||
            (event.kind != JournalEventKind.reopened && resolved)) {
          throw ArgumentError('Invalid event history');
        }
        resolved = event.kind == JournalEventKind.successfulRevisit;
        previous = event.at;
      }
    }
    await _db.transaction((tx) async {
      await tx.delete('events');
      await tx.delete('mistakes');
      await tx.delete('subjects');
      for (final subject in journal.subjects) {
        await tx.insert('subjects', {'id': subject.id, 'name': subject.name});
      }
      for (final mistake in journal.mistakes) {
        await tx.insert('mistakes', {
          'id': mistake.id,
          'subject_id': mistake.subjectId,
          'source_locator': mistake.sourceLocator,
          'wrong_answer': mistake.wrongAnswer,
          'corrected_answer': mistake.correctedAnswer,
          'prompt': mistake.prompt,
          'causes': mistake.causes.join('\n'),
          'created_at': mistake.createdAt.toIso8601String(),
        });
        for (var index = 0; index < mistake.events.length; index++) {
          final event = mistake.events[index];
          await tx.insert('events', {
            'mistake_id': mistake.id,
            'ordinal': index,
            'at': event.at.toIso8601String(),
            'kind': event.kind.name,
            'answer': event.answer,
          });
        }
      }
    });
  }
}
