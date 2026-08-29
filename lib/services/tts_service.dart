// lib/services/tts_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../core/services/cloud_function_caller.dart';
import '../features/dictionary/domain/entities/language.dart';

enum PronunciationTier { word, sentence }

abstract class TtsService {
  /// Cached word/sentence pronunciation (dictionary/vocab lookups) — calls
  /// the `getPronunciation` Cloud Function, which caches by
  /// sha256(text+lang+voice) in Firebase Storage and is shared across all
  /// users. No-ops silently if [language].ttsCloudCode is null.
  Future<void> pronounce(String text, Language language, {required PronunciationTier tier});

  /// Uncached synthesis for freshly AI-generated text (Nghe chép sentences,
  /// Nghe hiểu turns) — calls `synthesizeSpeech`, never cached. [voice]
  /// picks one of Piper's 4 voices ('male1'/'male2'/'female1'/'female2');
  /// [rate] is a post-synthesis playback-speed multiplier (1.0 = normal).
  /// No-ops silently if [language].ttsCloudCode is null.
  Future<void> synthesize(String text, Language language, {String? voice, double? rate});

  Future<void> stop();

  /// Releases the underlying native audio player, if one was ever created.
  /// Called from `ttsServiceProvider`'s `ref.onDispose` since the provider
  /// is auto-dispose and a fresh instance is built on every re-entry.
  Future<void> dispose();
}

class CloudTtsService implements TtsService {
  CloudTtsService({CloudFunctionCaller? caller, AudioPlayer? player})
      : _providedCaller = caller,
        _providedPlayer = player;

  final CloudFunctionCaller? _providedCaller;
  final AudioPlayer? _providedPlayer;
  CloudFunctionCaller? _resolvedCaller;
  AudioPlayer? _resolvedPlayer;

  // Lazy: constructing FirebaseCloudFunctionCaller()/AudioPlayer() touches
  // Firebase/platform channels, which throws in any context without a real
  // Firebase app initialized (e.g. a plain widget test that reads
  // ttsServiceProvider without overriding it). Deferring until the first
  // real pronounce()/synthesize()/stop() call means merely *constructing*
  // a CloudTtsService (which ttsServiceProvider's default builder does
  // unconditionally) never requires Firebase to already be initialized.
  CloudFunctionCaller get _caller =>
      _providedCaller ?? (_resolvedCaller ??= FirebaseCloudFunctionCaller());
  AudioPlayer get _player =>
      _providedPlayer ?? (_resolvedPlayer ??= AudioPlayer());

  @override
  Future<void> pronounce(String text, Language language, {required PronunciationTier tier}) async {
    final code = language.ttsCloudCode;
    if (code == null || text.trim().isEmpty) return;
    try {
      final result = await _caller.call('getPronunciation', {
        'text': text,
        'language': code,
        'tier': tier.name,
      });
      final url = result['url'] as String?;
      if (url == null) return;
      await _playAndAwaitCompletion(UrlSource(url));
    } catch (_) {
      // Best-effort: no error-display UI exists at any pronounce() call
      // site today (matches flutter_tts's own lack of one).
    }
  }

  @override
  Future<void> synthesize(String text, Language language, {String? voice, double? rate}) async {
    final code = language.ttsCloudCode;
    if (code == null || text.trim().isEmpty) return;
    try {
      final result = await _caller.call('synthesizeSpeech', {
        'text': text,
        'language': code,
        if (voice != null) 'voice': voice,
      });
      final audioBase64 = result['audioBase64'] as String?;
      if (audioBase64 == null) return;
      if (rate != null) await _player.setPlaybackRate(rate);
      await _playAndAwaitCompletion(BytesSource(base64Decode(audioBase64)));
    } catch (_) {
      // Best-effort — see pronounce()'s comment.
    }
  }

  /// Starts playing [source] and blocks until playback finishes — either
  /// naturally (PlayerState.completed) or because something else called
  /// stop() on this same player mid-playback (PlayerState.stopped).
  /// Mirrors flutter_tts's awaitSpeakCompletion(true), which several
  /// callers (Nghe chép/Nghe hiểu) depend on to know when to flip
  /// isSpeaking back to false.
  Future<void> _playAndAwaitCompletion(Source source) async {
    final done = Completer<void>();
    late final StreamSubscription<PlayerState> sub;
    sub = _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (!done.isCompleted) done.complete();
      }
    });
    try {
      await _player.play(source);
      await done.future;
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _resolvedPlayer?.dispose();
  }
}
