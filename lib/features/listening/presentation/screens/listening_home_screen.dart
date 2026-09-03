import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';

class ListeningHomeScreen extends StatelessWidget {
  const ListeningHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Luyện nghe',
        leading: BloomIconButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: () => context.go('/practice'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ListeningCard(
            icon: Icons.edit_note_outlined,
            title: 'Nghe chép',
            subtitle:
                'Nghe một câu và gõ lại chính xác những gì bạn nghe được.',
            onTap: () => context.go('/listening/dictation'),
          ),
          const SizedBox(height: 12),
          _ListeningCard(
            icon: Icons.quiz_outlined,
            title: 'Nghe hiểu',
            subtitle:
                'Nghe hội thoại/bài nói và trả lời câu hỏi trắc nghiệm kiểu TOEIC.',
            onTap: () => context.go('/listening/comprehension'),
          ),
        ],
      ),
    );
  }
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({
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
