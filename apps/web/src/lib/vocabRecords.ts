import { collection, deleteDoc, doc, getDocs, orderBy, query, setDoc, updateDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";

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

function vocabRecordsCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "vocab_records");
}

export async function countVocabRecords(uid: string): Promise<number> {
  const col = collection(getFirebaseDb(), "users", uid, "vocab_records");
  const snapshot = await getDocs(col);
  return snapshot.size;
}

export async function getVocabRecords(uid: string): Promise<VocabRecord[]> {
  const q = query(vocabRecordsCol(uid), orderBy("createdAt", "desc"));
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ ...(d.data() as VocabRecord), id: d.id }));
}

export async function deleteVocabRecord(uid: string, id: string): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, "vocab_records", id);
  await deleteDoc(ref);
}

export async function updateVocabRecord(
  uid: string,
  id: string,
  updates: VocabRecordUpdate
): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, "vocab_records", id);
  await updateDoc(ref, { ...updates, updatedAt: new Date().toISOString() });
}

export async function getVocabRecordByHeadword(
  uid: string,
  headword: string,
  targetLanguage: VocabRecord["targetLanguage"]
): Promise<VocabRecord | null> {
  const q = query(
    vocabRecordsCol(uid),
    where("headword", "==", headword),
    where("targetLanguage", "==", targetLanguage)
  );
  const snapshot = await getDocs(q);
  if (snapshot.empty) return null;
  const d = snapshot.docs[0];
  return { ...(d.data() as VocabRecord), id: d.id };
}

export async function saveVocabRecord(uid: string, record: NewVocabRecord): Promise<string> {
  const ref = doc(vocabRecordsCol(uid));
  await setDoc(ref, record);
  return ref.id;
}
