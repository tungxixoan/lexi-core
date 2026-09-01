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
          _ReadingCard(
            icon: Icons.menu_book_outlined,
            title: 'Đọc & gõ',
            subtitle:
                'Đọc đoạn văn song ngữ dùng từ vựng của bạn và luyện gõ.',
            onTap: () => context.go('/reading/bilingual'),
          ),
          const SizedBox(height: 12),
          _ReadingCard(
            icon: Icons.rule_outlined,
            title: 'Part 5 — Điền câu',
            subtitle:
                '15 câu điền từ/ngữ pháp trắc nghiệm kiểu TOEIC Part 5.',
            onTap: () => context.go('/reading/part5'),
          ),
          const SizedBox(height: 12),
          _ReadingCard(
            icon: Icons.article_outlined,
            title: 'Part 6 — Điền đoạn văn',
            subtitle:
                '3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống, kiểu TOEIC Part 6.',
            onTap: () => context.go('/reading/part6'),
          ),
          const SizedBox(height: 12),
          _ReadingCard(
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

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return BloomCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.sageBg,
              borderRadius: BorderRadius.circular(BloomRadii.md),
            ),
            child: Icon(icon, size: 20, color: c.sage),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.inkFaint),
        ],
      ),
    );
  }
}
