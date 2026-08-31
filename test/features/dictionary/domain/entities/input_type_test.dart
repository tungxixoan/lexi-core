import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';

void main() {
  test('label returns the Vietnamese term for each input type', () {
    expect(InputType.word.label, 'từ');
    expect(InputType.phrase.label, 'cụm từ');
    expect(InputType.sentence.label, 'câu');
  });

  test('name stays the English wire format', () {
    expect(InputType.word.name, 'word');
  });
}
