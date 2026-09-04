import { LANGUAGE_LABELS } from "./languages";
import { generateContent, type AiProvider } from "./generateContent";
import { parseAiJsonObject } from "./parseAiJson";
import type { VocabRecord } from "./vocabRecords";

export type { AiProvider };

// Port of lib/features/practice/domain/entities/exercise.dart's sealed
// `Exercise` hierarchy. The discriminant is `type`; every member carries the
// source `record` (Flutter's `vocabRecord`).
export type PracticeExercise =
  | { type: "flashcard"; record: VocabRecord }
  | {
      type: "multiple_choice";
      record: VocabRecord;
      question: string;
      options: string[]; // always 4 items
      correctIndex: number; // 0-3
    }
  | {
      type: "fill_in_blank";
      record: VocabRecord;
      sentence: string; // contains exactly one "___"
      answer: string; // lowercased + trimmed expected answer
    }
  | {
      type: "translation";
      record: VocabRecord;
      prompt: string;
      answer: string;
    };

// Verbatim port of ExerciseGeneratorSource._buildPrompt
// (lib/features/practice/data/sources/exercise_generator_source.dart).
// Flutter reads `record.targetLanguage.label` (Language.label) and
// `record.cefrLevel.label` (== `name.toUpperCase()`); the web equivalents are
// `LANGUAGE_LABELS[record.targetLanguage]` and `record.cefrLevel.toUpperCase()`.
export function buildExercisePrompt(record: VocabRecord): string {
  const examples = record.examples.slice(0, 2).join("; ");
  const languageLabel = LANGUAGE_LABELS[record.targetLanguage];
  const cefrLabel = record.cefrLevel.toUpperCase();
  return `Generate a vocabulary exercise for a learner studying ${languageLabel}.
Word: "${record.headword}"
Meaning: "${record.meaning}"
Examples: "${examples}"
CEFR level: ${cefrLabel}

Choose ONE exercise type appropriate for this CEFR level:
- A1/A2: prefer "multiple_choice"
- B1/B2: prefer "fill_in_blank" or "multiple_choice"
- C1/C2: prefer "translation" or "fill_in_blank"

If you use the "translation" type, the Vietnamese "prompt"/"answer" text must use only
Vietnamese script — never Chinese, Japanese, or other non-Vietnamese characters.

Respond with JSON only (no markdown), exactly one of these shapes:
{"type":"multiple_choice","question":"What does '${record.headword}' mean?","options":["...","...","...","..."],"correctIndex":0}
{"type":"fill_in_blank","sentence":"A sentence with ___ replacing the word.","answer":"${record.headword}"}
{"type":"translation","prompt":"Translate to Vietnamese: 'A short sentence using ${record.headword}'","answer":"Vietnamese translation here"}
`;
}

// Port of ExerciseGeneratorSource._parseExercise. Flutter uses hard casts
// (`json['question'] as String`) inside a `switch (type)` and lets a
// ClassCastException bubble to GenerateExerciseUseCase, which catches it and
// falls back to a flashcard. Here we guard each required field read instead:
// any missing / wrong-typed required field — or an unknown `type` — yields
// `{ type: "flashcard", record }` with no throw.
export function parseExercise(
  json: Record<string, unknown>,
  record: VocabRecord
): PracticeExercise {
  const flashcard: PracticeExercise = { type: "flashcard", record };
  const type = typeof json.type === "string" ? json.type : "";

  switch (type) {
    case "multiple_choice": {
      const { question, options, correctIndex } = json;
      if (typeof question !== "string") return flashcard;
      if (!Array.isArray(options) || !options.every((o) => typeof o === "string")) {
        return flashcard;
      }
      if (typeof correctIndex !== "number") return flashcard;
      return {
        type: "multiple_choice",
        record,
        question,
        options: options as string[],
        correctIndex,
      };
    }
    case "fill_in_blank": {
      const { sentence, answer } = json;
      if (typeof sentence !== "string" || typeof answer !== "string") return flashcard;
      return {
        type: "fill_in_blank",
        record,
        sentence,
        answer: answer.toLowerCase().trim(),
      };
    }
    case "translation": {
      const { prompt, answer } = json;
      if (typeof prompt !== "string" || typeof answer !== "string") return flashcard;
      return { type: "translation", record, prompt, answer };
    }
    default:
      return flashcard;
  }
}

// Port of GenerateExerciseUseCase.execute + ExerciseGeneratorSource.generate:
// build the prompt, call the BYOK proxy, parse the JSON, map to a
// PracticeExercise. ANY thrown error (network, proxy, non-JSON response,
// parse failure) collapses to a flashcard — matching Flutter's
// `try { ... } catch (_) { FlashcardExercise(record) }`.
export async function generateExercise(
  record: VocabRecord,
  ai: { provider: AiProvider; model: string; apiKeyCiphertext: string }
): Promise<PracticeExercise> {
  try {
    const { text } = await generateContent({
      provider: ai.provider,
      model: ai.model,
      apiKeyCiphertext: ai.apiKeyCiphertext,
      prompt: buildExercisePrompt(record),
    });
    return parseExercise(parseAiJsonObject(text), record);
  } catch {
    return { type: "flashcard", record };
  }
}
