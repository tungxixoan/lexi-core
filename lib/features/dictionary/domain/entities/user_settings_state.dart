// lib/features/dictionary/domain/entities/user_settings_state.dart
import 'package:flutter/material.dart' show ThemeMode;
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'ai_provider.dart';
import 'language.dart';
import 'provider_config.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.aiEnabled,
    required this.activeProvider,
    required this.providerConfigs,
    this.targetCefrLevel,
    this.themePreference = ThemeMode.system,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  final Language targetLanguage;
  final bool aiEnabled;
  final AiProvider activeProvider;
  final Map<AiProvider, ProviderConfig> providerConfigs;
  final CEFRLevel? targetCefrLevel;
  final ThemeMode themePreference;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  // The active provider's config. Falls back to an empty default if not yet configured.
  ProviderConfig get activeConfig =>
      providerConfigs[activeProvider] ?? ProviderConfig.empty(activeProvider);

  /// AI is usable iff the active provider has a stored key ciphertext —
  /// mirrors how the web app infers "AI enabled". (The explicit `aiEnabled`
  /// toggle is being retired in a later plan; new call sites should read
  /// this instead.)
  bool get aiAvailable => activeConfig.apiKeyCiphertext?.isNotEmpty ?? false;

  static const _absent = Object();

  UserSettingsState copyWith({
    Language? targetLanguage,
    bool? aiEnabled,
    AiProvider? activeProvider,
    Map<AiProvider, ProviderConfig>? providerConfigs,
    Object? targetCefrLevel = _absent,
    ThemeMode? themePreference,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      UserSettingsState(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        activeProvider: activeProvider ?? this.activeProvider,
        providerConfigs: providerConfigs ?? this.providerConfigs,
        targetCefrLevel: identical(targetCefrLevel, _absent)
            ? this.targetCefrLevel
            : targetCefrLevel as CEFRLevel?,
        themePreference: themePreference ?? this.themePreference,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );

  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    aiEnabled: false,
    activeProvider: AiProvider.gemini,
    providerConfigs: {
      AiProvider.gemini: ProviderConfig(apiKeyCiphertext: null, model: 'gemini-2.5-flash'),
    },
    targetCefrLevel: null,
    themePreference: ThemeMode.system,
    reminderEnabled: false,
    reminderHour: 20,
    reminderMinute: 0,
  );
}
