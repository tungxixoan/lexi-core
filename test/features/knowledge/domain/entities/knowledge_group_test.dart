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
      expect(ids.last, knowledgeOtherGroupId(lang), reason: lang.name);
    }
  });

  test('label lookup resolves a known id and passes through an unknown one', () {
    expect(knowledgeGroupLabel('en_tenses'), 'Thì');
    expect(knowledgeGroupLabel('nope_nope'), 'nope_nope');
  });
}
