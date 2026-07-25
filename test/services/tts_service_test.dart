import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/services/tts_service.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late MockFlutterTts mockTts;
  late FlutterTtsService service;

  setUp(() {
    mockTts = MockFlutterTts();
    when(() => mockTts.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => mockTts.speak(any())).thenAnswer((_) async => 1);
    when(() => mockTts.stop()).thenAnswer((_) async => 1);
    service = FlutterTtsService(mockTts);
  });

  test('constructor configures awaitSpeakCompletion(true)', () {
    verify(() => mockTts.awaitSpeakCompletion(true)).called(1);
  });

  test('speak() defaults pitch to 1.0 when not provided', () async {
    await service.speak('Hello world.', Language.english);
    verify(() => mockTts.setPitch(1.0)).called(1);
    verify(() => mockTts.setLanguage(Language.english.ttsLocale)).called(1);
    verify(() => mockTts.speak('Hello world.')).called(1);
  });

  test('speak() forwards a custom pitch', () async {
    await service.speak('Hi there.', Language.english, pitch: 1.3);
    verify(() => mockTts.setPitch(1.3)).called(1);
    verify(() => mockTts.speak('Hi there.')).called(1);
  });

  test('speak() does not call setSpeechRate when rate is omitted', () async {
    await service.speak('Hello world.', Language.english);
    verifyNever(() => mockTts.setSpeechRate(any()));
  });

  test('speak() forwards a custom rate via setSpeechRate', () async {
    await service.speak('Hi there.', Language.english, rate: 0.375);
    verify(() => mockTts.setSpeechRate(0.375)).called(1);
  });

  test('stop() delegates to FlutterTts.stop()', () async {
    await service.stop();
    verify(() => mockTts.stop()).called(1);
  });
}
