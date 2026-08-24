import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import type { DictationItem, DictationDifficulty } from "./dictation";
import type { ListeningKind, ListeningTurn, ListeningQuestion, Speaker, SpeakerGender } from "./listeningPassage";
import type { AppContext } from "./appContext";
import type { TargetLanguage } from "./languages";
import type { VocabRecord } from "./vocabRecords";

export interface DictationFilters {
  difficulty: DictationDifficulty;
}

export interface ComprehensionFilters {
  context: AppContext;
  level: VocabRecord["cefrLevel"];
}

export interface ComprehensionItem {
  kind: ListeningKind;
  turns: ListeningTurn[];
  questions: ListeningQuestion[];
  // Persisted deliberately, unlike the specific voice SLOT (male1 vs
  // male2) chosen for a session: gender is inherent content of the
  // passage (which speaker is male vs female), not a playback detail. The
  // raw AI JSON's "gender" field only exists at generation time — without
  // this, a reused conversation would have nothing to derive gender from
  // and every reused conversation would silently collapse to same-gender
  // voices for both speakers (assignVoices' own "default to female when
  // unknown" fallback), losing the variety the feature exists to provide.
  speakerGenders: Partial<Record<Speaker, SpeakerGender>>;
}

// A parallel, independent module to savedReadingExercises.ts — deliberately
// not a member of that file's SavedReadingExercise union, since a
// listening item's shape has nothing structurally in common with a reading
// passage. Mirrors savedReadingExercises.ts's own FiltersFor<T>/Extract<>
// generic pattern now that this module has more than one type.
export type SavedListeningExercise =
  | {
      id: string;
      type: "dictation";
      item: DictationItem;
      generationFilters: DictationFilters;
      targetLanguage: TargetLanguage;
      createdAt: string;
    }
  | {
      id: string;
      type: "comprehension";
      item: ComprehensionItem;
      generationFilters: ComprehensionFilters;
      targetLanguage: TargetLanguage;
      createdAt: string;
    };

type FiltersFor<T extends SavedListeningExercise["type"]> = Extract<SavedListeningExercise, { type: T }>["generationFilters"];
type ItemFor<T extends SavedListeningExercise["type"]> = Extract<SavedListeningExercise, { type: T }>["item"];

function listeningExercisesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "listening_exercises");
}

export async function saveListeningExercise<T extends SavedListeningExercise["type"]>(
  uid: string,
  type: T,
  item: ItemFor<T>,
  generationFilters: FiltersFor<T>,
  targetLanguage: TargetLanguage
): Promise<string> {
  const ref = doc(listeningExercisesCol(uid));
  // Carries its own id field, matching every other save*Exercise function
  // in this app — see savedReadingExercises.ts's saveReadingExercise.
  const record = {
    type,
    item,
    generationFilters,
    targetLanguage,
    createdAt: new Date().toISOString(),
  };
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

function matchesDictation(
  exercise: Extract<SavedListeningExercise, { type: "dictation" }>,
  filters: DictationFilters
): boolean {
  return exercise.generationFilters.difficulty === filters.difficulty;
}

function matchesComprehension(
  exercise: Extract<SavedListeningExercise, { type: "comprehension" }>,
  filters: ComprehensionFilters
): boolean {
  return exercise.generationFilters.context === filters.context && exercise.generationFilters.level === filters.level;
}

export async function getRandomSavedListeningExercise<T extends SavedListeningExercise["type"]>(
  uid: string,
  targetLanguage: TargetLanguage,
  type: T,
  filters: FiltersFor<T>,
  excludeId?: string
): Promise<Extract<SavedListeningExercise, { type: T }> | null> {
  const q = query(listeningExercisesCol(uid), where("targetLanguage", "==", targetLanguage));
  const snapshot = await getDocs(q);
  const candidates: Extract<SavedListeningExercise, { type: T }>[] = [];
  for (const d of snapshot.docs) {
    const ex = { ...(d.data() as SavedListeningExercise), id: d.id };
    if (ex.id === excludeId) continue;
    if (ex.type !== type) continue;
    // Safe: `type` narrows `ex` to the matching union member at runtime,
    // even though TypeScript can't express that narrowing through a
    // generic `T` — `filters`' own generic type already forces the caller
    // to pass the matching filter shape for this exact `type`.
    const matches =
      ex.type === "dictation" ? matchesDictation(ex, filters as DictationFilters) : matchesComprehension(ex, filters as ComprehensionFilters);
    if (matches) candidates.push(ex as Extract<SavedListeningExercise, { type: T }>);
  }
  if (candidates.length === 0) return null;
  return candidates[Math.floor(Math.random() * candidates.length)];
}
