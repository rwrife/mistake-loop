import 'dart:convert';
import 'dart:typed_data';

import 'mistake_journal.dart';

/// Versioned, local backup. Import constructs a fresh journal before any write.
class JournalPortability {
  static const version = 1;
  static const maxBytes = 10 * 1024 * 1024;

  static Uint8List backup(MistakeJournal journal) => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'version': version,
        'subjects': [
          for (final s in journal.subjects) {'id': s.id, 'name': s.name},
        ],
        'mistakes': [
          for (final m in journal.mistakes)
            {
              'id': m.id,
              'subjectId': m.subjectId,
              'sourceLocator': m.sourceLocator,
              'wrongAnswer': m.wrongAnswer,
              'correctedAnswer': m.correctedAnswer,
              'prompt': m.prompt,
              'causes': m.causes,
              'createdAt': m.createdAt.toIso8601String(),
              'events': [
                for (final e in m.events)
                  {
                    'at': e.at.toIso8601String(),
                    'kind': e.kind.name,
                    'answer': e.answer,
                  },
              ],
            },
        ],
      }),
    ),
  );

  static MistakeJournal restore(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Backup too large');
    }
    try {
      final data = _object(jsonDecode(utf8.decode(bytes)));
      _keys(data, {'version', 'subjects', 'mistakes'});
      if (data['version'] != version) {
        throw const FormatException('Unsupported backup version');
      }
      final subjects = [
        for (final value in _list(data['subjects']))
          () {
            final s = _object(value);
            _keys(s, {'id', 'name'});
            return Subject(id: _string(s['id']), name: _string(s['name']));
          }(),
      ];
      final mistakes = <Mistake>[];
      for (final value in _list(data['mistakes'])) {
        final m = _object(value);
        _keys(m, {
          'id',
          'subjectId',
          'sourceLocator',
          'wrongAnswer',
          'correctedAnswer',
          'prompt',
          'causes',
          'createdAt',
          'events',
        });
        var mistake = Mistake(
          id: _string(m['id']),
          subjectId: _string(m['subjectId']),
          sourceLocator: _string(m['sourceLocator']),
          wrongAnswer: _string(m['wrongAnswer']),
          correctedAnswer: _string(m['correctedAnswer']),
          prompt: m['prompt'] == null ? null : _string(m['prompt']),
          causes: [for (final c in _list(m['causes'])) _string(c)],
          createdAt: _date(m['createdAt']),
        );
        if (mistake.causes.any((c) => c.contains('\n') || c.contains('\r'))) {
          throw const FormatException('Cause tags must be single-line');
        }
        for (final value in _list(m['events'])) {
          final e = _object(value);
          _keys(e, {'at', 'kind', 'answer'});
          final kind = _string(e['kind']);
          final at = _date(e['at']);
          if (kind == 'reopened' && e['answer'] == null) {
            mistake = mistake.reopen(at: at);
          } else if (kind == 'failedRevisit' || kind == 'successfulRevisit') {
            mistake = mistake.revisit(
              at: at,
              answer: _string(e['answer']),
              successful: kind == 'successfulRevisit',
            );
          } else {
            throw const FormatException('Invalid revisit event');
          }
        }
        mistakes.add(mistake);
      }
      return MistakeJournal(subjects: subjects, mistakes: mistakes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid backup data');
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected object');
    }
    return value;
  }

  static List<dynamic> _list(Object? value) {
    if (value is! List<dynamic>) throw const FormatException('Expected list');
    return value;
  }

  static String _string(Object? value) {
    if (value is! String) throw const FormatException('Expected string');
    return value;
  }

  static DateTime _date(Object? value) {
    final text = _string(value);
    final date = DateTime.tryParse(text);
    if (date == null || !text.endsWith('Z') || date.toIso8601String() != text) {
      throw const FormatException('Expected canonical UTC timestamp');
    }
    return date;
  }

  static void _keys(Map<String, dynamic> map, Set<String> expected) {
    if (map.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(map.keys.toSet()).isNotEmpty) {
      throw const FormatException('Unexpected backup fields');
    }
  }

  static Uint8List csv(MistakeJournal journal) {
    String cell(String text) {
      // Spreadsheet software evaluates leading = + - @ even inside quoted CSV.
      final safe = RegExp(r'^[\s\x00-\x1f]*[=+\-@]').hasMatch(text)
          ? "'$text"
          : text;
      return '"${safe.replaceAll('"', '""')}"';
    }

    final subjectNames = {for (final s in journal.subjects) s.id: s.name};
    final rows = [
      [
        'Subject',
        'Source locator',
        'Error causes',
        'Status',
        'Revisit attempts',
      ],
      for (final m in journal.mistakes)
        [
          subjectNames[m.subjectId]!,
          m.sourceLocator,
          m.causes.join('; '),
          m.resolved ? 'Resolved' : 'Unresolved',
          '${m.events.where((e) => e.kind != JournalEventKind.reopened).length}',
        ],
    ];
    return Uint8List.fromList(
      utf8.encode(
        '${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n',
      ),
    );
  }
}
