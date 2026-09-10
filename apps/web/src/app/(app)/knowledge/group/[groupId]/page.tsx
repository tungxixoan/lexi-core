"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { useRouteParams } from "@/lib/useRouteParams";
import { getKnowledgeNotes, type CefrLevel, type KnowledgeNote } from "@/lib/knowledgeNotes";
import { knowledgeGroupLabel } from "@/lib/knowledgeGroups";
import { KnowledgeNoteCard } from "@/components/knowledge/KnowledgeNoteCard";
import { SignInButton } from "@/components/SignInButton";

const CEFR_ORDER: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const NO_CEFR_LABEL = "Chưa gắn cấp độ";

export default function KnowledgeGroupPage({ params }: { params: Promise<{ groupId: string }> }) {
  const resolvedParams = useRouteParams(params);
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const [notes, setNotes] = useState<KnowledgeNote[] | null>(null);

  useEffect(() => {
    if (!user || !settings) return;
    getKnowledgeNotes(user.uid, settings.targetLanguage).then(setNotes);
  }, [user, settings]);

  if (resolvedParams === null || authLoading) return <p>Đang tải…</p>;
  const { groupId } = resolvedParams;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">{knowledgeGroupLabel(groupId)}</h2>
        <p className="scr-sub">Đăng nhập để xem ghi chú.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings || notes === null) return <p>Đang tải…</p>;

  const groupNotes = notes.filter((n) => n.groupId === groupId);
  const sections = [
    ...CEFR_ORDER.map((level) => ({
      label: level.toUpperCase(),
      notes: groupNotes.filter((n) => n.cefrLevel === level),
    })),
    { label: NO_CEFR_LABEL, notes: groupNotes.filter((n) => n.cefrLevel === null) },
  ].filter((section) => section.notes.length > 0);

  return (
    <div>
      <h2 className="scr-title">{knowledgeGroupLabel(groupId)}</h2>
      {sections.length === 0 && <p className="scr-sub">Chưa có ghi chú nào trong nhóm này.</p>}
      {sections.map((section) => (
        <section key={section.label}>
          <h3>{section.label}</h3>
          <div className="knowledge-card-grid">
            {section.notes.map((note) => (
              <KnowledgeNoteCard key={note.id} note={note} href={`/knowledge/note/${note.id}`} />
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
