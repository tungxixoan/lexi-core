import 'package:flutter/material.dart';
import '../providers/dictation_practice_provider.dart';

class DictationResultScreen extends StatelessWidget {
  const DictationResultScreen({super.key, required this.result});
  final DictationSessionResult result;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Result — coming soon')));
}
