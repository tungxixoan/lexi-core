// test/services/tts_service_test.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/services/cloud_function_caller.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/services/tts_service.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class FakeSource extends Fake implements Source {}

class _FakeCaller implements CloudFunctionCaller {
  _FakeCaller({this.response, this.error});
  Map<String, dynamic>? response;
  Object? error;
  String? capturedName;
  Map<String, dynamic>? capturedData;

  @override
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    capturedName = name;
    capturedData = data;
    if (error != null) throw error!;
    return response!;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSource());
  });

  late MockAudioPlayer mockPlayer;

  setUp(() {
    mockPlayer = MockAudioPlayer();
    when(() => mockPlayer.play(any())).thenAnswer((_) async {});
    when(() => mockPlayer.stop()).thenAnswer((_) async {});
    when(() => mockPlayer.setPlaybackRate(any())).thenAnswer((_) async {});
    when(() => mockPlayer.onPlayerStateChanged)
        .thenAnswer((_) => Stream.value(PlayerState.completed));
  });

  group('CloudTtsService.pronounce', () {
    test(
        'sends {text, language, tier} to getPronunciation and plays the returned url',
        () async {
      final caller =
          _FakeCaller(response: {'url': 'https://example.com/a.wav'});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.pronounce('hello', Language.english,
          tier: PronunciationTier.word);

      expect(caller.capturedName, 'getPronunciation');
      expect(caller.capturedData,
          {'text': 'hello', 'language': 'en', 'tier': 'word'});
      verify(() => mockPlayer.play(any(that: isA<UrlSource>()))).called(1);
    });

    test('sends tier "sentence" for PronunciationTier.sentence', () async {
      final caller =
          _FakeCaller(response: {'url': 'https://example.com/a.wav'});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.pronounce('Hello world.', Language.vietnamese,
          tier: PronunciationTier.sentence);

      expect(caller.capturedData?['language'], 'vi');
      expect(caller.capturedData?['tier'], 'sentence');
    });

    test('does not call the Cloud Function for a language with no Piper voice',
        () async {
      final caller = _FakeCaller();
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.pronounce('你好', Language.chinese,
          tier: PronunciationTier.word);

      expect(caller.capturedName, isNull);
      verifyNever(() => mockPlayer.play(any()));
    });

    test('swallows a Cloud Function error without throwing', () async {
      final caller = _FakeCaller(error: Exception('network error'));
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await expectLater(
        service.pronounce('hello', Language.english,
            tier: PronunciationTier.word),
        completes,
      );
    });
  });

  group('CloudTtsService.synthesize', () {
    test(
        'sends {text, language} to synthesizeSpeech and plays the decoded audio',
        () async {
      final caller =
          _FakeCaller(response: {'audioBase64': 'T0s='}); // base64 for "OK"
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('Hello world.', Language.english);

      expect(caller.capturedName, 'synthesizeSpeech');
      expect(caller.capturedData, {'text': 'Hello world.', 'language': 'en'});
      verify(() => mockPlayer.play(any(that: isA<BytesSource>()))).called(1);
    });

    test('includes voice in the payload when provided', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('Hi.', Language.english, voice: 'female2');

      expect(caller.capturedData,
          {'text': 'Hi.', 'language': 'en', 'voice': 'female2'});
    });

    test('applies rate via setPlaybackRate before playing when provided',
        () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('Hi.', Language.english, rate: 1.25);

      verify(() => mockPlayer.setPlaybackRate(1.25)).called(1);
    });

    test('does not call setPlaybackRate when rate is omitted', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('Hi.', Language.english);

      verifyNever(() => mockPlayer.setPlaybackRate(any()));
    });

    test('does not call the Cloud Function for a language with no Piper voice',
        () async {
      final caller = _FakeCaller();
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('안녕하세요', Language.korean);

      expect(caller.capturedName, isNull);
      verifyNever(() => mockPlayer.play(any()));
    });
  });

  group('CloudTtsService playback-completion awaiting', () {
    test('play() blocks until onPlayerStateChanged emits completed', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final controller = StreamController<PlayerState>();
      when(() => mockPlayer.onPlayerStateChanged)
          .thenAnswer((_) => controller.stream);
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      var resolved = false;
      final future = service
          .synthesize('Hi.', Language.english)
          .then((_) => resolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse); // still waiting

      controller.add(PlayerState.completed);
      await future;
      expect(resolved, isTrue);
      await controller.close();
    });

    test(
        'play() also unblocks on PlayerState.stopped (an external stop() call)',
        () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final controller = StreamController<PlayerState>();
      when(() => mockPlayer.onPlayerStateChanged)
          .thenAnswer((_) => controller.stream);
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      var resolved = false;
      final future = service
          .synthesize('Hi.', Language.english)
          .then((_) => resolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse);

      controller.add(PlayerState.stopped);
      await future;
      expect(resolved, isTrue);
      await controller.close();
    });
  });

  group('CloudTtsService.stop', () {
    test('delegates to AudioPlayer.stop()', () async {
      final service =
          CloudTtsService(caller: _FakeCaller(), player: mockPlayer);
      await service.stop();
      verify(() => mockPlayer.stop()).called(1);
    });
  });

  group('CloudTtsService construction and disposal', () {
    test(
        'constructing with no args does not throw (no eager Firebase/platform-channel touch)',
        () {
      expect(() => CloudTtsService(), returnsNormally);
    });

    test('stop() before anything has played is a no-op that completes cleanly',
        () async {
      final service = CloudTtsService(caller: _FakeCaller());
      await expectLater(service.stop(), completes);
    });

    test('dispose() never disposes an injected (test-owned) player', () async {
      final service =
          CloudTtsService(caller: _FakeCaller(), player: mockPlayer);
      await service.dispose();
      verifyNever(() => mockPlayer.dispose());
    });

    test('stop() delegates to an injected player when one is provided',
        () async {
      final service =
          CloudTtsService(caller: _FakeCaller(), player: mockPlayer);
      await service.stop();
      verify(() => mockPlayer.stop()).called(1);
    });
  });
}
