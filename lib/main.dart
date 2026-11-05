import 'package:flutter/material.dart';
import 'package:mistake_loop/journal_store.dart';
import 'package:mistake_loop/mistake_journal.dart';

void main() {
  runApp(const MistakeLoopApp());
}

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initStore();
  }

  Future<void> _initStore() async {
    try {
      final store = widget.store ?? await openPrivateJournal();
      final journal = await store.load();
      if (!mounted) {
        await store.close();
        return;
      }
      setState(() {
        _store = store;
        _journal = journal;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    if (widget.store == null) {
      _store?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mistake Loop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: MistakeLoopHome(
        loading: _loading,
        error: _error,
        journal: _journal,
      ),
    );
  }
}

class MistakeLoopHome extends StatelessWidget {
  const MistakeLoopHome({
    super.key,
    this.loading = false,
    this.error,
    this.journal,
  });

  final bool loading;
  final Object? error;
  final MistakeJournal? journal;

  @override
  Widget build(BuildContext context) {
    final body = () {
      if (loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (error != null) {
        return Center(
          child: Text(
            'Failed to load study journal: $error',
            textAlign: TextAlign.center,
          ),
        );
      }
      final journal = this.journal;
      if (journal == null || journal.mistakes.isEmpty) {
        return const Center(child: Text('Offline Study Mistake Journal'));
      }
      return Center(
        child: Text(
          'Unresolved: ${journal.unresolved.length} • Resolved: ${journal.resolvedCount}',
        ),
      );
    }();

    return Scaffold(
      appBar: AppBar(title: const Text('Mistake Loop')),
      body: body,
    );
  }
}
