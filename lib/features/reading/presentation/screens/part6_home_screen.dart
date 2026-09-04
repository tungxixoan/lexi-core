import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../widgets/part6_options.dart';

class Part6HomeScreen extends StatelessWidget {
  const Part6HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BloomScaffold(
        appBar: BloomAppBar(
          title: 'Part 6 — Điền đoạn văn',
          leading: BloomIconButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: () => context.go('/reading'),
          ),
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Part6Options(),
        ),
      );
}
