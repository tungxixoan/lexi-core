// lib/features/dictionary/domain/entities/user_settings_state.dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'ai_provider.dart';
import 'app_context.dart';
import 'language.dart';
import 'provider_config.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.activeProvider,
    required this.providerConfigs,
    this.targetCefrLevel,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.showReadingPracticeOnMobile = false,
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final AiProvider activeProvider;
  final Map<AiProvider, ProviderConfig> providerConfigs;
  final CEFRLevel? targetCefrLevel;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool showReadingPracticeOnMobile;

  // The active provider's config. Falls back to an empty default if not yet configured.
  ProviderConfig get activeConfig =>
      providerConfigs[activeProvider] ?? ProviderConfig.empty(activeProvider);

  static const _absent = Object();

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    AiProvider? activeProvider,
    Map<AiProvider, ProviderConfig>? providerConfigs,
    Object? targetCefrLevel = _absent,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? showReadingPracticeOnMobile,
  }) =>
      UserSettingsState(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        activeContext: activeContext ?? this.activeContext,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        activeProvider: activeProvider ?? this.activeProvider,
        providerConfigs: providerConfigs ?? this.providerConfigs,
        targetCefrLevel: identical(targetCefrLevel, _absent)
            ? this.targetCefrLevel
            : targetCefrLevel as CEFRLevel?,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        showReadingPracticeOnMobile:
            showReadingPracticeOnMobile ?? this.showReadingPracticeOnMobile,
      );

  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    activeContext: AppContext.general,
    aiEnabled: false,
    activeProvider: AiProvider.gemini,
    providerConfigs: {
      AiProvider.gemini: ProviderConfig(apiKey: '', model: 'gemini-2.5-flash'),
    },
    targetCefrLevel: null,
    reminderEnabled: false,
    reminderHour: 20,
    reminderMinute: 0,
    showReadingPracticeOnMobile: false,
  );
}
