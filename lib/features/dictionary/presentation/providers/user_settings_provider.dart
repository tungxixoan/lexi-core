// lib/features/dictionary/presentation/providers/user_settings_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/provider_config.dart';
import '../../domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../../core/services/ai_settings_sync_service.dart';
import '../../../../core/services/encrypt_api_key.dart';

part 'user_settings_provider.g.dart';

// Overridden in main.dart with the real SharedPreferences instance.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError(
        'sharedPreferencesProvider must be overridden in main.dart');

// Overridden in tests with a fake to avoid a real Cloud Functions call.
@Riverpod(keepAlive: true)
ApiKeyEncryptor apiKeyEncryptor(ApiKeyEncryptorRef ref) => ApiKeyEncryptor();

// Overridden in tests with a fixed value to avoid touching real
// FirebaseAuth (which isn't initialized in plain unit tests).
@Riverpod(keepAlive: true)
String? currentUid(CurrentUidRef ref) => FirebaseAuth.instance.currentUser?.uid;

// Overridden in tests with a fake to verify push-on-change without a real
// Firestore/Cloud Functions round-trip.
@Riverpod(keepAlive: true)
AiSettingsSyncService aiSettingsSyncService(AiSettingsSyncServiceRef ref) =>
    AiSettingsSyncService();

@Riverpod(keepAlive: true)
class UserSettingsNotifier extends _$UserSettingsNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  AiSettingsSyncService get _syncService =>
      ref.read(aiSettingsSyncServiceProvider);

  /// Best-effort push of the fields AiSettingsSyncService syncs
  /// (activeProvider/providerConfigs/targetLanguage) to Firestore. Never
  /// throws — a failure here must never surface to a caller that just did a
  /// successful local SharedPreferences write.
  void _pushBestEffort() {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    unawaited(
      _syncService
          .pushProviderSettings(uid, state.activeProvider, state.providerConfigs,
              state.targetLanguage)
          .catchError((Object _) {}),
    );
  }

  /// Returns the raw legacy plaintext API key still stored under
  /// [provider]'s SharedPreferences entry, if that entry is still in the
  /// pre-encryption shape (`{"apiKey": "...", "model": "..."}` — no
  /// `apiKeyCiphertext` key) — i.e. a key entered before this update that
  /// hasn't been migrated to a Cloud KMS ciphertext yet. Returns null once
  /// migrated (or if nothing was ever stored for this provider).
  ///
  /// Used only by AiSettingsSyncService.bootstrapSync — ProviderConfig
  /// itself no longer reads the old `apiKey` field at all, so this is the
  /// one remaining place that inspects the raw pre-migration JSON shape.
  String? legacyPlaintextApiKey(AiProvider provider) {
    final raw = _prefs.getString('ai_config_${provider.name}');
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json.containsKey('apiKeyCiphertext')) return null;
    final legacy = json['apiKey'] as String?;
    return (legacy != null && legacy.isNotEmpty) ? legacy : null;
  }

  @override
  UserSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    // One-time silent migration from old gemini_api_key to new ai_config_* keys.
    if (!prefs.containsKey('ai_active_provider') &&
        prefs.containsKey('gemini_api_key')) {
      final oldKey = prefs.getString('gemini_api_key') ?? '';
      prefs.setString(
        'ai_config_gemini',
        jsonEncode({'apiKey': oldKey, 'model': 'gemini-2.5-flash'}),
      );
      prefs.setString('ai_active_provider', 'gemini');
      prefs.remove('gemini_api_key');
    }

    final activeProvider = AiProvider.values.byName(
      prefs.getString('ai_active_provider') ?? AiProvider.gemini.name,
    );

    final providerConfigs = <AiProvider, ProviderConfig>{};
    for (final provider in AiProvider.values) {
      final raw = prefs.getString('ai_config_${provider.name}');
      if (raw != null) {
        providerConfigs[provider] =
            ProviderConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    }

    return UserSettingsState(
      targetLanguage: Language.values.byName(
          prefs.getString('target_language') ?? Language.english.name),
      activeContext: AppContext.values.byName(
          prefs.getString('active_context') ?? AppContext.general.name),
      aiEnabled: prefs.getBool('ai_enabled') ?? false,
      activeProvider: activeProvider,
      providerConfigs: providerConfigs,
      targetCefrLevel: prefs.containsKey('target_cefr_level')
          ? CEFRLevel.values.byName(prefs.getString('target_cefr_level')!)
          : null,
      reminderEnabled: prefs.getBool('reminder_enabled') ?? false,
      reminderHour: prefs.getInt('reminder_hour') ?? 20,
      reminderMinute: prefs.getInt('reminder_minute') ?? 0,
    );
  }

  void setTargetLanguage(Language lang, {bool sync = true}) {
    _prefs.setString('target_language', lang.name);
    state = state.copyWith(targetLanguage: lang);
    if (sync) _pushBestEffort();
  }

  void setActiveContext(AppContext context) {
    _prefs.setString('active_context', context.name);
    state = state.copyWith(activeContext: context);
  }

  void setAiEnabled({required bool enabled}) {
    _prefs.setBool('ai_enabled', enabled);
    state = state.copyWith(aiEnabled: enabled);
  }

  void setActiveProvider(AiProvider provider, {bool sync = true}) {
    _prefs.setString('ai_active_provider', provider.name);
    state = state.copyWith(activeProvider: provider);
    if (sync) _pushBestEffort();
  }

  void setProviderConfig(AiProvider provider, ProviderConfig config, {bool sync = true}) {
    _prefs.setString(
      'ai_config_${provider.name}',
      jsonEncode(config.toJson()),
    );
    final updated = Map<AiProvider, ProviderConfig>.from(state.providerConfigs);
    updated[provider] = config;
    state = state.copyWith(providerConfigs: updated);
    if (sync) _pushBestEffort();
  }

  void setApiKeyCiphertextForActiveProvider(String ciphertext) {
    final current = state.activeConfig;
    setProviderConfig(
      state.activeProvider,
      ProviderConfig(apiKeyCiphertext: ciphertext, model: current.model),
    );
  }

  void setModelForActiveProvider(String model) {
    final current = state.activeConfig;
    setProviderConfig(
      state.activeProvider,
      ProviderConfig(apiKeyCiphertext: current.apiKeyCiphertext, model: model),
    );
  }

  void setTargetCefrLevel(CEFRLevel? level) {
    if (level == null) {
      _prefs.remove('target_cefr_level');
    } else {
      _prefs.setString('target_cefr_level', level.name);
    }
    state = state.copyWith(targetCefrLevel: level);
  }

  void setReminderEnabled({required bool enabled}) {
    _prefs.setBool('reminder_enabled', enabled);
    state = state.copyWith(reminderEnabled: enabled);
  }

  void setReminderHour(int hour) {
    _prefs.setInt('reminder_hour', hour);
    state = state.copyWith(reminderHour: hour);
  }

  void setReminderMinute(int minute) {
    _prefs.setInt('reminder_minute', minute);
    state = state.copyWith(reminderMinute: minute);
  }

  void setReminderTime(int hour, int minute) {
    _prefs.setInt('reminder_hour', hour);
    _prefs.setInt('reminder_minute', minute);
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
  }
}
