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
          BloomNavCard(
            icon: Icons.edit_note_outlined,
            title: 'Nghe chép',
            subtitle:
                'Nghe một câu và gõ lại chính xác những gì bạn nghe được.',
            onTap: () => context.go('/listening/dictation'),
          ),
          const SizedBox(height: 12),
          BloomNavCard(
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
