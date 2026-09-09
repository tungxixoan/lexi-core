import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/knowledge_note_source.dart';
import '../../domain/entities/knowledge_note.dart';
import '../../domain/knowledge_dedup.dart';
import 'knowledge_notes_provider.dart';

part 'knowledge_draft_provider.g.dart';

/// State machine for the "Nhờ AI soạn" flow: request → (maybe) related-notes
/// prompt → generate → review.
sealed class KnowledgeDraftState {
  const KnowledgeDraftState();
}

class KnowledgeDraftIdle extends KnowledgeDraftState {
  const KnowledgeDraftIdle();
}

/// Layer-1 hit: prompt keywords matched existing notes; awaiting the user's
/// Mở / Bổ sung / Vẫn tạo mới choice.
class KnowledgeDraftRelated extends KnowledgeDraftState {
  const KnowledgeDraftRelated(
      this.related, this.request, this.hintGroupId, this.hintCefr);
  final List<KnowledgeNote> related;
  final String request;
  final String? hintGroupId;
  final CEFRLevel? hintCefr;
}

class KnowledgeDraftLoading extends KnowledgeDraftState {
  const KnowledgeDraftLoading();
}

/// The draft is ready — go to the edit screen. When [layer2Related] is set the
/// model itself flagged a near-duplicate that the user hasn't seen yet, so the
/// banner is shown once more first.
class KnowledgeDraftReady extends KnowledgeDraftState {
  const KnowledgeDraftReady(
      this.draft, this.request, this.overwriteNoteId, this.layer2Related);
  final KnowledgeNoteDraft draft;
  final String request;
  final String? overwriteNoteId;
  final KnowledgeNote? layer2Related;
}

class KnowledgeDraftError extends KnowledgeDraftState {
  const KnowledgeDraftError(this.message);
  final String message;
}

@riverpod
class KnowledgeDraftNotifier extends _$KnowledgeDraftNotifier {
  @override
  KnowledgeDraftState build() => const KnowledgeDraftIdle();

  List<KnowledgeNote> get _notes =>
      ref.read(knowledgeNotesNotifierProvider).valueOrNull ?? const [];

  Future<void> submit({
    required String request,
    String? hintGroupId,
    CEFRLevel? hintCefr,
  }) async {
    final related = findRelatedNotes(prompt: request, notes: _notes);
    if (related.isNotEmpty) {
      state = KnowledgeDraftRelated(related, request, hintGroupId, hintCefr);
      return;
    }
    await _generate(
      request: request,
      hintGroupId: hintGroupId,
      hintCefr: hintCefr,
      extendingNote: null,
      overwriteNoteId: null,
      resolveLayer2: true,
    );
  }

  Future<void> proceedNew() async {
    final s = state;
    if (s is! KnowledgeDraftRelated) return;
    await _generate(
      request: s.request,
      hintGroupId: s.hintGroupId,
      hintCefr: s.hintCefr,
      extendingNote: null,
      overwriteNoteId: null,
      // The user already saw (and dismissed) a related-notes banner.
      resolveLayer2: false,
    );
  }

  Future<void> extend(KnowledgeNote note) async {
    final s = state;
    // The user can reach `extend` from the Layer-1 banner (state is
    // KnowledgeDraftRelated) or from the Layer-2 single-note re-banner (state
    // is already KnowledgeDraftReady) — both carry the original request, and
    // the AI merge prompt is near-useless without it.
    final (request, hintGroupId, hintCefr) = switch (s) {
      KnowledgeDraftRelated s => (s.request, s.hintGroupId, s.hintCefr),
      KnowledgeDraftReady s => (s.request, null, null),
      _ => ('', null, null),
    };
    await _generate(
      request: request,
      hintGroupId: hintGroupId,
      hintCefr: hintCefr,
      extendingNote: note,
      overwriteNoteId: note.id,
      resolveLayer2: false,
    );
  }

  void dismiss() => state = const KnowledgeDraftIdle();

  Future<void> _generate({
    required String request,
    required String? hintGroupId,
    required CEFRLevel? hintCefr,
    required KnowledgeNote? extendingNote,
    required String? overwriteNoteId,
    required bool resolveLayer2,
  }) async {
    state = const KnowledgeDraftLoading();
    final language = ref.read(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final groupScope = hintGroupId ?? extendingNote?.groupId;
    final scope = groupScope == null
        ? _notes
        : _notes.where((n) => n.groupId == groupScope).toList();
    try {
      final draft =
          await ref.read(generateKnowledgeNoteUseCaseProvider).execute(
                request: request,
                targetLanguage: language,
                hintGroupId: hintGroupId,
                hintCefr: hintCefr,
                existingInScope: scope,
                extendingNote: extendingNote,
              );
      KnowledgeNote? layer2;
      if (resolveLayer2 && draft.relatedNoteId != null) {
        for (final n in _notes) {
          if (n.id == draft.relatedNoteId) {
            layer2 = n;
            break;
          }
        }
      }
      state = KnowledgeDraftReady(draft, request, overwriteNoteId, layer2);
    } catch (_) {
      state = const KnowledgeDraftError('Không tạo được ghi chú. Thử lại.');
    }
  }
}
