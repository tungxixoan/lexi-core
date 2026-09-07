import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_group.dart';

void main() {
  test('English taxonomy has the spec groups, ending with Khác', () {
    final ids = knowledgeGroupsFor(Language.english).map((g) => g.id).toList();
    expect(ids.first, 'en_tenses');
    expect(ids.last, 'en_other');
    expect(ids, contains('en_conditionals'));
    expect(ids.length, 12);
  });

  test('every language ends with an _other group', () {
    for (final lang in Language.values) {
      final ids = knowledgeGroupsFor(lang).map((g) => g.id).toList();
      expect(ids, isNotEmpty, reason: lang.name);
      expect(ids.last, endsWith('_other'), reason: lang.name);
    }
  });

  test('per-language taxonomy sizes match the spec', () {
    expect(knowledgeGroupsFor(Language.english).length, 12);
    expect(knowledgeGroupsFor(Language.chinese).length, 11);
    expect(knowledgeGroupsFor(Language.korean).length, 9);
    expect(knowledgeGroupsFor(Language.japanese).length, 9);
    expect(knowledgeGroupsFor(Language.vietnamese).length, 5);
  });

  test('every group id is unique across all languages', () {
    final allIds = [
      for (final lang in Language.values)
        ...knowledgeGroupsFor(lang).map((g) => g.id),
    ];
    expect(allIds.toSet().length, allIds.length);
  });

  test('label lookup resolves a known id and passes through an unknown one', () {
    expect(knowledgeGroupLabel('en_tenses'), 'Thì');
    expect(knowledgeGroupLabel('nope_nope'), 'nope_nope');
  });
}
