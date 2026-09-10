// 1:1 port of lib/features/knowledge/data/sources/knowledge_note_source.dart
// (post whole-branch fix #3). Pure prompt-builder + defensive parser — no
// network call here; that happens later in the AI-compose component, mirrors
// part5.ts's buildXPrompt/parseXSet split.
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { knowledgeGroupsFor, knowledgeOtherGroupId } from "./knowledgeGroups";
import type { CefrLevel, KnowledgeNote } from "./knowledgeNotes";

const CEFRS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];

export interface KnowledgeNoteDraft {
  title: string;
  summary: string;
  explanation: string;
  patterns: string[];
  examples: { text: string; translation: string }[];
  pitfalls: string[];
  suggestedGroupId: string | null;
  suggestedCefr: CefrLevel | null;
  suggestedTags: string[];
  relatedNoteId: string | null;
}

function strList(v: unknown): string[] {
  if (Array.isArray(v)) return v.filter((x): x is string => typeof x === "string");
  return typeof v === "string" && v.length > 0 ? [v] : [];
}
function nonEmptyOrNull(v: unknown): string | null {
  return typeof v === "string" && v.trim().length > 0 ? v.trim() : null;
}

export function buildKnowledgeNotePrompt(args: {
  request: string;
  targetLanguage: TargetLanguage;
  hintGroupId?: string | null;
  hintCefr?: CefrLevel | null;
  existingInScope: Pick<KnowledgeNote, "id" | "title" | "summary">[];
  extendingNote?: KnowledgeNote | null;
}): string {
  const label = LANGUAGE_LABELS[args.targetLanguage];
  const groups = knowledgeGroupsFor(args.targetLanguage)
    .map((g) => `${g.id} (${g.label})`)
    .join("; ");
  const existing =
    args.existingInScope.length === 0
      ? "None."
      : args.existingInScope.map((n) => `- id=${n.id} | ${n.title} | ${n.summary}`).join("\n");
  const hint = [
    args.hintGroupId ? `Prefer groupId "${args.hintGroupId}".` : "",
    args.hintCefr ? `Target CEFR ${args.hintCefr.toUpperCase()}.` : "",
  ]
    .filter(Boolean)
    .join(" ");
  const extend = args.extendingNote
    ? `You are REVISING this existing note — merge the new request into it and return the full updated note:\n${JSON.stringify(args.extendingNote)}\n`
    : "";
  return (
    `You are a grammar reference assistant for a Vietnamese speaker learning ${label}. ` +
    `Write a single reference note answering this request: "${args.request}". ${hint}\n` +
    extend +
    `Available groupId values: ${groups}\n` +
    `Existing notes in the same area (for de-duplication):\n${existing}\n` +
    `All prose and translations must be in Vietnamese (Vietnamese script only). In "explanation" ` +
    `and each "pitfalls" item you may wrap key terms in **double asterisks** for bold; use \\n\\n ` +
    `between paragraphs; no other markup. ` +
    `Respond with JSON only (no code fences): ` +
    `{"title":"short Vietnamese title","summary":"1-2 Vietnamese sentences","explanation":"...",` +
    `"patterns":["form strings, may be empty"],"examples":[{"text":"target-language sentence",` +
    `"translation":"Vietnamese"}],"pitfalls":["common mistakes, may be empty"],` +
    `"suggestedGroupId":"one id from the list above","suggestedCefr":"a1|a2|b1|b2|c1|c2 or null",` +
    `"suggestedTags":["0-3 short kebab-case tags"],"relatedNoteId":"the id of an existing note this ` +
    `substantially duplicates, or null"}`
  );
}

export function parseKnowledgeNoteDraft(
  json: Record<string, unknown>,
  targetLanguage: TargetLanguage,
): KnowledgeNoteDraft {
  const validGroupIds = new Set(knowledgeGroupsFor(targetLanguage).map((g) => g.id));
  const rawGroup = nonEmptyOrNull(json.suggestedGroupId);
  // A hallucinated / wrong-language id would land the note in no group card
  // (the grid only iterates this language's taxonomy) — funnel it to "Khác".
  const suggestedGroupId =
    rawGroup === null ? null : validGroupIds.has(rawGroup) ? rawGroup : knowledgeOtherGroupId(targetLanguage);
  const rawCefr = typeof json.suggestedCefr === "string" ? json.suggestedCefr.trim().toLowerCase() : "";
  return {
    title: typeof json.title === "string" ? json.title : "",
    summary: typeof json.summary === "string" ? json.summary : "",
    explanation: typeof json.explanation === "string" ? json.explanation : "",
    patterns: strList(json.patterns),
    examples: Array.isArray(json.examples)
      ? json.examples
          .filter((e): e is Record<string, unknown> => typeof e === "object" && e !== null)
          .map((e) => ({
            text: typeof e.text === "string" ? e.text : "",
            translation: typeof e.translation === "string" ? e.translation : "",
          }))
      : [],
    pitfalls: strList(json.pitfalls),
    suggestedGroupId,
    suggestedCefr: (CEFRS as string[]).includes(rawCefr) ? (rawCefr as CefrLevel) : null,
    suggestedTags: strList(json.suggestedTags),
    relatedNoteId: nonEmptyOrNull(json.relatedNoteId),
  };
}
