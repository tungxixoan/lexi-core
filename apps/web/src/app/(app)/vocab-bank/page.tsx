"use client";

import { useEffect, useMemo, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { deleteVocabRecord, getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { formatDueLabel } from "@/lib/vocabDisplay";
import { SignInButton } from "@/components/SignInButton";
import { VocabDrawer } from "@/components/vocab-bank/VocabDrawer";

type FilterKey = "all" | "due" | `topic:${string}` | `cefr:${string}`;

export default function VocabBankPage() {
  const { user, loading: authLoading } = useAuthUser();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<FilterKey>("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  useEffect(() => {
    setError(null);
    if (!user) {
      setRecords(null);
      return;
    }
    setRecords(null);
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [user]);

  const now = useMemo(() => new Date(), [records]);

  const isDue = (r: VocabRecord) =>
    r.nextReviewAt === null || new Date(r.nextReviewAt).getTime() <= now.getTime();

  const topicChips = useMemo(() => {
    if (!records) return [];
    const idsWithWords = new Set(records.flatMap((r) => r.topicIds));
    return topics.filter((t) => idsWithWords.has(t.id));
  }, [records, topics]);

  const cefrChips = useMemo(() => {
    if (!records) return [];
    return Array.from(new Set(records.map((r) => r.cefrLevel))).sort();
  }, [records]);

  const filtered = useMemo(() => {
    if (!records) return [];
    if (filter === "all") return records;
    if (filter === "due") return records.filter(isDue);
    if (filter.startsWith("topic:")) {
      const topicId = filter.slice("topic:".length);
      return records.filter((r) => r.topicIds.includes(topicId));
    }
    if (filter.startsWith("cefr:")) {
      const level = filter.slice("cefr:".length);
      return records.filter((r) => r.cefrLevel === level);
    }
    return records;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [records, filter, now]);

  const selected = records?.find((r) => r.id === selectedId) ?? null;

  const handleDelete = async (id: string) => {
    if (!user) return;
    if (!window.confirm("Xoá từ này khỏi Ngân hàng từ vựng?")) return;
    setDeleteError(null);
    try {
      await deleteVocabRecord(user.uid, id);
      setRecords((prev) => (prev ? prev.filter((r) => r.id !== id) : prev));
      setSelectedId(null);
    } catch (err: unknown) {
      setDeleteError(err instanceof Error ? err.message : String(err));
    }
  };

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Ngân hàng từ vựng</h2>
        <p className="scr-sub">Đăng nhập để xem từ vựng đã lưu.</p>
        <SignInButton />
      </div>
    );
  }

  if (error) return <p role="alert">Lỗi đọc Firestore: {error}</p>;
  if (records === null) return <p>Đang tải từ vựng…</p>;

  return (
    <>
      <h2 className="scr-title">Ngân hàng từ vựng</h2>
      <p className="scr-sub">{records.length} từ trong Ngân hàng từ vựng.</p>
      {deleteError && <p role="alert">Lỗi xoá từ: {deleteError}</p>}
      <div className="vb-toolbar">
        <button className={`vb-chip${filter === "all" ? " active" : ""}`} onClick={() => setFilter("all")}>
          Tất cả ({records.length})
        </button>
        <button className={`vb-chip${filter === "due" ? " active" : ""}`} onClick={() => setFilter("due")}>
          Cần ôn hôm nay ({records.filter(isDue).length})
        </button>
        {topicChips.map((t) => (
          <button
            key={t.id}
            className={`vb-chip${filter === `topic:${t.id}` ? " active" : ""}`}
            onClick={() => setFilter(`topic:${t.id}`)}
          >
            {t.name}
          </button>
        ))}
        {cefrChips.map((level) => (
          <button
            key={level}
            className={`vb-chip${filter === `cefr:${level}` ? " active" : ""}`}
            onClick={() => setFilter(`cefr:${level}`)}
          >
            {level.toUpperCase()}
          </button>
        ))}
      </div>
      <div className="vb-shell">
        <div className="vb-list-wrap">
          {filtered.length === 0 && <p>Không có từ nào phù hợp.</p>}
          {filtered.map((r) => (
            <div
              key={r.id}
              className={`vrow${r.id === selectedId ? " selected" : ""}`}
              onClick={() => setSelectedId(r.id)}
              role="button"
              tabIndex={0}
            >
              <span className="dot">{r.cefrLevel.toUpperCase()}</span>
              <span className="word">{r.headword}</span>
              <span className="meaning">{r.meaning}</span>
              <span className="due">{formatDueLabel(r.nextReviewAt, now)}</span>
            </div>
          ))}
        </div>
        {selected && (
          <VocabDrawer
            record={selected}
            topics={topics}
            onClose={() => setSelectedId(null)}
            onDelete={() => void handleDelete(selected.id)}
          />
        )}
      </div>
    </>
  );
}
