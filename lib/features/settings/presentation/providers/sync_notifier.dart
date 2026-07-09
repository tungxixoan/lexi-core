import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import 'auth_notifier.dart';

part 'sync_notifier.g.dart';

const _kStoredUid = 'sync_last_uid';

@Riverpod(keepAlive: true)
class SyncNotifier extends _$SyncNotifier {
  SyncService? _service;

  @override
  SyncStatus build() {
    final initialUser = ref.read(authNotifierProvider).valueOrNull;
    if (initialUser != null) {
      Future.microtask(() => _startSync(initialUser.uid));
    }
    ref.listen<AsyncValue<User?>>(authNotifierProvider, (_, next) {
      final user = next.valueOrNull;
      if (user != null) {
        _startSync(user.uid);
      } else {
        _stopSync();
      }
    });
    return SyncStatus.idle;
  }

  Future<void> _startSync(String uid) async {
    _service?.stopSync();

    // Clear local data if signing in as a different account than last time.
    // This prevents account A's data leaking into account B's Firestore.
    final prefs = ref.read(sharedPreferencesProvider);
    final lastUid = prefs.getString(_kStoredUid);
    if (lastUid != null && lastUid != uid) {
      await Hive.box<String>('vocab_records').clear();
      await Hive.box<String>('topics').clear();
    }
    await prefs.setString(_kStoredUid, uid);

    _service = SyncService(
      vocabBox: Hive.box<String>('vocab_records'),
      topicsBox: Hive.box<String>('topics'),
    );
    final settings = ref.read(userSettingsNotifierProvider);
    await _service!.startSync(uid, settings, (status) => state = status);
  }

  void _stopSync() {
    _service?.stopSync();
    _service = null;
    state = SyncStatus.idle;
    // Hive is intentionally NOT cleared here — local data is authoritative
    // and may include offline changes not yet synced to Firestore.
    // Account isolation is handled by the uid mismatch check in _startSync().
  }
}
