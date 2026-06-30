import 'package:flutter/material.dart';

class VocabDetailScreen extends StatelessWidget {
  const VocabDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocab Detail')),
      body: Center(child: Text('Detail for: $id — coming in Task 10')),
    );
  }
}
