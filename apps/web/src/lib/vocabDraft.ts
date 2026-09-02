import type { Topic } from "./topics";
import type { WordPhraseResult } from "./lookup";
import type { VocabRecord } from "./vocabRecords";
import type { TargetLanguage } from "./languages";
import { capitalizeHeadword } from "./vocabDisplay";

const MAX_PRESELECTED_TOPICS = 2;

// Loose match instead of a strict case-insensitive equality: the AI is
// prompted with a fixed English topic list ("Food & Drink", "Social/Casual",
// ...) but doesn't always echo it back byte-for-byte (different punctuation,
// "and" instead of "&", extra whitespace) — collapse both sides down to
// bare alphanumerics before comparing so those variations still match.
export function normalizeTopicName(name: string): string {
  return name
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

export function preselectTopicIds(suggestedTopics: string[], topics: Topic[]): string[] {
  const selected: string[] = [];
  for (const suggestion of suggestedTopics) {
    if (selected.length >= MAX_PRESELECTED_TOPICS) break;
    const normalizedSuggestion = normalizeTopicName(suggestion);
    const match = topics.find((t) => normalizeTopicName(t.name) === normalizedSuggestion);
    if (match && !selected.includes(match.id)) selected.push(match.id);
  }
  // Nothing matched (missing suggestion, or one the AI gave doesn't exist
  // in this user's topic list) — fall back to "Other" so a save never
  // leaves the topic picker completely empty when a fallback exists.
  if (selected.length === 0) {
    const other = topics.find((t) => normalizeTopicName(t.name) === "other");
    if (other) selected.push(other.id);
  }
  return selected;
}

export function buildVocabRecordDraft(
  result: WordPhraseResult,
  topics: Topic[],
  targetLanguage: TargetLanguage
): VocabRecord {
  const now = new Date().toISOString();
  return {
    id: "",
    headword: capitalizeHeadword(result.headword),
    inputType: result.inputType,
    ipa: result.ipa,
    meaning: result.meaning,
    examples: result.examples,
    personalNotes: "",
    topicIds: preselectTopicIds(result.suggestedTopics, topics),
    // No "ngữ cảnh" (context) setting exists in Cài đặt yet — default to
    // "general" for every web-saved record (documented gap since Task 5 of
    // the Lookup/Ôn tập plan).
    targetLanguage,
    cefrLevel: result.cefrLevel ?? "b1",
    activeContext: "general",
    createdAt: now,
    updatedAt: now,
    nextReviewAt: null,
    sm2Repetitions: 0,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: result.definition,
    synonyms: result.synonyms,
  };
}
