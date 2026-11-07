import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mistake_loop/journal_portability.dart';
import 'package:mistake_loop/journal_store.dart';
import 'package:mistake_loop/mistake_journal.dart';

void main() => runApp(const MistakeLoopApp());

class MistakeLoopApp extends StatefulWidget {
  const MistakeLoopApp({super.key, this.store});
  final JournalStore? store;

  @override
  State<MistakeLoopApp> createState() => _MistakeLoopAppState();
}

class _MistakeLoopAppState extends State<MistakeLoopApp> {
  JournalStore? _store;
  MistakeJournal? _journal;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final store = widget.store ?? await openPrivateJournal();
      final journal = await store.load();
      if (!mounted) {
        if (widget.store == null) await store.close();
        return;
      }
      setState(() {
        _store = store;
        _journal = journal;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    if (widget.store == null) _store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mistake Loop',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: MistakeLoopHome(
      loading: _journal == null && _error == null,
      error: _error,
      journal: _journal,
      onSave: _store?.save,
    ),
  );
}

class MistakeLoopHome extends StatefulWidget {
  const MistakeLoopHome({
    super.key,
    this.loading = false,
    this.error,
    this.journal,
    this.onSave,
    this.pickBackup,
    this.saveFile,
  });
  final bool loading;
  final Object? error;
  final MistakeJournal? journal;
  final Future<void> Function(MistakeJournal)? onSave;
  final Future<PlatformFile?> Function()? pickBackup;
  final Future<Uri?> Function(String, String, List<int>)? saveFile;

  @override
  State<MistakeLoopHome> createState() => _MistakeLoopHomeState();
}

class _MistakeLoopHomeState extends State<MistakeLoopHome> {
  MistakeJournal? _journal;
  String? _subjectId;
  bool _resolved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _journal = widget.journal;
  }

  @override
  void didUpdateWidget(covariant MistakeLoopHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journal != widget.journal) _journal = widget.journal;
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  DateTime _after(Mistake mistake) {
    final last = mistake.events.isEmpty
        ? mistake.createdAt
        : mistake.events.last.at;
    final now = DateTime.now().toUtc();
    return now.isAfter(last) ? now : last.add(const Duration(microseconds: 1));
  }

  Future<bool> _save(MistakeJournal next) async {
    if (_saving || widget.onSave == null) return false;
    setState(() => _saving = true);
    try {
      await widget.onSave!(next);
      if (mounted) setState(() => _journal = next);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $error')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<T?> _dialog<T>({required WidgetBuilder builder}) async {
    final route = DialogRoute<T>(context: context, builder: builder);
    final result = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed; // TextFields unmount after reverse animation.
    return result;
  }

  Future<bool> _confirm(String title, String detail, String action) async =>
      await _dialog<bool>(
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _notice(String message) {
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _export({required bool csv}) async {
    final journal = _journal;
    if (journal == null || _saving) return;
    if (!await _confirm(
      'Export private data?',
      csv
          ? 'Summary includes subject names, source locators and causes. The chosen destination may share these details outside this device.'
          : 'Backup includes wrong answers, corrections and revisit history. The chosen destination may share these details outside this device.',
      'Choose destination',
    )) {
      return;
    }
    try {
      final bytes = csv
          ? JournalPortability.csv(journal)
          : JournalPortability.backup(journal);
      final name = csv
          ? 'mistake-loop-summary.csv'
          : 'mistake-loop-backup.json';
      final uri =
          await (widget.saveFile?.call(
                name,
                csv ? 'text/csv' : 'application/json',
                bytes,
              ) ??
              FilePicker.saveFile(
                fileName: name,
                bytes: bytes,
                mimeType: csv ? 'text/csv' : 'application/json',
              ));
      if (uri != null) _notice('Saved $name to chosen destination');
    } catch (error) {
      _notice('Export failed: $error');
    }
  }

  Future<void> _import() async {
    if (_saving || _journal == null) return;
    try {
      final file =
          await (widget.pickBackup?.call() ??
              FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: ['json'],
              ));
      if (file == null) return;
      if ((await file.length() ?? 0) > JournalPortability.maxBytes) {
        throw const FormatException('Backup too large');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > JournalPortability.maxBytes) {
        throw const FormatException('Backup too large');
      }
      final replacement = JournalPortability.restore(bytes);
      if (!mounted) return;
      final current = _journal!;
      if (!await _confirm(
        'Replace private journal?',
        'Backup preview: ${replacement.subjects.length} subjects, ${replacement.mistakes.length} mistakes, ${replacement.unresolved.length} unresolved. Current journal: ${current.subjects.length} subjects, ${current.mistakes.length} mistakes. Import replaces all current data. Export a backup first if needed.',
        'Replace journal',
      )) {
        return;
      }
      if (!mounted || !identical(current, _journal)) {
        _notice('Journal changed during import; retry to review current data.');
        return;
      }
      if (await _save(replacement) && mounted) {
        setState(() {
          _subjectId = null;
          _resolved = false;
        });
        _notice('Backup restored');
      }
    } catch (error) {
      _notice('Import failed; journal unchanged: $error');
    }
  }

  Future<void> _newSubject() async {
    final name = TextEditingController();
    try {
      final accepted = await _dialog<bool>(
        builder: (dialog) => AlertDialog(
          title: const Text('New subject'),
          content: TextField(
            key: const Key('subject-name'),
            controller: name,
            decoration: const InputDecoration(labelText: 'Subject name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) Navigator.pop(dialog, true);
              },
              child: const Text('Save subject'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      final journal = _journal!;
      await _save(
        MistakeJournal(
          subjects: [
            ...journal.subjects,
            Subject(id: _id(), name: name.text),
          ],
          mistakes: journal.mistakes,
        ),
      );
    } finally {
      name.dispose();
    }
  }

  Future<void> _edit([Mistake? original]) async {
    final journal = _journal!;
    final form = GlobalKey<FormState>();
    final source = TextEditingController(text: original?.sourceLocator);
    final prompt = TextEditingController(text: original?.prompt);
    final wrong = TextEditingController(text: original?.wrongAnswer);
    final correct = TextEditingController(text: original?.correctedAnswer);
    final cause = TextEditingController(text: original?.causes.join(', '));
    var subjectId =
        original?.subjectId ?? _subjectId ?? journal.subjects.first.id;
    String? requiredText(String? text) =>
        (text ?? '').trim().isEmpty ? 'Required' : null;
    try {
      await _dialog<void>(
        builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(original == null ? 'Record mistake' : 'Edit mistake'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        key: const Key('mistake-subject'),
                        initialValue: subjectId,
                        decoration: const InputDecoration(labelText: 'Subject'),
                        items: [
                          for (final s in journal.subjects)
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (id) {
                          if (id != null) update(() => subjectId = id);
                        },
                      ),
                      TextFormField(
                        key: const Key('source-locator'),
                        controller: source,
                        decoration: const InputDecoration(
                          labelText: 'Source locator',
                        ),
                        validator: requiredText,
                      ),
                      TextFormField(
                        key: const Key('optional-prompt'),
                        controller: prompt,
                        decoration: const InputDecoration(
                          labelText: 'Your prompt (optional)',
                        ),
                      ),
                      TextFormField(
                        key: const Key('wrong-answer'),
                        controller: wrong,
                        decoration: const InputDecoration(
                          labelText: 'Your wrong answer',
                        ),
                        validator: requiredText,
                      ),
                      TextFormField(
                        key: const Key('corrected-answer'),
                        controller: correct,
                        decoration: const InputDecoration(
                          labelText: 'Corrected answer',
                        ),
                        validator: requiredText,
                      ),
                      TextFormField(
                        key: const Key('cause-tags'),
                        controller: cause,
                        decoration: const InputDecoration(
                          labelText: 'Error causes (comma-separated)',
                        ),
                        validator: (value) {
                          final tags = (value ?? '')
                              .split(',')
                              .map((s) => s.trim())
                              .toList();
                          return tags.any(
                                    (s) =>
                                        s.isEmpty ||
                                        s.contains('\n') ||
                                        s.contains('\r'),
                                  ) ||
                                  tags.toSet().length != tags.length
                              ? 'Use unique, single-line causes'
                              : null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        final tags = cause.text
                            .split(',')
                            .map((s) => s.trim())
                            .toList();
                        final mistake = original == null
                            ? Mistake(
                                id: _id(),
                                subjectId: subjectId,
                                sourceLocator: source.text,
                                wrongAnswer: wrong.text,
                                correctedAnswer: correct.text,
                                prompt: prompt.text.trim().isEmpty
                                    ? null
                                    : prompt.text,
                                causes: tags,
                                createdAt: DateTime.now().toUtc(),
                              )
                            : original.edit(
                                subjectId: subjectId,
                                sourceLocator: source.text,
                                wrongAnswer: wrong.text,
                                correctedAnswer: correct.text,
                                prompt: prompt.text.trim().isEmpty
                                    ? null
                                    : prompt.text,
                                causes: tags,
                              );
                        if (await _save(
                              MistakeJournal(
                                subjects: journal.subjects,
                                mistakes: original == null
                                    ? [...journal.mistakes, mistake]
                                    : [
                                        for (final m in journal.mistakes)
                                          if (m.id == original.id)
                                            mistake
                                          else
                                            m,
                                      ],
                              ),
                            ) &&
                            dialog.mounted) {
                          Navigator.pop(dialog);
                        }
                      },
                child: const Text('Save mistake'),
              ),
            ],
          ),
        ),
      );
    } finally {
      source.dispose();
      prompt.dispose();
      wrong.dispose();
      correct.dispose();
      cause.dispose();
    }
  }

  Future<bool> _replace(Mistake original, Mistake updated) {
    final journal = _journal!;
    return _save(
      MistakeJournal(
        subjects: journal.subjects,
        mistakes: [
          for (final m in journal.mistakes)
            if (m.id == original.id) updated else m,
        ],
      ),
    );
  }

  Future<void> _revisit(Mistake mistake) async {
    final answer = TextEditingController();
    var revealed = false;
    try {
      await _dialog<void>(
        builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Revisit mistake'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Source: ${mistake.sourceLocator}'),
                    if (mistake.prompt != null) Text(mistake.prompt!),
                    TextField(
                      key: const Key('revisit-answer'),
                      controller: answer,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Your fresh answer',
                      ),
                    ),
                    if (revealed) ...[
                      Text('Correction: ${mistake.correctedAnswer}'),
                      const Text(
                        'Self-mark your attempt; no automatic grading.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              if (!revealed)
                FilledButton(
                  onPressed: () {
                    if (answer.text.trim().isNotEmpty) {
                      update(() => revealed = true);
                    }
                  },
                  child: const Text('Reveal correction'),
                )
              else
                for (final success in [false, true])
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final updated = mistake.revisit(
                              at: _after(mistake),
                              answer: answer.text,
                              successful: success,
                            );
                            if (await _replace(mistake, updated) &&
                                dialog.mounted) {
                              Navigator.pop(dialog);
                            }
                          },
                    child: Text(
                      success ? 'I answered correctly' : 'Still needs practice',
                    ),
                  ),
            ],
          ),
        ),
      );
    } finally {
      answer.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final journal = _journal;
    Widget body;
    if (widget.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (widget.error != null) {
      body = Center(
        child: Text('Failed to load study journal: ${widget.error}'),
      );
    } else if (journal == null) {
      body = const Center(child: Text('Offline Study Mistake Journal'));
    } else {
      final entries = journal.mistakes
          .where(
            (m) =>
                m.resolved == _resolved &&
                (_subjectId == null || m.subjectId == _subjectId),
          )
          .toList();
      entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Unresolved: ${journal.unresolved.length} • Resolved: ${journal.resolvedCount}',
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('All subjects'),
                selected: _subjectId == null,
                onSelected: (_) => setState(() => _subjectId = null),
              ),
              for (final s in journal.subjects)
                FilterChip(
                  label: Text(s.name),
                  selected: _subjectId == s.id,
                  onSelected: (_) => setState(() => _subjectId = s.id),
                ),
            ],
          ),
          SwitchListTile(
            title: const Text('Show resolved'),
            value: _resolved,
            onChanged: (value) => setState(() => _resolved = value),
          ),
          if (journal.subjects.isEmpty)
            const Text('Create a subject to start your private journal.'),
          if (entries.isEmpty)
            Text(_resolved ? 'No resolved mistakes' : 'No unresolved mistakes'),
          for (final m in entries)
            Card(
              child: ExpansionTile(
                title: Text(m.sourceLocator),
                subtitle: Text('Causes: ${m.causes.join(', ')}'),
                childrenPadding: const EdgeInsets.all(12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.prompt != null) Text('Prompt: ${m.prompt}'),
                  Text('Your wrong answer: ${m.wrongAnswer}'),
                  if (m.resolved) Text('Correction: ${m.correctedAnswer}'),
                  for (final event in m.events)
                    Text(
                      '${event.at.toLocal()} • ${event.kind.name}'
                      '${event.answer == null ? '' : ' • ${event.answer}'}',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => _edit(m),
                        child: const Text('Edit'),
                      ),
                      if (m.resolved)
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => _replace(m, m.reopen(at: _after(m))),
                          child: const Text('Reopen'),
                        )
                      else
                        FilledButton(
                          onPressed: _saving ? null : () => _revisit(m),
                          child: const Text('Revisit'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mistake Loop')),
      body: body,
      bottomNavigationBar: journal == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : _newSubject,
                      child: const Text('New subject'),
                    ),
                    FilledButton(
                      onPressed: _saving || journal.subjects.isEmpty
                          ? null
                          : () => _edit(),
                      child: const Text('Record mistake'),
                    ),
                    OutlinedButton(
                      onPressed: _saving ? null : () => _export(csv: false),
                      child: const Text('Export JSON backup'),
                    ),
                    OutlinedButton(
                      onPressed: _saving ? null : () => _export(csv: true),
                      child: const Text('Export CSV summary'),
                    ),
                    OutlinedButton(
                      onPressed: _saving ? null : _import,
                      child: const Text('Import JSON backup'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
