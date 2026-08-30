// test/core/di/app_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/di/app_providers.dart';

void main() {
  group('httpClientProvider', () {
    test(
        'stays alive (same instance) across an async gap with no active watcher',
        () async {
      // Regression test: LookupNotifier.lookup() obtains the dictionary
      // lookup chain via a one-shot `ref.read(lookupUseCaseProvider)` inside
      // an async method, with nothing ever `ref.watch`-ing httpClientProvider.
      // If httpClientProvider is autoDispose (the default for @riverpod), it
      // gets torn down as soon as its listener count drops to zero, and its
      // `ref.onDispose(client.close)` callback closes the shared http.Client
      // while a FreeDictionarySource request may still be in flight — this
      // surfaced as `ClientException: Request aborted by \`abortTrigger\``
      // on Flutter Web when AI was disabled (the only lookup path that
      // reuses this shared client).
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final client1 = container.read(httpClientProvider);

      // Give Riverpod's autoDispose scheduling a chance to run, same as the
      // real async gap between constructing the use case chain and the
      // network response coming back.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final client2 = container.read(httpClientProvider);

      expect(
        identical(client1, client2),
        isTrue,
        reason:
            'httpClientProvider was disposed (and its client closed) across '
            'the async gap even though nothing watched it — it must be '
            'keepAlive so a request in flight is never aborted.',
      );
    });
  });

  group('ttsServiceProvider', () {
    test(
        'stays alive (same instance) across an async gap with no active watcher',
        () async {
      // Regression test: every listening/pronunciation call site obtains
      // TtsService via a one-shot `ref.read(ttsServiceProvider)`, with
      // nothing ever `ref.watch`-ing it. If ttsServiceProvider is autoDispose
      // (the default for @riverpod), each read after the listener count
      // drops to zero returns a NEW CloudTtsService wrapping its own native
      // AudioPlayer — so stop() targets a different player than the one
      // actually playing, and a lazily-created player gets disposed before
      // it's ever used. Must be keepAlive so the whole app shares one player.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service1 = container.read(ttsServiceProvider);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final service2 = container.read(ttsServiceProvider);

      expect(
        identical(service1, service2),
        isTrue,
        reason:
            'ttsServiceProvider was disposed (and its AudioPlayer torn down) '
            'across the async gap even though nothing watched it.',
      );
    });
  });
}
