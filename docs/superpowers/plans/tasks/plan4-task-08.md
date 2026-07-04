# Plan 4 — Task 08: SettingsScreen full UI

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 02 (userSettingsNotifierProvider + setters), Task 05 (SettingsScreen placeholder exists), Task 06 (authNotifierProvider), Task 07 (syncNotifierProvider + SyncStatus)

## What this task builds

Replaces the spinner placeholder in `SettingsScreen` with the full settings UI:
- **Tài khoản section:** signed-out card with Google sign-in button, signed-in tile with avatar/name/email + sign-out button + sync status indicator
- **AI section:** switch for aiEnabled, conditional API key editor (shows last 4 chars of key)
- **Học tập section:** target language dropdown, CEFR target level picker (bottom sheet)

No new tests — UI-only.

## Files

- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

## Interfaces consumed

```dart
// userSettingsNotifierProvider — UserSettingsState + setters (Task 02)
// UserSettingsState: .targetLanguage, .activeContext, .aiEnabled, .geminiApiKey, .targetCefrLevel
// notifier methods: .setTargetLanguage(), .setActiveContext(), .setAiEnabled(), .setGeminiApiKey(), .setTargetCefrLevel()

// authNotifierProvider — AsyncValue<User?> (Task 06)
// ref.read(authNotifierProvider.notifier).signInWithGoogle()  — throws on failure
// ref.read(authNotifierProvider.notifier).signOut()

// syncNotifierProvider — SyncStatus (Task 07)
// enum SyncStatus { idle, syncing, error }  — in lib/core/services/sync_service.dart

// Language.values — for language dropdown
// Language.label  — display name (e.g. 'English', 'Chinese')

// CEFRLevel.values — for CEFR picker
// CEFRLevel.label  — 'A1', 'A2', etc.

// firebase_auth: User — .displayName, .email, .photoURL
```

---

- [ ] **Step 1: Replace SettingsScreen with full implementation**

Replace the full content of `lib/features/settings/presentation/screens/settings_screen.dart`:

```dart
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
          // ── Tài khoản ─────────────────────────────────────────
          _SectionHeader('Tài khoản'),
          authAsync.when(
            data: (user) => user == null
                ? _SignedOutCard(
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
                : _SignedInSection(
                    user: user,
                    syncStatus: syncStatus,
                    onSignOut: () =>
                        ref.read(authNotifierProvider.notifier).signOut(),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) =>
                const ListTile(title: Text('Lỗi xác thực')),
          ),

          // ── AI ────────────────────────────────────────────────
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
                    : '••••••••${settings.geminiApiKey.length > 4 ? settings.geminiApiKey.substring(settings.geminiApiKey.length - 4) : settings.geminiApiKey}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () =>
                  _showApiKeyDialog(context, ref, settings.geminiApiKey),
            ),

          // ── Học tập ───────────────────────────────────────────
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
            onTap: () => _showCefrPicker(
                context, ref, settings.targetCefrLevel),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(
      BuildContext context, WidgetRef ref, String currentKey) {
    final ctrl = TextEditingController(text: currentKey);
    showDialog<void>(
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

  void _showCefrPicker(
      BuildContext context, WidgetRef ref, CEFRLevel? current) {
    showModalBottomSheet<void>(
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

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard({required this.onSignIn});
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

class _SignedInSection extends StatelessWidget {
  const _SignedInSection({
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
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL == null
                ? Text(
                    (user.displayName?.isNotEmpty ?? false)
                        ? user.displayName![0].toUpperCase()
                        : '?',
                  )
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
                      ? Icons.sync_problem_outlined
                      : Icons.sync_outlined,
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

- [ ] **Step 3: Run full test suite**

```
flutter test
```

Expected: all prior tests still pass.

- [ ] **Step 4: Commit**

```
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat(plan4): implement full SettingsScreen with account, AI, and study sections"
```

## Self-review checklist

- [ ] `SettingsScreen` is `ConsumerWidget` (not StatelessWidget — it reads providers)
- [ ] `authNotifierProvider.notifier.signInWithGoogle()` is wrapped in try/catch → SnackBar on failure
- [ ] Sign-in error SnackBar text: `'Đăng nhập thất bại. Thử lại.'`
- [ ] `geminiApiKey` is ONLY in the local SharedPreferences dialog — no Firestore reference here
- [ ] API key display shows last 4 chars with mask: `••••••••XXXX`
- [ ] CEFR picker uses `RadioListTile<CEFRLevel?>` with `null` option at top ("Tất cả")
- [ ] `signOut` button calls `ref.read(authNotifierProvider.notifier).signOut()` (fire-and-forget, no await needed in onPressed)
- [ ] `SyncStatus.error` shows `Icons.sync_problem_outlined` in red
- [ ] `automaticallyImplyLeading: false` on AppBar (preserved from placeholder)
- [ ] `flutter analyze lib/` clean
