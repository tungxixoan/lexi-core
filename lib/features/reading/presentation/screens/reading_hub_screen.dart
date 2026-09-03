import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';

class ReadingHubScreen extends StatelessWidget {
  const ReadingHubScreen({super.key});

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
            onTap: () => context.go('/reading/bilingual'),
          ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.rule_outlined,
            title: 'Part 5 — Điền câu',
            subtitle: '15 câu điền từ/ngữ pháp trắc nghiệm kiểu TOEIC Part 5.',
            onTap: () => context.go('/reading/part5'),
          ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.article_outlined,
            title: 'Part 6 — Điền đoạn văn',
            subtitle:
                '3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống, kiểu TOEIC Part 6.',
            onTap: () => context.go('/reading/part6'),
          ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.dynamic_feed_outlined,
            title: 'Part 7 — Đọc hiểu',
            subtitle:
                '2 đoạn văn đơn + 1 bộ đoạn đôi, kèm câu hỏi trắc nghiệm kiểu TOEIC Part 7.',
            onTap: () => context.go('/reading/part7'),
          ),
        ],
      ),
    );
  }
}
