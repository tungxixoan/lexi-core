import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import type { VocabRecord } from "./vocabRecords";

type CefrLevel = VocabRecord["cefrLevel"];

export interface BilingualSentence {
  target: string;
  vietnamese: string;
  vocabWords: string[];
}

export interface ReadingPassage {
  sentences: BilingualSentence[];
  vocabIds: string[];
}

// Ports lib/features/reading/data/sources/reading_passage_source.dart's
// prompt: ~0.75 sentences per headword, clamped 6-12, one coherent
// narrative using as many given headwords as possible. Unlike the Dart
// source (which also threads a "context"/register through the prompt),
// this omits register — no "ngữ cảnh" setting exists in Cài đặt yet, the
// same documented gap as Tra từ's buildWordPhrasePrompt. maxCefr is a
// real signal though (the setup screen's own CEFR filter), so it's passed
// through as an explicit instruction rather than relying only on the
// implicit difficulty of the given word list.
export function buildReadingPassagePrompt(
  headwords: string[],
  targetLanguage: TargetLanguage,
  maxCefr: CefrLevel | null
): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const sentenceCount = Math.min(12, Math.max(6, Math.ceil(headwords.length * 0.75)));
  const levelClause = maxCefr
    ? `Keep the difficulty at or below CEFR level ${maxCefr.toUpperCase()}. `
    : "";
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Write one coherent short story in ${languageLabel} of about ${sentenceCount} sentences, ` +
    `using as many of these words as possible, naturally: ${headwords.join(", ")}. ` +
    `${levelClause}` +
    `Add a few other natural words if needed to make it flow. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"sentences":[{"target":"sentence in ${languageLabel}",` +
    `"vietnamese":"Vietnamese translation of that sentence",` +
    `"vocabWords":["which of the given words appear in this sentence, exactly as given"]}]} ` +
    `Every "vietnamese" field must use only Vietnamese script — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters.`
  );
}

export interface HighlightSegment {
  text: string;
  highlighted: boolean;
}

// Splits a sentence's target text into plain/highlighted runs around every
// occurrence of its own vocabWords, for the result screen's passage review.
// Whole-word matching (\b) avoids highlighting "cat" inside "category";
// longest-first ordering avoids a short vocab word matching inside a longer
// one that also appears in vocabWords (e.g. "base" inside "touch base").
export function highlightVocabWords(target: string, vocabWords: string[]): HighlightSegment[] {
  if (vocabWords.length === 0) return [{ text: target, highlighted: false }];

  const escaped = [...vocabWords]
    .sort((a, b) => b.length - a.length)
    .map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  const pattern = new RegExp(`\\b(${escaped.join("|")})\\b`, "gi");

  const segments: HighlightSegment[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(target)) !== null) {
    if (match.index > lastIndex) {
      segments.push({ text: target.slice(lastIndex, match.index), highlighted: false });
    }
    segments.push({ text: match[0], highlighted: true });
    lastIndex = match.index + match[0].length;
  }
  if (lastIndex < target.length) {
    segments.push({ text: target.slice(lastIndex), highlighted: false });
  }
  return segments;
}

interface RawSentence {
  target?: unknown;
  vietnamese?: unknown;
  vocabWords?: unknown;
}

export function parseReadingPassage(
  json: Record<string, unknown>,
  vocabRecords: VocabRecord[]
): ReadingPassage {
  const rawSentences = Array.isArray(json.sentences) ? (json.sentences as RawSentence[]) : [];
  const headwordToId = new Map(vocabRecords.map((r) => [r.headword.toLowerCase(), r.id]));

  const sentences: BilingualSentence[] = rawSentences.map((raw) => ({
    target: typeof raw.target === "string" ? raw.target : "",
    vietnamese: typeof raw.vietnamese === "string" ? raw.vietnamese : "",
    vocabWords: Array.isArray(raw.vocabWords) ? raw.vocabWords.map(String) : [],
  }));

  const vocabIds = new Set<string>();
  for (const sentence of sentences) {
    for (const word of sentence.vocabWords) {
      const id = headwordToId.get(word.toLowerCase());
      if (id) vocabIds.add(id);
    }
  }

  return { sentences, vocabIds: [...vocabIds] };
}
