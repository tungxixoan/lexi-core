import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { CONTEXT_LABELS, ECONOMY_VOLUMES, VOLUME_PROMPT_HINTS, type ToeicContext, type EconomyVolume } from "./toeicFilters";

export interface Part5Question {
  sentenceWithBlank: string;
  options: string[];
  correctIndex: number;
  explanation: string;
}

export interface Part5Set {
  questions: Part5Question[];
}

const QUESTION_COUNT = 15;

// Ports lib/features/reading/data/sources/part5_source.dart's prompt.
export function buildPart5Prompt(appContext: ToeicContext, targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const contextLabel = CONTEXT_LABELS[appContext];
  const effectiveVolumes = volumes.length === 0 ? ECONOMY_VOLUMES : volumes;
  const volumeHints = effectiveVolumes.map((v) => `${v}: ${VOLUME_PROMPT_HINTS[v]}`).join("; ");
  return (
    `You are creating a TOEIC Part 5 (Incomplete Sentences) practice set for a Vietnamese speaker ` +
    `learning ${languageLabel}, in a ${contextLabel} register/setting, calibrated to the TOEIC ` +
    `difficulty levels below (mix questions across them roughly evenly and randomly): ${volumeHints}. ` +
    `Write exactly ${QUESTION_COUNT} independent sentences, each with exactly one blank marked "___", ` +
    `testing grammar (word form, verb tense/agreement, prepositions, conjunctions) or ` +
    `vocabulary-in-context, with exactly 4 answer options in ${languageLabel} and a brief explanation ` +
    `(in Vietnamese) of why the correct option is right and, briefly, why the others are wrong. ` +
    `The explanation must use only Vietnamese script — never Chinese, Japanese, or other ` +
    `non-Vietnamese characters. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"questions": [{"sentenceWithBlank": "...", "options": ["...", "...", "...", "..."], ` +
    `"correctIndex": 0, "explanation": "..."}]}`
  );
}

export function parsePart5Set(json: Record<string, unknown>): Part5Set {
  const rawQuestions = Array.isArray(json.questions) ? json.questions : [];
  const questions: Part5Question[] = [];
  for (const raw of rawQuestions) {
    if (typeof raw !== "object" || raw === null) continue;
    const q = raw as Record<string, unknown>;
    questions.push({
      sentenceWithBlank: typeof q.sentenceWithBlank === "string" ? q.sentenceWithBlank : "",
      options: Array.isArray(q.options) ? q.options.map(String) : [],
      correctIndex: typeof q.correctIndex === "number" ? q.correctIndex : 0,
      explanation: typeof q.explanation === "string" ? q.explanation : "",
    });
  }
  return { questions };
}
