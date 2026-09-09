import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_starter_library.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_group.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes the bundled English starter file', () async {
    final lib = KnowledgeStarterLibrary(); // uses rootBundle
    final notes = await lib.notesFor(Language.english);
    expect(notes, isNotEmpty);
    expect(notes.every((n) => n.origin.name == 'starter'), isTrue);
    expect(notes.map((n) => n.id).toSet().length, notes.length); // unique ids
  });

  test('returns [] for a language with no starter asset', () async {
    final lib = KnowledgeStarterLibrary(
      loadAsset: (_) async => throw Exception('asset not found'),
    );
    expect(await lib.notesFor(Language.korean), isEmpty);
  });

  test('English starter set has all 12 spec ids in valid groups', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final notes = await KnowledgeStarterLibrary().notesFor(Language.english);
    const expectedIds = {
      'starter_en_tenses_overview', 'starter_en_present_simple',
      'starter_en_present_continuous', 'starter_en_present_simple_vs_continuous',
      'starter_en_past_simple', 'starter_en_present_perfect',
      'starter_en_present_perfect_vs_past', 'starter_en_future_forms',
      'starter_en_conditionals_0_1', 'starter_en_conditionals_2_3',
      'starter_en_articles', 'starter_en_comparatives_superlatives',
    };
    expect(notes.map((n) => n.id).toSet(), expectedIds);
    final validGroups =
        knowledgeGroupsFor(Language.english).map((g) => g.id).toSet();
    for (final n in notes) {
      expect(validGroups, contains(n.groupId), reason: n.id);
      expect(n.summary, isNotEmpty, reason: n.id);
      expect(n.explanation, isNotEmpty, reason: n.id);
      expect(n.examples.length, greaterThanOrEqualTo(2), reason: n.id);
    }
  });

  test('every starter string has balanced ** bold markers', () async {
    final notes = await KnowledgeStarterLibrary().notesFor(Language.english);
    for (final n in notes) {
      for (final s in [n.summary, n.explanation, ...n.pitfalls]) {
        expect('**'.allMatches(s).length.isEven, isTrue,
            reason: '${n.id}: unbalanced ** in "$s"');
      }
    }
  });
}
