// lib/features/knowledge/domain/use_cases/generate_knowledge_note_use_case.dart
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/knowledge_note_source.dart';
import '../entities/knowledge_note.dart';

class GenerateKnowledgeNoteUseCase {
  const GenerateKnowledgeNoteUseCase(this._source);
  final KnowledgeNoteSource _source;

  Future<KnowledgeNoteDraft> execute({
    required String request,
    required Language targetLanguage,
    String? hintGroupId,
    CEFRLevel? hintCefr,
    required List<KnowledgeNote> existingInScope,
    KnowledgeNote? extendingNote,
  }) =>
      _source.draft(
        request: request,
        targetLanguage: targetLanguage,
        hintGroupId: hintGroupId,
        hintCefr: hintCefr,
        existingInScope: existingInScope,
        extendingNote: extendingNote,
      );
}
