import '../../../core/utils/text_normalize.dart';
import '../../vocabulary/domain/entities/cefr_level.dart';
import 'entities/knowledge_note.dart';

class KnowledgeFilter {
  const KnowledgeFilter({
    this.query = '',
    this.groupIds = const {},
    this.levels = const {},
    this.tags = const {},
  });

  final String query;
  final Set<String> groupIds;
  final Set<CEFRLevel> levels;
  final Set<String> tags;

  bool get isActive =>
      query.trim().isNotEmpty ||
      groupIds.isNotEmpty ||
      levels.isNotEmpty ||
      tags.isNotEmpty;

  KnowledgeFilter copyWith({
    String? query,
    Set<String>? groupIds,
    Set<CEFRLevel>? levels,
    Set<String>? tags,
  }) =>
      KnowledgeFilter(
        query: query ?? this.query,
        groupIds: groupIds ?? this.groupIds,
        levels: levels ?? this.levels,
        tags: tags ?? this.tags,
      );
}

List<KnowledgeNote> applyKnowledgeFilter(
  List<KnowledgeNote> notes,
  KnowledgeFilter filter,
) {
  final q = normalizeForSearch(filter.query);
  return notes.where((n) {
    if (filter.groupIds.isNotEmpty && !filter.groupIds.contains(n.groupId)) {
      return false;
    }
    if (filter.levels.isNotEmpty &&
        (n.cefrLevel == null || !filter.levels.contains(n.cefrLevel))) {
      return false;
    }
    if (filter.tags.isNotEmpty && !n.tags.any(filter.tags.contains)) {
      return false;
    }
    if (q.isNotEmpty) {
      final hay = normalizeForSearch([
        n.title,
        n.summary,
        n.explanation,
        n.patterns.join(' '),
        n.pitfalls.join(' '),
        n.tags.join(' '),
      ].join(' '));
      if (!hay.contains(q)) return false;
    }
    return true;
  }).toList();
}

Map<String, int> knowledgeGroupCounts(List<KnowledgeNote> notes) {
  final counts = <String, int>{};
  for (final n in notes) {
    counts[n.groupId] = (counts[n.groupId] ?? 0) + 1;
  }
  return counts;
}

List<String> knowledgeAllTags(List<KnowledgeNote> notes) =>
    (notes.expand((n) => n.tags).toSet().toList()..sort());
