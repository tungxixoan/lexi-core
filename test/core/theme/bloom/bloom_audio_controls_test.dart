import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_audio_controls.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('playOnly: shows the play label and fires onPlayPause', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(BloomAudioControls.playOnly(
      isPlaying: false, playLabel: 'Phát', onPlayPause: () => taps++,
    )));
    expect(find.text('Phát'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsNothing);
    await tester.tap(find.text('Phát'));
    expect(taps, 1);
  });

  testWidgets('playOnly: null onPlayPause disables it (no tap fires)', (tester) async {
    await tester.pumpWidget(_host(const BloomAudioControls.playOnly(
      isPlaying: false, playLabel: 'Phát', onPlayPause: null,
    )));
    await tester.tap(find.text('Phát'), warnIfMissed: false);
    // nothing to assert beyond "did not throw"; also the pill is at 0.5 opacity
    expect(tester.takeException(), isNull);
  });

  testWidgets('playOnly: isPlaying swaps the label to Dừng and the icon to stop', (tester) async {
    await tester.pumpWidget(_host(BloomAudioControls.playOnly(
      isPlaying: true, playLabel: 'Nghe lại (1)', onPlayPause: () {},
    )));
    expect(find.text('Dừng'), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);
  });

  testWidgets('transport: renders all four controls and wires each callback', (tester) async {
    final hits = <String>[];
    await tester.pumpWidget(_host(BloomAudioControls.transport(
      isPlaying: false,
      onPlayPause: () => hits.add('play'),
      onPrevious: () => hits.add('prev'),
      onNext: () => hits.add('next'),
      onReplay: () => hits.add('replay'),
    )));
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.byIcon(Icons.replay), findsOneWidget);
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.tap(find.byIcon(Icons.replay));
    await tester.tap(find.text('Phát'));
    expect(hits, ['prev', 'next', 'replay', 'play']);
  });

  testWidgets('transport: null onPrevious renders the button disabled', (tester) async {
    await tester.pumpWidget(_host(BloomAudioControls.transport(
      isPlaying: false, onPlayPause: () {},
      onPrevious: null, onNext: () {}, onReplay: () {},
    )));
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    // BloomIconButton with onPressed: null — tapping does nothing / no throw
    await tester.tap(find.byIcon(Icons.skip_previous), warnIfMissed: false);
    expect(tester.takeException(), isNull);
  });
}
