# Task 1: Flutter Project Setup

**Project:** LexiCore — personal vocabulary-driven language learning app (Flutter, Clean Architecture)
**Working directory:** `d:/Flutter/lexi-core`

## Global Constraints
- Flutter SDK: >=3.22.0 · Dart SDK: >=3.4.0
- Target platforms: iOS, Android only
- State management: Riverpod 2.x with `@riverpod` annotation
- Navigation: GoRouter only

## What This Task Delivers
A Flutter project with all dependencies installed and folder structure created. No application code yet.

## Files
- Create: `pubspec.yaml` (replace generated one)
- Create: all `lib/` and `test/` subdirectories per structure below
- Delete: generated `lib/main.dart` content (will be replaced in Task 11)
- Delete: `test/widget_test.dart`

## Target Folder Structure
```
lib/
├── core/di/
├── core/router/
├── core/theme/
├── core/utils/
├── services/
└── features/dictionary/
    ├── domain/entities/
    ├── domain/repositories/
    ├── domain/use_cases/
    ├── data/sources/
    ├── data/repositories/
    └── presentation/providers/
    └── presentation/screens/
    └── presentation/widgets/

test/
├── core/utils/
└── features/dictionary/
    ├── domain/use_cases/
    ├── data/sources/
    ├── data/repositories/
    └── presentation/providers/
    └── presentation/widgets/
```

## Steps

- [ ] **Step 1: Create Flutter project**

```bash
flutter create lexi_core --org com.lexicore --platforms android,ios
```

Note: This creates in a subdirectory. Move contents up if needed, or run in parent dir and work inside `lexi_core/`.

- [ ] **Step 2: Replace pubspec.yaml**

```yaml
name: lexi_core
description: Personal vocabulary-driven language learning app.
version: 1.0.0+1

environment:
  sdk: ">=3.4.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  go_router: ^14.6.2
  http: ^1.2.2
  flutter_tts: ^4.2.0
  google_generative_ai: ^0.4.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  riverpod_generator: ^2.6.1
  build_runner: ^2.4.13
  mockito: ^5.4.4
```

- [ ] **Step 3: Install dependencies**

```bash
flutter pub get
```

Expected: resolves without error.

- [ ] **Step 4: Create folder structure**

```bash
mkdir -p lib/core/di lib/core/router lib/core/theme lib/core/utils
mkdir -p lib/services
mkdir -p lib/features/dictionary/domain/entities
mkdir -p lib/features/dictionary/domain/repositories
mkdir -p lib/features/dictionary/domain/use_cases
mkdir -p lib/features/dictionary/data/sources
mkdir -p lib/features/dictionary/data/repositories
mkdir -p lib/features/dictionary/presentation/providers
mkdir -p lib/features/dictionary/presentation/screens
mkdir -p lib/features/dictionary/presentation/widgets
mkdir -p test/core/utils
mkdir -p test/features/dictionary/domain/use_cases
mkdir -p test/features/dictionary/data/sources
mkdir -p test/features/dictionary/data/repositories
mkdir -p test/features/dictionary/presentation/providers
mkdir -p test/features/dictionary/presentation/widgets
```

- [ ] **Step 5: Clean up boilerplate**

Delete contents of `lib/main.dart` (replace with empty file — Task 11 will write it).
Delete `test/widget_test.dart`.

- [ ] **Step 6: Verify**

```bash
flutter doctor
flutter analyze
```

Expected: no blocking errors.

- [ ] **Step 7: Init git and commit**

```bash
git init
git add pubspec.yaml pubspec.lock
git commit -m "feat: initialize LexiCore Flutter project"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: N/A (no tests in this task)
Concerns: (if any)
