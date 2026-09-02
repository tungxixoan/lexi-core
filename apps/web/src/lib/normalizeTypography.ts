// Generated passage text sometimes comes back with "smart" punctuation
// (curly quotes, ellipsis, en/em dashes, non-breaking spaces). The Đọc & gõ
// typing flow compares what the user types against this text, and a normal
// keyboard produces the ASCII forms — so the raw smart characters are
// un-typable. Normalize them to ASCII before the text is ever shown.
const REPLACEMENTS: readonly [RegExp, string][] = [
  [/[\u2018\u2019\u201A\u201B\u2032]/g, "'"],
  [/[\u201C\u201D\u201E\u201F\u00AB\u00BB\u2033]/g, '"'],
  [/\u2026/g, "..."],
  [/[\u2013\u2014\u2012\u2015]/g, "-"],
  [/[\u00A0\u2009\u202F]/g, " "],
];

export function normalizeTypography(s: string): string {
  let out = s;
  for (const [pattern, replacement] of REPLACEMENTS) out = out.replace(pattern, replacement);
  return out;
}
