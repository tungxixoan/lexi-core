import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ListeningHomeScreen extends StatelessWidget {
  const ListeningHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện nghe'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Nghe chép'),
              subtitle: const Text(
                'Nghe một câu và gõ lại chính xác những gì bạn nghe được.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/listening/dictation'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Nghe hiểu'),
              subtitle: const Text(
                'Nghe hội thoại/bài nói và trả lời câu hỏi trắc nghiệm kiểu TOEIC.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/listening/comprehension'),
            ),
          ),
        ],
      ),
    );
  }
}
