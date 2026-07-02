import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import 'auth_notifier.dart';

part 'sync_notifier.g.dart';

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
  }
}
