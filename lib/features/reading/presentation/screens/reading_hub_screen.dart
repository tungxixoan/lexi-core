import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../providers/part5_practice_provider.dart';
import '../providers/part6_practice_provider.dart';
import '../providers/part7_practice_provider.dart';
import '../providers/reading_practice_provider.dart';
import '../widgets/part5_options.dart';
import '../widgets/part6_options.dart';
import '../widgets/part7_options.dart';
import '../widgets/reading_bilingual_options.dart';

class ReadingHubScreen extends ConsumerStatefulWidget {
  const ReadingHubScreen({super.key});

  @override
  ConsumerState<ReadingHubScreen> createState() => _ReadingHubScreenState();
}

class _ReadingHubScreenState extends ConsumerState<ReadingHubScreen> {
  /// One of `'bilingual' | 'part5' | 'part6' | 'part7'`, or null when every
  /// type card is collapsed.
  String? _expanded;

  /// True while the currently-expanded type's practice session is generating.
  /// The inline `*Options` is the sole listener of its `autoDispose` notifier,
  /// so collapsing/switching mid-generate would drop the in-flight AI result.
  bool _expandedIsLoading() {
    switch (_expanded) {
      case 'bilingual':
        return ref.read(readingPracticeNotifierProvider).isLoading;
      case 'part5':
        return ref.read(part5PracticeNotifierProvider).isLoading;
      case 'part6':
        return ref.read(part6PracticeNotifierProvider).isLoading;
      case 'part7':
        return ref.read(part7PracticeNotifierProvider).isLoading;
      default:
        return false;
    }
  }

  void _toggle(String type) {
    if (_expanded != null && _expandedIsLoading()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tạo bài — vui lòng đợi.')),
      );
      return;
    }
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
