import 'dart:convert';

/// Extracts and decodes a JSON object from raw AI model output.
///
/// Even when a provider is explicitly asked for JSON-only output, it can
/// still wrap the object in markdown code fences or append trailing
/// prose/garbage after it. This strips markdown fences first, then — if the
/// text still doesn't parse as-is — falls back to extracting just the
/// balanced-brace JSON object substring (respecting string literals, so a
/// `{`/`}` inside a JSON string value doesn't throw off the brace count).
Map<String, dynamic> parseAiJsonObject(String raw) {
  final stripped = _stripCodeFences(raw.trim());
  try {
    return jsonDecode(stripped) as Map<String, dynamic>;
  } on FormatException {
    final extracted = _extractBalancedObject(stripped);
    if (extracted == null) rethrow;
    return jsonDecode(extracted) as Map<String, dynamic>;
  }
}

final _fencePattern = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$');

String _stripCodeFences(String text) {
  final match = _fencePattern.firstMatch(text);
  return match?.group(1)?.trim() ?? text;
}

String? _extractBalancedObject(String text) {
  final start = text.indexOf('{');
  if (start == -1) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == '\\') {
      escaped = true;
      continue;
    }
    if (char == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  return null;
}
