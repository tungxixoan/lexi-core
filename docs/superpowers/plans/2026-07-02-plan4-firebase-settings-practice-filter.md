# LexiCore Plan 4 — Firebase Sync + Settings Screen + Practice Level Filter

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist user settings to disk, add a 4th Settings tab with Google Sign-In and Firestore cloud sync for VocabBank + Topics, and add a CEFR level filter to the Practice screen.

**Architecture:** Three slices built in order: (1) SharedPreferences settings persistence, (2) CEFR filter through the repository → use case → Practice screen, (3) Firebase Auth + Firestore bidirectional sync as an opt-in infrastructure layer over existing Hive storage.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod 2.x + riverpod_annotation, GoRouter, Hive (existing), SharedPreferences, Firebase Core + Auth + Firestore, Google Sign-In, mocktail (tests)

## Global Constraints

- Flutter SDK >=3.22.0, Dart >=3.4.0, iOS + Android only
- Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- `ref.read()` in async methods; `ref.watch()` only in `build()`
- GoRouter only — no `Navigator.push` for screen transitions
- **NEVER store `geminiApiKey` in Firestore** — local (SharedPreferences) only
- Firebase sign-in is entirely opt-in — all features work without it
- Offline-first: Hive is source of truth; Firestore is a mirror
- Firestore writes are best-effort — log failures, never crash the app
- Unit tests use `mocktail`
- After any `@riverpod` annotation change run: `dart run build_runner build --delete-conflicting-outputs`

---

## Existing codebase reference

```
lib/main.dart                 — existing: Hive.initFlutter(), openBox×2, ProviderScope
lib/core/di/app_providers.dart — existing providers (vocabRepository, useCase×many, etc.)
lib/core/router/app_router.dart — ShellRoute with 3 routes: /, /vocab, /practice
lib/core/widgets/app_shell.dart — 3-tab NavigationBar
lib/features/dictionary/domain/entities/user_settings_state.dart — UserSettingsState
lib/features/dictionary/presentation/providers/user_settings_provider.dart — in-memory Notifier
lib/features/vocabulary/domain/repositories/vocab_repository.dart — VocabRepository interface
lib/features/vocabulary/data/repositories/vocab_repository_impl.dart — Hive impl
lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart — getAll(topicId, inputType, language)
lib/features/practice/presentation/screens/practice_home_screen.dart — ConsumerStatefulWidget
```

```dart
// VocabRecord already has toJson() / fromJson() — use directly for Firestore
// CEFRLevel enum: a1(0), a2(1), b1(2), b2(3), c1(4), c2(5) — compare by .index
// Language enum: english, chinese, korean, japanese — each has .label
// AppContext enum: general, business, technology, etc.
```

---

### Task 01: Package setup + Firebase init + SharedPreferences init

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart` (add `sharedPreferencesProvider`)
- Modify: `.gitignore`

**No tests** — configuration-only task.

**Interfaces produced:**
```dart
// In user_settings_provider.dart (new provider at top of file):
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError('overridden in main.dart');
// sharedPreferencesProvider — used by UserSettingsNotifier (Task 02) and SyncService (Task 07)
```

- [ ] **Step 1: Add packages to pubspec.yaml**

```yaml
# Add under dependencies: (after uuid: ^4.5.1)
  shared_preferences: ^2.3.0
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  google_sign_in: ^6.0.0
```

- [ ] **Step 2: Run pub get**

```
flutter pub get
```

Expected: packages resolved, no conflicts.

- [ ] **Step 3: Set up Firebase project (manual — do once)**

Install FlutterFire CLI if not already installed:
```
dart pub global activate flutterfire_cli
```

Run from the project root (requires Firebase CLI logged in):
```
flutterfire configure
```

Select your Firebase project (create one at console.firebase.google.com if needed). This generates:
- `lib/firebase_options.dart` — auto-generated, commit this file
- `android/app/google-services.json` — do NOT commit (contains secrets)
- `ios/Runner/GoogleService-Info.plist` — do NOT commit (contains secrets)

Enable **Google Sign-In** in Firebase Console → Authentication → Sign-in method.

- [ ] **Step 4: Add Firebase config files to .gitignore**

Open `.gitignore` and add:
```
# Firebase config (contains secrets)
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

- [ ] **Step 5: Add sharedPreferencesProvider to user_settings_provider.dart**

Open `lib/features/dictionary/presentation/providers/user_settings_provider.dart` and add at the top (before `UserSettingsNotifier`):

```dart
import 'package:shared_preferences/shared_preferences.dart';

// Overridden in main.dart with the real SharedPreferences instance.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
```

The full file after edit:
```dart
// lib/features/dictionary/presentation/providers/user_settings_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/user_settings_state.dart';

part 'user_settings_provider.g.dart';

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');

@Riverpod(keepAlive: true)
class UserSettingsNotifier extends _$UserSettingsNotifier {
  @override
  UserSettingsState build() => UserSettingsState.defaults;

  void setTargetLanguage(Language lang) =>
      state = state.copyWith(targetLanguage: lang);

  void setActiveContext(AppContext context) =>
      state = state.copyWith(activeContext: context);

  void setAiEnabled({required bool enabled}) =>
      state = state.copyWith(aiEnabled: enabled);

  void setGeminiApiKey(String key) =>
      state = state.copyWith(geminiApiKey: key);
}
```

Note: `UserSettingsNotifier` stays in-memory for now — Task 02 wires SharedPreferences.

- [ ] **Step 6: Update main.dart with Firebase init + SharedPreferences init**

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/dictionary/presentation/providers/user_settings_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox<String>('vocab_records');
  await Hive.openBox<String>('topics');
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const LexiCoreApp(),
  ));
}

class LexiCoreApp extends StatelessWidget {
  const LexiCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LexiCore',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
```

- [ ] **Step 7: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `user_settings_provider.g.dart` regenerated (now includes `sharedPreferencesProvider`).

- [ ] **Step 8: Verify app still builds**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 9: Commit**

```
git add pubspec.yaml pubspec.lock lib/main.dart lib/firebase_options.dart lib/features/dictionary/presentation/providers/user_settings_provider.dart lib/features/dictionary/presentation/providers/user_settings_provider.g.dart .gitignore
git commit -m "chore(plan4): add Firebase + SharedPreferences packages and init"
```

---

### Task 02: UserSettingsState + SharedPreferences persistence

**Files:**
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Create: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

**Interfaces consumed:**
```dart
sharedPreferencesProvider  // from Task 01 — user_settings_provider.dart
CEFRLevel                  // from lib/features/vocabulary/domain/entities/cefr_level.dart
```

**Interfaces produced:**
```dart
// UserSettingsState (updated):
final class UserSettingsState {
  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  final CEFRLevel? targetCefrLevel;   // NEW — null = show all levels in Practice
  // copyWith uses sentinel for targetCefrLevel (nullable field)
  static const defaults = UserSettingsState(targetLanguage: Language.english,
      activeContext: AppContext.general, aiEnabled: false, geminiApiKey: '',
      targetCefrLevel: null);
}

// UserSettingsNotifier (updated setters):
void setTargetLanguage(Language lang)           // persists to prefs
void setActiveContext(AppContext ctx)            // persists to prefs
void setAiEnabled({required bool enabled})       // persists to prefs
void setGeminiApiKey(String key)                 // persists to prefs
void setTargetCefrLevel(CEFRLevel? level)        // persists to prefs (NEW)
```

- [ ] **Step 1: Update UserSettingsState**

```dart
// lib/features/dictionary/domain/entities/user_settings_state.dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'app_context.dart';
import 'language.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.geminiApiKey,
    this.targetCefrLevel,
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  final CEFRLevel? targetCefrLevel;

  // Sentinel object for nullable copyWith field
  static const _absent = Object();

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    String? geminiApiKey,
    Object? targetCefrLevel = _absent,
  }) =>
      UserSettingsState(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        activeContext: activeContext ?? this.activeContext,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        targetCefrLevel: identical(targetCefrLevel, _absent)
            ? this.targetCefrLevel
            : targetCefrLevel as CEFRLevel?,
      );

  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    activeContext: AppContext.general,
    aiEnabled: false,
    geminiApiKey: '',
    targetCefrLevel: null,
  );
}
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _makeContainer({Map<String, Object> initialValues = const {}}) {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = SharedPreferences.getInstance(); // returns same instance after setMockInitialValues
  late SharedPreferences resolved;
  prefs.then((p) => resolved = p);
  // Force synchronous resolution using fake async or just await in tests
  return ProviderContainer(overrides: []);
  // Note: actual containers created in each test after awaiting prefs
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> makeContainer(
      {Map<String, Object> initialValues = const {}}) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('UserSettingsNotifier', () {
    test('build() returns defaults when SharedPreferences is empty', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final state = container.read(userSettingsNotifierProvider);
      expect(state.targetLanguage, Language.english);
      expect(state.activeContext, AppContext.general);
      expect(state.aiEnabled, false);
      expect(state.geminiApiKey, '');
      expect(state.targetCefrLevel, isNull);
    });

    test('build() loads persisted values from SharedPreferences', () async {
      final container = await makeContainer(initialValues: {
        'target_language': 'chinese',
        'active_context': 'business',
        'ai_enabled': true,
        'gemini_api_key': 'test-key',
        'target_cefr_level': 'b2',
      });
      addTearDown(container.dispose);
      final state = container.read(userSettingsNotifierProvider);
      expect(state.targetLanguage, Language.chinese);
      expect(state.activeContext, AppContext.business);
      expect(state.aiEnabled, true);
      expect(state.geminiApiKey, 'test-key');
      expect(state.targetCefrLevel, CEFRLevel.b2);
    });

    test('setTargetLanguage() updates state and writes to prefs', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      container.read(userSettingsNotifierProvider.notifier)
          .setTargetLanguage(Language.japanese);
      expect(container.read(userSettingsNotifierProvider).targetLanguage,
          Language.japanese);
      expect(prefs.getString('target_language'), 'japanese');
    });

    test('setAiEnabled() updates state and writes to prefs', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      container.read(userSettingsNotifierProvider.notifier)
          .setAiEnabled(enabled: true);
      expect(container.read(userSettingsNotifierProvider).aiEnabled, true);
      expect(prefs.getBool('ai_enabled'), true);
    });

    test('setTargetCefrLevel(null) removes key from prefs', () async {
      final container = await makeContainer(initialValues: {'target_cefr_level': 'b1'});
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      container.read(userSettingsNotifierProvider.notifier)
          .setTargetCefrLevel(null);
      expect(container.read(userSettingsNotifierProvider).targetCefrLevel, isNull);
      expect(prefs.containsKey('target_cefr_level'), false);
    });

    test('setTargetCefrLevel(b2) writes to prefs', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      container.read(userSettingsNotifierProvider.notifier)
          .setTargetCefrLevel(CEFRLevel.b2);
      expect(container.read(userSettingsNotifierProvider).targetCefrLevel,
          CEFRLevel.b2);
      expect(prefs.getString('target_cefr_level'), 'b2');
    });
  });
}
```

- [ ] **Step 3: Run tests to confirm they fail**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: FAIL — `UserSettingsNotifier.build()` returns `UserSettingsState.defaults` without reading prefs, and setters don't write to prefs yet.

- [ ] **Step 4: Update UserSettingsNotifier to persist**

```dart
// lib/features/dictionary/presentation/providers/user_settings_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

part 'user_settings_provider.g.dart';

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');

@Riverpod(keepAlive: true)
class UserSettingsNotifier extends _$UserSettingsNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  UserSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return UserSettingsState(
      targetLanguage: Language.values.byName(
          prefs.getString('target_language') ?? Language.english.name),
      activeContext: AppContext.values.byName(
          prefs.getString('active_context') ?? AppContext.general.name),
      aiEnabled: prefs.getBool('ai_enabled') ?? false,
      geminiApiKey: prefs.getString('gemini_api_key') ?? '',
      targetCefrLevel: prefs.containsKey('target_cefr_level')
          ? CEFRLevel.values.byName(prefs.getString('target_cefr_level')!)
          : null,
    );
  }

  void setTargetLanguage(Language lang) {
    _prefs.setString('target_language', lang.name);
    state = state.copyWith(targetLanguage: lang);
  }

  void setActiveContext(AppContext context) {
    _prefs.setString('active_context', context.name);
    state = state.copyWith(activeContext: context);
  }

  void setAiEnabled({required bool enabled}) {
    _prefs.setBool('ai_enabled', enabled);
    state = state.copyWith(aiEnabled: enabled);
  }

  void setGeminiApiKey(String key) {
    _prefs.setString('gemini_api_key', key);
    state = state.copyWith(geminiApiKey: key);
  }

  void setTargetCefrLevel(CEFRLevel? level) {
    if (level == null) {
      _prefs.remove('target_cefr_level');
    } else {
      _prefs.setString('target_cefr_level', level.name);
    }
    state = state.copyWith(targetCefrLevel: level);
  }
}
```

- [ ] **Step 5: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run tests — expect all pass**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: 5/5 PASS.

- [ ] **Step 7: Run full suite**

```
flutter test
```

Expected: all prior tests still pass (57+ new total with these 5).

- [ ] **Step 8: Commit**

```
git add lib/features/dictionary/domain/entities/user_settings_state.dart lib/features/dictionary/presentation/providers/user_settings_provider.dart lib/features/dictionary/presentation/providers/user_settings_provider.g.dart test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
git commit -m "feat(plan4): persist UserSettings to SharedPreferences + add targetCefrLevel"
```

---

### Task 03: CEFR filter in VocabRepository + GetVocabListUseCase

**Files:**
- Modify: `lib/features/vocabulary/domain/repositories/vocab_repository.dart`
- Modify: `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`
- Modify: `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`
- Create: `test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart`

**Interfaces consumed:**
```dart
CEFRLevel  // a1.index=0 … c2.index=5 — filter: record.cefrLevel.index <= maxCefrLevel.index
VocabRecord.cefrLevel  // already exists on VocabRecord
```

**Interfaces produced:**
```dart
// VocabRepository.getAll() — updated signature:
Future<List<VocabRecord>> getAll({
  String? topicId, InputType? inputType, Language? language,
  CEFRLevel? maxCefrLevel,  // NEW — null = no filter
});

// GetVocabListUseCase.execute() — updated signature:
Future<List<VocabRecord>> execute({
  String? topicId, InputType? inputType, Language? language,
  CEFRLevel? maxCefrLevel,  // NEW
});
```

- [ ] **Step 1: Write the failing test**

```dart
// test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class MockVocabRepository extends Mock implements VocabRepository {}

VocabRecord _makeRecord(String id, CEFRLevel level) => VocabRecord(
      id: id,
      headword: id,
      inputType: InputType.word,
      ipa: '',
      meaning: '',
      examples: [],
      personalNotes: '',
      topicIds: [],
      targetLanguage: Language.english,
      cefrLevel: level,
      activeContext: AppContext.general,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

void main() {
  late MockVocabRepository repo;
  late GetVocabListUseCase useCase;

  setUp(() {
    repo = MockVocabRepository();
    useCase = GetVocabListUseCase(repo);
  });

  test('execute() with no maxCefrLevel passes null to repo', () async {
    when(() => repo.getAll(
          topicId: any(named: 'topicId'),
          inputType: any(named: 'inputType'),
          language: any(named: 'language'),
          maxCefrLevel: any(named: 'maxCefrLevel'),
        )).thenAnswer((_) async => []);

    await useCase.execute();

    verify(() => repo.getAll(
          topicId: null,
          inputType: null,
          language: null,
          maxCefrLevel: null,
        )).called(1);
  });

  test('execute() passes maxCefrLevel to repo', () async {
    final records = [_makeRecord('a', CEFRLevel.b1)];
    when(() => repo.getAll(
          topicId: any(named: 'topicId'),
          inputType: any(named: 'inputType'),
          language: any(named: 'language'),
          maxCefrLevel: any(named: 'maxCefrLevel'),
        )).thenAnswer((_) async => records);

    final result = await useCase.execute(maxCefrLevel: CEFRLevel.b2);

    verify(() => repo.getAll(
          topicId: null,
          inputType: null,
          language: null,
          maxCefrLevel: CEFRLevel.b2,
        )).called(1);
    expect(result, records);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
```

Expected: FAIL — `GetVocabListUseCase.execute()` doesn't accept `maxCefrLevel` yet.

- [ ] **Step 3: Update VocabRepository interface**

```dart
// lib/features/vocabulary/domain/repositories/vocab_repository.dart
// Modify getAll() signature — add maxCefrLevel parameter:

abstract interface class VocabRepository {
  Future<void> save(VocabRecord record);

  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,  // NEW
  });

  Future<VocabRecord?> getById(String id);
  Future<void> update(VocabRecord record);
  Future<void> delete(String id);
  Future<bool> existsByHeadword(String headword, Language language);
  Future<VocabRecord?> getByHeadword(String headword, Language language);
  Future<List<Topic>> getTopics();
  Future<void> addTopic(Topic topic);
  Future<void> deleteTopic(String id);
}
```

Add the import at the top of the file:
```dart
import '../entities/cefr_level.dart';
```

- [ ] **Step 4: Update VocabRepositoryImpl**

In `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`, update `getAll()`:

```dart
@override
Future<List<VocabRecord>> getAll({
  String? topicId,
  InputType? inputType,
  Language? language,
  CEFRLevel? maxCefrLevel,  // NEW
}) async {
  var records = _vocabBox.values
      .map((s) => VocabRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();
  if (topicId != null) {
    records = records.where((r) => r.topicIds.contains(topicId)).toList();
  }
  if (inputType != null) {
    records = records.where((r) => r.inputType == inputType).toList();
  }
  if (language != null) {
    records = records.where((r) => r.targetLanguage == language).toList();
  }
  if (maxCefrLevel != null) {
    records = records
        .where((r) => r.cefrLevel.index <= maxCefrLevel.index)
        .toList();
  }
  records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return records;
}
```

Add the import at the top:
```dart
import '../../domain/entities/cefr_level.dart';
```

- [ ] **Step 5: Update GetVocabListUseCase**

```dart
// lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/cefr_level.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class GetVocabListUseCase {
  const GetVocabListUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<VocabRecord>> execute({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
  }) =>
      _repo.getAll(
        topicId: topicId,
        inputType: inputType,
        language: language,
        maxCefrLevel: maxCefrLevel,
      );
}
```

- [ ] **Step 6: Run tests — expect pass**

```
flutter test test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
```

Expected: 2/2 PASS.

- [ ] **Step 7: Run full suite**

```
flutter test
```

Expected: all passing.

- [ ] **Step 8: Analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 9: Commit**

```
git add lib/features/vocabulary/domain/repositories/vocab_repository.dart lib/features/vocabulary/data/repositories/vocab_repository_impl.dart lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart test/features/vocabulary/domain/use_cases/get_vocab_list_use_case_test.dart
git commit -m "feat(plan4): add CEFR level filter to VocabRepository and GetVocabListUseCase"
```

---

### Task 04: PracticeHomeScreen CEFR filter UI

**Files:**
- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart`

**Interfaces consumed:**
```dart
userSettingsNotifierProvider  // UserSettingsState.targetCefrLevel
getVocabListUseCaseProvider.execute(maxCefrLevel: CEFRLevel?)  // from Task 03
CEFRLevel  // enum with .label → 'A1', 'A2', etc.
```

No new tests — UI-only change.

- [ ] **Step 1: Update PracticeHomeScreen**

Replace `lib/features/practice/presentation/screens/practice_home_screen.dart` with:

```dart
// lib/features/practice/presentation/screens/practice_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../domain/entities/exercise_result.dart';

class PracticeHomeScreen extends ConsumerStatefulWidget {
  const PracticeHomeScreen({super.key});

  @override
  ConsumerState<PracticeHomeScreen> createState() => _PracticeHomeScreenState();
}

class _PracticeHomeScreenState extends ConsumerState<PracticeHomeScreen> {
  String? _selectedTopicId;
  int? _wordLimit = 10;
  CEFRLevel? _maxCefrLevel; // null = All levels

  static const _limits = [5, 10, 20, null];
  static const _limitLabels = ['5', '10', '20', 'All'];

  @override
  void initState() {
    super.initState();
    // Initialize CEFR filter from settings default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(userSettingsNotifierProvider);
      setState(() => _maxCefrLevel = settings.targetCefrLevel);
    });
  }

  Future<void> _start() async {
    final words = await ref.read(getVocabListUseCaseProvider).execute(
          topicId: _selectedTopicId,
          maxCefrLevel: _maxCefrLevel,
        );
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có từ nào ở cấp độ này.')),
        );
      }
      return;
    }
    final shuffled = List.from(words)..shuffle();
    final limited = _wordLimit == null ? shuffled : shuffled.take(_wordLimit!).toList();
    if (mounted) {
      context.go('/practice/session', extra: SessionConfig(words: limited));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final theme = Theme.of(context);

    // CEFR segments: A1, A2, B1, B2, C1, C2, Tất cả (null)
    final cefrSegments = [
      ...CEFRLevel.values.map(
        (l) => ButtonSegment<CEFRLevel?>(value: l, label: Text(l.label)),
      ),
      const ButtonSegment<CEFRLevel?>(value: null, label: Text('Tất cả')),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Luyện tập')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chủ đề', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            topicsAsync.when(
              data: (topics) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Tất cả'),
                    selected: _selectedTopicId == null,
                    onSelected: (_) => setState(() => _selectedTopicId = null),
                  ),
                  ...topics.map(
                    (t) => FilterChip(
                      label: Text('${t.emoji} ${t.name}'),
                      selected: _selectedTopicId == t.id,
                      onSelected: (_) =>
                          setState(() => _selectedTopicId = t.id),
                    ),
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(e.toString()),
            ),
            const SizedBox(height: 24),
            Text('Cấp độ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<CEFRLevel?>(
                segments: cefrSegments,
                selected: {_maxCefrLevel},
                onSelectionChanged: (s) =>
                    setState(() => _maxCefrLevel = s.first),
              ),
            ),
            const SizedBox(height: 24),
            Text('Số từ mỗi session', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int?>(
              segments: List.generate(
                _limits.length,
                (i) => ButtonSegment<int?>(
                  value: _limits[i],
                  label: Text(_limitLabels[i]),
                ),
              ),
              selected: {_wordLimit},
              onSelectionChanged: (s) => setState(() => _wordLimit = s.first),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu luyện tập'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/features/practice/presentation/screens/practice_home_screen.dart
```

Expected: no issues.

- [ ] **Step 3: Run tests**

```
flutter test
```

Expected: all passing.

- [ ] **Step 4: Commit**

```
git add lib/features/practice/presentation/screens/practice_home_screen.dart
git commit -m "feat(plan4): add CEFR level filter to PracticeHomeScreen"
```

---

### Task 05: AppShell 4th tab + /settings route + placeholder SettingsScreen

**Files:**
- Modify: `lib/core/widgets/app_shell.dart`
- Modify: `lib/core/router/app_router.dart`
- Create: `lib/features/settings/presentation/screens/settings_screen.dart`

No tests — scaffolding task.

- [ ] **Step 1: Create placeholder SettingsScreen**

```dart
// lib/features/settings/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
```

- [ ] **Step 2: Update AppShell**

Replace `lib/core/widgets/app_shell.dart`:

```dart
// lib/core/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/vocab')) return 1;
    if (location.startsWith('/practice')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/');
            case 1: context.go('/vocab');
            case 2: context.go('/practice');
            case 3: context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Vocab Bank',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Luyện tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Update AppRouter**

Replace `lib/core/router/app_router.dart`:

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_bank_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_detail_screen.dart';
import '../../features/practice/presentation/screens/practice_home_screen.dart';
import '../../features/practice/presentation/screens/practice_session_screen.dart';
import '../../features/practice/presentation/screens/session_result_screen.dart';
import '../../features/practice/domain/entities/exercise_result.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LookupScreen()),
        GoRoute(
          path: '/vocab',
          builder: (context, state) => const VocabBankScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => VocabDetailScreen(
                id: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/practice',
          builder: (context, state) => const PracticeHomeScreen(),
          routes: [
            GoRoute(
              path: 'session',
              builder: (context, state) => PracticeSessionScreen(
                config: state.extra as SessionConfig,
              ),
              routes: [
                GoRoute(
                  path: 'result',
                  builder: (context, state) => SessionResultScreen(
                    result: state.extra as SessionResult,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
```

- [ ] **Step 4: Analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 5: Run tests**

```
flutter test
```

Expected: all passing.

- [ ] **Step 6: Commit**

```
git add lib/features/settings/presentation/screens/settings_screen.dart lib/core/widgets/app_shell.dart lib/core/router/app_router.dart
git commit -m "feat(plan4): add Settings tab and placeholder SettingsScreen"
```

---

### Task 06: AuthNotifier (Google Sign-In)

**Files:**
- Create: `lib/features/settings/presentation/providers/auth_notifier.dart`
- (generated) `lib/features/settings/presentation/providers/auth_notifier.g.dart`

No unit tests — thin wrapper around Firebase SDK (hard to mock without Firebase Test Lab).

**Interfaces produced:**
```dart
// authNotifierProvider: AsyncNotifierProvider<AuthNotifier, User?>
// state: AsyncValue<User?> — valueOrNull gives User? or null when signed out

class AuthNotifier extends _$AuthNotifier {
  Stream<User?> build();               // watches FirebaseAuth.authStateChanges()
  Future<void> signInWithGoogle();     // Google OAuth flow
  Future<void> signOut();              // signs out of both Google + Firebase
}
```

- [ ] **Step 1: Create AuthNotifier**

```dart
// lib/features/settings/presentation/providers/auth_notifier.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Stream<User?> build() => FirebaseAuth.instance.authStateChanges();

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // user cancelled
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      // Sign-in failure — state stays as current (signed out)
      // Error surfaced to caller via rethrow so UI can show SnackBar
      rethrow;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
```

- [ ] **Step 2: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `auth_notifier.g.dart` generated.

- [ ] **Step 3: Analyze**

```
flutter analyze lib/features/settings/presentation/providers/auth_notifier.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```
git add lib/features/settings/presentation/providers/auth_notifier.dart lib/features/settings/presentation/providers/auth_notifier.g.dart
git commit -m "feat(plan4): add AuthNotifier with Google Sign-In"
```

---

### Task 07: SyncService + SyncNotifier

**Files:**
- Create: `lib/core/services/sync_service.dart`
- Create: `lib/features/settings/presentation/providers/sync_notifier.dart`
- (generated) `lib/features/settings/presentation/providers/sync_notifier.g.dart`
- Create: `test/core/services/sync_service_test.dart`

**Interfaces consumed:**
```dart
authNotifierProvider     // AsyncValue<User?> — from Task 06
userSettingsNotifierProvider  // UserSettingsState — for settings doc sync
VocabRecord.toJson() / VocabRecord.fromJson()  // already exists
Topic.toJson() / Topic.fromJson()               // already exists
Hive.box<String>('vocab_records')  // opened in main.dart
Hive.box<String>('topics')         // opened in main.dart
```

**Interfaces produced:**
```dart
enum SyncStatus { idle, syncing, error }

class SyncService {
  SyncService({required Box<String> vocabBox, required Box<String> topicsBox});
  Future<void> startSync(String uid, UserSettingsState settings,
      void Function(SyncStatus) onStatus);
  void stopSync();
}

// syncNotifierProvider: NotifierProvider<SyncNotifier, SyncStatus>
// state: SyncStatus — exposed in SettingsScreen
```

**Critical implementation note — Hive loop prevention:**
When Firestore pushes an update into Hive, that update triggers the Hive watcher which would then push back to Firestore. Prevent this with a `_firestoreUpdatingKeys` Set: add the key before writing to Hive, remove after; the Hive watcher skips keys in this set. Since `Box.put()` triggers watchers synchronously (before the Future resolves), the add/remove bracketing works correctly.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lexi_core/core/services/sync_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

// Minimal path_provider mock for Hive init in tests
class _MockPathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.createTempSync('hive_test').path;
}

VocabRecord _record(String id, DateTime updatedAt) => VocabRecord(
      id: id, headword: id, inputType: InputType.word, ipa: '', meaning: '',
      examples: [], personalNotes: '', topicIds: [], targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1, activeContext: AppContext.general,
      createdAt: DateTime(2024), updatedAt: updatedAt,
    );

void main() {
  late Box<String> vocabBox;
  late Box<String> topicsBox;
  late Directory tempDir;

  setUpAll(() {
    PathProviderPlatform.instance = _MockPathProvider();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_test');
    Hive.init(tempDir.path);
    vocabBox = await Hive.openBox<String>('vocab_test');
    topicsBox = await Hive.openBox<String>('topics_test');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('SyncService creates instance without error', () {
    final service = SyncService(vocabBox: vocabBox, topicsBox: topicsBox);
    expect(service, isNotNull);
  });

  test('stopSync() is safe to call before startSync()', () {
    final service = SyncService(vocabBox: vocabBox, topicsBox: topicsBox);
    expect(() => service.stopSync(), returnsNormally);
  });
}
```

Note: Full Firestore integration testing requires Firebase Test SDK and is out of scope. These tests verify the service can be constructed and that `stopSync` is idempotent.

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/core/services/sync_service_test.dart
```

Expected: FAIL — `SyncService` not defined yet.

- [ ] **Step 3: Create SyncService**

```dart
// lib/core/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../../../features/dictionary/domain/entities/user_settings_state.dart';
import '../../../features/vocabulary/domain/entities/topic.dart';
import '../../../features/vocabulary/domain/entities/vocab_record.dart';

enum SyncStatus { idle, syncing, error }

class SyncService {
  SyncService({required this.vocabBox, required this.topicsBox});

  final Box<String> vocabBox;
  final Box<String> topicsBox;

  // Keys currently being written from Firestore → Hive (prevents echo back to Firestore)
  final _firestoreUpdatingVocab = <String>{};
  final _firestoreUpdatingTopic = <String>{};

  StreamSubscription? _vocabHiveSub;
  StreamSubscription? _topicHiveSub;
  StreamSubscription? _firestoreVocabSub;
  StreamSubscription? _firestoreTopicSub;

  Future<void> startSync(
    String uid,
    UserSettingsState settings,
    void Function(SyncStatus) onStatus,
  ) async {
    final db = FirebaseFirestore.instance;
    final vocabCol =
        db.collection('users').doc(uid).collection('vocab_records');
    final topicsCol =
        db.collection('users').doc(uid).collection('topics');
    final settingsDoc = db.collection('users').doc(uid);

    onStatus(SyncStatus.syncing);

    try {
      // 1. Batch-push all local vocab records to Firestore (local is authoritative at sign-in)
      var batch = db.batch();
      var count = 0;
      for (final raw in vocabBox.values) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        batch.set(vocabCol.doc(map['id'] as String), map);
        count++;
        if (count == 500) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      // 2. Batch-push all local topics
      for (final raw in topicsBox.values) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        batch.set(topicsCol.doc(map['id'] as String), map);
        count++;
        if (count == 500) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      // 3. Write settings doc (never include geminiApiKey)
      batch.set(settingsDoc, {
        'targetLanguage': settings.targetLanguage.name,
        'activeContext': settings.activeContext.name,
        'aiEnabled': settings.aiEnabled,
        if (settings.targetCefrLevel != null)
          'targetCefrLevel': settings.targetCefrLevel!.name,
      });

      await batch.commit();
    } catch (e) {
      dev.log('SyncService: initial push failed: $e');
      onStatus(SyncStatus.error);
      return;
    }

    // 4. Subscribe to Firestore vocab snapshots → update Hive if remote is newer
    _firestoreVocabSub = vocabCol.snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final id = change.doc.id;
        if (change.type == DocumentChangeType.removed) {
          _firestoreUpdatingVocab.add(id);
          vocabBox.delete(id).then((_) => _firestoreUpdatingVocab.remove(id));
        } else {
          final remoteMap = change.doc.data()!;
          final localRaw = vocabBox.get(id);
          bool shouldUpdate;
          if (localRaw == null) {
            shouldUpdate = true;
          } else {
            final localMap = jsonDecode(localRaw) as Map<String, dynamic>;
            final remoteUpdatedAt =
                DateTime.parse(remoteMap['updatedAt'] as String);
            final localUpdatedAt =
                DateTime.parse(localMap['updatedAt'] as String);
            shouldUpdate = remoteUpdatedAt.isAfter(localUpdatedAt);
          }
          if (shouldUpdate) {
            _firestoreUpdatingVocab.add(id);
            vocabBox
                .put(id, jsonEncode(remoteMap))
                .then((_) => _firestoreUpdatingVocab.remove(id))
                .catchError((e) {
              _firestoreUpdatingVocab.remove(id);
              dev.log('SyncService: Hive vocab update failed: $e');
            });
          }
        }
      }
    }, onError: (e) => dev.log('SyncService: Firestore vocab stream error: $e'));

    // 5. Subscribe to Hive vocab changes → push to Firestore (skip echo-back keys)
    _vocabHiveSub = vocabBox.watch().listen((event) {
      final key = event.key as String;
      if (_firestoreUpdatingVocab.contains(key)) return;
      if (event.deleted) {
        vocabCol.doc(key).delete().catchError(
            (e) => dev.log('SyncService: Firestore vocab delete failed: $e'));
      } else {
        final map = jsonDecode(event.value as String) as Map<String, dynamic>;
        vocabCol
            .doc(key)
            .set(map)
            .catchError((e) =>
                dev.log('SyncService: Firestore vocab write failed: $e'));
      }
    });

    // 6. Same for topics
    _firestoreTopicSub = topicsCol.snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final id = change.doc.id;
        if (change.type == DocumentChangeType.removed) {
          _firestoreUpdatingTopic.add(id);
          topicsBox.delete(id).then((_) => _firestoreUpdatingTopic.remove(id));
        } else {
          final remoteMap = change.doc.data()!;
          final localRaw = topicsBox.get(id);
          if (localRaw == null) {
            _firestoreUpdatingTopic.add(id);
            topicsBox
                .put(id, jsonEncode(remoteMap))
                .then((_) => _firestoreUpdatingTopic.remove(id))
                .catchError((e) => _firestoreUpdatingTopic.remove(id));
          }
          // Topics don't have updatedAt — remote wins only if not in local
        }
      }
    }, onError: (e) => dev.log('SyncService: Firestore topics stream error: $e'));

    _topicHiveSub = topicsBox.watch().listen((event) {
      final key = event.key as String;
      if (_firestoreUpdatingTopic.contains(key)) return;
      if (event.deleted) {
        topicsCol.doc(key).delete().catchError(
            (e) => dev.log('SyncService: Firestore topic delete failed: $e'));
      } else {
        final map =
            jsonDecode(event.value as String) as Map<String, dynamic>;
        topicsCol
            .doc(key)
            .set(map)
            .catchError((e) =>
                dev.log('SyncService: Firestore topic write failed: $e'));
      }
    });

    onStatus(SyncStatus.idle);
  }

  void stopSync() {
    _vocabHiveSub?.cancel();
    _topicHiveSub?.cancel();
    _firestoreVocabSub?.cancel();
    _firestoreTopicSub?.cancel();
    _vocabHiveSub = null;
    _topicHiveSub = null;
    _firestoreVocabSub = null;
    _firestoreTopicSub = null;
    _firestoreUpdatingVocab.clear();
    _firestoreUpdatingTopic.clear();
  }
}
```

- [ ] **Step 4: Create SyncNotifier**

```dart
// lib/features/settings/presentation/providers/sync_notifier.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/sync_service.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import 'auth_notifier.dart';

part 'sync_notifier.g.dart';

@Riverpod(keepAlive: true)
class SyncNotifier extends _$SyncNotifier {
  SyncService? _service;

  @override
  SyncStatus build() {
    ref.listen<AsyncValue<User?>>(authNotifierProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user != null) {
        _startSync(user.uid);
      } else {
        _stopSync();
      }
    });
    return SyncStatus.idle;
  }

  Future<void> _startSync(String uid) async {
    _service?.stopSync();
    _service = SyncService(
      vocabBox: Hive.box<String>('vocab_records'),
      topicsBox: Hive.box<String>('topics'),
    );
    final settings = ref.read(userSettingsNotifierProvider);
    await _service!.startSync(uid, settings, (status) => state = status);
  }

  void _stopSync() {
    _service?.stopSync();
    _service = null;
    state = SyncStatus.idle;
  }
}
```

- [ ] **Step 5: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `sync_notifier.g.dart` generated.

- [ ] **Step 6: Run tests**

```
flutter test test/core/services/sync_service_test.dart
```

Expected: 2/2 PASS.

- [ ] **Step 7: Run full suite and analyze**

```
flutter test
flutter analyze lib/
```

Expected: all passing, no analyzer errors.

- [ ] **Step 8: Commit**

```
git add lib/core/services/sync_service.dart lib/features/settings/presentation/providers/sync_notifier.dart lib/features/settings/presentation/providers/sync_notifier.g.dart test/core/services/sync_service_test.dart
git commit -m "feat(plan4): add SyncService and SyncNotifier for Firestore bidirectional sync"
```

---

### Task 08: SettingsScreen (full UI)

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

**Interfaces consumed:**
```dart
userSettingsNotifierProvider    // UserSettingsState + setters
authNotifierProvider            // AsyncValue<User?> + signInWithGoogle() + signOut()
syncNotifierProvider            // SyncStatus
Language.values                 // for language dropdown
CEFRLevel.values                // for CEFR level picker
```

No new tests — UI-only.

- [ ] **Step 1: Replace placeholder with full SettingsScreen**

```dart
// lib/features/settings/presentation/screens/settings_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../providers/auth_notifier.dart';
import '../providers/sync_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final authAsync = ref.watch(authNotifierProvider);
    final syncStatus = ref.watch(syncNotifierProvider);
    final notifier = ref.read(userSettingsNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // ── Tài khoản ──────────────────────────────────────────
          _SectionHeader('Tài khoản'),
          authAsync.when(
            data: (user) => user == null
                ? _SignedOutTile(
                    onSignIn: () async {
                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Đăng nhập thất bại. Thử lại.')),
                          );
                        }
                      }
                    },
                  )
                : _SignedInTile(
                    user: user,
                    syncStatus: syncStatus,
                    onSignOut: () => ref
                        .read(authNotifierProvider.notifier)
                        .signOut(),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const ListTile(
                title: Text('Lỗi xác thực')),
          ),

          // ── AI ─────────────────────────────────────────────────
          _SectionHeader('AI'),
          SwitchListTile(
            title: const Text('Bật Gemini AI'),
            subtitle: const Text('Tạo bài tập tự động khi luyện tập'),
            value: settings.aiEnabled,
            onChanged: (v) => notifier.setAiEnabled(enabled: v),
          ),
          if (settings.aiEnabled)
            ListTile(
              title: const Text('Gemini API Key'),
              subtitle: Text(
                settings.geminiApiKey.isEmpty
                    ? 'Chưa cài đặt'
                    : '••••••••${settings.geminiApiKey.length > 4 ? settings.geminiApiKey.substring(settings.geminiApiKey.length - 4) : ''}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _showApiKeyDialog(context, ref, settings.geminiApiKey),
            ),

          // ── Học tập ────────────────────────────────────────────
          _SectionHeader('Học tập'),
          ListTile(
            title: const Text('Ngôn ngữ mục tiêu'),
            trailing: DropdownButton<Language>(
              value: settings.targetLanguage,
              underline: const SizedBox(),
              items: Language.values
                  .map((l) => DropdownMenuItem(
                        value: l,
                        child: Text(l.label),
                      ))
                  .toList(),
              onChanged: (l) {
                if (l != null) notifier.setTargetLanguage(l);
              },
            ),
          ),
          ListTile(
            title: const Text('Cấp độ mục tiêu'),
            subtitle: Text(
              settings.targetCefrLevel?.label ?? 'Tất cả',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCefrLevelPicker(context, ref, settings.targetCefrLevel),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(
      BuildContext context, WidgetRef ref, String currentKey) {
    final ctrl = TextEditingController(text: currentKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'AIza...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              ref
                  .read(userSettingsNotifierProvider.notifier)
                  .setGeminiApiKey(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showCefrLevelPicker(
      BuildContext context, WidgetRef ref, CEFRLevel? current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<CEFRLevel?>(
              title: const Text('Tất cả'),
              value: null,
              groupValue: current,
              onChanged: (_) {
                ref
                    .read(userSettingsNotifierProvider.notifier)
                    .setTargetCefrLevel(null);
                Navigator.pop(ctx);
              },
            ),
            ...CEFRLevel.values.map((level) => RadioListTile<CEFRLevel?>(
                  title: Text(level.label),
                  value: level,
                  groupValue: current,
                  onChanged: (v) {
                    ref
                        .read(userSettingsNotifierProvider.notifier)
                        .setTargetCefrLevel(v);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _SignedOutTile extends StatelessWidget {
  const _SignedOutTile({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Đăng nhập để đồng bộ dữ liệu trên nhiều thiết bị'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Đăng nhập với Google'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInTile extends StatelessWidget {
  const _SignedInTile({
    required this.user,
    required this.syncStatus,
    required this.onSignOut,
  });
  final User user;
  final SyncStatus syncStatus;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage:
                user.photoURL != null ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null
                ? Text(user.displayName?.substring(0, 1) ?? '?')
                : null,
          ),
          title: Text(user.displayName ?? 'Người dùng'),
          subtitle: Text(user.email ?? ''),
          trailing: TextButton(
            onPressed: onSignOut,
            child: const Text('Đăng xuất'),
          ),
        ),
        ListTile(
          leading: syncStatus == SyncStatus.syncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  syncStatus == SyncStatus.error
                      ? Icons.sync_problem
                      : Icons.sync,
                  color: syncStatus == SyncStatus.error ? Colors.red : null,
                ),
          title: const Text('Đồng bộ'),
          subtitle: Text(switch (syncStatus) {
            SyncStatus.idle => 'Đã đồng bộ',
            SyncStatus.syncing => 'Đang đồng bộ...',
            SyncStatus.error => 'Lỗi đồng bộ',
          }),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Analyze**

```
flutter analyze lib/features/settings/presentation/screens/settings_screen.dart
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 3: Run tests**

```
flutter test
```

Expected: all passing.

- [ ] **Step 4: Commit**

```
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat(plan4): implement SettingsScreen with account, AI, and study sections"
```

---

## Self-Review Checklist (run after writing, before handing off)

**Spec coverage:**
- [x] SharedPreferences persistence of all 5 settings fields including `targetCefrLevel` — Task 02
- [x] `geminiApiKey` never written to Firestore — Task 07 SyncService explicitly excludes it; Task 08 SettingsScreen only reads/writes locally
- [x] `sharedPreferencesProvider` overridden in `main.dart` — Task 01
- [x] `CEFRLevel.index` filter in `VocabRepositoryImpl` — Task 03
- [x] `maxCefrLevel` threaded through use case — Task 03
- [x] CEFR filter UI in PracticeHomeScreen, initialized from settings — Task 04
- [x] AppShell 4th tab + `/settings` route — Task 05
- [x] Google Sign-In + Sign-Out — Task 06
- [x] Firestore schema: `users/{uid}/vocab_records`, `topics`, `settings` doc — Task 07
- [x] Hive ↔ Firestore bidirectional sync with loop prevention — Task 07
- [x] Batch initial push (local authoritative) — Task 07
- [x] `updatedAt` comparison for incoming Firestore changes — Task 07
- [x] Sign-in failure SnackBar — Task 08
- [x] Settings Screen: account section (signed in/out), AI section, study section — Task 08

**Type consistency:**
- `SyncStatus` defined in `sync_service.dart` — imported by `sync_notifier.dart` and `settings_screen.dart` ✓
- `sharedPreferencesProvider` defined in `user_settings_provider.dart` — imported by `main.dart` and `sync_notifier.dart` ✓
- `authNotifierProvider` defined in `auth_notifier.dart` — imported by `sync_notifier.dart` and `settings_screen.dart` ✓
- `UserSettingsState.targetCefrLevel: CEFRLevel?` used in Task 02, 04, 07, 08 ✓
- `GetVocabListUseCase.execute(maxCefrLevel: CEFRLevel?)` signature consistent across Task 03 and Task 04 ✓
