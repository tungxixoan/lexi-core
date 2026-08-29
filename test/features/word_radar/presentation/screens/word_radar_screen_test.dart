import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/word_radar/data/sources/word_radar_source.dart';
import 'package:lexi_core/features/word_radar/presentation/screens/word_radar_screen.dart';

class _FakeGenerativeModelClient implements GenerativeModelClient {
  _FakeGenerativeModelClient(this._responseText);
  final String _responseText;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    return GenerateContentResponse(
      [Candidate(Content.text(_responseText), null, null, null, null)],
      null,
    );
  }
}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

VocabRecord _record(String headword, {String? meaning}) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: headword,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: meaning ?? 'meaning of $headword',
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
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async => null;

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id, {required Language language}) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async => false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async {
    for (final r in records) {
      if (r.headword == headword) return r;
    }
    return null;
  }

  @override
  Future<List<Topic>> getTopics() async => [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

Future<Widget> _buildScreen({
  required bool aiEnabled,
  required List<VocabRecord> vocabItems,
  WordRadarSource? source,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const WordRadarScreen()),
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice hub')),
      ),
      GoRoute(
        path: '/vocab/:id',
        builder: (ctx, state) => Scaffold(
          body: Text('Vocab detail ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(
          UserSettingsState.defaults.copyWith(aiEnabled: aiEnabled),
        ),
      ),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(vocabItems)),
      if (source != null) wordRadarSourceProvider.overrideWithValue(source),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the AI-disabled note after scanning with AI off', (tester) async {
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'It was pure serendipity.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bật AI trong Cài đặt'), findsOneWidget);
  });

  testWidgets('tapping a highlighted known word navigates to its detail screen',
      (tester) async {
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'It was pure serendipity.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('serendipity'));
    await tester.pumpAndSettle();

    expect(find.text('Vocab detail serendipity'), findsOneWidget);
  });

  testWidgets('tapping a suggestion card opens the save sheet', (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient(jsonEncode({
        'suggestions': [
          {
            'headword': 'ubiquitous',
            'ipa': '/juːˈbɪkwɪtəs/',
            'meaning': 'có mặt khắp nơi',
            'examples': <String>[],
            'suggestedTopics': <String>[],
          },
        ],
      })),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: const [],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Some text here.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsOneWidget);
    await tester.tap(find.text('ubiquitous'));
    await tester.pumpAndSettle();

    expect(find.text('Save "ubiquitous"'), findsOneWidget);
  });

  testWidgets('tapping the dismiss icon removes a suggestion from the list',
      (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient(jsonEncode({
        'suggestions': [
          {
            'headword': 'ubiquitous',
            'ipa': '/juːˈbɪkwɪtəs/',
            'meaning': 'có mặt khắp nơi',
            'examples': <String>[],
            'suggestedTopics': <String>[],
          },
        ],
      })),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: const [],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Some text here.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsNothing);
    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });

  testWidgets('Lưu tất cả saves every unsaved suggestion and shows checkmarks',
      (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient(jsonEncode({
        'suggestions': [
          {
            'headword': 'ubiquitous',
            'ipa': '/juːˈbɪkwɪtəs/',
            'meaning': 'có mặt khắp nơi',
            'examples': <String>[],
            'suggestedTopics': <String>[],
          },
          {
            'headword': 'resilient',
            'ipa': '/rɪˈzɪliənt/',
            'meaning': 'kiên cường',
            'examples': <String>[],
            'suggestedTopics': <String>[],
          },
        ],
      })),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: const [],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Some text here.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('Lưu tất cả'), findsOneWidget);
    await tester.tap(find.text('Lưu tất cả'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.text('Lưu tất cả'), findsNothing);
  });

  testWidgets('shows "Không có gợi ý mới" when AI returns no suggestions',
      (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient('{"suggestions":[]}'),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: const [],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Some text here.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });

  testWidgets('the Quét button is disabled while the input is empty', (tester) async {
    await tester.pumpWidget(await _buildScreen(aiEnabled: false, vocabItems: const []));
    await tester.pumpAndSettle();

    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Quét'));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows a CEFR level chip on a suggestion when the AI provides one',
      (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient(jsonEncode({
        'suggestions': [
          {
            'headword': 'ubiquitous',
            'ipa': '/juːˈbɪkwɪtəs/',
            'meaning': 'có mặt khắp nơi',
            'examples': <String>[],
            'suggestedTopics': <String>[],
            'cefrLevel': 'c1',
          },
        ],
      })),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: const [],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Some text here.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('C1'), findsOneWidget);
  });

  testWidgets('shows the AI translation with the known word\'s meaning highlighted',
      (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient(jsonEncode({
        'translation': 'Con mèo ngồi trên tấm thảm.',
        'suggestions': <Map<String, dynamic>>[],
      })),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: [_record('cat', meaning: 'con mèo')],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'The cat sat on the mat.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('Bản dịch'), findsOneWidget);
    expect(find.textContaining('Con mèo ngồi trên tấm thảm.'), findsOneWidget);
  });

  testWidgets('does not show a translation section when the AI returns an empty translation',
      (tester) async {
    final source = WordRadarSource.withModel(
      _FakeGenerativeModelClient(jsonEncode({
        'translation': '',
        'suggestions': <Map<String, dynamic>>[],
      })),
    );
    await tester.pumpWidget(await _buildScreen(
      aiEnabled: true,
      vocabItems: const [],
      source: source,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Some text here.');
    await tester.pump();
    await tester.tap(find.text('Quét'));
    await tester.pumpAndSettle();

    expect(find.text('Bản dịch'), findsNothing);
  });
}
