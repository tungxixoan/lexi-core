import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện tập'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Từ vựng cách khoảng'),
              subtitle: const Text(
                'Ôn từ vựng theo lịch SM-2, với bài tập AI sinh tự động.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/practice/vocab'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Đọc & gõ'),
              subtitle: const Text(
                'Đọc đoạn văn song ngữ dùng từ vựng của bạn và luyện gõ.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reading'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.headphones_outlined),
              title: const Text('Luyện nghe'),
              subtitle: const Text(
                'Nghe chép và nghe hiểu kiểu TOEIC.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/listening'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Tiến độ học tập'),
              subtitle: const Text(
                'Chuỗi ngày học, từ đến hạn, phân bố cấp độ CEFR.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/practice/progress'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.radar_outlined),
              title: const Text('Quét từ vựng'),
              subtitle: const Text(
                'Dán văn bản bất kỳ để tìm từ đã học và gợi ý từ mới đáng học.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/practice/radar'),
            ),
          ),
        ],
      ),
    );
  }
}
