"use client";

import { useEffect, useRef, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, updateVocabRecordSm2, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import { FlashcardCard } from "@/components/practice/FlashcardCard";
import { computeSm2, type Sm2Fields } from "@/lib/sm2";

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const WORD_COUNT_OPTIONS = [5, 10, 20, null] as const;

type Phase = "setup" | "session" | "result";

export interface SessionGradeResult {
  vocabRecordId: string;
  quality: 1 | 5;
}

export default function PracticePage() {
  const { user, loading: authLoading } = useAuthUser();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [maxCefr, setMaxCefr] = useState<CefrLevel | null>(null);
  const [wordCount, setWordCount] = useState<number | null>(10);

  const [phase, setPhase] = useState<Phase>("setup");
  const [sessionWords, setSessionWords] = useState<VocabRecord[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [sessionResults, setSessionResults] = useState<SessionGradeResult[]>([]);
  const sm2WrittenRef = useRef(false);

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

  useEffect(() => {
    if (phase !== "result" || sm2WrittenRef.current || !user) return;
    sm2WrittenRef.current = true;
    const now = new Date();
    const updatedFieldsById = new Map<string, Sm2Fields>();
    for (const result of sessionResults) {
      const record = sessionWords.find((w) => w.id === result.vocabRecordId);
      if (!record) continue;
      const fields = computeSm2(record, result.quality, now);
      updatedFieldsById.set(result.vocabRecordId, fields);
      updateVocabRecordSm2(user.uid, result.vocabRecordId, fields).catch((err: unknown) => {
        console.error("Failed to save SM-2 result", err);
      });
    }
    // Merge the just-written SM-2 fields into local state so a second
    // "Ôn tập lại" session (still within this page load) selects from
    // up-to-date nextReviewAt/repetitions instead of the pre-session
    // snapshot — otherwise a just-reviewed word would still look due and
    // computeSm2 would run from its stale base on a repeat grade.
    setRecords((prev) =>
      prev
        ? prev.map((r) => {
            const updated = updatedFieldsById.get(r.id);
            return updated ? { ...r, ...updated } : r;
          })
        : prev
    );
  }, [phase, sessionResults, sessionWords, user]);

  function handleStart() {
    if (!records) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: wordCount };
    const words = selectSessionWords(records, filters);
    if (words.length === 0) return;
    setSessionWords(words);
    setCurrentIndex(0);
    setSessionResults([]);
    sm2WrittenRef.current = false;
    setPhase("session");
  }

  function handleGrade(quality: 1 | 5) {
    const current = sessionWords[currentIndex];
    const nextResults = [...sessionResults, { vocabRecordId: current.id, quality }];
    setSessionResults(nextResults);

    if (currentIndex + 1 < sessionWords.length) {
      setCurrentIndex(currentIndex + 1);
    } else {
      setPhase("result");
      // The batch SM-2 update runs in the useEffect above once phase becomes "result".
    }
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

  if (phase === "session") {
    const progressPct = Math.round(((currentIndex + 1) / sessionWords.length) * 100);
    return (
      <div>
        <div className="practice-progress-row">
          <span>
            Từ {currentIndex + 1} / {sessionWords.length}
          </span>
          <span>Ôn tập</span>
        </div>
        <div className="practice-progress-track">
          <div className="practice-progress-fill" style={{ width: `${progressPct}%` }} />
        </div>
        <FlashcardCard record={sessionWords[currentIndex]} onGrade={handleGrade} />
      </div>
    );
  }

  const correctCount = sessionResults.filter((r) => r.quality === 5).length;
  const totalCount = sessionResults.length;
  const percent = totalCount === 0 ? 0 : Math.round((correctCount / totalCount) * 100);

  return (
    <div>
      <h2 className="scr-title">Kết quả ôn tập</h2>
      <div className="practice-result-circle" style={{ ["--pct" as unknown as string]: `${percent}%` }}>
        <span>{percent}%</span>
      </div>
      <p className="practice-result-sub">
        Đúng {correctCount} / {totalCount} từ
      </p>
      <ul className="practice-result-list">
        {sessionResults.map((result) => {
          const record = sessionWords.find((w) => w.id === result.vocabRecordId);
          if (!record) return null;
          return (
            <li
              key={result.vocabRecordId}
              className={result.quality === 5 ? "practice-result-item-ok" : "practice-result-item-no"}
            >
              <span>{result.quality === 5 ? "✔" : "✘"}</span>
              <span className="practice-result-headword">{record.headword}</span>
              <span className="practice-result-meaning">{record.meaning}</span>
            </li>
          );
        })}
      </ul>
      <button className="btn-primary" onClick={() => setPhase("setup")}>
        Ôn tập lại
      </button>
    </div>
  );
}
