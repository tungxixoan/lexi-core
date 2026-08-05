enum EconomyVolume {
  vol2,
  vol3,
  vol4,
  vol5;

  String get label => switch (this) {
        EconomyVolume.vol2 => 'Vol 2 · 500–600+',
        EconomyVolume.vol3 => 'Vol 3 · 650–750+',
        EconomyVolume.vol4 => 'Vol 4 · 800–900+',
        EconomyVolume.vol5 => 'Vol 5 · 900+',
      };

  /// Fed into the AI prompt to calibrate question style/difficulty.
  /// Deliberately part-agnostic — shared across Part 5, Part 6, and (later) Part 7.
  String get promptHint => switch (this) {
        EconomyVolume.vol2 =>
          'easy-medium difficulty, standard trap depth, close to or slightly easier than the real exam',
        EconomyVolume.vol3 =>
          'medium-high difficulty, some advanced vocabulary, longer passages',
        EconomyVolume.vol4 =>
          'high difficulty, equal to or harder than the real exam, longer/more complex passages, unusual grammar/vocabulary traps',
        EconomyVolume.vol5 =>
          'very high difficulty, dense advanced vocabulary and the deepest grammar traps',
      };
}
