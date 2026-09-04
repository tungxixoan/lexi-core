import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../providers/dictation_practice_provider.dart';
import '../providers/listening_comprehension_provider.dart';
import '../widgets/comprehension_options.dart';
import '../widgets/dictation_options.dart';

class ListeningHomeScreen extends ConsumerStatefulWidget {
  const ListeningHomeScreen({super.key});

  @override
  ConsumerState<ListeningHomeScreen> createState() =>
      _ListeningHomeScreenState();
}

class _ListeningHomeScreenState extends ConsumerState<ListeningHomeScreen> {
  /// One of `'dictation' | 'comprehension'`, or null when every type card is
  /// collapsed.
  String? _expanded;

  /// True while the currently-expanded type's practice session is generating.
  /// The inline `*Options` is the sole listener of its `autoDispose` notifier,
  /// so collapsing/switching mid-generate would drop the in-flight AI result.
  bool _expandedIsLoading() {
    switch (_expanded) {
      case 'dictation':
        return ref.read(dictationPracticeNotifierProvider).isLoading;
      case 'comprehension':
        return ref.read(listeningComprehensionNotifierProvider).isLoading;
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
            selected: _expanded == 'dictation',
            onTap: () => _toggle('dictation'),
          ),
          if (_expanded == 'dictation')
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: DictationOptions(),
            ),
          const SizedBox(height: 12),
          BloomNavCard(
            icon: Icons.quiz_outlined,
            title: 'Nghe hiểu',
            subtitle:
                'Nghe hội thoại/bài nói và trả lời câu hỏi trắc nghiệm kiểu TOEIC.',
            selected: _expanded == 'comprehension',
            onTap: () => _toggle('comprehension'),
          ),
          if (_expanded == 'comprehension')
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: ComprehensionOptions(),
            ),
        ],
      ),
    );
  }
}
