import 'package:flutter/material.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionResultScreen extends StatelessWidget {
  const ComprehensionResultScreen({super.key, required this.result});
  final ComprehensionSessionResult result;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Result — coming soon')));
}
