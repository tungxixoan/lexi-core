import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../widgets/part7_options.dart';

class Part7HomeScreen extends StatelessWidget {
  const Part7HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BloomScaffold(
        appBar: BloomAppBar(
          title: 'Part 7 — Đọc hiểu',
          leading: BloomIconButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: () => context.go('/reading'),
          ),
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Part7Options(),
        ),
      );
}
