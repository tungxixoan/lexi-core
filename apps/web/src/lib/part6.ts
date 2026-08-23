import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { ECONOMY_VOLUMES, VOLUME_PROMPT_HINTS, type EconomyVolume } from "./toeicFilters";

export interface Part6Question {
  options: string[]; // always 4 — words/phrases OR full candidate sentences
  correctIndex: number;
  explanation: string; // Vietnamese
}

export interface Part6Passage {
  passageText: string; // blanks inline, e.g. "... the office (1)___ Monday ..."
  questions: Part6Question[]; // always 4, ordered to match blank numbering
}

export interface Part6Set {
  passages: Part6Passage[]; // always 3
}

const PASSAGE_COUNT = 3;
const BLANKS_PER_PASSAGE = 4;

// Ports lib/features/reading/data/sources/part6_source.dart's prompt. Takes
// resolved topic *names*, not a fixed enum — same shared "Chủ đề" filter
// every reading mode uses, per the hub/setup-merge spec. An empty topic list
// omits the register clause entirely rather than defaulting to a fake
// "general" register.
export function buildPart6Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const contextClause = topicNames.length > 0 ? `, in a ${topicNames.join("/")} register/setting` : "";
  const effectiveVolumes = volumes.length === 0 ? ECONOMY_VOLUMES : volumes;
  const volumeHints = effectiveVolumes.map((v) => `${v}: ${VOLUME_PROMPT_HINTS[v]}`).join("; ");
  return (
    `You are creating a TOEIC Part 6 (Text Completion) practice set for a Vietnamese speaker ` +
    `learning ${languageLabel}${contextClause}, calibrated to the Economy TOEIC difficulty ` +
    `volumes below (mix passages across them roughly evenly and randomly): ${volumeHints}. ` +
    `Write exactly ${PASSAGE_COUNT} short realistic business documents (choose from: email, ` +
    `memo, notice, advertisement, article), each with exactly ${BLANKS_PER_PASSAGE} numbered ` +
    `blanks marked inline as "(1)___", "(2)___", "(3)___", "(4)___" in reading order. ` +
    `For each passage, at least one of its 4 blanks must be a "select the sentence that ` +
    `best fits" item, where all 4 options are full candidate sentences instead of single ` +
    `words/phrases — the other blanks use word/phrase options (word form, verb tense, ` +
    `preposition, conjunction, transition word). Every blank has exactly 4 options and a ` +
    `brief explanation (in Vietnamese) of why the correct option is right. ` +
    `The explanation must use only Vietnamese script — never Chinese, Japanese, or other ` +
    `non-Vietnamese characters. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"passages": [{"passageText": "... (1)___ ... (2)___ ... (3)___ ... (4)___ ...", ` +
    `"questions": [{"options": ["...", "...", "...", "..."], "correctIndex": 0, ` +
    `"explanation": "..."}]}]}`
  );
}

export function parsePart6Set(json: Record<string, unknown>): Part6Set {
  const rawPassages = Array.isArray(json.passages) ? json.passages : [];
  const passages: Part6Passage[] = [];
  for (const raw of rawPassages) {
    if (typeof raw !== "object" || raw === null) continue;
    const p = raw as Record<string, unknown>;
    const rawQuestions = Array.isArray(p.questions) ? p.questions : [];
    const questions: Part6Question[] = [];
    for (const rq of rawQuestions) {
      if (typeof rq !== "object" || rq === null) continue;
      const q = rq as Record<string, unknown>;
      questions.push({
        options: Array.isArray(q.options) ? q.options.map(String) : [],
        correctIndex: typeof q.correctIndex === "number" ? q.correctIndex : 0,
        explanation: typeof q.explanation === "string" ? q.explanation : "",
      });
    }
    // Mirrors Flutter's own `.where((p) => p.questions.length == _blanksPerPassage)`
    // filter — a passage with the wrong blank count can't render against the
    // fixed "(1)"-"(4)" labeling, so it's dropped rather than shown broken.
    if (questions.length !== BLANKS_PER_PASSAGE) continue;
    passages.push({
      passageText: typeof p.passageText === "string" ? p.passageText : "",
      questions,
    });
  }
  return { passages };
}
