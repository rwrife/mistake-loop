/// Pure, local-only study journal rules. A successful revisit is self-marked,
/// never graded by comparing answer text.
library;

String _required(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank');
  }
  return trimmed;
}

DateTime _utc(DateTime value) => value.toUtc();

class Subject {
  Subject({required String id, required String name})
    : id = _required(id, 'id'),
      name = _required(name, 'name');

  final String id;
  final String name;
}

enum JournalEventKind { failedRevisit, successfulRevisit, reopened }

class JournalEvent {
  JournalEvent.revisit({
    required DateTime at,
    required String answer,
    required bool successful,
  }) : at = _utc(at),
       answer = _required(answer, 'answer'),
       kind = successful
           ? JournalEventKind.successfulRevisit
           : JournalEventKind.failedRevisit;

  JournalEvent.reopened({required DateTime at})
    : at = _utc(at),
      answer = null,
      kind = JournalEventKind.reopened;

  final DateTime at;
  final String? answer;
  final JournalEventKind kind;
}

class Mistake {
  Mistake({
    required String id,
    required String subjectId,
    required String sourceLocator,
    required String wrongAnswer,
    required String correctedAnswer,
    required Iterable<String> causes,
    required DateTime createdAt,
    String? prompt,
  }) : this._(
         id: _required(id, 'id'),
         subjectId: _required(subjectId, 'subjectId'),
         sourceLocator: _required(sourceLocator, 'sourceLocator'),
         wrongAnswer: _required(wrongAnswer, 'wrongAnswer'),
         correctedAnswer: _required(correctedAnswer, 'correctedAnswer'),
         prompt: prompt == null ? null : _required(prompt, 'prompt'),
         causes: _causes(causes),
         createdAt: _utc(createdAt),
         events: const [],
       );

  Mistake._({
    required this.id,
    required this.subjectId,
    required this.sourceLocator,
    required this.wrongAnswer,
    required this.correctedAnswer,
    required this.prompt,
    required this.causes,
    required this.createdAt,
    required this.events,
  });

  static List<String> _causes(Iterable<String> values) {
    final result = values.map((value) => _required(value, 'cause')).toList();
    if (result.isEmpty || result.toSet().length != result.length) {
      throw ArgumentError.value(result, 'causes', 'Require unique cause tags');
    }
    return List.unmodifiable(result);
  }

  final String id;
  final String subjectId;
  final String sourceLocator;
  final String wrongAnswer;
  final String correctedAnswer;
  final String? prompt;
  final List<String> causes;
  final DateTime createdAt;
  final List<JournalEvent> events;

  bool get resolved =>
      events.isNotEmpty &&
      events.last.kind == JournalEventKind.successfulRevisit;

  /// Append only; timestamps must advance so history remains unambiguous.
  Mistake _append(JournalEvent event) {
    final previous = events.isEmpty ? createdAt : events.last.at;
    if (!event.at.isAfter(previous)) {
      throw ArgumentError.value(event.at, 'at', 'Must follow previous event');
    }
    return Mistake._(
      id: id,
      subjectId: subjectId,
      sourceLocator: sourceLocator,
      wrongAnswer: wrongAnswer,
      correctedAnswer: correctedAnswer,
      prompt: prompt,
      causes: causes,
      createdAt: createdAt,
      events: List.unmodifiable([...events, event]),
    );
  }

  Mistake revisit({
    required DateTime at,
    required String answer,
    required bool successful,
  }) {
    if (resolved) throw StateError('Reopen before another revisit');
    return _append(
      JournalEvent.revisit(at: at, answer: answer, successful: successful),
    );
  }

  Mistake reopen({required DateTime at}) {
    if (!resolved) throw StateError('Only resolved mistakes can reopen');
    return _append(JournalEvent.reopened(at: at));
  }
}

class MistakeJournal {
  MistakeJournal({
    required Iterable<Subject> subjects,
    required Iterable<Mistake> mistakes,
  }) : subjects = List.unmodifiable(subjects),
       mistakes = List.unmodifiable(mistakes) {
    final subjectIds = this.subjects.map((s) => s.id).toSet();
    if (subjectIds.length != this.subjects.length) {
      throw ArgumentError('Duplicate subject IDs');
    }
    final mistakeIds = this.mistakes.map((m) => m.id).toSet();
    if (mistakeIds.length != this.mistakes.length) {
      throw ArgumentError('Duplicate mistake IDs');
    }
    if (this.mistakes.any((m) => !subjectIds.contains(m.subjectId))) {
      throw ArgumentError('Unknown subject ID');
    }
  }

  final List<Subject> subjects;
  final List<Mistake> mistakes;

  List<Mistake> get unresolved => List.unmodifiable(
    mistakes.where((m) => !m.resolved).toList()..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    }),
  );

  int get resolvedCount => mistakes.where((m) => m.resolved).length;

  Map<String, int> get unresolvedCauseCounts {
    final counts = <String, int>{};
    for (final mistake in unresolved) {
      for (final cause in mistake.causes) {
        counts.update(cause, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return Map.unmodifiable({
      for (final key in counts.keys.toList()..sort()) key: counts[key]!,
    });
  }
}
