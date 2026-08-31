import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all five Be Vietnam Pro weights are present and non-trivial', () {
    const files = [
      'BeVietnamPro-Regular.ttf',
      'BeVietnamPro-Medium.ttf',
      'BeVietnamPro-SemiBold.ttf',
      'BeVietnamPro-Bold.ttf',
      'BeVietnamPro-ExtraBold.ttf',
    ];
    for (final f in files) {
      final file = File('assets/fonts/$f');
      expect(file.existsSync(), isTrue, reason: '$f missing');
      expect(file.lengthSync(), greaterThan(20000),
          reason: '$f too small to be a real font');
    }
  });

  test('pubspec declares the BeVietnamPro family', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: BeVietnamPro'));
    expect(pubspec, contains('weight: 800'));
  });
}
