// lib/features/dictionary/domain/entities/user_settings_state.dart
import 'app_context.dart';
import 'language.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.geminiApiKey,
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    String? geminiApiKey,
  }) =>
      UserSettingsState(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        activeContext: activeContext ?? this.activeContext,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      );

  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    activeContext: AppContext.general,
    aiEnabled: false,
    geminiApiKey: '',
  );
}
