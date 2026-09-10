"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getKnowledgeNotes, upsertKnowledgeNote, type KnowledgeNote } from "@/lib/knowledgeNotes";
import { EditKnowledgeNoteModal } from "@/components/knowledge/EditKnowledgeNoteModal";
import { SignInButton } from "@/components/SignInButton";

export default function KnowledgeNewPage() {
  const router = useRouter();
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const [notes, setNotes] = useState<KnowledgeNote[] | null>(null);

  useEffect(() => {
    if (!user || !settings) return;
    getKnowledgeNotes(user.uid, settings.targetLanguage).then(setNotes);
  }, [user, settings]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Kiến thức</h2>
        <p className="scr-sub">Đăng nhập để tạo ghi chú.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings || notes === null) return <p>Đang tải…</p>;

  return (
    <EditKnowledgeNoteModal
      targetLanguage={settings.targetLanguage}
      existingNotes={notes}
      onSave={async (note) => {
        await upsertKnowledgeNote(user.uid, note);
        router.push(`/knowledge/note/${note.id}`);
      }}
      onClose={() => router.push("/knowledge")}
    />
  );
}
