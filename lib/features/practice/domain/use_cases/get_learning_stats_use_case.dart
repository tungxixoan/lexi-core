import '../../../../core/services/stats_service.dart';
import '../entities/learning_stats.dart';

class GetLearningStatsUseCase {
  const GetLearningStatsUseCase(this._statsService);
  final StatsService _statsService;

  Future<LearningStats> execute() => _statsService.computeStats();
}
