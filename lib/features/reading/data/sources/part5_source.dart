import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part5_question.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class Part5Source {
  Part5Source(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  Part5Source.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();
  static const _questionCount = 15;

  Future<Part5Set> generate({
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
    final text = response.text ?? '{"questions":[]}';
    final json = parseAiJsonObject(text);
    final set = _parse(json, effectiveVolumes, context, targetLanguage);
    if (set.questions.isEmpty) {
      throw const FormatException(
        'AI response produced an empty Part 5 question set.',
      );
    }
    return set;
  }

  String _buildPrompt({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) {
    final volumeHints = volumes.map((v) => '${v.label}: ${v.promptHint}').join('; ');
    return 'You are creating a TOEIC Part 5 (Incomplete Sentences) practice set for a '
        'Vietnamese speaker learning ${targetLanguage.label}, in a ${context.label} '
        'register/setting, calibrated to the Economy TOEIC difficulty volumes below '
        '(mix questions across them roughly evenly and randomly): $volumeHints. '
        'Write exactly $_questionCount independent sentences, each with exactly one blank '
        'marked "___", testing grammar (word form, verb tense/agreement, prepositions, '
        'conjunctions) or vocabulary-in-context, with exactly 4 answer options in '
        '${targetLanguage.label} and a brief explanation (in Vietnamese) of why the correct '
        'option is right and, briefly, why the others are wrong. '
        'The explanation must use only Vietnamese script — never Chinese, Japanese, or other '
        'non-Vietnamese characters. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"questions": [{"sentenceWithBlank": "...", "options": ["...", "...", "...", "..."], '
        '"correctIndex": 0, "explanation": "..."}]}';
  }

  Part5Set _parse(
    Map<String, dynamic> json,
    Set<EconomyVolume> volumes,
    AppContext context,
    Language targetLanguage,
  ) {
    final questions = (json['questions'] as List? ?? []).map((q) {
      final qm = q as Map<String, dynamic>;
      return Part5Question(
        sentenceWithBlank: qm['sentenceWithBlank'] as String? ?? '',
        options: List<String>.from(qm['options'] as List? ?? []),
        correctIndex: qm['correctIndex'] as int? ?? 0,
        explanation: qm['explanation'] as String? ?? '',
      );
    }).toList();

    return Part5Set(
      id: _uuid.v4(),
      questions: questions,
      volumes: volumes,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
