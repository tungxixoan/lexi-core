import Link from "next/link";
import type { KnowledgeNote } from "@/lib/knowledgeNotes";
import { knowledgeGroupLabel } from "@/lib/knowledgeGroups";

export function KnowledgeNoteCard({ note, href }: { note: KnowledgeNote; href: string }) {
  return (
    <Link href={href} className="knowledge-card">
      <span className="knowledge-card-title">{note.title}</span>
      {note.summary && <p className="known-summary-clamp">{note.summary}</p>}
      <div className="knowledge-pill-row">
        <span className="vb-chip">{knowledgeGroupLabel(note.groupId)}</span>
        {note.cefrLevel && <span className="cefr-pill">{note.cefrLevel.toUpperCase()}</span>}
        {note.source === "starter" && <span className="vb-chip">Mẫu</span>}
      </div>
    </Link>
  );
}
