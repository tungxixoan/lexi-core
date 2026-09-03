import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BloomScaffold(
      appBar: const BloomAppBar(title: 'Luyện tập'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BloomNavCard(
            icon: Icons.school_outlined,
            title: 'Từ vựng cách khoảng',
            subtitle: 'Ôn từ vựng theo lịch SM-2, với bài tập AI sinh tự động.',
            selected: true,
            onTap: () => context.go('/practice/vocab'),
          ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.menu_book_outlined,
            title: 'Luyện đọc',
            subtitle: 'Đọc & gõ song ngữ, và luyện đề TOEIC Part 5/6/7.',
            onTap: () => context.go('/reading'),
          ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.headphones_outlined,
            title: 'Luyện nghe',
            subtitle: 'Nghe chép và nghe hiểu kiểu TOEIC.',
            onTap: () => context.go('/listening'),
          ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.bar_chart_outlined,
            title: 'Tiến độ học tập',
            subtitle: 'Chuỗi ngày học, từ đến hạn, phân bố cấp độ CEFR.',
            onTap: () => context.push('/practice/progress'),
          ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.radar_outlined,
            title: 'Quét từ vựng',
            subtitle:
                'Dán văn bản bất kỳ để tìm từ đã học và gợi ý từ mới đáng học.',
            onTap: () => context.go('/practice/radar'),
          ),
        ],
      ),
    );
  }
}
