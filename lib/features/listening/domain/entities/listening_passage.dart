import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

enum ListeningKind { conversation, talk }

final class ListeningTurn {
  const ListeningTurn({this.speaker, this.gender, required this.text});

  final String? speaker; // 'A' or 'B' for a conversation; null for a talk
  final String? gender; // 'male' or 'female'; null if the AI omitted it
  final String text;
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
    nextSlotByGender[gender] = slot == 1 ? 2 : 1; // wraps back to 1 past 2 speakers of the same gender
  }
  return result;
}
