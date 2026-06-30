// lib/features/dictionary/presentation/providers/user_settings_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/user_settings_state.dart';

part 'user_settings_provider.g.dart';

@riverpod
class UserSettingsNotifier extends _$UserSettingsNotifier {
  @override
  UserSettingsState build() => UserSettingsState.defaults;

  void setTargetLanguage(Language lang) =>
      state = state.copyWith(targetLanguage: lang);

  void setActiveContext(AppContext context) =>
      state = state.copyWith(activeContext: context);

  void setAiEnabled({required bool enabled}) =>
      state = state.copyWith(aiEnabled: enabled);

  void setGeminiApiKey(String key) =>
      state = state.copyWith(geminiApiKey: key);
}
