import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../widgets/part5_options.dart';

class Part5HomeScreen extends StatelessWidget {
  const Part5HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BloomScaffold(
        appBar: BloomAppBar(
          title: 'Part 5 — Điền câu',
          leading: BloomIconButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: () => context.go('/reading'),
          ),
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Part5Options(),
        ),
      );
}
