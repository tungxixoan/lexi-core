import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/dictionary/domain/entities/user_settings_state.dart';
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

          // ── Thông báo ─────────────────────────────────────────
          _SectionHeader('Thông báo'),
          SwitchListTile(
            title: const Text('Nhắc nhở hàng ngày'),
            subtitle: const Text('Thông báo khi có từ cần ôn'),
            value: settings.reminderEnabled,
            onChanged: (v) => notifier.setReminderEnabled(enabled: v),
          ),
          if (settings.reminderEnabled)
            ListTile(
              title: const Text('Giờ nhắc cố định'),
              trailing: Text(
                '${settings.reminderHour.toString().padLeft(2, '0')}:'
                '${settings.reminderMinute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              onTap: () => _showTimePicker(context, ref, settings),
            ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(
      BuildContext context, WidgetRef ref, String currentKey) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ApiKeyDialog(
        currentKey: currentKey,
        onSave: (key) => ref
            .read(userSettingsNotifierProvider.notifier)
            .setGeminiApiKey(key),
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

  Future<void> _showTimePicker(
      BuildContext context, WidgetRef ref, UserSettingsState settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (picked == null) return;
    ref
        .read(userSettingsNotifierProvider.notifier)
        .setReminderHour(picked.hour);
    ref
        .read(userSettingsNotifierProvider.notifier)
        .setReminderMinute(picked.minute);
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

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.currentKey, required this.onSave});
  final String currentKey;
  final void Function(String) onSave;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gemini API Key'),
      content: TextField(
        controller: _ctrl,
        obscureText: true,
        decoration: const InputDecoration(
          hintText: 'AIza...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            widget.onSave(_ctrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
