"use client";

import { useEffect, useMemo, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import {
  deleteVocabRecord,
  getVocabRecords,
  updateVocabRecord,
  type VocabRecord,
  type VocabRecordUpdate,
} from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { formatDueLabel } from "@/lib/vocabDisplay";
import { isFilterActive, matchesFilters, type VocabFilterState } from "@/lib/vocabFilters";
import { usePaginatedScroll } from "@/lib/usePaginatedScroll";
import { getPageWindow } from "@/lib/pageWindow";
import { SignInButton } from "@/components/SignInButton";
import { VocabDrawer } from "@/components/vocab-bank/VocabDrawer";
import { EditVocabModal } from "@/components/vocab-bank/EditVocabModal";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";

export default function VocabBankPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings } = useSettingsContext();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [dueOnly, setDueOnly] = useState(false);
  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [selectedCefrLevels, setSelectedCefrLevels] = useState<Set<string>>(new Set());
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);

  useEffect(() => {
    setError(null);
    if (!user || !settings) {
      setRecords(null);
      return;
    }
    setRecords(null);
    Promise.all([getVocabRecords(user.uid, settings.targetLanguage), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [user, settings]);

  const now = useMemo(() => new Date(), [records]);

  const isDue = (r: VocabRecord) =>
    r.nextReviewAt === null || new Date(r.nextReviewAt).getTime() <= now.getTime();

  const cefrChips = useMemo(() => {
    if (!records) return [];
    return Array.from(new Set(records.map((r) => r.cefrLevel))).sort();
  }, [records]);

  const filters: VocabFilterState = { dueOnly, topicIds: selectedTopicIds, cefrLevels: selectedCefrLevels };
  const filterActive = isFilterActive(filters) || query.trim() !== "";

  const filtered = useMemo(() => {
    if (!records) return [];
    const q = query.trim().toLowerCase();
    return records.filter(
      (r) =>
        matchesFilters(r, filters, isDue) &&
        (q === "" ||
          r.headword.toLowerCase().includes(q) ||
          r.meaning.toLowerCase().includes(q))
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [records, query, dueOnly, selectedTopicIds, selectedCefrLevels, now]);

  const filterSignature = `${dueOnly}|${Array.from(selectedTopicIds).sort().join(",")}|${Array.from(
    selectedCefrLevels
  ).sort().join(",")}|${query.trim()}`;

  const { visibleItems, totalPages, currentPage, containerRef, sentinelRef, jumpToPage } =
    usePaginatedScroll(filtered, filterSignature);

  const toggleCefr = (level: string) => {
    setSelectedCefrLevels((prev) => {
      const next = new Set(prev);
      if (next.has(level)) next.delete(level);
      else next.add(level);
      return next;
    });
  };

  const clearFilters = () => {
    setQuery("");
    setDueOnly(false);
    setSelectedTopicIds(new Set());
    setSelectedCefrLevels(new Set());
  };

  const selected = records?.find((r) => r.id === selectedId) ?? null;

  const handleDelete = async (id: string) => {
    if (!user) return;
    const record = records?.find((r) => r.id === id);
    if (!record) return;
    if (!window.confirm("Xoá từ này khỏi Ngân hàng từ vựng?")) return;
    setDeleteError(null);
    try {
      await deleteVocabRecord(user.uid, id, record.targetLanguage);
      setRecords((prev) => (prev ? prev.filter((r) => r.id !== id) : prev));
      setSelectedId(null);
    } catch (err: unknown) {
      setDeleteError(err instanceof Error ? err.message : String(err));
    }
  };

  const handleUpdate = async (updates: VocabRecordUpdate) => {
    if (!user || !selected) return;
    await updateVocabRecord(user.uid, selected.id, updates, selected.targetLanguage);
    setRecords((prev) =>
      prev ? prev.map((r) => (r.id === selected.id ? { ...r, ...updates } : r)) : prev
    );
    setEditing(false);
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
      <div className="vb-search">
        <input
          type="text"
          aria-label="Tìm từ"
          placeholder="Tìm theo từ hoặc nghĩa…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        {query !== "" && (
          <button
            type="button"
            className="vb-search-clear"
            aria-label="Xoá tìm kiếm"
            onClick={() => setQuery("")}
          >
            ✕
          </button>
        )}
      </div>
      <div className="vb-toolbar">
        <button className={`vb-chip${!filterActive ? " active" : ""}`} onClick={clearFilters}>
          Tất cả ({records.length})
        </button>
        <button className={`vb-chip${dueOnly ? " active" : ""}`} onClick={() => setDueOnly((v) => !v)}>
          Cần ôn hôm nay ({records.filter(isDue).length})
        </button>
        <TopicFilterPopover topics={topics} selectedTopicIds={selectedTopicIds} onApply={setSelectedTopicIds} />
        {cefrChips.map((level) => (
          <button
            key={level}
            className={`vb-chip${selectedCefrLevels.has(level) ? " active" : ""}`}
            onClick={() => toggleCefr(level)}
          >
            {level.toUpperCase()}
          </button>
        ))}
        {filterActive && (
          <button className="vb-chip vb-chip-clear" onClick={clearFilters}>
            ✕ Xoá lọc
          </button>
        )}
      </div>
      <div className="vb-shell">
        <div className="vb-list-wrap" ref={containerRef}>
          {filtered.length === 0 && <p>Không có từ nào phù hợp.</p>}
          {visibleItems.map((r) => (
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
          <div ref={sentinelRef} style={{ height: 1 }} />
        </div>
        {selected && (
          <VocabDrawer
            record={selected}
            topics={topics}
            onClose={() => setSelectedId(null)}
            onDelete={() => void handleDelete(selected.id)}
            onEdit={() => setEditing(true)}
          />
        )}
      </div>
      {editing && selected && (
        <EditVocabModal
          record={selected}
          topics={topics}
          onClose={() => setEditing(false)}
          onSave={handleUpdate}
        />
      )}
      {totalPages > 1 && (
        <div className="vb-pagination">
          {getPageWindow(currentPage, totalPages).map((page, i) =>
            page === "…" ? (
              <span className="vb-page-ellipsis" key={`ellipsis-${i}`}>
                …
              </span>
            ) : (
              <button
                key={page}
                className={`vb-page-btn${page === currentPage ? " active" : ""}`}
                onClick={() => jumpToPage(page)}
              >
                {page}
              </button>
            )
          )}
        </div>
      )}
    </>
  );
}
