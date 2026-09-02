import { collection, deleteDoc, doc, getDocs, orderBy, query, setDoc, updateDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import { capitalizeHeadword } from "./vocabDisplay";
import type { Sm2Fields } from "./sm2";

export interface VocabRecord {
  id: string;
  headword: string;
  inputType: "word" | "phrase" | "sentence";
  ipa: string;
  meaning: string;
  examples: string[];
  personalNotes: string;
  topicIds: string[];
  targetLanguage: "vietnamese" | "english" | "chinese" | "korean" | "japanese";
  cefrLevel: "a1" | "a2" | "b1" | "b2" | "c1" | "c2";
  activeContext:
    | "general"
    | "business"
    | "technology"
    | "travel"
    | "foodAndDrink"
    | "health"
    | "academic"
    | "socialCasual";
  createdAt: string;
  updatedAt: string;
  nextReviewAt: string | null;
  sm2Repetitions: number;
  sm2EaseFactor: number;
  sm2Interval: number;
  definition: string;
  synonyms: string[];
}

export type VocabRecordUpdate = Pick<VocabRecord, "meaning" | "examples" | "topicIds" | "personalNotes">;
export type NewVocabRecord = Omit<VocabRecord, "id">;
type TargetLanguage = VocabRecord["targetLanguage"];

function vocabRecordsCol(uid: string, language: TargetLanguage) {
  return collection(getFirebaseDb(), "users", uid, `vocab_records_${language}`);
}

export async function countVocabRecords(uid: string, language: TargetLanguage): Promise<number> {
  const snapshot = await getDocs(vocabRecordsCol(uid, language));
  return snapshot.size;
}

export async function getVocabRecords(uid: string, language: TargetLanguage): Promise<VocabRecord[]> {
  const q = query(vocabRecordsCol(uid, language), orderBy("createdAt", "desc"));
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ ...(d.data() as VocabRecord), id: d.id }));
}

export async function deleteVocabRecord(uid: string, id: string, language: TargetLanguage): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, `vocab_records_${language}`, id);
  await deleteDoc(ref);
}

export async function updateVocabRecord(
  uid: string,
  id: string,
  updates: VocabRecordUpdate,
  language: TargetLanguage
): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, `vocab_records_${language}`, id);
  await updateDoc(ref, { ...updates, updatedAt: new Date().toISOString() });
}

export async function getVocabRecordByHeadword(
  uid: string,
  headword: string,
  targetLanguage: TargetLanguage
): Promise<VocabRecord | null> {
  // Stored headwords are capitalized (capitalizeHeadword on every save, plus
  // the one-off migration), so normalize the query term the same way — the
  // lookup cache is called with the raw user query / raw AI output, which is
  // usually lowercase. Idempotent for the save-time callers that already pass
  // a capitalized, trimmed draft.headword.
  const q = query(
    vocabRecordsCol(uid, targetLanguage),
    where("headword", "==", capitalizeHeadword(headword.trim()))
  );
  const snapshot = await getDocs(q);
  if (snapshot.empty) return null;
  const d = snapshot.docs[0];
  return { ...(d.data() as VocabRecord), id: d.id };
}

export async function saveVocabRecord(uid: string, record: NewVocabRecord): Promise<string> {
  const ref = doc(vocabRecordsCol(uid, record.targetLanguage));
  // Flutter's sync_service.dart caches the raw document body and reads
  // json['id'] from it directly (non-nullable) — the doc must carry its
  // own id field, not rely on the caller reading ref.id separately.
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

export async function updateVocabRecordSm2(
  uid: string,
  id: string,
  sm2Fields: Sm2Fields,
  language: TargetLanguage
): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, `vocab_records_${language}`, id);
  await updateDoc(ref, { ...sm2Fields });
}
