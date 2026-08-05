import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';

void main() {
  group('EconomyVolume', () {
    test('has exactly 4 values, Vol 2 through Vol 5', () {
      expect(EconomyVolume.values, [
        EconomyVolume.vol2,
        EconomyVolume.vol3,
        EconomyVolume.vol4,
        EconomyVolume.vol5,
      ]);
    });

    test('label describes each volume', () {
      expect(EconomyVolume.vol2.label, 'Vol 2 · 500–600+');
      expect(EconomyVolume.vol3.label, 'Vol 3 · 650–750+');
      expect(EconomyVolume.vol4.label, 'Vol 4 · 800–900+');
      expect(EconomyVolume.vol5.label, 'Vol 5 · 900+');
    });

    test('promptHint is non-empty and part-agnostic for every volume', () {
      for (final v in EconomyVolume.values) {
        expect(v.promptHint, isNotEmpty);
        expect(v.promptHint.toLowerCase(), isNot(contains('part 5')));
        expect(v.promptHint.toLowerCase(), isNot(contains('part 6')));
      }
    });
  });
}
