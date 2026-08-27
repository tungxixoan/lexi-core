import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';

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
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.reminderEnabled) {
      await _service.cancelAll();
      return;
    }
    final stats = await ref.read(getLearningStatsUseCaseProvider).execute();
    final nextDueAt = await _computeNextDueAt();
    await _service.scheduleAll(
      enabled: settings.reminderEnabled,
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      dueCount: stats.dueCount,
      nextDueAt: nextDueAt,
    );
  }

  Future<DateTime?> _computeNextDueAt() async {
    final records = await ref.read(vocabRepositoryProvider).getAll();
    final now = DateTime.now();
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
