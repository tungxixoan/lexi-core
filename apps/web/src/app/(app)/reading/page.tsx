"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import { ECONOMY_VOLUMES, VOLUME_LABELS, type EconomyVolume } from "@/lib/toeicFilters";

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const WORD_COUNT_OPTIONS = [5, 10, 20, null] as const;
const DEFAULT_WORD_COUNT = 10;
const MIN_VOCAB_WORDS = 5;

const CEFR_DROPDOWN_OPTIONS: SimpleDropdownOption<string>[] = [
  { value: "", label: "Mọi trình độ" },
  ...CEFR_LEVELS.map((level) => ({ value: level as string, label: `Tối đa ${level.toUpperCase()}` })),
];

const WORD_COUNT_DROPDOWN_OPTIONS: SimpleDropdownOption<string>[] = WORD_COUNT_OPTIONS.map((count) => ({
  value: count === null ? "all" : String(count),
  label: count === null ? "Tất cả" : `${count} từ`,
}));

type Mode = "bilingual" | "part5" | "part6" | "part7";

export default function ReadingHubPage() {
  const { user, loading: authLoading } = useAuthUser();
  const router = useRouter();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [mode, setMode] = useState<Mode | null>(null);
  const [maxCefr, setMaxCefr] = useState<CefrLevel | null>(null);
  const [wordCount, setWordCount] = useState<number | null>(DEFAULT_WORD_COUNT);
  const [selectedVolumes, setSelectedVolumes] = useState<Set<EconomyVolume>>(new Set());

  useEffect(() => {
    if (!user) return;
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {});
  }, [user]);

  function toggleVolume(v: EconomyVolume) {
    setSelectedVolumes((prev) => {
      const next = new Set(prev);
      if (next.has(v)) next.delete(v);
      else next.add(v);
      return next;
    });
  }

  function buildQuery(action: "generate" | "existing"): string {
    const params = new URLSearchParams();
    if (selectedTopicIds.size > 0) params.set("topicIds", [...selectedTopicIds].join(","));
    if (mode === "bilingual") {
      if (maxCefr) params.set("maxCefr", maxCefr);
      params.set("wordCount", wordCount === null ? "all" : String(wordCount));
    } else if (mode === "part5" || mode === "part6" || mode === "part7") {
      if (selectedVolumes.size > 0) params.set("volumes", [...selectedVolumes].join(","));
    }
    params.set("action", action);
    return params.toString();
  }

  function navigate(action: "generate" | "existing") {
    if (!mode) return;
    const path =
      mode === "bilingual"
        ? "/reading/bilingual"
        : mode === "part5"
          ? "/reading/part5"
          : mode === "part6"
            ? "/reading/part6"
            : "/reading/part7";
    router.push(`${path}?${buildQuery(action)}`);
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Đọc</h2>
        <p className="scr-sub">Đăng nhập để luyện đọc.</p>
        <SignInButton />
      </div>
    );
  }

  const matchingCount = selectSessionWords(records, {
    topicIds: selectedTopicIds,
    maxCefr,
    count: null,
  } satisfies SessionWordFilters).length;
  const canGenerateBilingual = matchingCount >= MIN_VOCAB_WORDS;

  return (
    <div>
      <h2 className="scr-title">Đọc</h2>
      <p className="scr-sub">Chọn chủ đề, chọn chế độ luyện, rồi tạo bài hoặc lấy bài có sẵn.</p>

      <TopicFilterPopover topics={topics} selectedTopicIds={selectedTopicIds} onApply={setSelectedTopicIds} />

      <div className="reading-hub-cards">
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "bilingual" ? " active" : ""}`}
          onClick={() => setMode("bilingual")}
        >
          <span className="reading-hub-card-title">✍️ Đọc &amp; gõ</span>
          <span className="reading-hub-card-desc">
            Gõ lại đoạn văn song ngữ được tạo từ từ vựng của bạn.
          </span>
        </button>
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "part5" ? " active" : ""}`}
          onClick={() => setMode("part5")}
        >
          <span className="reading-hub-card-title">📝 Part 5 — Điền câu</span>
          <span className="reading-hub-card-desc">
            15 câu điền từ/ngữ pháp kiểu TOEIC, AI tạo theo chủ đề và độ khó bạn chọn.
          </span>
        </button>
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "part6" ? " active" : ""}`}
          onClick={() => setMode("part6")}
        >
          <span className="reading-hub-card-title">📄 Part 6 — Điền đoạn văn</span>
          <span className="reading-hub-card-desc">
            3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống kiểu TOEIC.
          </span>
        </button>
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "part7" ? " active" : ""}`}
          onClick={() => setMode("part7")}
        >
          <span className="reading-hub-card-title">📖 Part 7 — Đọc hiểu</span>
          <span className="reading-hub-card-desc">
            3 nhóm văn bản, 9-13 câu hỏi đọc hiểu kiểu TOEIC.
          </span>
        </button>
        <button
          type="button"
          className="reading-hub-card"
          onClick={() => router.push("/reading/word-radar")}
        >
          <span className="reading-hub-card-title">🔎 Quét từ vựng</span>
          <span className="reading-hub-card-desc">
            Dán văn bản bất kỳ, tự nhận từ đã học và gợi ý từ mới.
          </span>
        </button>
      </div>

      {mode === "bilingual" && (
        <div className="practice-filters">
          <SimpleDropdown
            triggerLabel={maxCefr ? `Tối đa ${maxCefr.toUpperCase()}` : "Mọi trình độ"}
            ariaLabel="Chọn trình độ tối đa"
            options={CEFR_DROPDOWN_OPTIONS}
            value={maxCefr ?? ""}
            onChange={(v) => setMaxCefr((v || null) as CefrLevel | null)}
            active={maxCefr !== null}
          />
          <SimpleDropdown
            triggerLabel={wordCount === null ? "Tất cả" : `${wordCount} từ`}
            ariaLabel="Chọn số từ"
            options={WORD_COUNT_DROPDOWN_OPTIONS}
            value={wordCount === null ? "all" : String(wordCount)}
            onChange={(v) => setWordCount(v === "all" ? null : Number(v))}
            active={wordCount !== DEFAULT_WORD_COUNT}
          />
        </div>
      )}

      {mode !== "bilingual" && mode !== null && (
        <div className="practice-filters">
          {ECONOMY_VOLUMES.map((v) => (
            <button
              key={v}
              type="button"
              className={`vb-chip${selectedVolumes.has(v) ? " active" : ""}`}
              onClick={() => toggleVolume(v)}
            >
              {VOLUME_LABELS[v]}
            </button>
          ))}
        </div>
      )}

      {mode && (
        <div className="reading-setup-actions">
          {mode !== "bilingual" || canGenerateBilingual ? (
            <button type="button" className="btn-primary" onClick={() => navigate("generate")}>
              Tạo bài luyện
            </button>
          ) : (
            <p className="reading-min-words-hint">
              Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có{" "}
              {matchingCount} từ.
            </p>
          )}
          <button type="button" className="btn-secondary" onClick={() => navigate("existing")}>
            🔀 Lấy bài có sẵn
          </button>
        </div>
      )}
    </div>
  );
}
