import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';

void main() {
  test('label is the correct Vietnamese text for each value', () {
    expect(DictationDifficulty.easy.label, 'Dễ');
    expect(DictationDifficulty.medium.label, 'Trung bình');
    expect(DictationDifficulty.hard.label, 'Khó');
  });
}
