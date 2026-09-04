import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../widgets/reading_bilingual_options.dart';

class ReadingHomeScreen extends StatelessWidget {
  const ReadingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BloomScaffold(
        appBar: BloomAppBar(
          title: 'Luyện đọc & gõ',
          leading: BloomIconButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: () => context.go('/reading'),
          ),
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ReadingBilingualOptions(),
        ),
      );
}
