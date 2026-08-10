import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReadingHubScreen extends StatelessWidget {
  const ReadingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện đọc'),
        leading: BackButton(onPressed: () => context.go('/practice')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Đọc & gõ'),
              subtitle: const Text(
                'Đọc đoạn văn song ngữ dùng từ vựng của bạn và luyện gõ.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading/bilingual'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.rule_outlined),
              title: const Text('Part 5 — Điền câu'),
              subtitle: const Text(
                '15 câu điền từ/ngữ pháp trắc nghiệm kiểu TOEIC Part 5.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading/part5'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Part 6 — Điền đoạn văn'),
              subtitle: const Text(
                '3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống, kiểu TOEIC Part 6.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading/part6'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dynamic_feed_outlined),
              title: const Text('Part 7 — Đọc hiểu'),
              subtitle: const Text(
                '2 đoạn văn đơn + 1 bộ đoạn đôi, kèm câu hỏi trắc nghiệm kiểu TOEIC Part 7.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading/part7'),
            ),
          ),
        ],
      ),
    );
  }
}
