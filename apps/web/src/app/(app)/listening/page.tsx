"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import type { DictationDifficulty } from "@/lib/dictation";

const MIN_VOCAB_WORDS = 2;

const DIFFICULTY_OPTIONS: { value: DictationDifficulty; label: string }[] = [
  { value: "easy", label: "Dễ" },
  { value: "medium", label: "Trung bình" },
  { value: "hard", label: "Khó" },
];

export default function ListeningHubPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [difficulty, setDifficulty] = useState<DictationDifficulty>("hard");

  useEffect(() => {
    if (!user) return;
    getVocabRecords(user.uid)
      .then(setRecords)
      .catch(() => {});
  }, [user]);

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
          Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.
        </p>
      </div>
    );
  }

  const eligibleCount = records.filter((r) => r.targetLanguage === "english").length;
  const canGenerate = eligibleCount >= MIN_VOCAB_WORDS;

  function buildQuery(action: "generate" | "existing"): string {
    const params = new URLSearchParams();
    params.set("difficulty", difficulty);
    params.set("action", action);
    return params.toString();
  }

  function navigate(action: "generate" | "existing") {
    router.push(`/listening/dictation?${buildQuery(action)}`);
  }

  return (
    <div>
      <h2 className="scr-title">Nghe</h2>
      <p className="scr-sub">AI tạo 1 câu từ Vocab Bank của bạn. Nghe và gõ lại chính xác những gì bạn nghe được.</p>

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

      <div className="reading-setup-actions">
        {canGenerate ? (
          <button type="button" className="btn-primary" onClick={() => navigate("generate")}>
            Tạo bài luyện
          </button>
        ) : (
          <p className="reading-min-words-hint">
            Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ tiếng Anh vào Ngân hàng từ vựng. Hiện có {eligibleCount} từ.
          </p>
        )}
        <button type="button" className="btn-secondary" onClick={() => navigate("existing")}>
          🔀 Lấy bài có sẵn
        </button>
      </div>
    </div>
  );
}
