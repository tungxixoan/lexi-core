// lib/core/services/ai_settings_sync_service.dart
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/dictionary/domain/entities/ai_provider.dart';
import '../../features/dictionary/domain/entities/language.dart';
import '../../features/dictionary/domain/entities/provider_config.dart';
import '../../features/dictionary/presentation/providers/user_settings_provider.dart';
import 'encrypt_api_key.dart';

/// Syncs the AI-related subset of UserSettingsState
/// (activeProvider/providerConfigs/targetLanguage) with the same
/// `users/{uid}/settings/config` Firestore document apps/web/ already reads
/// and writes (apps/web/src/lib/settings.ts) — no live listener, just a
/// one-shot fetch-and-merge on bootstrap plus a best-effort push whenever
/// UserSettingsNotifier changes one of these fields locally.
///
/// Deliberately NOT a Riverpod provider's own logic host — it's a plain
/// injectable class (mirrors HiveMigrationService's shape), wired into
/// UserSettingsNotifier via the aiSettingsSyncServiceProvider seam so tests
/// can substitute a fake.
class AiSettingsSyncService {
  AiSettingsSyncService(
      {FirebaseFirestore? firestore, ApiKeyEncryptor? encryptor})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryptor = encryptor ?? ApiKeyEncryptor();

  final FirebaseFirestore _firestore;
  final ApiKeyEncryptor _encryptor;

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('config');

  /// One-shot fetch: pulls `users/{uid}/settings/config` and applies it onto
  /// [notifier] (remote wins for any provider Firestore already has data
  /// for), then migrates any local pre-encryption plaintext key Firestore
  /// had nothing for. Never throws — a failure here must never block app
  /// startup; [notifier]'s local SharedPreferences state stays authoritative
  /// for this session if the fetch (or a migration encryption call) fails.
  Future<void> bootstrapSync(String uid, UserSettingsNotifier notifier) async {
    try {
      final snapshot = await _settingsDoc(uid).get();
      final remote = snapshot.data();
      final remoteProviders = remote?['providers'];

      final legacyToMigrate = <AiProvider, String>{};
      for (final provider in AiProvider.values) {
        final remoteEntry = remoteProviders is Map<String, dynamic>
            ? remoteProviders[provider.cloudId]
            : null;
        if (remoteEntry is Map<String, dynamic>) {
          final remoteCiphertext = remoteEntry['apiKeyCiphertext'] as String?;
          if (remoteCiphertext != null && remoteCiphertext.isNotEmpty) {
            notifier.setProviderConfig(
              provider,
              ProviderConfig(
                apiKeyCiphertext: remoteCiphertext,
                model: remoteEntry['model'] as String? ?? provider.defaultModel,
              ),
              sync: false,
            );
            continue;
          }
          // Remote has an entry for this provider but no key (e.g.
          // apps/web/'s saveSettings persists its full
          // DEFAULT_SETTINGS.providers map, including apiKeyCiphertext:
          // null for every unconfigured provider, whenever ANY unrelated
          // field is saved from the web app). Treating that as "remote
          // wins" would silently blank out a real local key that simply
          // hasn't been pushed yet — fall through to the same
          // legacy-migration check as "no remote entry at all" instead.
        }
        final legacyKey = notifier.legacyPlaintextApiKey(provider);
        if (legacyKey != null) legacyToMigrate[provider] = legacyKey;
      }

      final remoteActiveId = remote?['activeProvider'];
      if (remoteActiveId is String) {
        final remoteActive = aiProviderFromCloudId(remoteActiveId);
        if (remoteActive != null) {
          notifier.setActiveProvider(remoteActive, sync: false);
        }
      }

      final remoteLanguage = remote?['targetLanguage'];
      if (remoteLanguage is String) {
        for (final lang in Language.values) {
          if (lang.name == remoteLanguage) {
            notifier.setTargetLanguage(lang, sync: false);
            break;
          }
        }
      }

      // Migrate any legacy plaintext key Firestore had nothing for. This
      // deliberately calls setProviderConfig with its default sync: true —
      // that fires the same best-effort push every other local change does,
      // so the newly-encrypted key reaches Firestore without this method
      // needing its own separate call to pushProviderSettings.
      for (final entry in legacyToMigrate.entries) {
        String ciphertext;
        try {
          ciphertext = await _encryptor.encrypt(entry.value);
        } catch (_) {
          // Best-effort — try again on the next bootstrap.
          continue;
        }
        final model = notifier.state.providerConfigs[entry.key]?.model ??
            entry.key.defaultModel;
        notifier.setProviderConfig(
          entry.key,
          ProviderConfig(apiKeyCiphertext: ciphertext, model: model),
        );
      }
    } catch (_) {
      // Best-effort: any Firestore fetch failure (offline, first launch,
      // permission issue) leaves local state as-is for this session.
    }
  }

  /// Best-effort push of the current synced fields to Firestore. Never
  /// throws — UserSettingsNotifier fires this without awaiting it.
  Future<void> pushProviderSettings(
    String uid,
    AiProvider activeProvider,
    Map<AiProvider, ProviderConfig> providerConfigs,
    Language targetLanguage,
  ) async {
    try {
      await _settingsDoc(uid).set({
        'activeProvider': activeProvider.cloudId,
        'providers': {
          for (final entry in providerConfigs.entries)
            entry.key.cloudId: {
              'model': entry.value.model,
              // Omit apiKeyCiphertext entirely when this device has no key
              // for this provider, rather than writing an explicit null.
              // Firestore's merge:true is a deep merge on nested maps: an
              // explicit null here WOULD overwrite a real key already
              // configured on another device/platform — the same
              // null-blanking bug already fixed on the read side
              // (bootstrapSync's remote-wins branch), now closed here too
              // on the write side.
              if (entry.value.apiKeyCiphertext != null &&
                  entry.value.apiKeyCiphertext!.isNotEmpty)
                'apiKeyCiphertext': entry.value.apiKeyCiphertext,
            },
        },
        'targetLanguage': targetLanguage.name,
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort — see class doc.
    }
  }
}
