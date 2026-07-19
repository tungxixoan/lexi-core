# Plan 9 — Task 05: DictationHomeScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 9 Task 04 (provider, DI, routes wired; stub `dictation_home_screen.dart` exists)

## Global Constraints
(see `plan9-global-constraints.md`)

## What This Task Delivers
Replace the stub `DictationHomeScreen` with a full implementation: Ngôn ngữ / Chủ đề (Topic tag, filters the Vocab Bank pool — **not** AppContext) / Cấp độ filter pickers (mirroring `ReadingHomeScreen`'s `FilterTile` pattern exactly), two error states (AI disabled; fewer than 2 eligible words), and a "Tạo bài luyện" button that picks 2 words (due-for-review first) and starts generation.

## Files
- Modify: `lib/features/listening/presentation/screens/dictation_home_screen.dart`
- Create: `test/features/listening/presentation/screens/dictation_home_screen_test.dart`

## Interfaces
- Consumes:
  - `dictationPracticeNotifierProvider` — to trigger generation + watch loading/error state
  - `getVocabListUseCaseProvider` — to fetch words filtered by language/level
  - `userSettingsNotifierProvider` — for `aiEnabled`, `targetLanguage`, `targetCefrLevel`, `activeContext`
  - `topicsNotifierProvider` — for the Topic-tag picker options
  - `FilterTile`, `showSingleSelectSheet`, `showMultiSelectSheet` (existing, `lib/core/widgets/`)
- Produces: fully functional `DictationHomeScreen`

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/listening/presentation/screens/dictation_home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/dictation_home_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabRecord _record(int i) {
  final now = DateTime(2026, 1, i + 1);
  return VocabRecord(
    id: 'word-$i',
    headword: 'word$i',
    inputType: InputType.word,
    ipa: '',
    meaning: 'meaning $i',
    examples: const [],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: Language.english,
    cefrLevel: CEFRLevel.a1,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async =>
      null;

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

Widget _buildHome({
  required UserSettingsState settings,
  required List<VocabRecord> vocabItems,
}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const DictationHomeScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(vocabItems)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows AI disabled message when aiEnabled is false', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: false),
      vocabItems: List.generate(5, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tính năng này yêu cầu AI'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows low vocab message when fewer than 2 words', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(1, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 từ'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI enabled and >= 2 vocab words', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(2, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });

  testWidgets('shows language, topic and level pickers', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(2, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Cấp độ'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/dictation_home_screen_test.dart
```

Expected: FAIL — current stub doesn't implement these states.

- [ ] **Step 3: Replace dictation_home_screen.dart**

Replace `lib/features/listening/presentation/screens/dictation_home_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/topic.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../providers/dictation_practice_provider.dart';

class DictationHomeScreen extends ConsumerStatefulWidget {
  const DictationHomeScreen({super.key});

  @override
  ConsumerState<DictationHomeScreen> createState() =>
      _DictationHomeScreenState();
}

class _DictationHomeScreenState extends ConsumerState<DictationHomeScreen> {
  static const _minVocabWords = 2;

  late Language _language;
  final Set<String> _topicIds = {};
  CEFRLevel? _level;

  List<VocabRecord>? _matchingWords; // null while loading

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsNotifierProvider);
    _language = settings.targetLanguage;
    _level = settings.targetCefrLevel;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _matchingWords = null);
    final words = await ref.read(getVocabListUseCaseProvider).execute(
          language: _language,
          maxCefrLevel: _level,
        );
    var filtered = words;
    if (_topicIds.isNotEmpty) {
      filtered =
          filtered.where((r) => r.topicIds.any(_topicIds.contains)).toList();
    }
    if (mounted) setState(() => _matchingWords = filtered);
  }

  Future<void> _pickLanguage() async {
    final result = await showSingleSelectSheet<Language>(
      context: context,
      title: 'Ngôn ngữ',
      options: Language.values
          .map((l) => SelectOption(value: l, label: l.label))
          .toList(),
      selected: _language,
    );
    if (result != null) {
      setState(() => _language = result.value);
      _reload();
    }
  }

  Future<void> _pickTopics(List<Topic> topics) async {
    final result = await showMultiSelectSheet<String>(
      context: context,
      title: 'Chủ đề',
      options: topics
          .map((t) => SelectOption(value: t.id, label: t.name, emoji: t.emoji))
          .toList(),
      initialSelected: _topicIds,
    );
    if (result != null) {
      setState(() {
        _topicIds
          ..clear()
          ..addAll(result);
      });
      _reload();
    }
  }

  Future<void> _pickLevel() async {
    final result = await showSingleSelectSheet<CEFRLevel?>(
      context: context,
      title: 'Cấp độ',
      options: [
        ...CEFRLevel.values.map((l) => SelectOption(value: l, label: l.label)),
        const SelectOption<CEFRLevel?>(value: null, label: 'Tất cả'),
      ],
      selected: _level,
    );
    if (result != null) {
      setState(() => _level = result.value);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final sessionAsync = ref.watch(dictationPracticeNotifierProvider);
    final theme = Theme.of(context);
    final words = _matchingWords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nghe chép'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'AI tạo một câu từ Vocab Bank của bạn. Nghe và gõ lại chính xác '
                'những gì bạn nghe được — nghe lại càng nhiều lần, điểm càng thấp.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),

            FilterTile(
              icon: Icons.language_outlined,
              label: 'Ngôn ngữ',
              value: _language.label,
              onTap: _pickLanguage,
            ),
            topicsAsync.when(
              data: (topics) => FilterTile(
                icon: Icons.sell_outlined,
                label: 'Chủ đề',
                value: _topicIds.isEmpty
                    ? 'Tất cả'
                    : '${_topicIds.length} đã chọn',
                onTap: () => _pickTopics(topics),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(e.toString()),
            ),
            FilterTile(
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _level?.label ?? 'Tất cả',
              onTap: _pickLevel,
            ),
            const SizedBox(height: 16),

            if (!settings.aiEnabled)
              _ErrorCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else if (words == null)
              const Center(child: CircularProgressIndicator())
            else if (words.length < _minVocabWords)
              _ErrorCard(
                message:
                    'Hãy lưu ít nhất 2 từ khớp với bộ lọc trên vào Vocab Bank. '
                    'Hiện có ${words.length} từ.',
              )
            else
              sessionAsync.when(
                data: (_) => FilledButton.icon(
                  onPressed: () => _generate(context, ref, words),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Tạo bài luyện'),
                ),
                loading: () => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang tạo bài...'),
                  ],
                ),
                error: (e, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lỗi tạo bài: $e',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _generate(context, ref, words),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref,
    List<VocabRecord> eligibleWords,
  ) async {
    final settings = ref.read(userSettingsNotifierProvider);

    final now = DateTime.now();
    bool isDue(VocabRecord r) =>
        r.nextReviewAt == null || r.nextReviewAt!.isBefore(now);
    final dueWords = eligibleWords.where(isDue).toList()..shuffle();
    final notDueWords = eligibleWords.where((r) => !isDue(r)).toList()..shuffle();
    final prioritized = [...dueWords, ...notDueWords];
    final words = prioritized.take(2).toList();

    await ref.read(dictationPracticeNotifierProvider.notifier).generate(
          words: words,
          level: _level ?? settings.targetCefrLevel ?? CEFRLevel.b1,
          context: settings.activeContext,
          targetLanguage: _language,
        );

    if (context.mounted) {
      final session = ref.read(dictationPracticeNotifierProvider).valueOrNull;
      if (session != null && !session.isComplete) {
        context.go('/listening/dictation/session');
      }
    }
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/listening/presentation/screens/dictation_home_screen_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/listening/presentation/screens/dictation_home_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/listening/presentation/screens/dictation_home_screen.dart \
        test/features/listening/presentation/screens/dictation_home_screen_test.dart
git commit -m "feat(plan9): implement DictationHomeScreen with filters + error states"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
