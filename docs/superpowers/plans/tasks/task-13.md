# Task 13: Search Bar + Discover Button Widget

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 10, 11

## Interfaces From Prior Tasks
- `lookupNotifierProvider.notifier` → `LookupNotifier`
  - `LookupNotifier.lookup(String query)` — triggers lookup
  - `LookupNotifier.discover()` — triggers AI discover
- `userSettingsNotifierProvider` → `UserSettingsState`
  - `UserSettingsState.aiEnabled` — bool; Discover button only shown when true

## What This Task Delivers
A `ConsumerStatefulWidget` with a `TextField` for input, a search `IconButton`, and a Discover `IconButton` (visible only when AI is enabled).

## Files
- Create: `lib/features/dictionary/presentation/widgets/search_bar_widget.dart`

No widget test for this task — interaction is covered end-to-end in Task 15.

## Steps

- [ ] **Step 1: Implement search_bar_widget.dart**

```dart
// lib/features/dictionary/presentation/widgets/search_bar_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lookup_provider.dart';
import '../providers/user_settings_provider.dart';

class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  final _controller = TextEditingController();

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    ref.read(lookupNotifierProvider.notifier).lookup(query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiEnabled = ref.watch(
      userSettingsNotifierProvider.select((s) => s.aiEnabled),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Word, phrase, or sentence...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.search),
            onPressed: _submit,
            tooltip: 'Lookup',
          ),
          if (aiEnabled) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.auto_awesome),
              onPressed: () =>
                  ref.read(lookupNotifierProvider.notifier).discover(),
              tooltip: 'Discover a new word',
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
flutter analyze lib/features/dictionary/presentation/widgets/search_bar_widget.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dictionary/presentation/widgets/search_bar_widget.dart
git commit -m "feat: add SearchBarWidget with lookup input and AI Discover button"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: N/A (covered in Task 15 manual verification)
Concerns: (if any)
