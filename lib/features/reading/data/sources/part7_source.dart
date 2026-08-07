import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part7_passage.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class Part7Source {
  Part7Source(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  Part7Source.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();
  static const _singleQuestionRange = {3, 4};
  static const _doubleQuestionCount = 5;

  Future<Part7Set> generate({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) async {
    final effectiveVolumes = volumes.isEmpty ? EconomyVolume.values.toSet() : volumes;
    final prompt = _buildPrompt(
      context: context,
      targetLanguage: targetLanguage,
      volumes: effectiveVolumes,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{"passageGroups":[]}';
    final json = parseAiJsonObject(text);
    final set = _parse(json, effectiveVolumes, context, targetLanguage);
    if (!_hasValidShape(set.passageGroups)) {
      throw const FormatException(
        'AI response produced a malformed Part 7 set (expected 2 single-passage '
        'groups with 3-4 questions each, then 1 double-passage group with exactly '
        '2 documents and 5 questions).',
      );
    }
    return set;
  }

  bool _hasValidShape(List<Part7PassageGroup> groups) {
    if (groups.length != 3) return false;
    for (var i = 0; i < 2; i++) {
      if (groups[i].documents.length != 1) return false;
      if (!_singleQuestionRange.contains(groups[i].questions.length)) return false;
    }
    final doubleGroup = groups[2];
    if (doubleGroup.documents.length != 2) return false;
    if (doubleGroup.questions.length != _doubleQuestionCount) return false;
    return true;
  }

  String _buildPrompt({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) {
    final volumeHints = volumes.map((v) => '${v.label}: ${v.promptHint}').join('; ');
    return 'You are creating a TOEIC Part 7 (Reading Comprehension) practice set for a '
        'Vietnamese speaker learning ${targetLanguage.label}, in a ${context.label} '
        'register/setting, calibrated to the Economy TOEIC difficulty volumes below '
        '(mix questions across them roughly evenly and randomly): $volumeHints. '
        'Write exactly 3 passage groups in this exact order: '
        '(1) a single-passage group: one realistic business document (email, letter, memo, '
        'notice, advertisement, article, or a short text-message exchange), with 3 or 4 '
        'multiple-choice questions; '
        '(2) another single-passage group, same rules, using a different document type than '
        'group 1; '
        '(3) a double-passage group: two genuinely related documents (e.g. a job ad and an '
        'application email, an announcement and a reply, an invoice and a follow-up letter) '
        'where the second document cannot be fully understood without the first, with exactly '
        '5 multiple-choice questions, at least one of which requires information from both '
        'documents to answer. '
        'Every question has exactly 4 answer options in ${targetLanguage.label}, testing main '
        'idea, a specific detail, an inference, or vocabulary-in-context, plus a brief '
        'explanation (in Vietnamese) of why the correct option is right. The explanation must '
        'use only Vietnamese script — never Chinese, Japanese, or other non-Vietnamese '
        'characters. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"passageGroups": [{"documents": ["..."], "questions": [{"question": "...", '
        '"options": ["...", "...", "...", "..."], "correctIndex": 0, "explanation": "..."}]}]}';
  }

  Part7Set _parse(
    Map<String, dynamic> json,
    Set<EconomyVolume> volumes,
    AppContext context,
    Language targetLanguage,
  ) {
    final groups = (json['passageGroups'] as List? ?? []).map((g) {
      final gm = g as Map<String, dynamic>;
      final questions = (gm['questions'] as List? ?? []).map((q) {
        final qm = q as Map<String, dynamic>;
        return Part7Question(
          question: qm['question'] as String? ?? '',
          options: List<String>.from(qm['options'] as List? ?? []),
          correctIndex: qm['correctIndex'] as int? ?? 0,
          explanation: qm['explanation'] as String? ?? '',
        );
      }).toList();
      return Part7PassageGroup(
        documents: List<String>.from(gm['documents'] as List? ?? []),
        questions: questions,
      );
    }).toList();

    return Part7Set(
      id: _uuid.v4(),
      passageGroups: groups,
      volumes: volumes,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
