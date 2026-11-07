import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mistake_loop/journal_portability.dart';
import 'package:mistake_loop/journal_store.dart';
import 'package:mistake_loop/mistake_journal.dart';

void main() {
  final first = DateTime.utc(2026, 1, 1);
  MistakeJournal sample() => MistakeJournal(
    subjects: [Subject(id: 's', name: '=Math,"hard"')],
    mistakes: [
      Mistake(
            id: 'm',
            subjectId: 's',
            sourceLocator: 'page 1\n=evil',
            wrongAnswer: 'wrong',
            correctedAnswer: 'right',
            causes: ['rushed'],
            createdAt: first,
          )
          .revisit(
            at: first.add(const Duration(minutes: 1)),
            answer: 'retry',
            successful: true,
          )
          .reopen(at: first.add(const Duration(minutes: 2)))
          .revisit(
            at: first.add(const Duration(minutes: 3)),
            answer: 'again',
            successful: false,
          ),
    ],
  );

  test(
    'backup round-trips full event history and CSV excludes answer text',
    () {
      final journal = JournalPortability.restore(
        JournalPortability.backup(sample()),
      );
      expect(journal.subjects.single.name, '=Math,"hard"');
      expect(journal.mistakes.single.events.map((e) => e.kind), [
        JournalEventKind.successfulRevisit,
        JournalEventKind.reopened,
        JournalEventKind.failedRevisit,
      ]);
      expect(journal.unresolved.length, 1);
      final csv = utf8.decode(JournalPortability.csv(journal));
      expect(csv, contains('"\'=Math,""hard"""'));
      expect(csv, contains('"page 1\n=evil"'));
      expect(csv, contains('"2"'));
      expect(csv, isNot(contains('wrong')));
      expect(csv, isNot(contains('right')));
    },
  );

  test('rejects malicious, unknown-version and invalid snapshots', () {
    final source = jsonDecode(
      utf8.decode(JournalPortability.backup(sample())),
    ) as Map<String, dynamic>;
    Uint8List bytes(Object value) =>
        Uint8List.fromList(utf8.encode(jsonEncode(value)));
    for (final invalid in [
      {...source, 'version': 999},
      {...source, 'extra': 'hidden'},
      {...source, 'subjects': []},
      {
        ...source,
        'mistakes': [source['mistakes'][0], source['mistakes'][0]],
      },
      {
        ...source,
        'mistakes': [
          {
            ...source['mistakes'][0],
            'causes': ['bad\ninjection'],
          },
        ],
      },
      {
        ...source,
        'mistakes': [
          {
            ...source['mistakes'][0],
            'events': [
              {
                'at': '2026-01-01T00:00:00.000Z',
                'kind': 'reopened',
                'answer': null,
              },
            ],
          },
        ],
      },
    ]) {
      expect(
        () => JournalPortability.restore(bytes(invalid)),
        throwsFormatException,
      );
    }
    expect(
      () => JournalPortability.restore(
        Uint8List(JournalPortability.maxBytes + 1),
      ),
      throwsFormatException,
    );
    expect(
      () => JournalPortability.restore(Uint8List.fromList([0xff])),
      throwsFormatException,
    );
  });

  test('invalid import cannot replace existing SQLite data', () async {
    final dir = await Directory.systemTemp.createTemp('mistake-backup-test-');
    try {
      final store = await openPrivateJournal(directory: dir);
      try {
        await store.save(sample());
        expect(
          () => JournalPortability.restore(
            Uint8List.fromList(utf8.encode('{"version":1}')),
          ),
          throwsFormatException,
        );
        expect((await store.load()).mistakes.single.events.length, 3);
        final replacement = JournalPortability.restore(
          JournalPortability.backup(
            MistakeJournal(
              subjects: [Subject(id: 'new', name: 'New')],
              mistakes: [],
            ),
          ),
        );
        await store.save(replacement);
        expect((await store.load()).subjects.single.id, 'new');
        expect((await store.load()).mistakes, isEmpty);
      } finally {
        await store.close();
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
