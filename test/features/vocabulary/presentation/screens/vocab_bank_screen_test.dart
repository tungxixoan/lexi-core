import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/core/widgets/filter_tile.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/topics_provider.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import 'package:lexi_core/features/vocabulary/presentation/screens/vocab_bank_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  @override
  UserSettingsState build() => UserSettingsState.defaults;
}

class _FakeVocabBankNotifier extends VocabBankNotifier {
  _FakeVocabBankNotifier(this._records);
  final List<VocabRecord> _records;
  @override
  Future<List<VocabRecord>> build() async => _records;
}

class _FakeTopicsNotifier extends TopicsNotifier {
  @override
  Future<List<Topic>> build() async => const [];
}

VocabRecord _record(
  String id, {
  String headword = 'serendipity',
  CEFRLevel cefrLevel = CEFRLevel.b1,
  DateTime? nextReviewAt,
}) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: id,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: 'sự tình cờ may mắn',
    examples: const [],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: Language.english,
    cefrLevel: cefrLevel,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
    nextReviewAt: nextReviewAt,
  );
}

Widget _buildScreen(List<VocabRecord> records) {
  final router = GoRouter(
    initialLocation: '/vocab',
    routes: [
      GoRoute(
          path: '/',
          builder: (ctx, state) => const Scaffold(body: Text('Lookup tab'))),
      GoRoute(path: '/vocab', builder: (ctx, state) => const VocabBankScreen()),
      GoRoute(
        path: '/vocab/:id',
        builder: (ctx, state) =>
            Scaffold(body: Text('Detail ${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(_FakeSettingsNotifier.new),
      vocabBankNotifierProvider
          .overrideWith(() => _FakeVocabBankNotifier(records)),
      topicsNotifierProvider.overrideWith(_FakeTopicsNotifier.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('empty state renders the Vietnamese empty copy', (tester) async {
    await tester.pumpWidget(_buildScreen(const []));
    await tester.pumpAndSettle();

    expect(find.text('Chưa lưu từ nào.'), findsOneWidget);
    expect(find.text('Tra một từ rồi bấm Lưu từ.'), findsOneWidget);
  });

  testWidgets('a seeded record renders as a BloomListRow with its headword',
      (tester) async {
    await tester
        .pumpWidget(_buildScreen([_record('v1', headword: 'ephemeral')]));
    await tester.pumpAndSettle();

    expect(find.byType(BloomListRow), findsOneWidget);
    expect(find.text('ephemeral'), findsOneWidget);
  });

  testWidgets('tapping a row navigates to /vocab/<id>', (tester) async {
    await tester
        .pumpWidget(_buildScreen([_record('abc123', headword: 'ephemeral')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BloomListRow));
    await tester.pumpAndSettle();

    expect(find.text('Detail abc123'), findsOneWidget);
  });

  testWidgets('the "Cần ôn hôm nay" chip narrows the list to due records',
      (tester) async {
    await tester.pumpWidget(_buildScreen([
      _record('due1', headword: 'duebound'),
      _record('notdue1', headword: 'laterword', nextReviewAt: DateTime(2999)),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(BloomListRow), findsNWidgets(2));
    expect(find.text('Cần ôn hôm nay (1)'), findsOneWidget);

    await tester.tap(find.text('Cần ôn hôm nay (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(BloomListRow), findsOneWidget);
    expect(find.text('duebound'), findsOneWidget);
    expect(find.text('laterword'), findsNothing);
  });

  testWidgets('selecting a CEFR level in the sheet narrows the list',
      (tester) async {
    await tester.pumpWidget(_buildScreen([
      _record('a', headword: 'basicword', cefrLevel: CEFRLevel.a1),
      _record('b', headword: 'hardword', cefrLevel: CEFRLevel.b1),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterTile, 'Cấp độ'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'B1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng (1)'));
    await tester.pumpAndSettle();

    expect(find.text('hardword'), findsOneWidget);
    expect(find.text('basicword'), findsNothing);
  });

  testWidgets('due chip and CEFR filter combine (AND)', (tester) async {
    await tester.pumpWidget(_buildScreen([
      _record('a', headword: 'duebasic', cefrLevel: CEFRLevel.a1),
      _record('b', headword: 'duehard', cefrLevel: CEFRLevel.b1),
      _record('c',
          headword: 'laterhard',
          cefrLevel: CEFRLevel.b1,
          nextReviewAt: DateTime(2999)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cần ôn hôm nay (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterTile, 'Cấp độ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'B1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng (1)'));
    await tester.pumpAndSettle();

    expect(find.text('duehard'), findsOneWidget);
    expect(find.text('duebasic'), findsNothing);
    expect(find.text('laterhard'), findsNothing);
  });
}
