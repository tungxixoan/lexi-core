# LexiCore Plan 4 — Firebase Sync + Settings Screen + Practice Level Filter

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.
> Implementation plan: `docs/superpowers/plans/2026-07-02-plan4-*.md` (written after spec approval).

**Goal:** Persist user settings locally, add a 4th Settings tab with Google Sign-In and Firestore cloud sync for VocabBank + Topics, and add a CEFR level filter to the Practice screen with a default from Settings.

**Architecture:** Three independent slices — (1) Settings persistence via `shared_preferences`, (2) Firebase Auth + Firestore sync as an opt-in infrastructure layer that wraps existing Hive storage, (3) CEFR filter threaded through `GetVocabListUseCase` → `PracticeHomeScreen`. Each slice is independently testable and deployable.

---

## Global Constraints

- Flutter SDK >=3.22.0, Dart >=3.4.0, iOS + Android only
- Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- GoRouter only — no `Navigator.push` for screen transitions
- **NEVER store `geminiApiKey` in Firestore** — it stays local (SharedPreferences) only
- Firebase sign-in is entirely opt-in — all features work without it
- Offline-first: Hive is the source of truth; Firestore is a mirror
- Sync is best-effort: write failures to Firestore are logged but never crash the app
- Unit tests use `mocktail`

---

## New Packages

```yaml
# pubspec.yaml additions
dependencies:
  shared_preferences: ^2.3.0
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  google_sign_in: ^6.0.0
```

> Platform setup required: `google-services.json` (Android) + `GoogleService-Info.plist` (iOS) from Firebase Console. These are NOT committed to git (add to `.gitignore`).

---

## Feature 1 — Settings Persistence

### What changes

`UserSettingsState` gains one new field:
```dart
final CEFRLevel? targetCefrLevel; // null = no filter (show all levels in Practice)
```

`UserSettingsNotifier` switches from a simple in-memory `Notifier` to a `Notifier` that reads/writes `SharedPreferences`. `SharedPreferences` is initialized once in `main.dart` and injected via a provider override.

```dart
// lib/core/di/app_providers.dart — new provider
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError('override in main.dart');

// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const App(),
  ));
}
```

### SharedPreferences keys

| Key | Type | Maps to |
|-----|------|---------|
| `'target_language'` | `String` | `Language.name` |
| `'active_context'` | `String` | `AppContext.name` |
| `'ai_enabled'` | `bool` | `aiEnabled` |
| `'target_cefr_level'` | `String?` | `CEFRLevel.name` or absent = null |
| `'gemini_api_key'` | `String` | `geminiApiKey` — local only, never synced |

### UserSettingsNotifier pattern

```dart
@Riverpod(keepAlive: true)
class UserSettingsNotifier extends _$UserSettingsNotifier {
  @override
  UserSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _load(prefs);
  }

  UserSettingsState _load(SharedPreferences prefs) {
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
    ref.read(sharedPreferencesProvider).setString('target_language', lang.name);
    state = state.copyWith(targetLanguage: lang);
  }
  // ... same pattern for each field; setTargetCefrLevel(CEFRLevel? level)
}
```

---

## Feature 2 — Settings Screen (4th Tab)

### AppShell changes

`app_shell.dart`: add 4th `NavigationDestination` (`Icons.settings_outlined` / `Icons.settings`, label `'Cài đặt'`). `_selectedIndex` returns `3` for paths starting with `/settings`. `onDestinationSelected case 3`: `context.go('/settings')`.

`app_router.dart`: add `GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen())` inside `ShellRoute.routes`.

### SettingsScreen layout

`lib/features/settings/presentation/screens/settings_screen.dart` — `ConsumerWidget`:

```
AppBar: title 'Cài đặt', no back button (top-level tab)

Section: Tài khoản
  [if signed out]
    Banner card: "Đăng nhập để đồng bộ dữ liệu trên nhiều thiết bị"
    FilledButton: "Đăng nhập với Google"  → calls authNotifier.signIn()
  [if signed in]
    ListTile: avatar (photoURL) + displayName + email
    TextButton: "Đăng xuất"  → calls authNotifier.signOut()
  [if signed in] SyncStatusTile: shows SyncStatus (idle / syncing / error)

Section: AI
  SwitchListTile: "Bật Gemini AI" → userSettings.setAiEnabled()
  [if aiEnabled] ListTile with TextField: "Gemini API Key" → userSettings.setGeminiApiKey()

Section: Học tập
  ListTile: "Ngôn ngữ mục tiêu" → DropdownButton<Language>
  ListTile: "Cấp độ mục tiêu" → SegmentedButton<CEFRLevel?> [A1|A2|B1|B2|C1|C2|Tất cả]
```

---

## Feature 3 — Firebase Auth

`lib/features/settings/presentation/providers/auth_notifier.dart`:

```dart
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Stream<User?> build() => FirebaseAuth.instance.authStateChanges();

  Future<void> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
```

`authNotifierProvider` is `StreamProvider<User?>` (Riverpod stream) — consumers use `.when()` or `.valueOrNull`.

---

## Feature 4 — Firestore Sync

### Firestore schema

```
users/{uid}/
  vocab_records/{recordId}   ← VocabRecord.toJson() (all fields)
  topics/{topicId}           ← Topic.toJson()
  settings                   ← single doc: targetLanguage, activeContext, aiEnabled, targetCefrLevel
                               (geminiApiKey is NEVER written here)
```

### SyncService

`lib/core/services/sync_service.dart` — plain Dart class (not a provider), injected into `SyncNotifier`:

```dart
enum SyncStatus { idle, syncing, error }

class SyncService {
  SyncService({required this.vocabBox, required this.topicsBox});
  final Box<String> vocabBox;
  final Box<String> topicsBox;

  StreamSubscription? _vocabSub;
  StreamSubscription? _topicSub;
  StreamSubscription? _firestoreVocabSub;
  StreamSubscription? _firestoreTopicSub;

  // Called by SyncNotifier on sign-in
  Future<void> startSync(String uid, void Function(SyncStatus) onStatus) async { ... }

  // Called by SyncNotifier on sign-out
  void stopSync() { ... }
}
```

**On sign-in flow (`startSync`):**
1. `onStatus(SyncStatus.syncing)`
2. Batch-write all local vocab records to Firestore (`batch.set` with merge:false — local is authoritative at sign-in time, no read required)
3. Batch-write all local topics similarly
4. Write settings doc to Firestore (excluding `geminiApiKey`)
5. Subscribe to `users/{uid}/vocab_records` Firestore snapshot → for each changed doc: parse `VocabRecord.fromJson`, compare `updatedAt` with the value currently in Hive (`vocabBox.get(id)`); if remote `updatedAt` is newer → `vocabBox.put(id, jsonEncode(remote.toJson()))` (best-effort, log on error)
6. Subscribe to Hive `vocabBox.watch()` → on each event: if `event.deleted` → `firestoreVocabCollection.doc(key).delete()` (fire-and-forget); else decode `event.value as String` → `firestoreVocabCollection.doc(key).set(json)` (fire-and-forget, log on error)
7. Same pattern for topics box ↔ Firestore topics collection
8. `onStatus(SyncStatus.idle)`

**On sign-out (`stopSync`):** cancel all 4 subscriptions (2 Hive watchers + 2 Firestore listeners).

### SyncNotifier

`lib/features/settings/presentation/providers/sync_notifier.dart`:

```dart
@Riverpod(keepAlive: true)
class SyncNotifier extends _$SyncNotifier {
  SyncService? _service;

  @override
  SyncStatus build() {
    ref.listen(authNotifierProvider, (_, next) {
      final user = next.valueOrNull;
      if (user != null) _startSync(user.uid);
      else _stopSync();
    });
    return SyncStatus.idle;
  }

  void _startSync(String uid) { ... }
  void _stopSync() { ... }
}
```

---

## Feature 5 — Practice Level Filter

### VocabRepository change

`VocabRepository.getAll()` gains `CEFRLevel? maxCefrLevel` parameter. `VocabRepositoryImpl` adds filter:
```dart
if (maxCefrLevel != null) {
  records = records
      .where((r) => r.cefrLevel.index <= maxCefrLevel.index)
      .toList();
}
```

### GetVocabListUseCase change

```dart
Future<List<VocabRecord>> execute({
  String? topicId,
  InputType? inputType,
  Language? language,
  CEFRLevel? maxCefrLevel, // new
}) => _repo.getAll(topicId: topicId, inputType: inputType,
                   language: language, maxCefrLevel: maxCefrLevel);
```

### PracticeHomeScreen change

Below the topic filter, add a CEFR level filter row:

```
"Cấp độ" label
SegmentedButton<CEFRLevel?>:
  segments: [A1, A2, B1, B2, C1, C2, Tất cả (null)]
  selected: {_maxCefrLevel}  // initialized from userSettings.targetCefrLevel
  onSelectionChanged: (s) => setState(() => _maxCefrLevel = s.first)
```

`_start()` passes `maxCefrLevel: _maxCefrLevel` to `getVocabListUseCaseProvider.execute(...)`.

If filtered list is empty: SnackBar `'Không có từ nào ở cấp độ này.'`

---

## File Map

### New files

| File | Responsibility |
|------|---------------|
| `lib/core/services/sync_service.dart` | Hive ↔ Firestore bidirectional sync logic |
| `lib/features/settings/presentation/screens/settings_screen.dart` | 4th tab Settings UI |
| `lib/features/settings/presentation/providers/auth_notifier.dart` | Google Sign-In / Sign-Out, `Stream<User?>` |
| `lib/features/settings/presentation/providers/sync_notifier.dart` | Wraps SyncService, exposes SyncStatus |

### Modified files

| File | Change |
|------|--------|
| `pubspec.yaml` | +5 new packages |
| `lib/main.dart` | `Firebase.initializeApp()` + `SharedPreferences.getInstance()` + provider override |
| `lib/features/dictionary/domain/entities/user_settings_state.dart` | +`targetCefrLevel: CEFRLevel?` |
| `lib/features/dictionary/presentation/providers/user_settings_provider.dart` | Read/write SharedPreferences |
| `lib/features/vocabulary/domain/repositories/vocab_repository.dart` | `getAll()` +`maxCefrLevel` |
| `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart` | Filter by `cefrLevel.index` |
| `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart` | Pass `maxCefrLevel` through |
| `lib/features/practice/presentation/screens/practice_home_screen.dart` | CEFR filter UI + pass to use case |
| `lib/core/widgets/app_shell.dart` | 4th NavigationDestination + `/settings` routing |
| `lib/core/router/app_router.dart` | `/settings` GoRoute inside ShellRoute |
| `lib/core/di/app_providers.dart` | `sharedPreferencesProvider` (keepAlive, override) |

---

## Error Handling

- **Sign-in cancelled by user:** `GoogleSignIn().signIn()` returns `null` → return silently, no error shown
- **Sign-in failure (network):** catch in `signInWithGoogle()`, show `SnackBar('Đăng nhập thất bại. Thử lại.')`
- **Firestore write failure:** logged to console, `SyncStatus.error` for 5s then resets to idle — never throws to UI
- **Firestore read conflict (same updatedAt):** remote wins (simpler, consistent)

## Testing

- `UserSettingsNotifier`: mock `SharedPreferences`, verify each setter writes correct key, verify `build()` loads from prefs
- `SyncService`: mock Hive boxes + Firestore, verify push on sign-in, verify merge on snapshot with older/newer updatedAt
- `GetVocabListUseCase`: verify `maxCefrLevel` filter passes through correctly
- `VocabRepositoryImpl`: verify `cefrLevel.index` filter returns correct subset
- No widget tests required for SettingsScreen (same as Plans 2+3)
