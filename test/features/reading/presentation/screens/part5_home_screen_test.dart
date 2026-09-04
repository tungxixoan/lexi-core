import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/saved_exercises_service.dart';
import 'package:lexi_core/core/widgets/ai_key_missing_card.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/practice/domain/entities/saved_exercise.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';
import 'package:lexi_core/features/reading/presentation/screens/part5_home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

class _FakeSavedExercisesService extends SavedExercisesService {
  _FakeSavedExercisesService({this.random})
      : super(firestore: FakeFirebaseFirestore(), currentUid: () => null);
  final ({String id, Map<String, dynamic> passageJson})? random;

  @override
  Future<({String id, Map<String, dynamic> passageJson})?> getRandom({
    required SavedExerciseType type,
    required Language targetLanguage,
    required Map<String, dynamic> filters,
    String? excludeId,
  }) async =>
      random;
}

Part5Set _set() => Part5Set(
      id: 'p1',
      questions: const [
        Part5Question(
          sentenceWithBlank: 'The report is ___ ready.',
          options: ['almost', 'nearby', 'quickly', 'hardly'],
          correctIndex: 0,
          explanation: 'x',
        ),
      ],
      volumes: const {},
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime.utc(2026, 1, 1),
    );

UserSettingsState _settings({bool aiAvailable = true}) =>
    UserSettingsState.defaults.copyWith(
      providerConfigs: {
        AiProvider.gemini: ProviderConfig(
          apiKeyCiphertext: aiAvailable ? 'ck' : null,
          model: 'gemini-2.5-flash',
        ),
      },
    );

Widget _buildHome({
  required UserSettingsState settings,
  SavedExercisesService? savedService,
}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part5HomeScreen()),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const Scaffold(body: Text('Settings stub')),
      ),
      GoRoute(
        path: '/reading/part5/session',
        builder: (ctx, state) => const Scaffold(body: Text('session stub')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider
          .overrideWith(() => _FakeSettingsNotifier(settings)),
      if (savedService != null)
        savedExercisesServiceProvider.overrideWithValue(savedService),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the missing-API-key card when no key is set',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(aiAvailable: false),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AiKeyMissingCard), findsOneWidget);
    expect(find.textContaining('Chưa có API key cho nhà cung cấp AI'),
        findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI is enabled (no vocab gate)',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });

  testWidgets('shows language, context and difficulty pickers', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Độ khó'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget); // no volumes selected yet
  });

  testWidgets('shows "Lấy bài có sẵn" alongside "Tạo bài luyện"',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      savedService: _FakeSavedExercisesService(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
    expect(find.text('Lấy bài có sẵn'), findsOneWidget);
  });

  testWidgets('reuse navigates to the part5 session on a match', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      savedService: _FakeSavedExercisesService(
        random: (id: 'p1', passageJson: _set().toJson()),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lấy bài có sẵn'));
    await tester.pumpAndSettle();
    expect(find.text('session stub'), findsOneWidget);
  });

  testWidgets('reuse shows a snackbar when nothing matches the filters',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      savedService: _FakeSavedExercisesService(random: null),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lấy bài có sẵn'));
    await tester.pump();
    expect(find.text('Chưa có bài đã lưu khớp bộ lọc.'), findsOneWidget);
  });
}
