import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part6_passage.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class Part6Source {
  Part6Source(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  Part6Source.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();
  static const _passageCount = 3;
  static const _blanksPerPassage = 4;

  Future<Part6Set> generate({
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
    final text = response.text ?? '{"passages":[]}';
    final json = parseAiJsonObject(text);
    final set = _parse(json, effectiveVolumes, context, targetLanguage);
    if (set.passages.isEmpty) {
      throw const FormatException(
        'AI response produced an empty Part 6 passage set.',
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
    return 'You are creating a TOEIC Part 6 (Text Completion) practice set for a Vietnamese '
        'speaker learning ${targetLanguage.label}, in a ${context.label} register/setting, '
        'calibrated to the Economy TOEIC difficulty volumes below (mix passages across them '
        'roughly evenly and randomly): $volumeHints. '
        'Write exactly $_passageCount short realistic business documents (choose from: email, '
        'memo, notice, advertisement, article), each with exactly $_blanksPerPassage numbered '
        'blanks marked inline as "(1)___", "(2)___", "(3)___", "(4)___" in reading order. '
        'For each passage, at least one of its 4 blanks must be a "select the sentence that '
        'best fits" item, where all 4 options are full candidate sentences instead of single '
        'words/phrases — the other blanks use word/phrase options (word form, verb tense, '
        'preposition, conjunction, transition word). Every blank has exactly 4 options and a '
        'brief explanation (in Vietnamese) of why the correct option is right. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"passages": [{"passageText": "... (1)___ ... (2)___ ... (3)___ ... (4)___ ...", '
        '"questions": [{"options": ["...", "...", "...", "..."], "correctIndex": 0, '
        '"explanation": "..."}]}]}';
  }

  Part6Set _parse(
    Map<String, dynamic> json,
    Set<EconomyVolume> volumes,
    AppContext context,
    Language targetLanguage,
  ) {
    final passages = (json['passages'] as List? ?? []).map((p) {
      final pm = p as Map<String, dynamic>;
      final questions = (pm['questions'] as List? ?? []).map((q) {
        final qm = q as Map<String, dynamic>;
        return Part6Question(
          options: List<String>.from(qm['options'] as List? ?? []),
          correctIndex: qm['correctIndex'] as int? ?? 0,
          explanation: qm['explanation'] as String? ?? '',
        );
      }).toList();
      return Part6Passage(
        passageText: pm['passageText'] as String? ?? '',
        questions: questions,
      );
    }).toList();

    return Part6Set(
      id: _uuid.v4(),
      passages: passages,
      volumes: volumes,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
