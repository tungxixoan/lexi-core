import { collection, deleteDoc, doc, getDocs, orderBy, query, updateDoc } from "firebase/firestore";
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

export async function countVocabRecords(uid: string): Promise<number> {
  const col = collection(getFirebaseDb(), "users", uid, "vocab_records");
  const snapshot = await getDocs(col);
  return snapshot.size;
}

export async function getVocabRecords(uid: string): Promise<VocabRecord[]> {
  const col = collection(getFirebaseDb(), "users", uid, "vocab_records");
  const q = query(col, orderBy("createdAt", "desc"));
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
