"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import type { DictationDifficulty } from "@/lib/dictation";
import { APP_CONTEXTS, APP_CONTEXT_LABELS, APP_CONTEXT_EMOJI, type AppContext } from "@/lib/appContext";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";

const MIN_VOCAB_WORDS = 2;

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];

const DIFFICULTY_OPTIONS: { value: DictationDifficulty; label: string }[] = [
  { value: "easy", label: "Dễ" },
  { value: "medium", label: "Trung bình" },
  { value: "hard", label: "Khó" },
];

const CEFR_DROPDOWN_OPTIONS: SimpleDropdownOption<string>[] = [
  { value: "", label: "Tất cả" },
  ...CEFR_LEVELS.map((level) => ({ value: level as string, label: level.toUpperCase() })),
];

type Mode = "dictation" | "comprehension";

export default function ListeningHubPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [mode, setMode] = useState<Mode | null>(null);
  const [difficulty, setDifficulty] = useState<DictationDifficulty>("hard");
  const [context, setContext] = useState<AppContext>("general");
  const [level, setLevel] = useState<CefrLevel | null>(null);

  useEffect(() => {
    if (!user || !settings) return;
    getVocabRecords(user.uid, settings.targetLanguage)
      .then(setRecords)
      .catch(() => {});
  }, [user, settings]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Nghe</h2>
        <p className="scr-sub">Đăng nhập để luyện nghe.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (settings.targetLanguage !== "english") {
    return (
      <div>
        <h2 className="scr-title">Nghe</h2>
        <p className="reading-min-words-hint">
          Nghe hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.
        </p>
      </div>
    );
  }

  const eligibleCount = records.filter((r) => r.targetLanguage === "english").length;
  const canGenerateDictation = eligibleCount >= MIN_VOCAB_WORDS;

  function buildQuery(action: "generate" | "existing"): string {
    const params = new URLSearchParams();
    if (mode === "dictation") {
      params.set("difficulty", difficulty);
    } else if (mode === "comprehension") {
      params.set("context", context);
      if (level) params.set("level", level);
    }
    params.set("action", action);
    return params.toString();
  }

  function navigate(action: "generate" | "existing") {
    if (!mode) return;
    const path = mode === "dictation" ? "/listening/dictation" : "/listening/comprehension";
    router.push(`${path}?${buildQuery(action)}`);
  }

  return (
    <div>
      <h2 className="scr-title">Nghe</h2>
      <p className="scr-sub">Chọn chế độ luyện nghe.</p>

      <div className="reading-hub-cards">
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "dictation" ? " active" : ""}`}
          onClick={() => setMode("dictation")}
        >
          <span className="reading-hub-card-title">🎤 Nghe chép</span>
          <span className="reading-hub-card-desc">AI tạo 1 câu từ Vocab Bank của bạn. Nghe và gõ lại chính xác.</span>
        </button>
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "comprehension" ? " active" : ""}`}
          onClick={() => setMode("comprehension")}
        >
          <span className="reading-hub-card-title">🎧 Nghe hiểu</span>
          <span className="reading-hub-card-desc">
            AI tạo một đoạn hội thoại hoặc bài nói ngắn. Nghe và trả lời 3 câu hỏi trắc nghiệm — giống phần nghe TOEIC.
          </span>
        </button>
      </div>

      {mode === "dictation" && (
        <div className="practice-filters">
          {DIFFICULTY_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              type="button"
              className={`vb-chip${difficulty === opt.value ? " active" : ""}`}
              onClick={() => setDifficulty(opt.value)}
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}

      {mode === "comprehension" && (
        <div className="practice-filters">
          {APP_CONTEXTS.map((ctx) => (
            <button
              key={ctx}
              type="button"
              className={`vb-chip${context === ctx ? " active" : ""}`}
              onClick={() => setContext(ctx)}
            >
              {APP_CONTEXT_EMOJI[ctx]} {APP_CONTEXT_LABELS[ctx]}
            </button>
          ))}
          <SimpleDropdown
            triggerLabel={level ? level.toUpperCase() : "Tất cả"}
            ariaLabel="Chọn cấp độ"
            options={CEFR_DROPDOWN_OPTIONS}
            value={level ?? ""}
            onChange={(v) => setLevel((v || null) as CefrLevel | null)}
            active={level !== null}
          />
        </div>
      )}

      {mode && (
        <div className="reading-setup-actions">
          {mode === "dictation" && !canGenerateDictation ? (
            <p className="reading-min-words-hint">
              Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ tiếng Anh vào Ngân hàng từ vựng. Hiện có {eligibleCount} từ.
            </p>
          ) : (
            <button type="button" className="btn-primary" onClick={() => navigate("generate")}>
              Tạo bài luyện
            </button>
          )}
          <button type="button" className="btn-secondary" onClick={() => navigate("existing")}>
            🔀 Lấy bài có sẵn
          </button>
        </div>
      )}
    </div>
  );
}
