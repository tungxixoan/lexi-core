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
    expect(
        item.vietnamese, 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.');
    expect(item.vocabIds, ['id1', 'id2']);
    expect(item.level, CEFRLevel.b1);
    expect(item.context, AppContext.general);
    expect(item.targetLanguage, Language.english);
    expect(item.generatedAt, DateTime(2026, 7, 19));
  });

  test('toJson / fromJson round-trips', () {
    final item = DictationItem(
      id: 'item-1',
      target: 'She showed remarkable perseverance in her work.',
      vietnamese: 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.',
      vocabIds: const ['id1', 'id2'],
      level: CEFRLevel.b1,
      context: AppContext.business,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 7, 19),
    );
    final json = item.toJson();
    expect(json['target'], item.target);
    expect(json['vietnamese'], item.vietnamese);
    expect(json['vocabIds'], ['id1', 'id2']);
    expect(json['level'], 'b1');
    expect(json['context'], 'business');
    expect(json['targetLanguage'], 'english');

    final decoded = DictationItem.fromJson(json);
    expect(decoded.id, item.id);
    expect(decoded.target, item.target);
    expect(decoded.vietnamese, item.vietnamese);
    expect(decoded.vocabIds, item.vocabIds);
    expect(decoded.level, CEFRLevel.b1);
    expect(decoded.context, AppContext.business);
    expect(decoded.targetLanguage, Language.english);
    expect(decoded.generatedAt, item.generatedAt);
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
