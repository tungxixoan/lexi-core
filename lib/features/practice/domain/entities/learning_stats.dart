import '../../../vocabulary/domain/entities/cefr_level.dart';

final class LearningStats {
  const LearningStats({
    required this.dueCount,
    required this.masteredCount,
    required this.totalCount,
    required this.cefrBreakdown,
    required this.currentStreak,
    required this.weeklyLog,
  });

  final int dueCount;
  final int masteredCount;
  final int totalCount;
  final Map<CEFRLevel, int> cefrBreakdown;
  final int currentStreak;
  final Map<String, int> weeklyLog; // "yyyy-MM-dd" → words practiced
}
