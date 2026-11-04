import 'package:flutter/material.dart';

void main() {
  runApp(const MistakeLoopApp());
}

class MistakeLoopApp extends StatelessWidget {
  const MistakeLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mistake Loop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MistakeLoopHome(),
    );
  }
}

class MistakeLoopHome extends StatelessWidget {
  const MistakeLoopHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mistake Loop')),
      body: const Center(child: Text('Offline Study Mistake Journal')),
    );
  }
}
