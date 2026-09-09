import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  Timestamp,
} from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import type { TargetLanguage } from "./languages";

export interface KnowledgeExample {
  text: string;
  translation: string;
}
export type KnowledgeNoteOrigin = "ai" | "manual" | "starter";
export type CefrLevel = "a1" | "a2" | "b1" | "b2" | "c1" | "c2";

export interface KnowledgeNote {
  id: string;
  title: string;
  summary: string;
  explanation: string;
  patterns: string[];
  examples: KnowledgeExample[];
  pitfalls: string[];
  groupId: string;
  tags: string[];
  cefrLevel: CefrLevel | null;
  targetLanguage: TargetLanguage;
  source: KnowledgeNoteOrigin;
  sourcePrompt: string | null;
  createdAt: string;
  updatedAt: string;
}
export type NewKnowledgeNote = Omit<KnowledgeNote, "id">;

const LANGUAGES: TargetLanguage[] = [
  "vietnamese",
  "english",
  "chinese",
  "korean",
  "japanese",
];
const CEFRS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const ORIGINS: KnowledgeNoteOrigin[] = ["ai", "manual", "starter"];
const EPOCH = new Date(0).toISOString();

function strList(raw: unknown): string[] {
  return Array.isArray(raw) ? raw.filter((x): x is string => typeof x === "string") : [];
}

// Port of knowledge_note.dart `_parseDate`. Accepts an ISO-8601 string (what
// both apps write), a Firestore `Timestamp`, or an epoch-millis number. Two
// deliberately distinct paths:
//   - `null` / `undefined` / an unparseable string → EPOCH (documented
//     fallback: a single malformed date sorts to the bottom, never throws).
//   - an unrecognised object (no `toDate`, not a `Timestamp`) → THROWS. That
//     is a real decode failure and is what lets `getKnowledgeNotes` skip one
//     bad doc while keeping the rest.
function parseDate(raw: unknown): string {
  if (raw == null) return EPOCH;
  if (typeof raw === "string") {
    const t = Date.parse(raw);
    return Number.isNaN(t) ? EPOCH : new Date(t).toISOString();
  }
  if (typeof raw === "number") return new Date(raw).toISOString();
  if (raw instanceof Timestamp) return raw.toDate().toISOString();
  if (
    typeof raw === "object" &&
    typeof (raw as { toDate?: unknown }).toDate === "function"
  ) {
    return (raw as { toDate(): Date }).toDate().toISOString();
  }
  throw new Error("knowledge note: unrecognised date value");
}

export function parseKnowledgeNote(raw: unknown): KnowledgeNote {
  const j = (raw ?? {}) as Record<string, unknown>;
  const lang = LANGUAGES.includes(j.targetLanguage as TargetLanguage)
    ? (j.targetLanguage as TargetLanguage)
    : "english";
  return {
    id: typeof j.id === "string" ? j.id : "",
    title: typeof j.title === "string" ? j.title : "",
    summary: typeof j.summary === "string" ? j.summary : "",
    explanation: typeof j.explanation === "string" ? j.explanation : "",
    patterns: strList(j.patterns),
    examples: Array.isArray(j.examples)
      ? j.examples
          .filter((e): e is Record<string, unknown> => typeof e === "object" && e !== null)
          .map((e) => ({
            text: typeof e.text === "string" ? e.text : "",
            translation: typeof e.translation === "string" ? e.translation : "",
          }))
      : [],
    pitfalls: strList(j.pitfalls),
    groupId: typeof j.groupId === "string" ? j.groupId : "",
    tags: strList(j.tags),
    cefrLevel: CEFRS.includes(j.cefrLevel as CefrLevel) ? (j.cefrLevel as CefrLevel) : null,
    targetLanguage: lang,
    source: ORIGINS.includes(j.source as KnowledgeNoteOrigin)
      ? (j.source as KnowledgeNoteOrigin)
      : "manual",
    sourcePrompt: typeof j.sourcePrompt === "string" ? j.sourcePrompt : null,
    createdAt: parseDate(j.createdAt),
    updatedAt: parseDate(j.updatedAt),
  };
}

function notesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "knowledge_notes");
}
function seedRef(uid: string) {
  return doc(getFirebaseDb(), "users", uid, "knowledge_meta", "seed");
}

/// Every note whose `targetLanguage` matches `language`, newest first. Reads
/// the whole collection and filters in memory (mirrors the Flutter service).
/// One undecodable doc is skipped; an outer failure degrades to `[]`.
export async function getKnowledgeNotes(
  uid: string,
  language: TargetLanguage,
): Promise<KnowledgeNote[]> {
  try {
    const snapshot = await getDocs(notesCol(uid));
    const notes: KnowledgeNote[] = [];
    for (const d of snapshot.docs) {
      try {
        const n = parseKnowledgeNote({ ...(d.data() as object), id: d.id });
        if (n.targetLanguage === language) notes.push(n);
      } catch {
        /* skip one undecodable doc rather than losing the whole list */
      }
    }
    notes.sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : a.updatedAt > b.updatedAt ? -1 : 0));
    return notes;
  } catch {
    return [];
  }
}

/// Creates or replaces `knowledge_notes/{note.id}`. The id is duplicated into
/// the doc body so a raw cached read can find it. Throws on a write failure —
/// a lost save of hand-authored content must not look successful.
export async function upsertKnowledgeNote(uid: string, note: KnowledgeNote): Promise<void> {
  await setDoc(doc(notesCol(uid), note.id), { ...note });
}

/// Deletes `knowledge_notes/{id}`. Throws on a write failure (see `upsert`).
export async function deleteKnowledgeNote(uid: string, id: string): Promise<void> {
  await deleteDoc(doc(notesCol(uid), id));
}

async function writeMissing(
  uid: string,
  starters: KnowledgeNote[],
): Promise<KnowledgeNote[]> {
  if (starters.length === 0) return [];
  const existing = new Set((await getDocs(notesCol(uid))).docs.map((d) => d.id));
  const toWrite = starters.filter((s) => !existing.has(s.id));
  for (const s of toWrite) await setDoc(doc(notesCol(uid), s.id), { ...s });
  return toWrite;
}

/// First-run seeding for `language`: if the seed flag is not `true` and the
/// language has no notes yet, writes every starter whose id is absent and sets
/// the flag. If the language already has notes, sets the flag and writes
/// nothing. Returns what it wrote (`[]` otherwise). Best-effort.
export async function seedStartersIfNeeded(
  uid: string,
  language: TargetLanguage,
  starters: KnowledgeNote[],
): Promise<KnowledgeNote[]> {
  try {
    const flag = (await getDoc(seedRef(uid))).data()?.[language] === true;
    if (flag) return [];

    const all = await getDocs(notesCol(uid));
    const hasForLang = all.docs.some(
      (d) => (d.data() as { targetLanguage?: string }).targetLanguage === language,
    );
    if (hasForLang) {
      await setDoc(seedRef(uid), { [language]: true }, { merge: true });
      return [];
    }

    const wrote = await writeMissing(uid, starters);
    await setDoc(seedRef(uid), { [language]: true }, { merge: true });
    return wrote;
  } catch {
    return [];
  }
}

/// Re-adds any starter for `language` whose id is missing from the collection;
/// never overwrites an existing (possibly user-edited) note. Returns what it
/// wrote. Best-effort.
export async function restoreStarters(
  uid: string,
  language: TargetLanguage,
  starters: KnowledgeNote[],
): Promise<KnowledgeNote[]> {
  void language;
  try {
    return await writeMissing(uid, starters);
  } catch {
    return [];
  }
}
