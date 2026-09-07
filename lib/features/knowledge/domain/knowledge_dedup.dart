import '../../../core/utils/text_normalize.dart';
import 'entities/knowledge_note.dart';
import 'entities/knowledge_group.dart';

const _stopwords = {
  'va', 'khi', 'nao', 'cho', 'cua', 'la', 'cac', 'mot', 'voi', 'thi',
  'dung', 'giai', 'thich', 'vi', 'du', 'doi', 'thuong', 'cach', 'nay',
  'the', 'a', 'an', 'and', 'or', 'when', 'how', 'what', 'explain', 'give',
  'example',
};

List<String> _contentTokens(String prompt) {
  final norm = normalizeForSearch(prompt);
  if (norm.isEmpty) return const [];
  return norm
      .split(' ')
      .where((t) => t.isNotEmpty && !_stopwords.contains(t) && t.length > 1)
      .toList();
}

List<String> _phrases(List<String> tokens) {
  final out = <String>[];
  for (var i = 0; i < tokens.length - 1; i++) {
    out.add('${tokens[i]} ${tokens[i + 1]}');
    if (i < tokens.length - 2) {
      out.add('${tokens[i]} ${tokens[i + 1]} ${tokens[i + 2]}');
    }
  }
  return out;
}

List<KnowledgeNote> findRelatedNotes({
  required String prompt,
  required List<KnowledgeNote> notes,
}) {
  final tokens = _contentTokens(prompt);
  if (tokens.isEmpty) return const [];
  final phrases = _phrases(tokens);
  final promptTerms = {...tokens, ...phrases};

  final scored = <({KnowledgeNote note, int score})>[];
  for (final note in notes) {
    final title = normalizeForSearch(note.title);
    final haystack = normalizeForSearch([
      note.title,
      note.summary,
      note.tags.join(' '),
      knowledgeGroupLabel(note.groupId),
    ].join(' '));
    final noteTags = note.tags.map(normalizeForSearch).toSet();

    var score = 0;
    for (final phrase in phrases) {
      if (haystack.contains(phrase)) {
        score += 3;
        if (title.contains(phrase)) score += 2;
      }
    }
    for (final term in promptTerms) {
      if (noteTags.contains(term)) score += 3;
    }
    for (final token in tokens) {
      if (haystack.contains(token)) score += 1;
    }
    if (score >= 3) scored.add((note: note, score: score));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(3).map((e) => e.note).toList();
}
