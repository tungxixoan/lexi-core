import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';

part 'notification_notifier.g.dart';

@Riverpod(keepAlive: true)
class NotificationNotifier extends _$NotificationNotifier {
  final _service = NotificationService();

  @override
  void build() {
    if (kIsWeb) return;
    _service.initialize();
    ref.listen(userSettingsNotifierProvider, (_, __) => reschedule());
    Future.microtask(reschedule);
  }

  Future<void> reschedule() async {
    if (kIsWeb) return;
    try {
      final settings = ref.read(userSettingsNotifierProvider);
      if (!settings.reminderEnabled) {
        await _service.cancelAll();
        return;
      }
      final records = await ref.read(vocabRepositoryProvider).getAll();
      final now = DateTime.now();
      final dueCount = records
          .where((r) => r.nextReviewAt == null || r.nextReviewAt!.isBefore(now))
          .length;
      final nextDueAt = _findNextDueAt(records, now);
      await _service.scheduleAll(
        enabled: settings.reminderEnabled,
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
        dueCount: dueCount,
        nextDueAt: nextDueAt,
      );
    } catch (_) {
      // Best-effort: a Firestore/notification-plugin failure here must
      // never crash the app — just skip this reschedule cycle, the next
      // trigger (settings change, app resume, session result) retries.
    }
  }

  DateTime? _findNextDueAt(List<VocabRecord> records, DateTime now) {
    DateTime? earliest;
    for (final r in records) {
      final nextReviewAt = r.nextReviewAt;
      if (nextReviewAt == null) continue;
      if (nextReviewAt.isAfter(now)) {
        if (earliest == null || nextReviewAt.isBefore(earliest)) {
          earliest = nextReviewAt;
        }
      }
    }
    return earliest;
  }
}
