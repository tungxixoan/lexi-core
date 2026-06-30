# Task 4: TTS Service

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 2 (`Language` enum with `.ttsLocale` getter)

## What This Task Delivers
An abstract `TtsService` interface + `FlutterTtsService` implementation. Abstract so widgets can be tested with a mock. No unit test for the impl (wraps a device plugin — tested during manual run in Task 15).

## Files
- Create: `lib/services/tts_service.dart`

## Produces (used by Tasks 10, 14)
```dart
abstract class TtsService {
  Future<void> speak(String text, Language language);
  Future<void> stop();
}

class FlutterTtsService implements TtsService { ... }
```

## Steps

- [ ] **Step 1: Create tts_service.dart**

```dart
// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';

abstract class TtsService {
  Future<void> speak(String text, Language language);
  Future<void> stop();
}

class FlutterTtsService implements TtsService {
  FlutterTtsService(this._tts);

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, Language language) async {
    await _tts.setLanguage(language.ttsLocale);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}
```

- [ ] **Step 2: Verify compilation**

```bash
flutter analyze lib/services/tts_service.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/tts_service.dart
git commit -m "feat: add TtsService abstraction wrapping flutter_tts"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: N/A (device plugin — no unit test)
Concerns: (if any)
