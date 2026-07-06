// lib/features/dictionary/domain/entities/user_settings_state.dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'app_context.dart';
import 'language.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.geminiApiKey,
    this.targetCefrLevel,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.showReadingPracticeOnMobile = false,
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  final CEFRLevel? targetCefrLevel;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool showReadingPracticeOnMobile;

  static const _absent = Object();

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    String? geminiApiKey,
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
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
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
    geminiApiKey: '',
    targetCefrLevel: null,
    reminderEnabled: false,
    reminderHour: 20,
    reminderMinute: 0,
    showReadingPracticeOnMobile: false,
  );
}
