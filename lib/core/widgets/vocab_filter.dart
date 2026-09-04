// lib/core/widgets/vocab_filter.dart
//
// Shared filter model for the Vocab Bank, mirroring the web app's
// `apps/web/src/lib/vocabFilters.ts` (`{dueOnly, topicIds, cefrLevels}`) plus
// the search box the Flutter screen already has.
import '../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../features/vocabulary/domain/entities/cefr_level.dart';

class VocabFilterState {
  const VocabFilterState({
    this.query = '',
    this.topicIds = const {},
    this.dueOnly = false,
    this.cefrLevels = const {},
  });
  final String query;
  final Set<String> topicIds;
  final bool dueOnly;
  final Set<CEFRLevel> cefrLevels;

  bool get isActive =>
      query.trim().isNotEmpty ||
      topicIds.isNotEmpty ||
      dueOnly ||
      cefrLevels.isNotEmpty;

  VocabFilterState copyWith({
    String? query,
    Set<String>? topicIds,
    bool? dueOnly,
    Set<CEFRLevel>? cefrLevels,
  }) =>
      VocabFilterState(
        query: query ?? this.query,
        topicIds: topicIds ?? this.topicIds,
        dueOnly: dueOnly ?? this.dueOnly,
        cefrLevels: cefrLevels ?? this.cefrLevels,
      );
}

bool vocabRecordIsDue(VocabRecord r, {DateTime? now}) {
  final at = now ?? DateTime.now();
  return r.nextReviewAt == null || r.nextReviewAt!.isBefore(at);
}

bool matchesVocabFilters(VocabRecord r, VocabFilterState f, {DateTime? now}) {
  if (f.dueOnly && !vocabRecordIsDue(r, now: now)) return false;
  if (f.topicIds.isNotEmpty && !r.topicIds.any(f.topicIds.contains)) {
    return false;
  }
  if (f.cefrLevels.isNotEmpty && !f.cefrLevels.contains(r.cefrLevel)) {
    return false;
  }
  final q = f.query.trim().toLowerCase();
  if (q.isNotEmpty &&
      !(r.headword.toLowerCase().contains(q) ||
          r.meaning.toLowerCase().contains(q))) {
    return false;
  }
  return true;
}
