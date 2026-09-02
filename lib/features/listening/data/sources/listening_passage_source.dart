import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/listening_passage.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class ListeningPassageSource {
  ListeningPassageSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  ListeningPassageSource.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();

  Future<ListeningPassage> generate({
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    final prompt = _buildPrompt(
      level: level,
      context: context,
      targetLanguage: targetLanguage,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{"kind":"talk","turns":[],"questions":[]}';
    final json = parseAiJsonObject(text);
    final passage = _parse(json, level, context, targetLanguage);
    if (passage.turns.isEmpty || passage.questions.isEmpty) {
      throw const FormatException(
        'AI response produced an empty listening passage (no turns or no questions).',
      );
    }
    return passage;
  }

  String _buildPrompt({
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) {
    return 'You are creating a TOEIC-style listening exercise for a Vietnamese speaker '
        'learning ${targetLanguage.label}, at ${level.label} level, in a ${context.label} '
        'register/setting. '
        'Randomly choose ONE of these two formats: '
        '(1) a CONVERSATION between exactly two speakers. In the JSON, label them "A" and "B" '
        '(these are internal labels for voice selection only). The letters "A" and "B" must NEVER '
        'appear in any turn\'s spoken text or in any question — the speakers address each other by '
        'first name or by pronoun, never as "A" or "B". Use 3 to 6 turns alternating between the two speakers '
        '(e.g. at an office, store, or while traveling); or '
        '(2) a TALK by a single speaker (e.g. an announcement, advertisement, or set of '
        'instructions), split into 2 to 4 turns, each with speaker set to null. '
        'For every turn, also declare "gender" as "male" or "female" for that turn\'s '
        'speaker — keep it consistent for the same speaker letter across the whole '
        'passage (speaker "A" is always the same gender in every one of its turns; '
        'same for "B"). A conversation may use two speakers of the same gender or two '
        'different genders — vary this across different generations. '
        'Then write exactly 3 multiple-choice questions in ${targetLanguage.label} about '
        'the passage, each with exactly 4 answer options in ${targetLanguage.label}, '
        'testing the main idea, a specific detail, or an implied meaning — never a '
        'fill-in-the-blank question. '
        'In the questions (written in ${targetLanguage.label}), never refer to a speaker as "A" or "B": '
        'if the two speakers are one male and one female, call them "the man" and "the woman" '
        '(use the natural equivalent in ${targetLanguage.label}); if the two speakers are the same gender, refer to them '
        'by their role in the situation when there is a clear one (the customer, the clerk, the manager, the '
        'receptionist, ...), otherwise by the first name used in the dialogue; for a talk with one speaker, '
        'call them "the speaker". '
        'Respond with JSON only (no markdown, no code fences): '
        '{"kind": "conversation" or "talk", '
        '"turns": [{"speaker": "A" or "B" or null, "gender": "male" or "female", "text": "..."}], '
        '"questions": [{"question": "...", "options": ["...", "...", "...", "..."], '
        '"correctIndex": 0}]}';
  }

  ListeningPassage _parse(
    Map<String, dynamic> json,
    CEFRLevel level,
    AppContext context,
    Language targetLanguage,
  ) {
    final kind = json['kind'] == 'conversation'
        ? ListeningKind.conversation
        : ListeningKind.talk;

    final rawTurns = json['turns'] as List? ?? [];
    final turns = rawTurns.map((t) {
      final tm = t as Map<String, dynamic>;
      final gender = tm['gender'] as String?;
      return ListeningTurn(
        speaker: tm['speaker'] as String?,
        gender: (gender == 'male' || gender == 'female') ? gender : null,
        text: tm['text'] as String? ?? '',
      );
    }).toList();

    // First-seen wins: an AI response that's inconsistent about a speaker's
    // gender on a later turn must not change which voice gets used mid-passage.
    final speakerGenders = <String, String>{};
    for (final t in rawTurns) {
      final tm = t as Map<String, dynamic>;
      final key = speakerKey(tm['speaker'] as String?);
      if (speakerGenders.containsKey(key)) continue;
      final gender = tm['gender'] as String?;
      if (gender == 'male' || gender == 'female') {
        speakerGenders[key] = gender!;
      }
    }

    final questions = (json['questions'] as List? ?? []).map((q) {
      final qm = q as Map<String, dynamic>;
      return ListeningQuestion(
        question: qm['question'] as String? ?? '',
        options: List<String>.from(qm['options'] as List? ?? []),
        correctIndex: qm['correctIndex'] as int? ?? 0,
      );
    }).toList();

    return ListeningPassage(
      id: _uuid.v4(),
      kind: kind,
      turns: turns,
      questions: questions,
      speakerGenders: speakerGenders,
      level: level,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
