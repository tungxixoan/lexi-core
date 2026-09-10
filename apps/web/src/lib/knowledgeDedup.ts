// 1:1 port of lib/features/knowledge/domain/knowledge_dedup.dart (post
// whole-branch fix). Layer-1 duplicate check: cheap client-side scoring to
// suggest existing notes related to a new lookup prompt.
import { normalizeForSearch } from "./normalizeSearch";
import { knowledgeGroupLabel } from "./knowledgeGroups";
import type { KnowledgeNote } from "./knowledgeNotes";

// NB: "thi" (thì = tense) and "the" (thể = aspect) are deliberately NOT
// stopwords — they're group labels and the highest-signal dedup terms.
const STOPWORDS = new Set([
  "va", "khi", "nao", "cho", "cua", "la", "cac", "mot", "voi",
  "dung", "giai", "thich", "vi", "du", "doi", "thuong", "cach", "nay",
  "a", "an", "and", "or", "when", "how", "what", "explain", "give", "example",
]);

function contentTokens(prompt: string): string[] {
  const norm = normalizeForSearch(prompt);
  if (!norm) return [];
  return norm.split(" ").filter((t) => t.length > 1 && !STOPWORDS.has(t));
}

function phrases(tokens: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < tokens.length - 1; i++) {
    out.push(`${tokens[i]} ${tokens[i + 1]}`);
    if (i < tokens.length - 2) out.push(`${tokens[i]} ${tokens[i + 1]} ${tokens[i + 2]}`);
  }
  return out;
}

export function findRelatedNotes(args: { prompt: string; notes: KnowledgeNote[] }): KnowledgeNote[] {
  const tokens = contentTokens(args.prompt);
  if (tokens.length === 0) return [];
  const ph = phrases(tokens);
  const promptTerms = new Set([...tokens, ...ph]);

  const scored: { note: KnowledgeNote; score: number }[] = [];
  for (const note of args.notes) {
    const title = normalizeForSearch(note.title);
    const haystack = normalizeForSearch(
      [note.title, note.summary, note.tags.join(" "), knowledgeGroupLabel(note.groupId)].join(" "),
    );
    const noteTags = new Set(note.tags.map(normalizeForSearch));

    let score = 0;
    for (const p of ph) {
      if (haystack.includes(p)) {
        score += 3;
        if (title.includes(p)) score += 2;
      }
    }
    for (const term of promptTerms) if (noteTags.has(term)) score += 3;
    for (const t of tokens) if (haystack.includes(t)) score += 1;
    if (score >= 3) scored.push({ note, score });
  }
  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, 3).map((s) => s.note);
}
