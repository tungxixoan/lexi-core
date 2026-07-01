import 'package:flutter/material.dart';
import '../../domain/entities/exercise_result.dart';

class SessionResultScreen extends StatelessWidget {
  const SessionResultScreen({super.key, required this.result});
  final SessionResult result;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Result — coming soon')));
}
