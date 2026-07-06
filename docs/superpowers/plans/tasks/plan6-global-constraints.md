# Plan 6 — Global Constraints

- Flutter SDK >=3.22.0, Dart >=3.4.0
- Target platforms: Android, iOS, **Web**
- Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- Navigation: GoRouter only — no `Navigator.push`
- All domain entities: immutable, `const` constructors, no public setters; mutation via `copyWith`
- `kIsWeb` import: `import 'package:flutter/foundation.dart' show kIsWeb;`
- Adaptive nav breakpoints: `<600dp` → `NavigationBar`, `600–1199dp` → `NavigationRail` (collapsed), `≥1200dp` → `NavigationRail` (extended)
- `geminiApiKey` is **NEVER** stored in Firestore — `SharedPreferences` only
- Hive storage: `Box<String>` with JSON — no Hive code generation
