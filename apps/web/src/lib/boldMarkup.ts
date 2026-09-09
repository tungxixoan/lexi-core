/**
 * A minimal inline-markup parser for Knowledge Note bodies.
 *
 * The grammar is deliberately tiny — NOT Markdown:
 * - `\n\n` (one or more blank lines) splits paragraphs; each paragraph is
 *   trimmed and empty paragraphs are dropped.
 * - `**x**` (x non-empty, no nested `**`, non-greedy) marks a bold run.
 * - Everything else is literal — a lone `**` renders as the two characters,
 *   and `*` / `_` / `#` are plain text. No nesting, italics, or links.
 *
 * Port of `lib/core/utils/bold_markup.dart` — keep in exact sync. The shared
 * test vectors (`test/fixtures/bold_markup_vectors.json`) guard both.
 */

/** One styled span of text within a paragraph. */
export interface TextRun {
  text: string;
  bold: boolean;
}

const BOLD_PATTERN = /\*\*([^*]+?)\*\*/g;

/**
 * Parses `source` into paragraphs of {@link TextRun}s. See the module doc
 * comment for the grammar. Returns an empty array for blank input.
 */
export function parseBoldMarkup(source: string): TextRun[][] {
  return source
    .split(/\n\n+/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0)
    .map(runsForParagraph);
}

function runsForParagraph(para: string): TextRun[] {
  const runs: TextRun[] = [];
  let cursor = 0;
  BOLD_PATTERN.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = BOLD_PATTERN.exec(para)) !== null) {
    if (m.index > cursor) {
      runs.push({ text: para.slice(cursor, m.index), bold: false });
    }
    runs.push({ text: m[1], bold: true });
    cursor = m.index + m[0].length;
  }
  if (cursor < para.length) {
    runs.push({ text: para.slice(cursor), bold: false });
  }
  // Drop empty plain runs (e.g. the "" before a leading match).
  const nonEmpty = runs.filter((r) => r.bold || r.text.length > 0);
  return nonEmpty.length > 0 ? nonEmpty : [{ text: "", bold: false }];
}
