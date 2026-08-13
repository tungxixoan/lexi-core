import { collection, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";

export async function countVocabRecords(uid: string): Promise<number> {
  const col = collection(getFirebaseDb(), "users", uid, "vocab_records");
  const snapshot = await getDocs(col);
  return snapshot.size;
}
