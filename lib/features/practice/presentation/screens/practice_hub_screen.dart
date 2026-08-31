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
          _HubCard(
            icon: Icons.school_outlined,
            title: 'Từ vựng cách khoảng',
            subtitle: 'Ôn từ vựng theo lịch SM-2, với bài tập AI sinh tự động.',
            selected: true,
            onTap: () => context.go('/practice/vocab'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.menu_book_outlined,
            title: 'Luyện đọc',
            subtitle: 'Đọc & gõ song ngữ, và luyện đề TOEIC Part 5/6/7.',
            onTap: () => context.go('/reading'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.headphones_outlined,
            title: 'Luyện nghe',
            subtitle: 'Nghe chép và nghe hiểu kiểu TOEIC.',
            onTap: () => context.go('/listening'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.bar_chart_outlined,
            title: 'Tiến độ học tập',
            subtitle: 'Chuỗi ngày học, từ đến hạn, phân bố cấp độ CEFR.',
            onTap: () => context.push('/practice/progress'),
          ),
          const SizedBox(height: 12),
          _HubCard(
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

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return BloomCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.surface : c.sageBg,
              borderRadius: BorderRadius.circular(BloomRadii.md),
            ),
            child: Icon(icon, size: 20, color: selected ? c.accent : c.sage),
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
