import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import type { VocabRecord } from "./vocabRecords";

export type DictationDifficulty = "easy" | "medium" | "hard";

// Describes one blank as a range in the sentence's whitespace-tokenized word
// list: words at indices [startWordIndex, startWordIndex + wordCount) are
// hidden and must be filled in. Ports lib/features/listening/domain/entities/blank_span.dart.
export interface BlankSpan {
  startWordIndex: number;
  wordCount: number;
}

export interface DictationItem {
  target: string;
  vietnamese: string;
  vocabIds: string[];
}

// Ports lib/features/listening/data/sources/dictation_source.dart's prompt.
// Unlike the reading Parts, this feature has no topic/context filter at
// all (Nghe chép only ever generates from the user's own selected vocab
// words) and no per-request register/setting clause.
export function buildDictationPrompt(headwords: string[], targetLanguage: TargetLanguage): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const wordList = headwords.join(", ");
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Write exactly one natural sentence of medium length (10 to 18 words) in ${languageLabel}. ` +
    `Naturally use these vocabulary words in the sentence: ${wordList}. ` +
    `Provide the sentence's Vietnamese translation and list which vocabulary words from the ` +
    `input actually appear in it. ` +
    `The Vietnamese translation must use only Vietnamese script — never Chinese, Japanese, or ` +
    `other non-Vietnamese characters. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"target": "the sentence in ${languageLabel}", "vietnamese": "Vietnamese translation", ` +
    `"vocabWords": ["only words from the provided list that appear in this sentence"]}`
  );
}

export function parseDictationItem(json: Record<string, unknown>, wordMap: Record<string, string>): DictationItem {
  const vocabWords = Array.isArray(json.vocabWords) ? json.vocabWords.map(String) : [];
  const vocabIds = vocabWords.map((w) => wordMap[w]).filter((id): id is string => id !== undefined);
  return {
    target: typeof json.target === "string" ? json.target : "",
    vietnamese: typeof json.vietnamese === "string" ? json.vietnamese : "",
    vocabIds,
  };
}

export function targetWords(sentence: string): string[] {
  return sentence.split(/\s+/).filter((w) => w.length > 0);
}

export function targetTextForBlank(sentence: string, blank: BlankSpan): string {
  return targetWords(sentence)
    .slice(blank.startWordIndex, blank.startWordIndex + blank.wordCount)
    .join(" ");
}

// Ports lib/features/listening/domain/use_cases/select_dictation_blanks_use_case.dart
// exactly, including its non-adjacency rule for "easy" (only enforced once
// the sentence has 6+ words) and its clamped span-length formula for
// "medium". `random` defaults to Math.random and exists purely so tests can
// inject a deterministic sequence — mirrors Dart's optional Random param.
export function selectDictationBlanks(
  sentence: string,
  difficulty: DictationDifficulty,
  random: () => number = Math.random
): BlankSpan[] {
  const wordCount = targetWords(sentence).length;

  if (difficulty === "hard") return [];
  if (difficulty === "easy") return selectEasyBlanks(wordCount, random);
  return selectMediumBlanks(wordCount, random);
}

function randInt(random: () => number, max: number): number {
  return Math.floor(random() * max);
}

function selectEasyBlanks(wordCount: number, random: () => number): BlankSpan[] {
  if (wordCount <= 1) return [{ startWordIndex: 0, wordCount: 1 }];

  const enforceNonAdjacent = wordCount >= 6;
  const minIndex = enforceNonAdjacent ? 1 : 0;
  const maxIndex = enforceNonAdjacent ? wordCount - 2 : wordCount - 1;
  const range = maxIndex - minIndex + 1;

  let first = minIndex + randInt(random, range);
  let second = minIndex + randInt(random, range);

  let attempts = 0;
  while ((second === first || (enforceNonAdjacent && Math.abs(second - first) < 2)) && attempts < 30) {
    second = minIndex + randInt(random, range);
    attempts++;
  }
  if (second === first) {
    second = first === maxIndex ? first - 1 : first + 1;
  }

  const indices = Array.from(new Set([first, second])).sort((a, b) => a - b);
  return indices.map((i) => ({ startWordIndex: i, wordCount: 1 }));
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function selectMediumBlanks(wordCount: number, random: () => number): BlankSpan[] {
  if (wordCount <= 3) return [{ startWordIndex: 0, wordCount }];

  const spanLength = clamp(Math.round(wordCount * 0.35), 2, wordCount - 2);
  const maxStartIndexInclusive = wordCount - spanLength - 1;
  const startIndex = maxStartIndexInclusive > 1 ? 1 + randInt(random, maxStartIndexInclusive) : 1;
  return [{ startWordIndex: startIndex, wordCount: spanLength }];
}

function isDue(record: VocabRecord, now: Date): boolean {
  return record.nextReviewAt === null || new Date(record.nextReviewAt).getTime() <= now.getTime();
}

function shuffle<T>(items: T[]): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// Ports DictationHomeScreen._generate's exact word-prioritization: due words
// shuffled first, not-due words shuffled second, concatenated — unlike
// selectSessionWords (used elsewhere), this always returns every eligible
// word, guaranteeing the caller can still take() a full count even when
// fewer than that many words are due.
export function prioritizeDueWords(records: VocabRecord[], now: Date = new Date()): VocabRecord[] {
  const due = shuffle(records.filter((r) => isDue(r, now)));
  const notDue = shuffle(records.filter((r) => !isDue(r, now)));
  return [...due, ...notDue];
}

const EDGE_PUNCTUATION = /^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu;

// Ports DictationSessionResult._normalize exactly (lowercase, trim, collapse
// whitespace, strip leading/trailing punctuation per word) — Unicode-aware
// so accented Vietnamese/English text strips correctly.
export function normalizeForComparison(text: string): string {
  return text
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ")
    .split(" ")
    .map((word) => word.replace(EDGE_PUNCTUATION, ""))
    .join(" ");
}

export function isBlankCorrect(sentence: string, blank: BlankSpan, answer: string): boolean {
  return normalizeForComparison(answer) === normalizeForComparison(targetTextForBlank(sentence, blank));
}

// Ports DictationSessionResult.charAccuracy, with one deliberate deviation:
// the comparison is case-insensitive (Flutter's original is case-sensitive)
// so Caps Lock or stray shift-key casing doesn't penalize an otherwise-
// correct answer. Still only characters at the same index count, over the
// target's full length (not the typed length) — a too-short answer is still
// scored down by the missing trailing characters.
export function charAccuracy(target: string, typed: string): number {
  if (target.length === 0) return 1;
  const limit = Math.min(typed.length, target.length);
  let correct = 0;
  for (let i = 0; i < limit; i++) {
    if (typed[i].toLowerCase() === target[i].toLowerCase()) correct++;
  }
  return correct / target.length;
}

export function blockAccuracy(sentence: string, blanks: BlankSpan[], blankAnswers: string[]): number {
  if (blanks.length === 0) return 1;
  const correctCount = blanks.filter((b, i) => isBlankCorrect(sentence, b, blankAnswers[i] ?? "")).length;
  return correctCount / blanks.length;
}

// Ports seekPenaltyFraction from dictation_practice_provider.dart exactly:
// TTS always speaks from the seek point to the end of the sentence, so
// seeking near the start re-hears almost the whole sentence (expensive,
// 0.05) while seeking near the end re-hears almost nothing (cheap, 0.01).
export function seekPenaltyFraction(wordIndex: number, totalWords: number): number {
  if (totalWords <= 0) return 0;
  const wordsReheard = totalWords - wordIndex;
  const reheardRatio = wordsReheard / totalWords;
  if (reheardRatio <= 0.2) return 0.01;
  return clamp(0.01 + (0.04 * (reheardRatio - 0.2)) / 0.8, 0.01, 0.05);
}

export interface DictationScoreInput {
  difficulty: DictationDifficulty;
  target: string;
  typed: string;
  blanks: BlankSpan[];
  blankAnswers: string[];
  replayCount: number;
  seekPenaltyTotal: number;
}

// Ports DictationSessionResult.finalScore exactly.
export function computeDictationScore(input: DictationScoreInput): number {
  const rawAccuracy =
    input.difficulty === "hard"
      ? charAccuracy(input.target, input.typed)
      : blockAccuracy(input.target, input.blanks, input.blankAnswers);
  return clamp(rawAccuracy - 0.05 * input.replayCount - input.seekPenaltyTotal, 0, 1);
}

// Ports DictationSessionResult.sm2Quality exactly — note there is
// deliberately no "1" tier (jumps from 2 straight to 0); this is a Flutter
// quirk to preserve, not a bug to fix.
export function sm2QualityFromScore(score: number): number {
  if (score >= 0.95) return 5;
  if (score >= 0.8) return 4;
  if (score >= 0.6) return 3;
  if (score >= 0.4) return 2;
  return 0;
}
