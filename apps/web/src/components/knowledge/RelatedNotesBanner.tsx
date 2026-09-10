"use client";

import Link from "next/link";
import type { KnowledgeNote } from "@/lib/knowledgeNotes";

interface RelatedNotesBannerProps {
  related: KnowledgeNote[];
  onOpen: (note: KnowledgeNote) => void;
  onExtend: (note: KnowledgeNote) => void;
  onProceedNew: () => void;
}

/**
 * Shown after a Layer-1 (client-side dedup) or Layer-2 (AI-flagged
 * `relatedNoteId`) hit in the "Nhờ AI soạn" flow. Lets the user open one of
 * the existing notes, ask the AI to extend one of them in place, or ignore
 * the match and generate a brand-new note anyway.
 */
export function RelatedNotesBanner({ related, onOpen, onExtend, onProceedNew }: RelatedNotesBannerProps) {
  return (
    <div className="related-notes-banner">
      <p>Bạn đã có {related.length} ghi chú liên quan:</p>
      <div className="related-note-list">
        {related.map((note) => (
          <div className="related-note-card" key={note.id}>
            <span className="related-note-title">{note.title}</span>
            <div className="related-note-actions">
              <Link href={`/knowledge/note/${note.id}`} className="link-btn" onClick={() => onOpen(note)}>
                Mở
              </Link>
              <button type="button" className="link-btn" onClick={() => onExtend(note)}>
                Bổ sung vào ghi chú này
              </button>
            </div>
          </div>
        ))}
      </div>
      <button type="button" className="btn-secondary" onClick={onProceedNew}>
        Vẫn tạo mới
      </button>
    </div>
  );
}
