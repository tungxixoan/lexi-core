import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { parseLookupResult, type WordPhraseResult } from "./lookup";
import type { VocabRecord } from "./vocabRecords";

export function findKnownHeadwords(text: string, records: VocabRecord[]): string[] {
  const lowerText = text.toLowerCase();
  const seen = new Set<string>();
  const known: string[] = [];
  for (const record of records) {
    const lowerHeadword = record.headword.toLowerCase();
    if (lowerText.includes(lowerHeadword) && !seen.has(lowerHeadword)) {
      seen.add(lowerHeadword);
      known.push(record.headword);
    }
  }
  return known;
}

// Ports word_radar_source.dart's suggestion prompt, including the
// includeTranslation branch — some call sites (e.g. Word Radar) need a
// full-text translation alongside the suggestions.
export function buildVocabSuggestionsPrompt(
  text: string,
  targetLanguage: TargetLanguage,
  knownHeadwords: string[],
  includeTranslation: boolean = false
): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const knownClause =
    knownHeadwords.length === 0
      ? ""
      : ` Do NOT suggest any of these already-known words: ${knownHeadwords.join(", ")}.`;
  const task = includeTranslation
    ? "do two things. First, translate the full text into Vietnamese. Second, suggest"
    : "suggest";
  const translationField = includeTranslation
    ? '"translation":"Vietnamese translation of the full text",'
    : "";
  const translationReminder = includeTranslation
    ? '. Always provide the "translation" even when "suggestions" is empty.'
    : "";
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Given this text: "${text}", ${task} up to 10 words or short phrases from the text that are ` +
    `worth learning.${knownClause} If nothing in the text is worth learning, use an empty ` +
    `"suggestions" array. Respond with JSON only (no markdown, no code fences): ` +
    `{${translationField}"suggestions":[{"headword":"exact word or phrase from the text","ipa":"IPA transcription",` +
    `"meaning":"Vietnamese definition","definition":"English definition",` +
    `"synonyms":["2-4 English synonyms, or empty array if none fit"],` +
    `"examples":["example 1","example 2"],` +
    `"suggestedTopics":["exactly one topic chosen from: Daily Life, Travel, Food & Drink, Business, ` +
    `Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, ` +
    `Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"],` +
    `"cefrLevel":"a1, a2, b1, b2, c1, or c2"}]}${translationReminder} ` +
    `Every suggestion's "suggestedTopics" array is REQUIRED and must contain exactly one topic from ` +
    `that list — never an empty array, even when generating many suggestions at once. ` +
    `Every "meaning" field must use only Vietnamese script — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters.`
  );
}

export interface VocabSuggestionsResult {
  suggestions: WordPhraseResult[];
  translation: string;
}

export function parseVocabSuggestions(json: Record<string, unknown>): VocabSuggestionsResult {
  const rawSuggestions = Array.isArray(json.suggestions) ? json.suggestions : [];
  const suggestions: WordPhraseResult[] = [];
  for (const raw of rawSuggestions) {
    if (typeof raw !== "object" || raw === null) continue;
    const item = raw as Record<string, unknown>;
    if (typeof item.headword !== "string" || item.headword.length === 0) continue;
    const parsed = parseLookupResult(item, "word", item.headword);
    if (parsed.kind === "wordPhrase") suggestions.push(parsed);
  }
  return {
    suggestions,
    translation: typeof json.translation === "string" ? json.translation : "",
  };
}
