"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { useRouteParams } from "@/lib/useRouteParams";
import { getKnowledgeNotes, upsertKnowledgeNote, type KnowledgeNote } from "@/lib/knowledgeNotes";
import { EditKnowledgeNoteModal } from "@/components/knowledge/EditKnowledgeNoteModal";
import { SignInButton } from "@/components/SignInButton";

export default function KnowledgeNoteEditPage({ params }: { params: Promise<{ id: string }> }) {
  const resolvedParams = useRouteParams(params);
  const router = useRouter();
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const [notes, setNotes] = useState<KnowledgeNote[] | null>(null);

  useEffect(() => {
    if (!user || !settings) return;
    getKnowledgeNotes(user.uid, settings.targetLanguage).then(setNotes);
  }, [user, settings]);

  if (resolvedParams === null || authLoading) return <p>Đang tải…</p>;
  const { id } = resolvedParams;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Kiến thức</h2>
        <p className="scr-sub">Đăng nhập để sửa ghi chú.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings || notes === null) return <p>Đang tải…</p>;

  const note = notes.find((n) => n.id === id);
  if (!note) return <p>Không tìm thấy ghi chú</p>;

  const handleSave = async (updated: KnowledgeNote) => {
    await upsertKnowledgeNote(user.uid, updated);
    router.push(`/knowledge/note/${updated.id}`);
  };

  return (
    <EditKnowledgeNoteModal
      initial={note}
      targetLanguage={settings.targetLanguage}
      existingNotes={notes}
      onClose={() => router.push(`/knowledge/note/${id}`)}
      onSave={handleSave}
    />
  );
}
