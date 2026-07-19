import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/dictation_practice_provider.dart';

class DictationSessionScreen extends ConsumerStatefulWidget {
  const DictationSessionScreen({super.key});

  @override
  ConsumerState<DictationSessionScreen> createState() =>
      _DictationSessionScreenState();
}

class _DictationSessionScreenState extends ConsumerState<DictationSessionScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DictationSessionState?>>(
      dictationPracticeNotifierProvider,
      (prev, next) {
        final session = next.valueOrNull;
        if (session == null) return;

        if (session.isComplete) {
          final result = DictationSessionResult(
            item: session.item,
            typed: session.typedText,
            replayCount: session.replayCount,
            duration: DateTime.now().difference(session.startedAt),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/listening/dictation/session/result', extra: result);
            }
          });
        }
      },
    );

    final sessionAsync = ref.watch(dictationPracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/listening/dictation');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        // Safety guard: navigation to the result route is already scheduled
        // via ref.listen above once isComplete flips to true.
        if (session.isComplete) {
          return const Scaffold(body: SizedBox.shrink());
        }
        return _SessionScaffold(session: session, ctrl: _ctrl);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({required this.session, required this.ctrl});
  final DictationSessionState session;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dictationPracticeNotifierProvider.notifier);
    final canSubmit = session.hasPlayedOnce && session.typedText.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Nghe chép'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: FilledButton.icon(
                onPressed: notifier.play,
                icon: Icon(session.hasPlayedOnce ? Icons.replay : Icons.play_arrow),
                label: Text(
                  session.hasPlayedOnce
                      ? 'Nghe lại (${session.replayCount})'
                      : 'Phát',
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: ctrl,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Gõ lại những gì bạn nghe được...',
              ),
              onChanged: notifier.updateTypedText,
            ),
            const Spacer(),
            FilledButton(
              onPressed: canSubmit ? notifier.submit : null,
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      ),
    );
  }
}
