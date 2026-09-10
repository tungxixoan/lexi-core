import starterEn from "@/data/knowledge/starter_en.json";
import { parseKnowledgeNote, type KnowledgeNote } from "./knowledgeNotes";
import type { TargetLanguage } from "./languages";

const EN: KnowledgeNote[] = (starterEn as unknown[]).map(parseKnowledgeNote);

export function startersFor(language: TargetLanguage): KnowledgeNote[] {
  return language === "english" ? EN : [];
}
