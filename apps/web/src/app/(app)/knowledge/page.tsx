"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import {
  getKnowledgeNotes,
  restoreStarters,
  seedStartersIfNeeded,
  type KnowledgeNote,
} from "@/lib/knowledgeNotes";
import { startersFor } from "@/lib/knowledgeStarters";
import {
  applyKnowledgeFilter,
  knowledgeAllTags,
  knowledgeGroupCounts,
  type KnowledgeFilter,
} from "@/lib/knowledgeFilters";
import { KnowledgeGroupGrid } from "@/components/knowledge/KnowledgeGroupGrid";
import { KnowledgeNoteCard } from "@/components/knowledge/KnowledgeNoteCard";
import { SignInButton } from "@/components/SignInButton";

const EXAMPLE_PROMPTS = [
  "Thì hiện tại hoàn thành",
  "Câu điều kiện loại 2",
  'Phân biệt "make" và "do"',
];

export default function KnowledgePage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const [notes, setNotes] = useState<KnowledgeNote[] | null>(null);
  const [query, setQuery] = useState("");
  const [selectedTags, setSelectedTags] = useState<Set<string>>(new Set());
  const [composing, setComposing] = useState(false);
  const [restoreMessage, setRestoreMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!user || !settings) return;
    const language = settings.targetLanguage;
    seedStartersIfNeeded(user.uid, language, startersFor(language))
      .then(() => getKnowledgeNotes(user.uid, language))
      .then(setNotes)
      .catch(() => setNotes([]));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Kiến thức</h2>
        <p className="scr-sub">Đăng nhập để xem kiến thức.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings || notes === null) return <p>Đang tải…</p>;

  const language = settings.targetLanguage;
  const showRestore = language === "english";

  const toggleTag = (tag: string) => {
    setSelectedTags((prev) => {
      const next = new Set(prev);
      if (next.has(tag)) next.delete(tag);
      else next.add(tag);
      return next;
    });
  };

  const handleRestore = async () => {
    await restoreStarters(user.uid, language, startersFor(language));
    const refreshed = await getKnowledgeNotes(user.uid, language);
    setNotes(refreshed);
    setRestoreMessage("Đã khôi phục ghi chú mẫu.");
  };

  const filter: KnowledgeFilter = {
    query,
    groupIds: new Set(),
    levels: new Set(),
    tags: selectedTags,
  };
  const listMode = query.trim() !== "" || selectedTags.size > 0;
  const counts = knowledgeGroupCounts(notes);
  const allTags = knowledgeAllTags(notes);
  const filtered = listMode ? applyKnowledgeFilter(notes, filter) : [];

  return (
    <div>
      <div className="knowledge-header-row">
        <h2 className="scr-title">Kiến thức</h2>
        {showRestore && (
          <button type="button" className="link-btn" onClick={() => void handleRestore()}>
            Khôi phục ghi chú mẫu
          </button>
        )}
      </div>
      {restoreMessage && <p className="scr-sub">{restoreMessage}</p>}

      {notes.length === 0 ? (
        <>
          <div className="knowledge-empty">
            <p>Chưa có ghi chú nào.</p>
            <p className="scr-sub">Thử nhờ AI soạn một ghi chú, ví dụ:</p>
            <ul>
              {EXAMPLE_PROMPTS.map((prompt) => (
                <li key={prompt}>{prompt}</li>
              ))}
            </ul>
            <button type="button" className="btn-primary" onClick={() => setComposing(true)}>
              Nhờ AI soạn
            </button>
          </div>
          <Link href="/knowledge/new" className="knowledge-write-link">
            + Tự viết
          </Link>
        </>
      ) : (
        <>
          <div className="vb-search">
            <input
              type="text"
              aria-label="Tìm kiến thức"
              placeholder="Tìm kiến thức…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
          </div>
          {allTags.length > 0 && (
            <div className="vb-toolbar">
              {allTags.map((tag) => (
                <button
                  key={tag}
                  type="button"
                  className={`vb-chip${selectedTags.has(tag) ? " active" : ""}`}
                  onClick={() => toggleTag(tag)}
                >
                  {tag}
                </button>
              ))}
            </div>
          )}

          {listMode ? (
            filtered.length === 0 ? (
              <p className="scr-sub">Không có ghi chú nào khớp.</p>
            ) : (
              <div className="knowledge-card-grid">
                {filtered.map((note) => (
                  <KnowledgeNoteCard key={note.id} note={note} href={`/knowledge/note/${note.id}`} />
                ))}
              </div>
            )
          ) : (
            <KnowledgeGroupGrid language={language} counts={counts} />
          )}

          <div className="knowledge-bottom-actions">
            <button type="button" className="btn-primary" onClick={() => setComposing(true)}>
              + Nhờ AI soạn
            </button>
            <Link href="/knowledge/new" className="btn-secondary">
              + Tự viết
            </Link>
          </div>
        </>
      )}

      {composing && null /* TODO(Task 13): render <AiComposeModal .../> here */}
    </div>
  );
}
