// lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/vocab_record.dart';
import '../providers/topics_provider.dart';
import '../providers/vocab_bank_provider.dart';

class VocabBankScreen extends ConsumerStatefulWidget {
  const VocabBankScreen({super.key});

  @override
  ConsumerState<VocabBankScreen> createState() => _VocabBankScreenState();
}

class _VocabBankScreenState extends ConsumerState<VocabBankScreen> {
  final Set<String> _selectedTopicIds = {};
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTopicPicker(List<Topic> topics) async {
    final result = await showMultiSelectSheet<String>(
      context: context,
      title: 'Chủ đề',
      options: topics
          .map((t) => SelectOption(value: t.id, label: t.name, emoji: t.emoji))
          .toList(),
      initialSelected: _selectedTopicIds,
    );
    if (result != null) {
      setState(() {
        _selectedTopicIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  List<VocabRecord> _filter(List<VocabRecord> records, Language targetLanguage) {
    var result = records.where((r) => r.targetLanguage == targetLanguage).toList();
    if (_selectedTopicIds.isNotEmpty) {
      result = result
          .where((r) => r.topicIds.any(_selectedTopicIds.contains))
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((r) =>
              r.headword.toLowerCase().contains(q) ||
              r.meaning.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vocabAsync = ref.watch(vocabBankNotifierProvider);
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final targetLanguage = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Vocab Bank · ${targetLanguage.label}'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add custom topic',
            onPressed: () => _showAddTopicDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search words...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 8),
          // Topic filter — opens a bottom sheet with multi-select checkboxes
          topicsAsync.when(
            data: (topics) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openTopicPicker(topics),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.sell_outlined,
                            size: 20, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedTopicIds.isEmpty
                                ? 'Chủ đề: Tất cả'
                                : 'Chủ đề: ${_selectedTopicIds.length} đã chọn',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down,
                            color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox(height: 48),
          ),
          const Divider(height: 1),
          // Vocab list
          Expanded(
            child: vocabAsync.when(
              data: (records) {
                final filtered = _filter(records, targetLanguage);
                if (filtered.isEmpty && records.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No words saved yet.',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Look up a word and tap Save.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No words match your search or filter.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _VocabCard(record: filtered[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTopicDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📌');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Topic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Topic name', hintText: 'e.g. My Vocabulary'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(labelText: 'Emoji'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(topicsNotifierProvider.notifier)
                    .addTopic(nameCtrl.text, emojiCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    emojiCtrl.dispose();
  }
}

class _VocabCard extends StatelessWidget {
  const _VocabCard({required this.record});
  final VocabRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => context.push('/vocab/${record.id}'),
        title: Text(
          record.headword,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.ipa.isNotEmpty)
              Text(
                record.ipa,
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary),
              ),
            Text(
              record.meaning,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Chip(
          label: Text(record.inputType.name,
              style: const TextStyle(fontSize: 11)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        isThreeLine: record.ipa.isNotEmpty,
      ),
    );
  }
}
