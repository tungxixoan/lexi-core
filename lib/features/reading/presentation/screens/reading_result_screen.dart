import 'package:flutter/material.dart';
import '../providers/reading_practice_provider.dart';

class ReadingResultScreen extends StatelessWidget {
  const ReadingResultScreen({super.key, required this.result});
  final ReadingSessionResult result;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Result — coming soon')));
}
