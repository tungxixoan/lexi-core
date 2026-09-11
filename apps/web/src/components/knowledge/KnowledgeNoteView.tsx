"use client";

import { useState } from "react";
import Link from "next/link";
import type { KnowledgeNote } from "@/lib/knowledgeNotes";
import { knowledgeGroupLabel } from "@/lib/knowledgeGroups";
import { BoldText } from "@/components/shared/BoldText";
import { HighlightedText } from "@/components/shared/HighlightedText";

interface KnowledgeNoteViewProps {
  note: KnowledgeNote;
  knownHeadwords: string[];
  onDelete: () => void;
}

export function KnowledgeNoteView({ note, knownHeadwords, onDelete }: KnowledgeNoteViewProps) {
  const [confirmingDelete, setConfirmingDelete] = useState(false);

  return (
    <div className="knowledge-detail">
      <div className="knowledge-detail-actions">
        <Link href={`/knowledge/note/${note.id}/edit`} className="vb-chip">
          Sửa
        </Link>
        {confirmingDelete ? (
          <>
            <button type="button" className="vb-chip" onClick={onDelete}>
              Xác nhận xoá?
            </button>
            <button type="button" className="vb-chip" onClick={() => setConfirmingDelete(false)}>
              Huỷ
            </button>
          </>
        ) : (
          <button type="button" className="vb-chip" onClick={() => setConfirmingDelete(true)}>
            Xoá
          </button>
        )}
      </div>

      <h2>{note.title}</h2>
      {note.summary && <p className="scr-sub">{note.summary}</p>}
      <BoldText source={note.explanation} />

      {note.patterns.length > 0 && (
        <section>
          <h3>Mẫu câu</h3>
          {note.patterns.map((pattern, i) => (
            <code key={i} className="knowledge-pattern">
              {pattern}
            </code>
          ))}
        </section>
      )}

      {note.examples.length > 0 && (
        <section>
          <h3>Ví dụ</h3>
          {note.examples.map((example, i) => (
            <div key={i} className="knowledge-example">
              <HighlightedText variant="static" text={example.text} highlights={knownHeadwords} />
              <p className="ex-translation">{example.translation}</p>
            </div>
          ))}
        </section>
      )}

      {note.pitfalls.length > 0 && (
        <section>
          <h3>Lỗi thường gặp</h3>
          {note.pitfalls.map((pitfall, i) => (
            <BoldText key={i} source={pitfall} />
          ))}
        </section>
      )}

      <div className="knowledge-pill-row">
        <span className="vb-chip">{knowledgeGroupLabel(note.groupId)}</span>
        {note.cefrLevel && <span className="cefr-pill">{note.cefrLevel.toUpperCase()}</span>}
        {note.tags.map((tag) => (
          <span key={tag} className="vb-chip">
            {tag}
          </span>
        ))}
        {note.source === "starter" && <span className="vb-chip">Mẫu</span>}
      </div>
    </div>
  );
}
