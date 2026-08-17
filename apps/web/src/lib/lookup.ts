import type { InputType } from "./inputDetector";
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";

export interface WordPhraseResult {
  kind: "wordPhrase";
  headword: string;
  inputType: "word" | "phrase";
  ipa: string;
  meaning: string;
  examples: string[];
  definition: string;
  synonyms: string[];
  suggestedTopics: string[];
  cefrLevel: "a1" | "a2" | "b1" | "b2" | "c1" | "c2" | null;
}

export interface SentenceResult {
  kind: "sentence";
  original: string;
  translation: string;
}

export type LookupResult = WordPhraseResult | SentenceResult;

// Ports lib/features/dictionary/data/sources/gemini_dictionary_source.dart's
// _wordPhrasePrompt exactly (field names, topic list, multi-sense handling,
// Vietnamese-script-only instruction) — verified against that file.
export function buildWordPhrasePrompt(query: string, targetLanguage: TargetLanguage): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  return (
    `You are a language learning assistant helping a Vietnamese speaker learn ${languageLabel}. ` +
    `Look up "${query}" and respond with JSON only (no markdown, no code fences): ` +
    `{"headword":"exact word or phrase","ipa":"IPA transcription",` +
    `"meaning":"Vietnamese definition",` +
    `"definition":"English definition",` +
    `"synonyms":["2-4 English synonyms for this sense, or empty array if none fit"],` +
    `"examples":["example 1 in ${languageLabel}","example 2"],` +
    `"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"],` +
    `"cefrLevel":"a1, a2, b1, b2, c1, or c2 — the CEFR difficulty level of this word or phrase"} ` +
    `If the word has multiple common parts of speech (e.g. "record" as both noun and verb), ` +
    `cover each sense in both "meaning" and "definition" using this format: "(n) ...; (v) ...", ` +
    `and give an IPA per sense too, e.g. "N: /ˈrekɔːrd/; V: /rɪˈkɔːrd/". ` +
    `The "meaning" field must use only Vietnamese script — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters.`
  );
}

// Ports gemini_dictionary_source.dart's _sentencePrompt exactly.
export function buildSentencePrompt(sentence: string): string {
  return (
    `Translate this sentence to Vietnamese: "${sentence}" ` +
    `Use only Vietnamese script in the translation — ` +
    `never Chinese, Japanese, or other non-Vietnamese characters. ` +
    `Respond with JSON only: {"translation":"translated sentence"}`
  );
}

const CEFR_LEVELS = new Set(["a1", "a2", "b1", "b2", "c1", "c2"]);

export function parseLookupResult(
  json: Record<string, unknown>,
  inputType: InputType,
  query: string
): LookupResult {
  if (inputType === "sentence") {
    return {
      kind: "sentence",
      original: query,
      translation: typeof json.translation === "string" ? json.translation : "",
    };
  }

  const rawCefr = typeof json.cefrLevel === "string" ? json.cefrLevel.toLowerCase() : null;
  return {
    kind: "wordPhrase",
    headword: typeof json.headword === "string" ? json.headword : query,
    inputType,
    ipa: typeof json.ipa === "string" ? json.ipa : "",
    meaning: typeof json.meaning === "string" ? json.meaning : "",
    examples: Array.isArray(json.examples) ? json.examples.map(String) : [],
    definition: typeof json.definition === "string" ? json.definition : "",
    synonyms: Array.isArray(json.synonyms) ? json.synonyms.map(String) : [],
    suggestedTopics: Array.isArray(json.suggestedTopics) ? json.suggestedTopics.map(String) : [],
    cefrLevel: rawCefr && CEFR_LEVELS.has(rawCefr) ? (rawCefr as WordPhraseResult["cefrLevel"]) : null,
  };
}
