"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { useRouteParams } from "@/lib/useRouteParams";
import { deleteKnowledgeNote, getKnowledgeNotes, type KnowledgeNote } from "@/lib/knowledgeNotes";
import { getVocabRecords } from "@/lib/vocabRecords";
import { KnowledgeNoteView } from "@/components/knowledge/KnowledgeNoteView";
import { SignInButton } from "@/components/SignInButton";

export default function KnowledgeNoteDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const resolvedParams = useRouteParams(params);
  const router = useRouter();
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const [notes, setNotes] = useState<KnowledgeNote[] | null>(null);
  const [knownHeadwords, setKnownHeadwords] = useState<string[]>([]);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  useEffect(() => {
    if (!user || !settings) return;
    Promise.all([
      getKnowledgeNotes(user.uid, settings.targetLanguage),
      getVocabRecords(user.uid, settings.targetLanguage).catch(() => []),
    ]).then(([n, records]) => {
      setNotes(n);
      setKnownHeadwords(records.map((r) => r.headword));
    });
  }, [user, settings]);

  if (resolvedParams === null || authLoading) return <p>Đang tải…</p>;
  const { id } = resolvedParams;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Kiến thức</h2>
        <p className="scr-sub">Đăng nhập để xem ghi chú.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings || notes === null) return <p>Đang tải…</p>;

  const note = notes.find((n) => n.id === id);
  if (!note) return <p>Không tìm thấy ghi chú</p>;

  const handleDelete = async () => {
    setDeleteError(null);
    try {
      await deleteKnowledgeNote(user.uid, id);
      router.push("/knowledge");
    } catch (err: unknown) {
      setDeleteError(err instanceof Error ? err.message : String(err));
    }
  };

  return (
    <div>
      {deleteError && <p role="alert">Lỗi xoá ghi chú: {deleteError}</p>}
      <KnowledgeNoteView note={note} knownHeadwords={knownHeadwords} onDelete={() => void handleDelete()} />
    </div>
  );
}
