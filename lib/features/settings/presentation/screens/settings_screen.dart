// lib/features/settings/presentation/screens/settings_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/encrypt_api_key.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../../features/dictionary/domain/entities/ai_provider.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/dictionary/domain/entities/user_settings_state.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../providers/auth_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final authAsync = ref.watch(authNotifierProvider);
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
                ? const SizedBox.shrink()
                : _SignedInSection(
                    user: user,
                    onSignOut: () =>
                        ref.read(authNotifierProvider.notifier).signOut(),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const ListTile(title: Text('Lỗi xác thực')),
          ),

          // ── AI ────────────────────────────────────────────────
          _SectionHeader('AI'),
          // Provider picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Provider',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                SegmentedButton<AiProvider>(
                  segments: AiProvider.values
                      .map((p) => ButtonSegment<AiProvider>(
                            value: p,
                            label: Text(p.label),
                          ))
                      .toList(),
                  selected: {settings.activeProvider},
                  onSelectionChanged: (s) {
                    if (s.isNotEmpty) notifier.setActiveProvider(s.first);
                  },
                ),
              ],
            ),
          ),
          // Model picker
          _ModelTile(
            settings: settings,
            onModelChanged: notifier.setModelForActiveProvider,
          ),
          // API Key
          ListTile(
            title: const Text('API Key'),
            subtitle: Text(
              (settings.activeConfig.apiKeyCiphertext?.isNotEmpty ?? false)
                  ? 'Đã cài đặt'
                  : 'Chưa cài đặt',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _showApiKeyDialog(
              context,
              ref,
              settings.activeConfig.apiKeyCiphertext?.isNotEmpty ?? false,
            ),
          ),

          // ── Học tập ───────────────────────────────────────────
          _SectionHeader('Học tập'),
          ListTile(
            title: const Text('Ngôn ngữ mục tiêu'),
            subtitle: Text(
              settings.targetLanguage.label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, ref, settings.targetLanguage),
          ),
          ListTile(
            title: const Text('Cấp độ mục tiêu'),
            subtitle: Text(
              settings.targetCefrLevel?.label ?? 'Tất cả',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _showCefrPicker(context, ref, settings.targetCefrLevel),
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
      BuildContext context, WidgetRef ref, bool isConfigured) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ApiKeyDialog(
        isConfigured: isConfigured,
        encryptor: ref.read(apiKeyEncryptorProvider),
        onSave: (ciphertext) => ref
            .read(userSettingsNotifierProvider.notifier)
            .setApiKeyCiphertextForActiveProvider(ciphertext),
      ),
    );
  }

  Future<void> _pickLanguage(
      BuildContext context, WidgetRef ref, Language current) async {
    final result = await showSingleSelectSheet<Language>(
      context: context,
      title: 'Ngôn ngữ mục tiêu',
      options: Language.values
          .map((l) => SelectOption(value: l, label: l.label))
          .toList(),
      selected: current,
    );
    if (result != null) {
      ref
          .read(userSettingsNotifierProvider.notifier)
          .setTargetLanguage(result.value);
    }
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
        .setReminderTime(picked.hour, picked.minute);
  }
}

// ── Model tile with preset dropdown + free-text "Khác..." option ──────────

class _ModelTile extends ConsumerWidget {
  const _ModelTile({required this.settings, required this.onModelChanged});
  final UserSettingsState settings;
  final void Function(String) onModelChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = settings.activeProvider.modelPresets;
    final currentModel = settings.activeConfig.model.isEmpty
        ? settings.activeProvider.defaultModel
        : settings.activeConfig.model;
    final isCustom = !presets.contains(currentModel);

    return ListTile(
      title: const Text('Model'),
      subtitle: Text(currentModel),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showModelPicker(context, presets, currentModel, isCustom),
    );
  }

  void _showModelPicker(
    BuildContext context,
    List<String> presets,
    String currentModel,
    bool isCustom,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom)
              RadioListTile<String>(
                title: Text(currentModel),
                subtitle: const Text('Tuỳ chỉnh'),
                value: currentModel,
                groupValue: currentModel,
                onChanged: (_) => Navigator.pop(ctx),
              ),
            ...presets.map((model) => RadioListTile<String>(
                  title: Text(model),
                  value: model,
                  groupValue: currentModel,
                  onChanged: (v) {
                    if (v != null) onModelChanged(v);
                    Navigator.pop(ctx);
                  },
                )),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Khác...'),
              onTap: () {
                Navigator.pop(ctx);
                _showCustomModelDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomModelDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CustomModelDialog(
        currentModel: settings.activeConfig.model,
        onSave: onModelChanged,
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

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

class _SignedInSection extends StatelessWidget {
  const _SignedInSection({
    required this.user,
    required this.onSignOut,
  });
  final User user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            user.photoURL != null ? NetworkImage(user.photoURL!) : null,
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
    );
  }
}

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({
    required this.isConfigured,
    required this.encryptor,
    required this.onSave,
  });
  final bool isConfigured;
  final ApiKeyEncryptor encryptor;
  final void Function(String ciphertext) onSave;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ciphertext = await widget.encryptor.encrypt(raw);
      widget.onSave(ciphertext);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is EncryptApiKeyException
            ? e.message
            : 'Không thể mã hoá API key. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            obscureText: true,
            enabled: !_saving,
            decoration: InputDecoration(
              hintText: widget.isConfigured ? '••••••••' : 'Nhập API key...',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}

class _CustomModelDialog extends StatefulWidget {
  const _CustomModelDialog({required this.currentModel, required this.onSave});
  final String currentModel;
  final void Function(String) onSave;

  @override
  State<_CustomModelDialog> createState() => _CustomModelDialogState();
}

class _CustomModelDialogState extends State<_CustomModelDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentModel);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tên model'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          hintText: 'vd: gemini-2.5-pro, openai/gpt-oss-20b...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            final model = _ctrl.text.trim();
            if (model.isNotEmpty) widget.onSave(model);
            Navigator.pop(context);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
