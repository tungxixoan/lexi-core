import { collection, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";

export interface Topic {
  id: string;
  name: string;
  emoji: string;
  isPredefined: boolean;
  createdAt: string;
}

export async function getTopics(uid: string): Promise<Topic[]> {
  const col = collection(getFirebaseDb(), "users", uid, "topics");
  const snapshot = await getDocs(col);
  return snapshot.docs.map((d) => {
    const data = d.data() as Topic;
    return { ...data, id: d.id, emoji: data.emoji ?? "📌" };
  });
}
