import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/saved_exercises_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/saved_exercise.dart';

const _uid = 'u1';

SavedExercisesService _service({
  FakeFirebaseFirestore? firestore,
  String? uid = _uid,
}) =>
    SavedExercisesService(
      firestore: firestore ?? FakeFirebaseFirestore(),
      currentUid: () => uid,
    );

Future<Map<String, dynamic>> _doc(
  FakeFirebaseFirestore fs,
  String collection,
  String id,
) async =>
    (await fs
            .collection('users')
            .doc(_uid)
            .collection(collection)
            .doc(id)
            .get())
        .data()!;

void main() {
  test('save() writes the web doc body to reading_exercises with id in body',
      () async {
    final fs = FakeFirebaseFirestore();
    final id = await _service(firestore: fs).save(
      type: SavedExerciseType.bilingual,
      passageJson: const {
        'sentences': [],
        'vocabIds': ['v1']
      },
      generationFilters: const {
        'topicIds': ['t1'],
        'maxCefr': 'b1',
        'wordCount': 120
      },
      targetLanguage: Language.english,
    );

    expect(id, isNotNull);
    final data = await _doc(fs, 'reading_exercises', id!);
    expect(data['type'], 'bilingual');
    expect(data['passage'], {
      'sentences': [],
      'vocabIds': ['v1']
    });
    expect(data['generationFilters'], {
      'topicIds': ['t1'],
      'maxCefr': 'b1',
      'wordCount': 120
    });
    expect(data['targetLanguage'], 'english');
    expect(data['createdAt'], isA<String>());
    expect(data['id'], id);
  });

  test('save() routes dictation/comprehension to listening_exercises',
      () async {
    final fs = FakeFirebaseFirestore();
    final id = await _service(firestore: fs).save(
      type: SavedExerciseType.dictation,
      passageJson: const {'text': 'hello'},
      generationFilters: const {'difficulty': 'medium'},
      targetLanguage: Language.english,
    );
    final data = await _doc(fs, 'listening_exercises', id!);
    expect(data['type'], 'dictation');
  });

  group('save + getRandom round-trip', () {
    test('bilingual', () async {
      final fs = FakeFirebaseFirestore();
      final svc = _service(firestore: fs);
      final id = await svc.save(
        type: SavedExerciseType.bilingual,
        passageJson: const {
          'vocabIds': ['v1']
        },
        generationFilters: const {
          'topicIds': <String>[],
          'maxCefr': null,
          'wordCount': null
        },
        targetLanguage: Language.english,
      );
      final got = await svc.getRandom(
        type: SavedExerciseType.bilingual,
        targetLanguage: Language.english,
        filters: const {
          'topicIds': <String>[],
          'maxCefr': null,
          'wordCount': null
        },
      );
      expect(got!.id, id);
      expect(got.passageJson, {
        'vocabIds': ['v1']
      });
    });

    test('part5', () async {
      final fs = FakeFirebaseFirestore();
      final svc = _service(firestore: fs);
      final id = await svc.save(
        type: SavedExerciseType.part5,
        passageJson: const {
          'questions': [
            {'sentenceWithBlank': 'a ___ b'}
          ]
        },
        generationFilters: const {
          'topicIds': <String>[],
          'volumes': <String>[]
        },
        targetLanguage: Language.english,
      );
      final got = await svc.getRandom(
        type: SavedExerciseType.part5,
        targetLanguage: Language.english,
        filters: const {'topicIds': <String>[], 'volumes': <String>[]},
      );
      expect(got!.id, id);
      expect((got.passageJson['questions'] as List).length, 1);
    });

    test('dictation', () async {
      final fs = FakeFirebaseFirestore();
      final svc = _service(firestore: fs);
      final id = await svc.save(
        type: SavedExerciseType.dictation,
        passageJson: const {'text': 'x'},
        generationFilters: const {'difficulty': 'easy'},
        targetLanguage: Language.english,
      );
      final got = await svc.getRandom(
        type: SavedExerciseType.dictation,
        targetLanguage: Language.english,
        filters: const {'difficulty': 'easy'},
      );
      expect(got!.id, id);
    });

    test('getRandom respects targetLanguage', () async {
      final fs = FakeFirebaseFirestore();
      final svc = _service(firestore: fs);
      await svc.save(
        type: SavedExerciseType.dictation,
        passageJson: const {'text': 'x'},
        generationFilters: const {'difficulty': 'easy'},
        targetLanguage: Language.english,
      );
      final got = await svc.getRandom(
        type: SavedExerciseType.dictation,
        targetLanguage: Language.chinese,
        filters: const {'difficulty': 'easy'},
      );
      expect(got, isNull);
    });
  });

  group('matchesBilingual', () {
    Future<({String id, Map<String, dynamic> passageJson})?> run({
      required Map<String, dynamic> saved,
      required Map<String, dynamic> filters,
    }) async {
      final fs = FakeFirebaseFirestore();
      final svc = _service(firestore: fs);
      await svc.save(
        type: SavedExerciseType.bilingual,
        passageJson: const {'vocabIds': <String>[]},
        generationFilters: saved,
        targetLanguage: Language.english,
      );
      return svc.getRandom(
        type: SavedExerciseType.bilingual,
        targetLanguage: Language.english,
        filters: filters,
      );
    }

    test('topic-overlap filter excludes a non-overlapping saved doc', () async {
      final got = await run(
        saved: const {
          'topicIds': ['t2'],
          'maxCefr': null,
          'wordCount': null
        },
        filters: const {
          'topicIds': ['t1'],
          'maxCefr': null,
          'wordCount': null
        },
      );
      expect(got, isNull);
    });

    test('maxCefr ceiling excludes a saved b2 when the filter is a2', () async {
      final got = await run(
        saved: const {
          'topicIds': <String>[],
          'maxCefr': 'b2',
          'wordCount': null
        },
        filters: const {
          'topicIds': <String>[],
          'maxCefr': 'a2',
          'wordCount': null
        },
      );
      expect(got, isNull);
    });

    test('maxCefr ceiling allows a saved a1 when the filter is b2', () async {
      final got = await run(
        saved: const {
          'topicIds': <String>[],
          'maxCefr': 'a1',
          'wordCount': null
        },
        filters: const {
          'topicIds': <String>[],
          'maxCefr': 'b2',
          'wordCount': null
        },
      );
      expect(got, isNotNull);
    });

    test('wordCount mismatch excludes', () async {
      final got = await run(
        saved: const {
          'topicIds': <String>[],
          'maxCefr': null,
          'wordCount': 100
        },
        filters: const {
          'topicIds': <String>[],
          'maxCefr': null,
          'wordCount': 150
        },
      );
      expect(got, isNull);
    });
  });

  group('matchesToeic', () {
    Future<({String id, Map<String, dynamic> passageJson})?> run({
      required Map<String, dynamic> saved,
      required Map<String, dynamic> filters,
    }) async {
      final fs = FakeFirebaseFirestore();
      final svc = _service(firestore: fs);
      await svc.save(
        type: SavedExerciseType.part5,
        passageJson: const {'questions': <dynamic>[]},
        generationFilters: saved,
        targetLanguage: Language.english,
      );
      return svc.getRandom(
        type: SavedExerciseType.part5,
        targetLanguage: Language.english,
        filters: filters,
      );
    }

    test('volumes overlap matches', () async {
      final got = await run(
        saved: const {
          'topicIds': <String>[],
          'volumes': ['A', 'B']
        },
        filters: const {
          'topicIds': <String>[],
          'volumes': ['B']
        },
      );
      expect(got, isNotNull);
    });

    test('volumes disjoint excludes', () async {
      final got = await run(
        saved: const {
          'topicIds': <String>[],
          'volumes': ['A']
        },
        filters: const {
          'topicIds': <String>[],
          'volumes': ['C']
        },
      );
      expect(got, isNull);
    });

    test('empty filter volumes matches anything', () async {
      final got = await run(
        saved: const {
          'topicIds': <String>[],
          'volumes': ['A']
        },
        filters: const {'topicIds': <String>[], 'volumes': <String>[]},
      );
      expect(got, isNotNull);
    });

    test('old doc missing topicIds does not throw and falls through', () async {
      final got = await run(
        saved: const {
          'volumes': ['A']
        },
        filters: const {
          'topicIds': ['t1'],
          'volumes': <String>[]
        },
      );
      expect(got, isNull); // no topicIds → no overlap with requested t1
    });
  });

  group('matchesComprehension', () {
    Future<({String id, Map<String, dynamic> passageJson})?> run({
      required Map<String, dynamic> saved,
      required Map<String, dynamic> filters,
    }) async {
      final fs = FakeFirebaseFirestore();
      final svc = _service(firestore: fs);
      await svc.save(
        type: SavedExerciseType.comprehension,
        passageJson: const {'turns': <dynamic>[]},
        generationFilters: saved,
        targetLanguage: Language.english,
      );
      return svc.getRandom(
        type: SavedExerciseType.comprehension,
        targetLanguage: Language.english,
        filters: filters,
      );
    }

    test('level: null filter matches a saved c1', () async {
      final got = await run(
        saved: const {'context': 'business', 'level': 'c1'},
        filters: const {'context': 'business', 'level': null},
      );
      expect(got, isNotNull);
    });

    test('context mismatch excludes', () async {
      final got = await run(
        saved: const {'context': 'travel', 'level': 'a1'},
        filters: const {'context': 'business', 'level': null},
      );
      expect(got, isNull);
    });

    test('level ceiling excludes a saved c1 when the filter is a2', () async {
      final got = await run(
        saved: const {'context': 'business', 'level': 'c1'},
        filters: const {'context': 'business', 'level': 'a2'},
      );
      expect(got, isNull);
    });
  });

  test('getRandom with excludeId skips that doc', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _service(firestore: fs);
    final id = await svc.save(
      type: SavedExerciseType.dictation,
      passageJson: const {'text': 'x'},
      generationFilters: const {'difficulty': 'easy'},
      targetLanguage: Language.english,
    );
    final got = await svc.getRandom(
      type: SavedExerciseType.dictation,
      targetLanguage: Language.english,
      filters: const {'difficulty': 'easy'},
      excludeId: id,
    );
    expect(got, isNull);
  });

  test('getRandom returns null when nothing matches', () async {
    final fs = FakeFirebaseFirestore();
    final svc = _service(firestore: fs);
    await svc.save(
      type: SavedExerciseType.dictation,
      passageJson: const {'text': 'x'},
      generationFilters: const {'difficulty': 'easy'},
      targetLanguage: Language.english,
    );
    final got = await svc.getRandom(
      type: SavedExerciseType.dictation,
      targetLanguage: Language.english,
      filters: const {'difficulty': 'hard'},
    );
    expect(got, isNull);
  });

  test('usedBilingualVocabIds unions across bilingual docs, ignores part5',
      () async {
    final fs = FakeFirebaseFirestore();
    final svc = _service(firestore: fs);
    await svc.save(
      type: SavedExerciseType.bilingual,
      passageJson: const {
        'vocabIds': ['v1', 'v2']
      },
      generationFilters: const {},
      targetLanguage: Language.english,
    );
    await svc.save(
      type: SavedExerciseType.bilingual,
      passageJson: const {
        'vocabIds': ['v2', 'v3']
      },
      generationFilters: const {},
      targetLanguage: Language.english,
    );
    await svc.save(
      type: SavedExerciseType.part5,
      passageJson: const {
        'questions': [],
        'vocabIds': ['v9']
      },
      generationFilters: const {},
      targetLanguage: Language.english,
    );
    expect(await svc.usedBilingualVocabIds(), {'v1', 'v2', 'v3'});
  });

  group('signed out', () {
    test('save returns null', () async {
      final id = await _service(uid: null).save(
        type: SavedExerciseType.bilingual,
        passageJson: const {},
        generationFilters: const {},
        targetLanguage: Language.english,
      );
      expect(id, isNull);
    });

    test('getRandom returns null', () async {
      final got = await _service(uid: null).getRandom(
        type: SavedExerciseType.bilingual,
        targetLanguage: Language.english,
        filters: const {},
      );
      expect(got, isNull);
    });

    test('usedBilingualVocabIds returns empty', () async {
      expect(await _service(uid: null).usedBilingualVocabIds(), isEmpty);
    });
  });

  test('a web-saved minimal part5 doc loads without throwing', () async {
    final fs = FakeFirebaseFirestore();
    // Doc as the web app writes it: passage carries ONLY the web keys.
    await fs
        .collection('users')
        .doc(_uid)
        .collection('reading_exercises')
        .doc('web1')
        .set({
      'type': 'part5',
      'passage': {
        'questions': [
          {
            'sentenceWithBlank': 'The report is ___ complete.',
            'options': ['near', 'nearly', 'nearness', 'neared'],
            'correctIndex': 1,
            'explanation': 'adverb',
          }
        ]
      },
      'generationFilters': {'topicIds': <String>[], 'volumes': <String>[]},
      'targetLanguage': 'english',
      'createdAt': '2026-09-01T00:00:00.000Z',
      'id': 'web1',
    });

    final got = await _service(firestore: fs).getRandom(
      type: SavedExerciseType.part5,
      targetLanguage: Language.english,
      filters: const {'topicIds': <String>[], 'volumes': <String>[]},
    );
    expect(got!.id, 'web1');
    expect((got.passageJson['questions'] as List).length, 1);
  });
}
