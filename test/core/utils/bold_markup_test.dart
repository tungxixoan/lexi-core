import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/utils/bold_markup.dart';

void main() {
  final vectors = (jsonDecode(
    File('test/fixtures/bold_markup_vectors.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  for (final v in vectors) {
    test('vector: ${v['name']}', () {
      final expected = (v['out'] as List)
          .map((para) => (para as List)
              .map((r) => TextRun(r['t'] as String, bold: r['b'] as bool))
              .toList())
          .toList();
      expect(parseBoldMarkup(v['in'] as String), expected);
    });
  }

  test('rejects nested ** inside a span (treats inner as boundary)', () {
    // Actual deterministic split by RegExp(r'\*\*([^*]+?)\*\*'): non-overlapping
    // matches are "**a **" (bold "a ") then "** c**" (bold " c"), leaving the
    // "b" between them as a plain run. `[^*]+?` forbids `*` inside a span, so
    // nesting cannot occur — the behaviour is defined and deterministic.
    expect(parseBoldMarkup('**a **b** c**'), [
      [
        const TextRun('a ', bold: true),
        const TextRun('b'),
        const TextRun(' c', bold: true),
      ]
    ]);
  });
}
