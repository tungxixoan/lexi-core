import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/knowledge_note_source.dart';
import '../../domain/entities/knowledge_group.dart';
import '../../domain/entities/knowledge_note.dart';
import '../providers/knowledge_notes_provider.dart';

/// The shared write / edit / review-AI-draft form for a [KnowledgeNote].
///
/// Exactly one of [initial] (edit an existing note), [draft] (review an
/// AI-generated draft), or neither (blank new note). [overwriteNoteId], when
/// set, makes Save write that id instead of minting a new one (the "Bổ sung"
/// path). [sourcePrompt] carries the request text through the draft flow.
class KnowledgeEditScreen extends ConsumerStatefulWidget {
  const KnowledgeEditScreen({
    super.key,
    this.initial,
    this.draft,
    this.overwriteNoteId,
    this.sourcePrompt,
  });

  final KnowledgeNote? initial;
  final KnowledgeNoteDraft? draft;
  final String? overwriteNoteId;
  final String? sourcePrompt;

  @override
  ConsumerState<KnowledgeEditScreen> createState() =>
      _KnowledgeEditScreenState();
}

class _KnowledgeEditScreenState extends ConsumerState<KnowledgeEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _explanation;
  final _tagInput = TextEditingController();
  late final List<TextEditingController> _patterns;
  late final List<(TextEditingController, TextEditingController)> _examples;
  late final List<TextEditingController> _pitfalls;
  String? _groupId;
  CEFRLevel? _cefr;
  late final List<String> _tags;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    final n = widget.initial;
    _title = TextEditingController(text: n?.title ?? d?.title ?? '');
    _summary = TextEditingController(text: n?.summary ?? d?.summary ?? '');
    _explanation =
        TextEditingController(text: n?.explanation ?? d?.explanation ?? '');
    _patterns = [
      for (final p in n?.patterns ?? d?.patterns ?? const <String>[])
        TextEditingController(text: p),
    ];
    _examples = [
      for (final e in n?.examples ?? d?.examples ?? const <KnowledgeExample>[])
        (
          TextEditingController(text: e.text),
          TextEditingController(text: e.translation),
        ),
    ];
    _pitfalls = [
      for (final p in n?.pitfalls ?? d?.pitfalls ?? const <String>[])
        TextEditingController(text: p),
    ];
    _groupId = n?.groupId ?? d?.suggestedGroupId;
    _cefr = n?.cefrLevel ?? d?.suggestedCefr;
    _tags = [...?n?.tags, ...?d?.suggestedTags];
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _summary,
      _explanation,
      _tagInput,
      ..._patterns,
      ..._pitfalls,
    ]) {
      c.dispose();
    }
    for (final (text, translation) in _examples) {
      text.dispose();
      translation.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _error = null);
    final language =
        ref.read(userSettingsNotifierProvider.select((s) => s.targetLanguage));
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tiêu đề cho ghi chú.');
      return;
    }
    if (_groupId == null) {
      setState(() => _error = 'Chọn một nhóm.');
      return;
    }

    final targetId = widget.overwriteNoteId ?? widget.initial?.id;
    KnowledgeNote? existing;
    if (targetId != null) {
      for (final x in ref.read(knowledgeNotesNotifierProvider).valueOrNull ??
          const <KnowledgeNote>[]) {
        if (x.id == targetId) {
          existing = x;
          break;
        }
      }
    }
    // Fall back to the note handed to us when the provider list hasn't
    // loaded yet — otherwise a plain edit would lose its origin/createdAt.
    existing ??= widget.initial;
    setState(() => _saving = true);

    final now = DateTime.now();
    final origin = widget.draft != null
        ? KnowledgeNoteOrigin.ai
        : (existing?.origin ?? KnowledgeNoteOrigin.manual);
    final note = KnowledgeNote(
      id: targetId ?? const Uuid().v4(),
      title: _title.text.trim(),
      summary: _summary.text.trim(),
      explanation: _explanation.text.trim(),
      patterns: _patterns
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      examples: _examples
          .map((e) => KnowledgeExample(
                text: e.$1.text.trim(),
                translation: e.$2.text.trim(),
              ))
          .where((e) => e.text.isNotEmpty || e.translation.isNotEmpty)
          .toList(),
      pitfalls: _pitfalls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      groupId: _groupId!,
      tags: _tags,
      cefrLevel: _cefr,
      targetLanguage: language,
      origin: origin,
      sourcePrompt: widget.sourcePrompt ?? existing?.sourcePrompt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(knowledgeNotesNotifierProvider.notifier).saveNote(note);
      if (mounted) context.go('/knowledge/note/${note.id}');
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Không lưu được ghi chú. Thử lại.';
        });
      }
    }
  }

  void _pickGroup(List<KnowledgeGroup> groups) async {
    final picked = await showSingleSelectSheet<String>(
      context: context,
      title: 'Chọn nhóm',
      options: [
        for (final g in groups) SelectOption(value: g.id, label: g.label),
      ],
      selected: _groupId ?? '',
    );
    if (picked != null) setState(() => _groupId = picked.value);
  }

  void _pickCefr() async {
    final picked = await showSingleSelectSheet<CEFRLevel?>(
      context: context,
      title: 'Trình độ (CEFR)',
      options: [
        const SelectOption<CEFRLevel?>(value: null, label: 'Không đặt'),
        for (final l in CEFRLevel.values)
          SelectOption<CEFRLevel?>(value: l, label: l.label),
      ],
      selected: _cefr,
    );
    if (picked != null) setState(() => _cefr = picked.value);
  }

  void _addTag() {
    final t = _tagInput.text.trim();
    if (t.isNotEmpty && !_tags.contains(t)) setState(() => _tags.add(t));
    _tagInput.clear();
  }

  List<Widget> _stringRows(List<TextEditingController> rows, String addLabel) => [
        ...rows.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: BloomTextField(controller: e.value)),
                    const SizedBox(width: 8),
                    BloomIconButton(
                      icon: Icons.close,
                      tooltip: 'Xoá',
                      onPressed: () => setState(() => rows.removeAt(e.key)),
                    ),
                  ],
                ),
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: BloomPillButton(
            label: addLabel,
            icon: Icons.add,
            variant: BloomButtonVariant.link,
            onPressed: () => setState(() => rows.add(TextEditingController())),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final language =
        ref.watch(userSettingsNotifierProvider.select((s) => s.targetLanguage));
    final groups = knowledgeGroupsFor(language);
    final c = context.bloom;
    final heading = widget.draft != null
        ? 'Xem lại bản nháp'
        : widget.initial == null
            ? 'Ghi chú mới'
            : 'Sửa ghi chú';

    return BloomScaffold(
      appBar: BloomAppBar(title: heading),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const BloomSectionHeader('Tiêu đề'),
                  BloomTextField(
                    controller: _title,
                    hintText: 'Ví dụ: Câu điều kiện loại 2',
                  ),

                  const BloomSectionHeader('Tóm tắt'),
                  BloomTextField(
                    controller: _summary,
                    maxLines: 3,
                    minLines: 2,
                    hintText: '1–2 câu tóm tắt',
                  ),

                  const BloomSectionHeader('Giải thích'),
                  BloomTextField(
                    controller: _explanation,
                    maxLines: 14,
                    minLines: 4,
                    hintText: 'bọc **...**  để in đậm',
                  ),

                  const BloomSectionHeader('Nhóm'),
                  FilterTile(
                    icon: Icons.folder_outlined,
                    label: 'Nhóm',
                    value: _groupId == null
                        ? 'Chưa chọn'
                        : knowledgeGroupLabel(_groupId!),
                    onTap: () => _pickGroup(groups),
                  ),

                  const BloomSectionHeader('Trình độ (CEFR)'),
                  FilterTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'CEFR',
                    value: _cefr?.label ?? 'Không đặt',
                    onTap: _pickCefr,
                  ),

                  const BloomSectionHeader('Công thức / Cấu trúc'),
                  ..._stringRows(_patterns, 'Thêm công thức'),

                  const BloomSectionHeader('Ví dụ'),
                  ..._examples.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: BloomTextField(
                                      controller: e.value.$1,
                                      hintText: 'Câu ví dụ',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  BloomIconButton(
                                    icon: Icons.close,
                                    tooltip: 'Xoá',
                                    onPressed: () => setState(
                                        () => _examples.removeAt(e.key)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              BloomTextField(
                                controller: e.value.$2,
                                hintText: 'Bản dịch tiếng Việt',
                              ),
                            ],
                          ),
                        ),
                      ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BloomPillButton(
                      label: 'Thêm ví dụ',
                      icon: Icons.add,
                      variant: BloomButtonVariant.link,
                      onPressed: () => setState(() => _examples.add(
                          (TextEditingController(), TextEditingController()))),
                    ),
                  ),

                  const BloomSectionHeader('Lỗi thường gặp'),
                  ..._stringRows(_pitfalls, 'Thêm lỗi thường gặp'),

                  const BloomSectionHeader('Thẻ'),
                  if (_tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in _tags)
                            BloomChip(
                              label: t,
                              trailing: GestureDetector(
                                onTap: () => setState(() => _tags.remove(t)),
                                child: Icon(Icons.close,
                                    size: 14, color: c.inkSoft),
                              ),
                            ),
                        ],
                      ),
                    ),
                  BloomTextField(
                    controller: _tagInput,
                    hintText: 'Thêm thẻ rồi nhấn Enter',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTag(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                          color: c.danger, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                  ],
                  BloomPillButton(
                    label: _saving ? 'Đang lưu…' : 'Lưu',
                    block: true,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
