import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

enum ListeningKind { conversation, talk }

final class ListeningTurn {
  const ListeningTurn({this.speaker, required this.text});

  final String? speaker; // 'A' or 'B' for a conversation; null for a talk
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
  });

  final String id;
  final ListeningKind kind;
  final List<ListeningTurn> turns;
  final List<ListeningQuestion> questions; // always 3 items
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
