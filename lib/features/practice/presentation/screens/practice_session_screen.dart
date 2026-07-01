import 'package:flutter/material.dart';
import '../../domain/entities/exercise_result.dart';

class PracticeSessionScreen extends StatelessWidget {
  const PracticeSessionScreen({super.key, required this.config});
  final SessionConfig config;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Session — coming soon')));
}
