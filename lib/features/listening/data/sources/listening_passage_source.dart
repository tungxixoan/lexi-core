import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
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
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _parse(json, level, context, targetLanguage);
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
        '(1) a CONVERSATION between exactly two speakers labeled "A" and "B" only '
        '(e.g. at an office, store, or while traveling), with 3 to 6 turns alternating '
        'between "A" and "B"; or '
        '(2) a TALK by a single speaker (e.g. an announcement, advertisement, or set of '
        'instructions), split into 2 to 4 turns, each with speaker set to null. '
        'Then write exactly 3 multiple-choice questions in ${targetLanguage.label} about '
        'the passage, each with exactly 4 answer options in ${targetLanguage.label}, '
        'testing the main idea, a specific detail, or an implied meaning — never a '
        'fill-in-the-blank question. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"kind": "conversation" or "talk", '
        '"turns": [{"speaker": "A" or "B" or null, "text": "..."}], '
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

    final turns = (json['turns'] as List? ?? []).map((t) {
      final tm = t as Map<String, dynamic>;
      return ListeningTurn(
        speaker: tm['speaker'] as String?,
        text: tm['text'] as String? ?? '',
      );
    }).toList();

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
      level: level,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
