import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_starter_library.dart';

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
}
