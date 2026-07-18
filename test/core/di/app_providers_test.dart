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
}
