import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

enum ListeningKind { conversation, talk }

final class ListeningTurn {
  const ListeningTurn({this.speaker, this.gender, required this.text});

  final String? speaker; // 'A' or 'B' for a conversation; null for a talk
  final String? gender; // 'male' or 'female'; null if the AI omitted it
  final String text;

  /// `speaker` / `text` match apps/web/src/lib/listeningPassage.ts's
  /// `ListeningTurn`. Web keeps per-speaker gender only in the passage-level
  /// `speakerGenders` map; Flutter also keeps it per turn, so `gender` is
  /// serialized here as an extra key (web ignores it) to round-trip cleanly.
  Map<String, dynamic> toJson() => {
        'speaker': speaker,
        'gender': gender,
        'text': text,
      };

  factory ListeningTurn.fromJson(Map<String, dynamic> json) => ListeningTurn(
        speaker: json['speaker'] as String?,
        gender: json['gender'] as String?,
        text: json['text'] as String? ?? '',
      );
}

final class ListeningQuestion {
  const ListeningQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String question;
  final List<String> options; // always 4 items
  final int correctIndex; // 0-3

  /// Keys match apps/web/src/lib/listeningPassage.ts's `ListeningQuestion`.
  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
      };

  factory ListeningQuestion.fromJson(Map<String, dynamic> json) =>
      ListeningQuestion(
        question: json['question'] as String? ?? '',
        options: List<String>.from(json['options'] as List? ?? const []),
        correctIndex: json['correctIndex'] as int? ?? 0,
      );
}

final class ListeningPassage {
  const ListeningPassage({
    required this.id,
    required this.kind,
    required this.turns,
    required this.questions,
    required this.level,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
    this.speakerGenders = const {},
  });

  final String id;
  final ListeningKind kind;
  final List<ListeningTurn> turns;
  final List<ListeningQuestion> questions; // always 3 items
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;

  /// Keyed by speaker key ('A', 'B', or 'solo' — see [speakerKey]), value is
  /// 'male' or 'female'. Derived once at parse time from each speaker's
  /// first-seen turn (see `ListeningPassageSource._parse`).
  final Map<String, String> speakerGenders;

  /// `kind` / `turns` / `questions` / `speakerGenders` match the persisted
  /// `ComprehensionItem` shape in apps/web/src/lib/savedListeningExercises.ts
  /// (`speakerGenders` is web's `Partial<Record<Speaker, SpeakerGender>>` —
  /// a `{speakerKey: "male"|"female"}` map). The web persists
  /// `level` / `context` / `targetLanguage` on the wrapping saved-exercise
  /// document, not on the item sub-object — serialized here too so the
  /// Flutter entity round-trips on its own.
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'turns': turns.map((t) => t.toJson()).toList(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'speakerGenders': speakerGenders,
        'level': level.name,
        'context': context.name,
        'targetLanguage': targetLanguage.name,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory ListeningPassage.fromJson(Map<String, dynamic> json) =>
      ListeningPassage(
        id: json['id'] as String? ?? '',
        kind: json['kind'] != null
            ? ListeningKind.values.byName(json['kind'] as String)
            : ListeningKind.conversation,
        turns: (json['turns'] as List? ?? const [])
            .map((t) => ListeningTurn.fromJson(t as Map<String, dynamic>))
            .toList(),
        questions: (json['questions'] as List? ?? const [])
            .map((q) => ListeningQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
        speakerGenders: (json['speakerGenders'] as Map?)?.map(
              (k, v) => MapEntry(k as String, v as String),
            ) ??
            const {},
        level: json['level'] != null
            ? CEFRLevel.values.byName(json['level'] as String)
            : CEFRLevel.a1,
        context: json['context'] != null
            ? AppContext.values.byName(json['context'] as String)
            : AppContext.general,
        targetLanguage: json['targetLanguage'] != null
            ? Language.values.byName(json['targetLanguage'] as String)
            : Language.english,
        generatedAt: json['generatedAt'] != null
            ? DateTime.parse(json['generatedAt'] as String)
            : DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Normalizes a raw turn speaker ('A', 'B', or null for a talk) into the key
/// [ListeningPassage.speakerGenders] and [assignVoices] use.
String speakerKey(String? speaker) => speaker ?? 'solo';

/// Deterministic, computed fresh each time it's needed (not cached on any
/// session state) — cheap and pure given the same passage. Walks distinct
/// speakers in order of first appearance; for each, takes the next unused
/// voice slot (1 or 2) of that speaker's declared gender. A speaker with no
/// declared gender (malformed AI response) defaults to 'female' — an
/// arbitrary but harmless choice, since the alternative (throwing) would
/// break an otherwise-usable passage over a cosmetic voice-picking detail.
/// Ports apps/web/src/lib/listeningPassage.ts's assignVoices() exactly.
Map<String, String> assignVoices(ListeningPassage passage) {
  final seen = <String>{};
  final order = <String>[];
  for (final t in passage.turns) {
    final key = speakerKey(t.speaker);
    if (seen.add(key)) order.add(key);
  }

  final nextSlotByGender = <String, int>{'male': 1, 'female': 1};
  final result = <String, String>{};
  for (final speaker in order) {
    final gender = passage.speakerGenders[speaker] ?? 'female';
    final slot = nextSlotByGender[gender]!;
    result[speaker] = '$gender$slot';
    nextSlotByGender[gender] =
        slot == 1 ? 2 : 1; // wraps back to 1 past 2 speakers of the same gender
  }
  return result;
}
