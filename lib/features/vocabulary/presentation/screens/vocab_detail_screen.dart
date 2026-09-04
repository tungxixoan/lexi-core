// lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../../services/tts_service.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../dictionary/presentation/widgets/pronounce_button.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/vocab_record.dart';
import '../providers/topics_provider.dart';
import '../providers/vocab_bank_provider.dart';

class VocabDetailScreen extends ConsumerStatefulWidget {
  const VocabDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<VocabDetailScreen> createState() => _VocabDetailScreenState();
}

class _VocabDetailScreenState extends ConsumerState<VocabDetailScreen> {
  VocabRecord? _record;
  bool _editing = false;
  bool _loading = true;

  // Edit-mode controllers
  late TextEditingController _meaningCtrl;
  late TextEditingController _notesCtrl;
  late List<TextEditingController> _exampleCtrls;
  late List<String> _editTopicIds;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    final repo = ref.read(vocabRepositoryProvider);
    final language = ref.read(userSettingsNotifierProvider).targetLanguage;
    final record = await repo.getById(widget.id, language: language);
    setState(() {
      _record = record;
      _loading = false;
      if (record != null) _initControllers(record);
    });
  }

  void _initControllers(VocabRecord r) {
    _meaningCtrl = TextEditingController(text: r.meaning);
    _notesCtrl = TextEditingController(text: r.personalNotes);
    _exampleCtrls =
        r.examples.map((e) => TextEditingController(text: e)).toList();
    _editTopicIds = List.from(r.topicIds);
  }

  @override
  void dispose() {
    if (!_loading && _record != null) {
      _meaningCtrl.dispose();
      _notesCtrl.dispose();
      for (final c in _exampleCtrls) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pickTopics(List<Topic> topics) async {
    final result = await showMultiSelectSheet<String>(
      context: context,
      title: 'Chủ đề',
      options: topics
          .map((t) => SelectOption(value: t.id, label: t.name, emoji: t.emoji))
          .toList(),
      initialSelected: _editTopicIds.toSet(),
      maxSelected: 2,
    );
    if (result != null) {
      setState(() => _editTopicIds = result.toList());
    }
  }

  Future<void> _saveEdit() async {
    if (_record == null) return;
    final updated = _record!.copyWith(
      meaning: _meaningCtrl.text.trim(),
      examples: _exampleCtrls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      personalNotes: _notesCtrl.text.trim(),
      topicIds: _editTopicIds,
      updatedAt: DateTime.now(),
    );
    try {
      await ref.read(vocabBankNotifierProvider.notifier).updateRecord(updated);
      setState(() {
        _record = updated;
        _editing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _cancelEdit() {
    if (_record != null) _initControllers(_record!);
    setState(() => _editing = false);
  }

  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá khỏi Ngân hàng từ?'),
        content: Text('"${_record!.headword}" sẽ bị xoá. Không thể hoàn tác.'),
        actions: [
          BloomPillButton(
            label: 'Huỷ',
            variant: BloomButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          BloomPillButton(
            label: 'Xoá',
            variant: BloomButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(vocabBankNotifierProvider.notifier).delete(widget.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BloomScaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_record == null) {
      return const BloomScaffold(
        appBar: BloomAppBar(title: ''),
        body: Center(child: Text('Không tìm thấy từ.')),
      );
    }

    final r = _record!;
    final c = context.bloom;
    final tts = ref.read(ttsServiceProvider);
    final settings = ref.read(userSettingsNotifierProvider);
    final canSpeak = settings.targetLanguage.ttsCloudCode != null;

    return BloomScaffold(
      appBar: BloomAppBar(
        title: r.headword,
        actions: _editing
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: BloomPillButton(
                    label: 'Huỷ',
                    variant: BloomButtonVariant.link,
                    onPressed: _cancelEdit,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: BloomPillButton(
                    label: 'Lưu',
                    variant: BloomButtonVariant.primary,
                    onPressed: _saveEdit,
                  ),
                ),
                const SizedBox(width: 8),
              ]
            : [
                BloomIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Sửa',
                  onPressed: () => setState(() => _editing = true),
                ),
                BloomIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Xoá',
                  onPressed: _deleteRecord,
                ),
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Headword + IPA + CEFR + TTS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.headword,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        if (r.ipa.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            r.ipa,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: c.inkSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canSpeak) ...[
                    const SizedBox(width: 8),
                    PronounceButton(
                      onPressed: () => tts.pronounce(
                          r.headword, settings.targetLanguage,
                          tier: PronunciationTier.word),
                    ),
                  ],
                  const SizedBox(width: 8),
                  BloomCefrPill(r.cefrLevel.label),
                ],
              ),

              // Meaning
              const BloomSectionHeader('Nghĩa'),
              _editing
                  ? BloomTextField(
                      controller: _meaningCtrl,
                      maxLines: 3,
                      minLines: 2,
                    )
                  : Text(r.meaning, style: const TextStyle(fontSize: 16)),

              // Definition — read-only, optional
              if (!_editing && r.definition.isNotEmpty) ...[
                const BloomSectionHeader('Định nghĩa'),
                Text(r.definition, style: TextStyle(color: c.inkSoft)),
              ],

              // Synonyms — read-only, optional
              if (!_editing && r.synonyms.isNotEmpty) ...[
                const BloomSectionHeader('Từ đồng nghĩa'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final s in r.synonyms) BloomChip(label: s)],
                ),
              ],

              // Examples
              const BloomSectionHeader('Ví dụ'),
              if (_editing) ...[
                ..._exampleCtrls.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: BloomTextField(controller: e.value),
                            ),
                            const SizedBox(width: 8),
                            BloomIconButton(
                              icon: Icons.close,
                              onPressed: () =>
                                  setState(() => _exampleCtrls.removeAt(e.key)),
                            ),
                          ],
                        ),
                      ),
                    ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BloomPillButton(
                    label: 'Thêm ví dụ',
                    variant: BloomButtonVariant.secondary,
                    icon: Icons.add,
                    onPressed: () => setState(
                        () => _exampleCtrls.add(TextEditingController())),
                  ),
                ),
              ] else
                ...r.examples.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e.key + 1}. ',
                                style: TextStyle(color: c.inkSoft)),
                            Expanded(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: c.inkSoft),
                              ),
                            ),
                            if (canSpeak) ...[
                              const SizedBox(width: 8),
                              PronounceButton(
                                size: 22,
                                onPressed: () => tts.pronounce(
                                    e.value, settings.targetLanguage,
                                    tier: PronunciationTier.sentence),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

              // Topics
              const BloomSectionHeader('Chủ đề'),
              if (_editing)
                ref.watch(topicsNotifierProvider).when(
                      data: (topics) {
                        final selectedTopics = topics
                            .where((t) => _editTopicIds.contains(t.id))
                            .toList();
                        return FilterTile(
                          icon: Icons.sell_outlined,
                          label: 'Chủ đề (tối đa 2)',
                          value: selectedTopics.isEmpty
                              ? 'Chưa chọn'
                              : selectedTopics
                                  .map((t) => '${t.emoji} ${t.name}')
                                  .join(', '),
                          onTap: () => _pickTopics(topics),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text(e.toString()),
                    )
              else if (r.topicIds.isEmpty)
                Text('Chưa có', style: TextStyle(color: c.inkSoft))
              else
                ref.watch(topicsNotifierProvider).when(
                      data: (topics) {
                        final matched = r.topicIds.map((id) {
                          final found =
                              topics.where((t) => t.id == id).toList();
                          return found.isNotEmpty
                              ? '${found.first.emoji} ${found.first.name}'
                              : id;
                        }).toList();
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in matched)
                              BloomChip(
                                  label: label, style: BloomChipStyle.topic),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                          height: 32, child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

              // Personal notes
              const BloomSectionHeader('Ghi chú cá nhân'),
              _editing
                  ? BloomTextField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      minLines: 3,
                      hintText: 'Thêm ghi chú để dễ nhớ…',
                    )
                  : r.personalNotes.isEmpty
                      ? Text('Chưa có ghi chú.',
                          style: TextStyle(color: c.inkSoft))
                      : Text(r.personalNotes,
                          style: TextStyle(color: c.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
