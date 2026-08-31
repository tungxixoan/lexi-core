// lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/topic.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/topics_provider.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';

class SaveVocabSheet extends ConsumerStatefulWidget {
  const SaveVocabSheet({super.key, required this.result});
  final WordPhraseResult result;

  @override
  ConsumerState<SaveVocabSheet> createState() => _SaveVocabSheetState();
}

class _SaveVocabSheetState extends ConsumerState<SaveVocabSheet> {
  late final TextEditingController _meaningCtrl;
  late final TextEditingController _notesCtrl;
  late List<String> _selectedTopicIds;
  late List<TextEditingController> _exampleCtrls;
  bool _topicsPreselected = false;

  @override
  void initState() {
    super.initState();
    _meaningCtrl = TextEditingController(text: widget.result.meaning);
    _notesCtrl = TextEditingController();
    _exampleCtrls = widget.result.examples
        .map((e) => TextEditingController(text: e))
        .toList();
    _selectedTopicIds = [];
  }

  @override
  void dispose() {
    _meaningCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _exampleCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTopics(List<Topic> topics) async {
    final result = await showMultiSelectSheet<String>(
      context: context,
      title: 'Topics',
      options: topics
          .map((t) => SelectOption(value: t.id, label: t.name, emoji: t.emoji))
          .toList(),
      initialSelected: _selectedTopicIds.toSet(),
      maxSelected: 2,
    );
    if (result != null) {
      setState(() => _selectedTopicIds = result.toList());
    }
  }

  void _preSelectTopics(List<Topic> topics) {
    if (_topicsPreselected) return;
    _topicsPreselected = true;
    final suggestions = widget.result.suggestedTopics;
    for (final suggestion in suggestions) {
      final match = topics.where(
        (t) => t.name.toLowerCase() == suggestion.toLowerCase(),
      );
      if (match.isNotEmpty && _selectedTopicIds.length < 2) {
        _selectedTopicIds.add(match.first.id);
      }
    }
  }

  Future<void> _save() async {
    final settings = ref.read(userSettingsNotifierProvider);
    final record = VocabRecord(
      id: const Uuid().v4(),
      headword: widget.result.headword,
      inputType: widget.result.inputType,
      ipa: widget.result.ipa,
      meaning: _meaningCtrl.text.trim(),
      examples: _exampleCtrls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      personalNotes: _notesCtrl.text.trim(),
      topicIds: _selectedTopicIds,
      targetLanguage: settings.targetLanguage,
      cefrLevel: widget.result.cefrLevel ?? CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      definition: widget.result.definition,
      synonyms: widget.result.synonyms,
    );
    try {
      await ref.read(vocabBankNotifierProvider.notifier).save(record);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final theme = Theme.of(context);

    // Own SelectionArea: the app-wide one (main.dart) and this modal's
    // content both sit under the same Navigator, but modal routes render in
    // a separate OverlayEntry stacked visually on top — the outer
    // SelectionArea attributes drag-select pointer events to whichever
    // content is earliest in paint/traversal order (the screen behind the
    // sheet), not what's visually on top. A nested SelectionArea gives this
    // sheet its own independent selection scope so drag-select targets its
    // own text instead of the screen underneath.
    return SelectionArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Save "${widget.result.headword}"',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Meaning
                  Text('Meaning', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _meaningCtrl,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  // Definition (English) — read-only
                  if (widget.result.definition.isNotEmpty) ...[
                    Text('Definition', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(widget.result.definition,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                  ],
                  // Synonyms — read-only
                  if (widget.result.synonyms.isNotEmpty) ...[
                    Text('Synonyms', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.result.synonyms
                          .map((s) => Chip(
                                label: Text(s),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Examples
                  Text('Examples', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  ..._exampleCtrls.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: e.value,
                                  decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(
                                    () => _exampleCtrls.removeAt(e.key)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add example'),
                    onPressed: () => setState(
                        () => _exampleCtrls.add(TextEditingController())),
                  ),
                  const SizedBox(height: 16),
                  // Topics
                  Text('Topics', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  topicsAsync.when(
                    data: (topics) {
                      if (!_topicsPreselected) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() => _preSelectTopics(topics));
                        });
                      }
                      final selectedTopics = topics
                          .where((t) => _selectedTopicIds.contains(t.id))
                          .toList();
                      return FilterTile(
                        icon: Icons.sell_outlined,
                        label: 'Topics (tối đa 2)',
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
                  ),
                  const SizedBox(height: 16),
                  // Personal notes
                  Text('Personal notes', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add a note to help you remember...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Save button pinned at bottom
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('Save to Vocab Bank'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
