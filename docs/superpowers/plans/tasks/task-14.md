# Task 14: Result Widgets (Word/Phrase + Sentence)

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 2, 4, 10, 11

## Interfaces From Prior Tasks
- `WordPhraseResult` fields: `headword`, `ipa`, `meaning`, `examples (List<String>)`, `suggestedTopics (List<String>)`, `inputType`
- `SentenceResult` fields: `original`, `translation`
- `ttsServiceProvider` → `TtsService` with `speak(String text, Language language)`
- `userSettingsNotifierProvider` → `UserSettingsState` with `targetLanguage`

## What This Task Delivers
Two display widgets:
1. `WordResultWidget` — shows headword, IPA, TTS button (word), meaning, examples with TTS buttons, topic chips
2. `SentenceResultWidget` — shows original sentence, translation, TTS button (sentence)

## Files
- Create: `lib/features/dictionary/presentation/widgets/word_result_widget.dart`
- Create: `lib/features/dictionary/presentation/widgets/sentence_result_widget.dart`

## Steps

- [ ] **Step 1: Implement word_result_widget.dart**

```dart
// lib/features/dictionary/presentation/widgets/word_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';

class WordResultWidget extends ConsumerWidget {
  const WordResultWidget({super.key, required this.result});

  final WordPhraseResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetLanguage = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final tts = ref.read(ttsServiceProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.headword,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Pronounce word',
                  onPressed: () => tts.speak(result.headword, targetLanguage),
                ),
              ],
            ),
            if (result.ipa.isNotEmpty)
              Text(
                result.ipa,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 8),
            Text(result.meaning, style: theme.textTheme.bodyLarge),
            if (result.examples.isNotEmpty) ...[
              const Divider(height: 24),
              ...result.examples.map(
                (ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ex,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 18),
                        tooltip: 'Pronounce example',
                        onPressed: () => tts.speak(ex, targetLanguage),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (result.suggestedTopics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: result.suggestedTopics
                    .map((t) => Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement sentence_result_widget.dart**

```dart
// lib/features/dictionary/presentation/widgets/sentence_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';

class SentenceResultWidget extends ConsumerWidget {
  const SentenceResultWidget({super.key, required this.result});

  final SentenceResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetLanguage = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final tts = ref.read(ttsServiceProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.original,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Pronounce sentence',
                  onPressed: () =>
                      tts.speak(result.original, targetLanguage),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.translation,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify compilation**

```bash
flutter analyze lib/features/dictionary/presentation/widgets/word_result_widget.dart \
               lib/features/dictionary/presentation/widgets/sentence_result_widget.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dictionary/presentation/widgets/word_result_widget.dart \
        lib/features/dictionary/presentation/widgets/sentence_result_widget.dart
git commit -m "feat: add WordResultWidget and SentenceResultWidget with IPA and TTS"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: N/A (visual widgets — verified during Task 15 flutter run)
Concerns: (if any)
