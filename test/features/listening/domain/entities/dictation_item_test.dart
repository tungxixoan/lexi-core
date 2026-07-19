import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';

void main() {
  test('holds all constructor fields', () {
    final item = DictationItem(
      id: 'item-1',
      target: 'She showed remarkable perseverance in her work.',
      vietnamese: 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.',
      vocabIds: const ['id1', 'id2'],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 7, 19),
    );

    expect(item.id, 'item-1');
    expect(item.target, 'She showed remarkable perseverance in her work.');
    expect(item.vietnamese, 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.');
    expect(item.vocabIds, ['id1', 'id2']);
    expect(item.level, CEFRLevel.b1);
    expect(item.context, AppContext.general);
    expect(item.targetLanguage, Language.english);
    expect(item.generatedAt, DateTime(2026, 7, 19));
  });

  test('vocabIds can be empty', () {
    final item = DictationItem(
      id: 'item-2',
      target: 'Hello world.',
      vietnamese: 'Xin chào thế giới.',
      vocabIds: const [],
      level: CEFRLevel.a1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026),
    );
    expect(item.vocabIds, isEmpty);
  });
}
