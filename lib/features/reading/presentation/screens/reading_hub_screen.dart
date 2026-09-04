import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../widgets/part5_options.dart';
import '../widgets/part6_options.dart';
import '../widgets/part7_options.dart';
import '../widgets/reading_bilingual_options.dart';

class ReadingHubScreen extends StatefulWidget {
  const ReadingHubScreen({super.key});

  @override
  State<ReadingHubScreen> createState() => _ReadingHubScreenState();
}

class _ReadingHubScreenState extends State<ReadingHubScreen> {
  /// One of `'bilingual' | 'part5' | 'part6' | 'part7'`, or null when every
  /// type card is collapsed.
  String? _expanded;

  void _toggle(String type) {
    setState(() => _expanded = _expanded == type ? null : type);
  }

  @override
  Widget build(BuildContext context) {
    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Luyện đọc',
        leading: BloomIconButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: () => context.go('/practice'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BloomNavCard(
            icon: Icons.menu_book_outlined,
            title: 'Đọc & gõ',
            subtitle: 'Đọc đoạn văn song ngữ dùng từ vựng của bạn và luyện gõ.',
            selected: _expanded == 'bilingual',
            onTap: () => _toggle('bilingual'),
          ),
          if (_expanded == 'bilingual')
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: ReadingBilingualOptions(),
            ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.rule_outlined,
            title: 'Part 5 — Điền câu',
            subtitle: '15 câu điền từ/ngữ pháp trắc nghiệm kiểu TOEIC Part 5.',
            selected: _expanded == 'part5',
            onTap: () => _toggle('part5'),
          ),
          if (_expanded == 'part5')
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Part5Options(),
            ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.article_outlined,
            title: 'Part 6 — Điền đoạn văn',
            subtitle:
                '3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống, kiểu TOEIC Part 6.',
            selected: _expanded == 'part6',
            onTap: () => _toggle('part6'),
          ),
          if (_expanded == 'part6')
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Part6Options(),
            ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.dynamic_feed_outlined,
            title: 'Part 7 — Đọc hiểu',
            subtitle:
                '2 đoạn văn đơn + 1 bộ đoạn đôi, kèm câu hỏi trắc nghiệm kiểu TOEIC Part 7.',
            selected: _expanded == 'part7',
            onTap: () => _toggle('part7'),
          ),
          if (_expanded == 'part7')
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Part7Options(),
            ),
        ],
      ),
    );
  }
}
