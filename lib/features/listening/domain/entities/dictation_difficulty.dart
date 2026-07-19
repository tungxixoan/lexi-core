enum DictationDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        DictationDifficulty.easy => 'Dễ',
        DictationDifficulty.medium => 'Trung bình',
        DictationDifficulty.hard => 'Khó',
      };
}
