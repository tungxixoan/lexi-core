import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/ai_key_missing_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/knowledge_group.dart';
import '../../domain/entities/knowledge_note.dart';
import '../providers/knowledge_draft_provider.dart';
import '../providers/knowledge_notes_provider.dart';
import 'related_notes_banner.dart';

/// Opens the "Nhờ AI soạn" bottom sheet: a request box + optional group/CEFR
/// hints, then the generate → (maybe) related-notes → review flow, ending in a
/// navigation to `/knowledge/new` with the draft carried in `extra`.
Future<void> showKnowledgeAiRequestSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _KnowledgeAiRequestSheet(),
  );
}

class _KnowledgeAiRequestSheet extends ConsumerStatefulWidget {
  const _KnowledgeAiRequestSheet();

  @override
  ConsumerState<_KnowledgeAiRequestSheet> createState() =>
      _KnowledgeAiRequestSheetState();
}

class _KnowledgeAiRequestSheetState
    extends ConsumerState<_KnowledgeAiRequestSheet> {
  final _requestCtrl = TextEditingController();
  String? _hintGroupId;
  CEFRLevel? _hintCefr;
  String? _emptyError;

  /// The layer-2 note id the re-shown banner currently covers, so [_onState]
  /// only swaps to it once.
  String? _layer2BannerNoteId;
  bool _navigated = false;
  late final KnowledgeDraftNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(knowledgeDraftNotifierProvider.notifier);
    ref.listenManual(knowledgeDraftNotifierProvider, _onState);
  }

  @override
  void dispose() {
    _requestCtrl.dispose();
    // Don't leak a stale Ready/Error state into the next open.
    try {
      _notifier.dismiss();
    } catch (_) {
      // Provider scope already torn down (e.g. test teardown) — nothing to do.
    }
    super.dispose();
  }

  void _onState(KnowledgeDraftState? prev, KnowledgeDraftState next) {
    if (next is! KnowledgeDraftReady || _navigated) return;
    if (next.layer2Related != null &&
        _layer2BannerNoteId != next.layer2Related!.id) {
      setState(() => _layer2BannerNoteId = next.layer2Related!.id);
      return;
    }
    _goToEdit(next);
  }

  void _goToEdit(KnowledgeDraftReady s) {
    _navigated = true;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(
      '/knowledge/new',
      extra: (
        draft: s.draft,
        request: s.request,
        overwriteNoteId: s.overwriteNoteId,
      ),
    );
  }

  void _openNote(KnowledgeNote note) {
    _navigated = true;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/knowledge/note/${note.id}');
  }

  void _submit() {
    final request = _requestCtrl.text.trim();
    if (request.isEmpty) {
      setState(() => _emptyError = 'Nhập yêu cầu để AI soạn.');
      return;
    }
    setState(() => _emptyError = null);
    _notifier.submit(
      request: request,
      hintGroupId: _hintGroupId,
      hintCefr: _hintCefr,
    );
  }

  Future<void> _pickGroup(List<KnowledgeGroup> groups) async {
    final picked = await showSingleSelectSheet<String?>(
      context: context,
      title: 'Chọn nhóm',
      options: [
        const SelectOption<String?>(value: null, label: 'Tự động'),
        for (final g in groups)
          SelectOption<String?>(value: g.id, label: g.label),
      ],
      selected: _hintGroupId,
    );
    if (picked != null) setState(() => _hintGroupId = picked.value);
  }

  Future<void> _pickCefr() async {
    final picked = await showSingleSelectSheet<CEFRLevel?>(
      context: context,
      title: 'Trình độ (CEFR)',
      options: [
        const SelectOption<CEFRLevel?>(value: null, label: 'Tự động'),
        for (final l in CEFRLevel.values)
          SelectOption<CEFRLevel?>(value: l, label: l.label),
      ],
      selected: _hintCefr,
    );
    if (picked != null) setState(() => _hintCefr = picked.value);
  }

  @override
  Widget build(BuildContext context) {
    // Kick off the notes load so Layer-1 dedup has something to match against.
    ref.watch(knowledgeNotesNotifierProvider);
    final state = ref.watch(knowledgeDraftNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) =>
          _content(context, scrollController, state),
    );
  }

  Widget _content(
    BuildContext context,
    ScrollController scrollController,
    KnowledgeDraftState state,
  ) {
    // Layer-2: model flagged a near-duplicate — re-show the banner for it.
    if (state is KnowledgeDraftReady &&
        state.layer2Related != null &&
        _layer2BannerNoteId == state.layer2Related!.id) {
      final note = state.layer2Related!;
      return RelatedNotesBanner(
        scrollController: scrollController,
        related: [note],
        onProceedNew: () => _goToEdit(state),
        onExtend: (n) => _notifier.extend(n),
        onOpen: _openNote,
      );
    }

    return switch (state) {
      KnowledgeDraftRelated s => RelatedNotesBanner(
          scrollController: scrollController,
          related: s.related,
          onProceedNew: _notifier.proceedNew,
          onExtend: _notifier.extend,
          onOpen: _openNote,
        ),
      KnowledgeDraftLoading() => _busy('Đang soạn…'),
      KnowledgeDraftReady() => _busy('Đang mở bản nháp…'),
      KnowledgeDraftError s => _error(context, scrollController, s.message),
      KnowledgeDraftIdle() => _form(context, scrollController),
    };
  }

  Widget _busy(String label) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      );

  Widget _error(
    BuildContext context,
    ScrollController scrollController,
    String message,
  ) {
    final c = context.bloom;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.danger, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        BloomPillButton(
          label: 'Thử lại',
          block: true,
          onPressed: _notifier.dismiss,
        ),
      ],
    );
  }

  Widget _form(BuildContext context, ScrollController scrollController) {
    final aiAvailable = ref.watch(
      userSettingsNotifierProvider.select((s) => s.aiAvailable),
    );
    final language = ref.read(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final groups = knowledgeGroupsFor(language);
    final c = context.bloom;

    if (!aiAvailable) {
      return ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        children: const [
          BloomSectionHeader('Nhờ AI soạn'),
          SizedBox(height: 8),
          AiKeyMissingCard(),
        ],
      );
    }

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      children: [
        const BloomSectionHeader('Nhờ AI soạn'),
        BloomTextField(
          controller: _requestCtrl,
          maxLines: 5,
          minLines: 3,
          hintText: 'Ví dụ: giải thích câu điều kiện loại 2 và 3…',
        ),
        if (_emptyError != null) ...[
          const SizedBox(height: 8),
          Text(
            _emptyError!,
            style: TextStyle(color: c.danger, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 12),
        FilterTile(
          icon: Icons.folder_outlined,
          label: 'Nhóm',
          value: _hintGroupId == null
              ? 'Tự động'
              : knowledgeGroupLabel(_hintGroupId!),
          onTap: () => _pickGroup(groups),
        ),
        FilterTile(
          icon: Icons.bar_chart_outlined,
          label: 'CEFR',
          value: _hintCefr?.label ?? 'Tự động',
          onTap: _pickCefr,
        ),
        const SizedBox(height: 16),
        BloomPillButton(
          label: 'Soạn',
          block: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}
