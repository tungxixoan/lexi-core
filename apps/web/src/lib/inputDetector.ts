// Ports lib/core/utils/input_detector.dart's InputDetector.detect exactly —
// verified against that file, not guessed.
export type InputType = "word" | "phrase" | "sentence";

const PHRASE_MAX_WORDS = 4;
const TERMINAL_PUNCTUATION = /[.?!]\s*$/;

export function detectInputType(input: string): InputType {
  const trimmed = input.trim();
  if (trimmed === "") return "word";
  if (TERMINAL_PUNCTUATION.test(trimmed)) return "sentence";

  const wordCount = trimmed.split(/\s+/).length;
  if (wordCount > PHRASE_MAX_WORDS) return "sentence";
  if (wordCount >= 2) return "phrase";
  return "word";
}
