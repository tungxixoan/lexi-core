// lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
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
    final record = await repo.getById(widget.id);
    setState(() {
      _record = record;
      _loading = false;
      if (record != null) _initControllers(record);
    });
  }

  void _initControllers(VocabRecord r) {
    _meaningCtrl = TextEditingController(text: r.meaning);
    _notesCtrl = TextEditingController(text: r.personalNotes);
    _exampleCtrls = r.examples.map((e) => TextEditingController(text: e)).toList();
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
      title: 'Topics',
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
        title: const Text('Remove from Vocab Bank?'),
        content: Text(
            '"${_record!.headword}" will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Word not found.')),
      );
    }

    final r = _record!;
    final theme = Theme.of(context);
    final tts = ref.read(ttsServiceProvider);
    final settings = ref.read(userSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(r.headword),
        actions: _editing
            ? [
                TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _saveEdit,
                  child: const Text('Save'),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () => setState(() => _editing = true),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                  color: Colors.red,
                  onPressed: _deleteRecord,
                ),
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headword + IPA + TTS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.headword,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (r.ipa.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          r.ipa,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: () =>
                      tts.speak(r.headword, settings.targetLanguage),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Meaning
            _SectionLabel('Meaning'),
            const SizedBox(height: 6),
            _editing
                ? TextField(
                    controller: _meaningCtrl,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                  )
                : Text(r.meaning, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),

            // Examples
            _SectionLabel('Examples'),
            const SizedBox(height: 6),
            if (_editing) ...[
              ..._exampleCtrls.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: e.value,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 20, color: Colors.red),
                            onPressed: () =>
                                setState(() => _exampleCtrls.removeAt(e.key)),
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
            ] else
              ...r.examples.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.key + 1}. ',
                              style: TextStyle(
                                  color: theme.colorScheme.outline)),
                          Expanded(
                            child: Text(
                              e.value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up_outlined,
                                size: 18),
                            onPressed: () =>
                                tts.speak(e.value, settings.targetLanguage),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 16),

            // Topics
            _SectionLabel('Topics'),
            const SizedBox(height: 6),
            if (_editing)
              ref.watch(topicsNotifierProvider).when(
                    data: (topics) {
                      final selectedTopics = topics
                          .where((t) => _editTopicIds.contains(t.id))
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
                  )
            else if (r.topicIds.isEmpty)
              Text('None',
                  style: TextStyle(color: theme.colorScheme.outline))
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
                        children: matched
                            .map((label) => Chip(
                                  label: Text(label),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const SizedBox(
                        height: 32, child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
            const SizedBox(height: 16),

            // Personal notes
            _SectionLabel('Personal notes'),
            const SizedBox(height: 6),
            _editing
                ? TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Add a note to help you remember...',
                      border: OutlineInputBorder(),
                    ),
                  )
                : r.personalNotes.isEmpty
                    ? Text('No notes.',
                        style: TextStyle(color: theme.colorScheme.outline))
                    : Text(r.personalNotes, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
