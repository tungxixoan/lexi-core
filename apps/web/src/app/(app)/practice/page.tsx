"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const WORD_COUNT_OPTIONS = [5, 10, 20, null] as const;

type Phase = "setup" | "session" | "result";

export default function PracticePage() {
  const { user, loading: authLoading } = useAuthUser();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [maxCefr, setMaxCefr] = useState<CefrLevel | null>(null);
  const [wordCount, setWordCount] = useState<number | null>(10);

  const [phase, setPhase] = useState<Phase>("setup");

  useEffect(() => {
    if (!user) return;
    setLoadError(null);
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setLoadError(err instanceof Error ? err.message : String(err)));
  }, [user]);

  function handleStart() {
    if (!records) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: wordCount };
    const words = selectSessionWords(records, filters);
    if (words.length === 0) return;
    setPhase("session");
    // Session-phase state (current word, results-so-far) is wired in Task 11.
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Ôn tập</h2>
        <p className="scr-sub">Đăng nhập để ôn tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (loadError) return <p role="alert">Lỗi: {loadError}</p>;
  if (records === null) return <p>Đang tải từ vựng…</p>;

  if (phase === "setup") {
    const previewWords = selectSessionWords(
      records,
      { topicIds: selectedTopicIds, maxCefr, count: wordCount },
      new Date()
    );

    return (
      <div>
        <h2 className="scr-title">Ôn tập</h2>
        <p className="scr-sub">Chọn bộ lọc rồi bắt đầu phiên ôn tập.</p>
        <div className="practice-filters">
          <TopicFilterPopover
            topics={topics}
            selectedTopicIds={selectedTopicIds}
            onApply={setSelectedTopicIds}
          />
          <select
            value={maxCefr ?? ""}
            onChange={(e) => setMaxCefr((e.target.value || null) as CefrLevel | null)}
          >
            <option value="">Mọi trình độ</option>
            {CEFR_LEVELS.map((level) => (
              <option key={level} value={level}>
                Tối đa {level.toUpperCase()}
              </option>
            ))}
          </select>
          <select
            value={wordCount ?? "all"}
            onChange={(e) => setWordCount(e.target.value === "all" ? null : Number(e.target.value))}
          >
            {WORD_COUNT_OPTIONS.map((count) => (
              <option key={count ?? "all"} value={count ?? "all"}>
                {count === null ? "Tất cả" : `${count} từ`}
              </option>
            ))}
          </select>
        </div>
        <p className="practice-preview-count">{previewWords.length} từ khớp bộ lọc hiện tại.</p>
        <button className="btn-primary" onClick={handleStart} disabled={previewWords.length === 0}>
          Bắt đầu
        </button>
      </div>
    );
  }

  return null; // "session"/"result" phases wired in Tasks 11-12
}
