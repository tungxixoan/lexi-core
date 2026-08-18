import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import type { VocabRecord } from "./vocabRecords";

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
// narrative using as many given headwords as possible.
export function buildReadingPassagePrompt(headwords: string[], targetLanguage: TargetLanguage): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const sentenceCount = Math.min(12, Math.max(6, Math.ceil(headwords.length * 0.75)));
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Write one coherent short story in ${languageLabel} of about ${sentenceCount} sentences, ` +
    `using as many of these words as possible, naturally: ${headwords.join(", ")}. ` +
    `Add a few other level-appropriate words if needed to make it flow. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"sentences":[{"target":"sentence in ${languageLabel}",` +
    `"vietnamese":"Vietnamese translation of that sentence",` +
    `"vocabWords":["which of the given words appear in this sentence, exactly as given"]}]} ` +
    `Every "vietnamese" field must use only Vietnamese script — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters.`
  );
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
