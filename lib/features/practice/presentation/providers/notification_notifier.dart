import 'dart:convert';
import 'package:hive/hive.dart';
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
    _service.initialize();
    ref.listen(userSettingsNotifierProvider, (_, __) => reschedule());
    Future.microtask(reschedule);
  }

  Future<void> reschedule() async {
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.reminderEnabled) {
      await _service.cancelAll();
      return;
    }
    final stats = ref.read(getLearningStatsUseCaseProvider).execute();
    final nextDueAt = _computeNextDueAt();
    await _service.scheduleAll(
      enabled: settings.reminderEnabled,
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      dueCount: stats.dueCount,
      nextDueAt: nextDueAt,
    );
  }

  DateTime? _computeNextDueAt() {
    final box = Hive.box<String>('vocab_records');
    final now = DateTime.now();
    DateTime? earliest;
    for (final raw in box.values) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final nextReviewRaw = map['nextReviewAt'] as String?;
        if (nextReviewRaw == null) continue;
        final dt = DateTime.parse(nextReviewRaw);
        if (dt.isAfter(now)) {
          if (earliest == null || dt.isBefore(earliest)) earliest = dt;
        }
      } catch (_) {
        // Skip malformed records — don't abort the whole search
      }
    }
    return earliest;
  }
}
