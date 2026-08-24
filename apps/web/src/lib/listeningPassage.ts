import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { APP_CONTEXT_LABELS, type AppContext } from "./appContext";
import type { VocabRecord } from "./vocabRecords";

export type ListeningKind = "conversation" | "talk";
export type SpeakerGender = "male" | "female";
export type VoiceId = "male1" | "male2" | "female1" | "female2";
export type Speaker = "A" | "B" | "solo";
type CefrLevel = VocabRecord["cefrLevel"];

export interface ListeningTurn {
  speaker: "A" | "B" | null; // null for a talk's single speaker
  text: string;
}

export interface ListeningQuestion {
  question: string;
  options: string[]; // always 4
  correctIndex: number; // 0-3
}

export interface ListeningPassage {
  kind: ListeningKind;
  turns: ListeningTurn[];
  questions: ListeningQuestion[]; // always 3
  speakerGenders: Partial<Record<Speaker, SpeakerGender>>;
  level: CefrLevel;
  context: AppContext;
  targetLanguage: TargetLanguage;
}

const CEFR_LABELS: Record<CefrLevel, string> = {
  a1: "A1",
  a2: "A2",
  b1: "B1",
  b2: "B2",
  c1: "C1",
  c2: "C2",
};

// Ports lib/features/listening/data/sources/listening_passage_source.dart's
// _buildPrompt word-for-word, with one addition: each turn also carries a
// "gender" field (male/female), consistent per speaker letter across the
// whole passage — needed to pick an appropriate voice on the web (Flutter
// differentiates speakers via on-device TTS pitch instead, which has no
// equivalent on this app's self-hosted Piper backend).
export function buildListeningPassagePrompt(
  level: CefrLevel,
  context: AppContext,
  targetLanguage: TargetLanguage
): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const levelLabel = CEFR_LABELS[level];
  const contextLabel = APP_CONTEXT_LABELS[context];
  return (
    `You are creating a TOEIC-style listening exercise for a Vietnamese speaker ` +
    `learning ${languageLabel}, at ${levelLabel} level, in a ${contextLabel} ` +
    `register/setting. ` +
    `Randomly choose ONE of these two formats: ` +
    `(1) a CONVERSATION between exactly two speakers labeled "A" and "B" only ` +
    `(e.g. at an office, store, or while traveling), with 3 to 6 turns alternating ` +
    `between "A" and "B"; or ` +
    `(2) a TALK by a single speaker (e.g. an announcement, advertisement, or set of ` +
    `instructions), split into 2 to 4 turns, each with speaker set to null. ` +
    `For every turn, also declare "gender" as "male" or "female" for that turn's ` +
    `speaker — keep it consistent for the same speaker letter across the whole ` +
    `passage (speaker "A" is always the same gender in every one of its turns; ` +
    `same for "B"). A conversation may use two speakers of the same gender or two ` +
    `different genders — vary this across different generations. ` +
    `Then write exactly 3 multiple-choice questions in ${languageLabel} about ` +
    `the passage, each with exactly 4 answer options in ${languageLabel}, ` +
    `testing the main idea, a specific detail, or an implied meaning — never a ` +
    `fill-in-the-blank question. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"kind": "conversation" or "talk", ` +
    `"turns": [{"speaker": "A" or "B" or null, "gender": "male" or "female", "text": "..."}], ` +
    `"questions": [{"question": "...", "options": ["...", "...", "...", "..."], ` +
    `"correctIndex": 0}]}`
  );
}

function speakerKey(speaker: "A" | "B" | null): Speaker {
  return speaker ?? "solo";
}

// Ports ListeningPassageSource._parse, plus derives speakerGenders from
// each speaker's first-seen turn — deliberately not re-derived per turn,
// so an AI response that's inconsistent about a speaker's gender on a
// later turn doesn't change which voice gets used mid-passage.
export function parseListeningPassage(
  json: Record<string, unknown>,
  level: CefrLevel,
  context: AppContext,
  targetLanguage: TargetLanguage
): ListeningPassage {
  const kind: ListeningKind = json.kind === "conversation" ? "conversation" : "talk";

  const rawTurns = Array.isArray(json.turns) ? json.turns : [];
  const turns: ListeningTurn[] = rawTurns.map((t) => {
    const tm = t as Record<string, unknown>;
    const speaker = tm.speaker === "A" || tm.speaker === "B" ? tm.speaker : null;
    return { speaker, text: typeof tm.text === "string" ? tm.text : "" };
  });

  const speakerGenders: Partial<Record<Speaker, SpeakerGender>> = {};
  for (const t of rawTurns) {
    const tm = t as Record<string, unknown>;
    const speaker = tm.speaker === "A" || tm.speaker === "B" ? tm.speaker : null;
    const key = speakerKey(speaker);
    if (key in speakerGenders) continue; // first-seen wins
    if (tm.gender === "male" || tm.gender === "female") {
      speakerGenders[key] = tm.gender;
    }
  }

  const rawQuestions = Array.isArray(json.questions) ? json.questions : [];
  const questions: ListeningQuestion[] = rawQuestions.map((q) => {
    const qm = q as Record<string, unknown>;
    return {
      question: typeof qm.question === "string" ? qm.question : "",
      options: Array.isArray(qm.options) ? qm.options.map(String) : [],
      correctIndex: typeof qm.correctIndex === "number" ? qm.correctIndex : 0,
    };
  });

  return { kind, turns, questions, speakerGenders, level, context, targetLanguage };
}

// Deterministic, computed once per session (not per synthesizeSpeech call).
// Walks distinct speakers in order of first appearance; for each, takes the
// next unused voice slot of that speaker's declared gender. A speaker with
// no declared gender (malformed AI response) defaults to "female" — an
// arbitrary but harmless choice, since the alternative (throwing) would
// break an otherwise-usable passage over a cosmetic voice-picking detail.
export function assignVoices(passage: ListeningPassage): Partial<Record<Speaker, VoiceId>> {
  const seen = new Set<Speaker>();
  const order: Speaker[] = [];
  for (const t of passage.turns) {
    const key = speakerKey(t.speaker);
    if (!seen.has(key)) {
      seen.add(key);
      order.push(key);
    }
  }

  const nextSlotByGender: Record<SpeakerGender, 1 | 2> = { male: 1, female: 1 };
  const result: Partial<Record<Speaker, VoiceId>> = {};
  for (const speaker of order) {
    const gender = passage.speakerGenders[speaker] ?? "female";
    const slot = nextSlotByGender[gender];
    result[speaker] = `${gender}${slot}` as VoiceId;
    nextSlotByGender[gender] = slot === 1 ? 2 : 1; // wraps back to 1 past 2 speakers of the same gender
  }
  return result;
}

// Ports ComprehensionSessionResult.correctCount, expressed as a ratio
// (correctCount / total) rather than a raw count, matching this app's
// other scoring functions (e.g. dictation.ts's computeDictationScore)
// returning a 0-1 fraction. A null (unanswered) entry never counts as
// correct even if correctIndex happens to be 0.
export function scoreComprehension(passage: ListeningPassage, selectedAnswers: (number | null)[]): number {
  if (passage.questions.length === 0) return 0;
  let correct = 0;
  for (let i = 0; i < passage.questions.length; i++) {
    if (selectedAnswers[i] !== null && selectedAnswers[i] === passage.questions[i].correctIndex) {
      correct++;
    }
  }
  return correct / passage.questions.length;
}
