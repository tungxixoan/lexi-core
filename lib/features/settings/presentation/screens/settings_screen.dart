// lib/features/settings/presentation/screens/settings_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/encrypt_api_key.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/filter_tile.dart';
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
    final c = context.bloom;

    final subLabelStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: c.inkSoft,
    );

    return BloomScaffold(
      appBar: const BloomAppBar(
        title: 'Cài đặt',
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tài khoản ─────────────────────────────────────────
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BloomSectionHeader('Tài khoản'),
                authAsync.when(
                  data: (user) => user == null
                      ? const SizedBox.shrink()
                      : _SignedInSection(
                          user: user,
                          onSignOut: () =>
                              ref.read(authNotifierProvider.notifier).signOut(),
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(
                    'Lỗi xác thực',
                    style: TextStyle(color: c.danger),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── AI ────────────────────────────────────────────────
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BloomSectionHeader('AI'),
                Text('Provider', style: subLabelStyle),
                const SizedBox(height: BloomSpacing.sm),
                BloomSegmented<AiProvider>(
                  segments: AiProvider.values
                      .map((p) => BloomSegment(value: p, label: p.label))
                      .toList(),
                  selected: settings.activeProvider,
                  onChanged: notifier.setActiveProvider,
                ),
                const SizedBox(height: BloomSpacing.sm),
                _ModelTile(
                  settings: settings,
                  onModelChanged: notifier.setModelForActiveProvider,
                ),
                FilterTile(
                  icon: Icons.key_outlined,
                  label: 'API Key',
                  value: (settings.activeConfig.apiKeyCiphertext?.isNotEmpty ??
                          false)
                      ? 'Đã cài đặt'
                      : 'Chưa cài đặt',
                  onTap: () => _showApiKeyDialog(
                    context,
                    ref,
                    settings.activeConfig.apiKeyCiphertext?.isNotEmpty ?? false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Học tập ───────────────────────────────────────────
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BloomSectionHeader('Học tập'),
                FilterTile(
                  icon: Icons.language_outlined,
                  label: 'Ngôn ngữ mục tiêu',
                  value: settings.targetLanguage.label,
                  onTap: () =>
                      _pickLanguage(context, ref, settings.targetLanguage),
                ),
                FilterTile(
                  icon: Icons.school_outlined,
                  label: 'Cấp độ mục tiêu',
                  value: settings.targetCefrLevel?.label ?? 'Tất cả',
                  onTap: () =>
                      _showCefrPicker(context, ref, settings.targetCefrLevel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Giao diện ─────────────────────────────────────────
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BloomSectionHeader('Giao diện'),
                Text('Chủ đề', style: subLabelStyle),
                const SizedBox(height: BloomSpacing.sm),
                BloomSegmented<ThemeMode>(
                  segments: const [
                    BloomSegment(value: ThemeMode.light, label: 'Sáng'),
                    BloomSegment(value: ThemeMode.dark, label: 'Tối'),
                    BloomSegment(value: ThemeMode.system, label: 'Hệ thống'),
                  ],
                  selected: settings.themePreference,
                  onChanged: notifier.setThemePreference,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Thông báo ─────────────────────────────────────────
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BloomSectionHeader('Thông báo'),
                BloomSwitch(
                  title: 'Nhắc nhở hàng ngày',
                  subtitle: 'Thông báo khi có từ cần ôn',
                  value: settings.reminderEnabled,
                  onChanged: (v) => notifier.setReminderEnabled(enabled: v),
                ),
                if (settings.reminderEnabled) ...[
                  const SizedBox(height: BloomSpacing.sm),
                  FilterTile(
                    icon: Icons.schedule,
                    label: 'Giờ nhắc cố định',
                    value:
                        '${settings.reminderHour.toString().padLeft(2, '0')}:'
                        '${settings.reminderMinute.toString().padLeft(2, '0')}',
                    onTap: () => _showTimePicker(context, ref, settings),
                  ),
                ],
              ],
            ),
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

  Future<void> _showCefrPicker(
      BuildContext context, WidgetRef ref, CEFRLevel? current) async {
    final picked = await showSingleSelectSheet<CEFRLevel?>(
      context: context,
      title: 'Cấp độ mục tiêu',
      options: [
        const SelectOption<CEFRLevel?>(value: null, label: 'Tất cả'),
        ...CEFRLevel.values
            .map((l) => SelectOption<CEFRLevel?>(value: l, label: l.label)),
      ],
      selected: current,
    );
    // `showSingleSelectSheet` returns null only on dismiss; an explicit pick of
    // the "Tất cả" row comes back as a non-null option whose `.value` is null —
    // which is exactly the intended `setTargetCefrLevel(null)`.
    if (picked != null) {
      ref
          .read(userSettingsNotifierProvider.notifier)
          .setTargetCefrLevel(picked.value);
    }
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

// ── Model tile with preset picker + free-text "Khác…" option ─────────────────

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.settings, required this.onModelChanged});
  final UserSettingsState settings;
  final void Function(String) onModelChanged;

  @override
  Widget build(BuildContext context) {
    final presets = settings.activeProvider.modelPresets;
    final currentModel = settings.activeConfig.model.isEmpty
        ? settings.activeProvider.defaultModel
        : settings.activeConfig.model;
    final isCustom = !presets.contains(currentModel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterTile(
          icon: Icons.psychology_outlined,
          label: 'Model',
          value: currentModel,
          onTap: () =>
              _showModelPicker(context, presets, currentModel, isCustom),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: BloomPillButton(
            variant: BloomButtonVariant.link,
            label: 'Nhập model khác…',
            onPressed: () => _showCustomModelDialog(context),
          ),
        ),
      ],
    );
  }

  Future<void> _showModelPicker(
    BuildContext context,
    List<String> presets,
    String currentModel,
    bool isCustom,
  ) async {
    final picked = await showSingleSelectSheet<String>(
      context: context,
      title: 'Model',
      options: [
        // Keep the current model visible/selected when it's a custom value
        // not in this provider's presets.
        if (isCustom) SelectOption(value: currentModel, label: currentModel),
        ...presets.map((m) => SelectOption(value: m, label: m)),
      ],
      selected: currentModel,
    );
    if (picked != null) onModelChanged(picked.value);
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

class _SignedInSection extends StatelessWidget {
  const _SignedInSection({
    required this.user,
    required this.onSignOut,
  });
  final User user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final hasName = user.displayName?.isNotEmpty ?? false;
    final initial = hasName ? user.displayName![0].toUpperCase() : '?';

    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: user.photoURL != null
              ? CircleAvatar(backgroundImage: NetworkImage(user.photoURL!))
              : Container(
                  decoration: BoxDecoration(
                    gradient: BloomGradients.leafMark(c),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: c.accentInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName ?? 'Người dùng',
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
              ),
              Text(
                user.email ?? '',
                style: TextStyle(color: c.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        BloomPillButton(
          label: 'Đăng xuất',
          variant: BloomButtonVariant.danger,
          onPressed: onSignOut,
        ),
      ],
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
          BloomTextField(
            controller: _ctrl,
            obscureText: true,
            enabled: !_saving,
            hintText: widget.isConfigured ? '••••••••' : 'Nhập API key...',
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: context.bloom.danger)),
          ],
        ],
      ),
      actions: [
        BloomPillButton(
          label: 'Huỷ',
          variant: BloomButtonVariant.link,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          BloomPillButton(
            label: 'Lưu',
            onPressed: () => _save(),
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
      content: BloomTextField(
        controller: _ctrl,
        hintText: 'vd: gemini-2.5-pro, openai/gpt-oss-20b...',
      ),
      actions: [
        BloomPillButton(
          label: 'Huỷ',
          variant: BloomButtonVariant.link,
          onPressed: () => Navigator.pop(context),
        ),
        BloomPillButton(
          label: 'Lưu',
          onPressed: () {
            final model = _ctrl.text.trim();
            if (model.isNotEmpty) widget.onSave(model);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
