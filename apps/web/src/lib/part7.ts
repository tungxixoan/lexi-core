import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { ECONOMY_VOLUMES, VOLUME_PROMPT_HINTS, type EconomyVolume } from "./toeicFilters";

export interface Part7Question {
  question: string;
  options: string[]; // always 4
  correctIndex: number;
  explanation: string; // Vietnamese
}

export interface Part7PassageGroup {
  documents: string[]; // 1 (single-passage) or 2 (double-passage)
  questions: Part7Question[]; // 3-4 for single-passage groups, 5 for the double-passage group
}

export interface Part7Set {
  passageGroups: Part7PassageGroup[]; // always 3: [single, single, double]
}

const SINGLE_QUESTION_COUNTS = [3, 4];
const DOUBLE_QUESTION_COUNT = 5;

// Ports lib/features/reading/data/sources/part7_source.dart's prompt. Takes
// resolved topic *names*, not a fixed enum — same shared "Chủ đề" filter
// every reading mode uses, per the hub/setup-merge spec. An empty topic list
// omits the register clause entirely rather than defaulting to a fake
// "general" register.
export function buildPart7Prompt(topicNames: string[], targetLanguage: TargetLanguage, volumes: EconomyVolume[]): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const contextClause = topicNames.length > 0 ? `, in a ${topicNames.join("/")} register/setting` : "";
  const effectiveVolumes = volumes.length === 0 ? ECONOMY_VOLUMES : volumes;
  const volumeHints = effectiveVolumes.map((v) => `${v}: ${VOLUME_PROMPT_HINTS[v]}`).join("; ");
  return (
    `You are creating a TOEIC Part 7 (Reading Comprehension) practice set for a Vietnamese speaker ` +
    `learning ${languageLabel}${contextClause}, calibrated to the Economy TOEIC difficulty ` +
    `volumes below (mix questions across them roughly evenly and randomly): ${volumeHints}. ` +
    `Write exactly 3 passage groups in this exact order: ` +
    `(1) a single-passage group: one realistic business document (email, letter, memo, ` +
    `notice, advertisement, article, or a short text-message exchange), with 3 or 4 ` +
    `multiple-choice questions; ` +
    `(2) another single-passage group, same rules, using a different document type than ` +
    `group 1; ` +
    `(3) a double-passage group: two genuinely related documents (e.g. a job ad and an ` +
    `application email, an announcement and a reply, an invoice and a follow-up letter) ` +
    `where the second document cannot be fully understood without the first, with exactly ` +
    `5 multiple-choice questions, at least one of which requires information from both ` +
    `documents to answer. ` +
    `Every question has exactly 4 answer options in ${languageLabel}, testing main ` +
    `idea, a specific detail, an inference, or vocabulary-in-context, plus a brief ` +
    `explanation (in Vietnamese) of why the correct option is right. The explanation must ` +
    `use only Vietnamese script — never Chinese, Japanese, or other non-Vietnamese ` +
    `characters. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"passageGroups": [{"documents": ["..."], "questions": [{"question": "...", ` +
    `"options": ["...", "...", "...", "..."], "correctIndex": 0, "explanation": "..."}]}]}`
  );
}

export function parsePart7Set(json: Record<string, unknown>): Part7Set {
  const rawGroups = Array.isArray(json.passageGroups) ? json.passageGroups : [];
  const passageGroups: Part7PassageGroup[] = [];
  for (const raw of rawGroups) {
    if (typeof raw !== "object" || raw === null) continue;
    const g = raw as Record<string, unknown>;
    const rawQuestions = Array.isArray(g.questions) ? g.questions : [];
    const questions: Part7Question[] = [];
    for (const rq of rawQuestions) {
      if (typeof rq !== "object" || rq === null) continue;
      const q = rq as Record<string, unknown>;
      questions.push({
        question: typeof q.question === "string" ? q.question : "",
        options: Array.isArray(q.options) ? q.options.map(String) : [],
        correctIndex: typeof q.correctIndex === "number" ? q.correctIndex : 0,
        explanation: typeof q.explanation === "string" ? q.explanation : "",
      });
    }
    passageGroups.push({
      documents: Array.isArray(g.documents) ? g.documents.map(String) : [],
      questions,
    });
  }
  return { passageGroups };
}

// Ports Part7Source's private _hasValidShape check — a stricter structural
// check than "is it empty", since a malformed group count or a wrong
// single/double-document split can't be rendered as a valid Part 7 set at
// all. Deliberately separate from parsePart7Set (which stays non-throwing,
// like its Part5/Part6 siblings) — the page decides whether to reject a
// parsed-but-invalid-shape result, exactly as Part5/Part6's pages already
// decide "is this empty" themselves.
export function hasValidPart7Shape(set: Part7Set): boolean {
  if (set.passageGroups.length !== 3) return false;
  for (let i = 0; i < 2; i++) {
    const group = set.passageGroups[i];
    if (group.documents.length !== 1) return false;
    if (!SINGLE_QUESTION_COUNTS.includes(group.questions.length)) return false;
  }
  const doubleGroup = set.passageGroups[2];
  if (doubleGroup.documents.length !== 2) return false;
  if (doubleGroup.questions.length !== DOUBLE_QUESTION_COUNT) return false;
  return true;
}
