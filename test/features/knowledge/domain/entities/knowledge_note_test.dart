import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';

void main() {
  final json = {
    'id': 'n1',
    'title': 'Câu điều kiện loại 2',
    'summary': 'Giả định không có thật ở hiện tại.',
    'explanation': 'Dùng **were** cho mọi ngôi.',
    'patterns': ['If + S + V-past, S + would + V'],
    'examples': [
      {'text': 'If I were you...', 'translation': 'Nếu tôi là bạn...'}
    ],
    'pitfalls': ['Không dùng "was" trong văn trang trọng.'],
    'groupId': 'en_conditionals',
    'tags': ['ngu-phap'],
    'cefrLevel': 'b1',
    'targetLanguage': 'english',
    'source': 'ai',
    'sourcePrompt': 'giải thích loại 2',
    'createdAt': '2026-09-07T00:00:00.000Z',
    'updatedAt': '2026-09-07T00:00:00.000Z',
  };

  test('fromJson / toJson round-trip', () {
    final note = KnowledgeNote.fromJson(json);
    expect(note.targetLanguage, Language.english);
    expect(note.cefrLevel, CEFRLevel.b1);
    expect(note.origin, KnowledgeNoteOrigin.ai);
    expect(note.examples.single.translation, 'Nếu tôi là bạn...');
    expect(note.toJson(), json);
  });

  test('fromJson defends against missing lists and unknown enums', () {
    final note = KnowledgeNote.fromJson({
      'id': 'n2',
      'title': 't',
      'summary': 's',
      'explanation': 'e',
      'groupId': 'en_other',
      'targetLanguage': 'english',
      'source': 'weird',
      'cefrLevel': null,
      'createdAt': '2026-09-07T00:00:00.000Z',
      'updatedAt': '2026-09-07T00:00:00.000Z',
    });
    expect(note.patterns, isEmpty);
    expect(note.examples, isEmpty);
    expect(note.pitfalls, isEmpty);
    expect(note.tags, isEmpty);
    expect(note.cefrLevel, isNull);
    expect(note.origin, KnowledgeNoteOrigin.manual); // fallback
  });

  group('fromJson parses dates defensively', () {
    Map<String, dynamic> withDate(Object? d) => {
          'id': 'n',
          'title': 't',
          'summary': 's',
          'explanation': 'e',
          'groupId': 'en_other',
          'targetLanguage': 'english',
          'source': 'manual',
          'createdAt': d,
          'updatedAt': d,
        };

    test('null → epoch, does not throw', () {
      final note = KnowledgeNote.fromJson(withDate(null));
      expect(note.createdAt,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });

    test('a Firestore Timestamp', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 3, 4));
      expect(KnowledgeNote.fromJson(withDate(ts)).createdAt,
          DateTime.utc(2026, 3, 4));
    });

    test('an int of epoch millis', () {
      final millis = DateTime.utc(2025, 1, 2).millisecondsSinceEpoch;
      expect(KnowledgeNote.fromJson(withDate(millis)).createdAt,
          DateTime.utc(2025, 1, 2));
    });
  });
}
