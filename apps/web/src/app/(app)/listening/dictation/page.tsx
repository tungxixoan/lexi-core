"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, updateVocabRecordSm2, type VocabRecord } from "@/lib/vocabRecords";
import { computeSm2, type Sm2Fields } from "@/lib/sm2";
import { recordDailyActivity } from "@/lib/dailyActivity";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import {
  buildDictationPrompt,
  parseDictationItem,
  selectDictationBlanks,
  prioritizeDueWords,
  targetWords,
  computeDictationScore,
  sm2QualityFromScore,
  type DictationItem,
  type DictationDifficulty,
  type BlankSpan,
} from "@/lib/dictation";
import { saveListeningExercise, getRandomSavedListeningExercise } from "@/lib/savedListeningExercises";
import { useDictationAudio } from "@/lib/useDictationAudio";
import { ClozeInput } from "@/components/listening/ClozeInput";
import { ClozeResult } from "@/components/listening/ClozeResult";
import { DiffText } from "@/components/listening/DiffText";

type Phase = "loading" | "session" | "result";
const MIN_VOCAB_WORDS = 2;
const MIN_SPEED = 0.5;
const MAX_SPEED = 2;
const SPEED_STEP = 0.05;

function isDifficulty(value: string | null): value is DictationDifficulty {
  return value === "easy" || value === "medium" || value === "hard";
}

function formatDuration(ms: number): string {
  const totalSeconds = Math.round(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;
}

function DictationPageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
  const searchParams = useSearchParams();

  const difficultyParam = searchParams.get("difficulty");
  const difficulty: DictationDifficulty = isDifficulty(difficultyParam) ? difficultyParam : "hard";
  const action = searchParams.get("action");

  const [records, setRecords] = useState<VocabRecord[] | null>(null);

  const [phase, setPhase] = useState<Phase>("loading");
  const [generating, setGenerating] = useState(false);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [item, setItem] = useState<DictationItem | null>(null);
  const [blanks, setBlanks] = useState<BlankSpan[]>([]);
  const [typed, setTyped] = useState("");
  const [blankAnswers, setBlankAnswers] = useState<string[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [sessionStartedAt, setSessionStartedAt] = useState(0);
  const [durationMs, setDurationMs] = useState(0);
  const [finalScore, setFinalScore] = useState(0);
  const [seekPreviewIndex, setSeekPreviewIndex] = useState(0);

  // Identifies the current session independently of the sentence text — a
  // reused saved exercise (only one saved item, so "Câu khác" re-picks the
  // identical document) keeps item.target byte-identical across sessions,
  // so useDictationAudio's reset must not rely on the sentence alone.
  const sessionKeyRef = useRef(0);
  const isDraggingSeekRef = useRef(false);

  const audio = useDictationAudio(item?.target ?? "", sessionKeyRef.current);

  useEffect(() => {
    if (!isDraggingSeekRef.current) {
      setSeekPreviewIndex(audio.estimatedWordIndex);
    }
  }, [audio.estimatedWordIndex]);

  useEffect(() => {
    if (!user || !settings) return;
    getVocabRecords(user.uid, settings.targetLanguage)
      .then(setRecords)
      .catch(() => setRecords([]));
  }, [user, settings]);

  function startSession(newItem: DictationItem, mode: "generated" | "reused") {
    const computedBlanks = selectDictationBlanks(newItem.target, difficulty);
    sessionKeyRef.current += 1;
    isDraggingSeekRef.current = false;
    setSessionMode(mode);
    setJustSavedId(null);
    setSaveError(null);
    setItem(newItem);
    setBlanks(computedBlanks);
    setTyped("");
    setBlankAnswers(new Array(computedBlanks.length).fill(""));
    setSessionStartedAt(Date.now());
    setSeekPreviewIndex(0);
    setPhase("session");
  }

  async function handleGenerate() {
    if (!user || !settings || records === null) return;
    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }
    const eligible = records.filter((r) => r.targetLanguage === "english");
    const words = prioritizeDueWords(eligible).slice(0, MIN_VOCAB_WORDS);
    if (words.length < MIN_VOCAB_WORDS) {
      setGenerateError(`Hãy lưu ít nhất ${MIN_VOCAB_WORDS} từ tiếng Anh vào Ngân hàng từ vựng. Hiện có ${eligible.length} từ.`);
      return;
    }
    setGenerating(true);
    setGenerateError(null);
    try {
      const wordMap: Record<string, string> = {};
      for (const w of words) wordMap[w.headword] = w.id;
      const prompt = buildDictationPrompt(words.map((w) => w.headword), "english");
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parseDictationItem(json, wordMap);
      if (generated.target.length === 0) {
        throw new Error("AI không trả về câu luyện hợp lệ.");
      }
      startSession(generated, "generated");
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
    } finally {
      setGenerating(false);
      setSavedNotice(null);
    }
  }

  async function fetchSavedExercise(excludeId?: string): Promise<boolean> {
    if (!user || !settings) return false;
    setGenerateError(null);
    setSavedNotice(null);
    setFetchingSaved(true);
    let found = false;
    try {
      const saved = await getRandomSavedListeningExercise(user.uid, "english", "dictation", { difficulty }, excludeId);
      if (saved) {
        found = true;
        startSession(saved.item, "reused");
      } else {
        setSavedNotice("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…");
      }
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
      return true;
    } finally {
      setFetchingSaved(false);
    }
    if (!found) {
      await handleGenerate();
      return true;
    }
    return found;
  }

  async function runAction() {
    if (action === "generate") {
      await handleGenerate();
    } else if (action === "existing") {
      await fetchSavedExercise();
    }
  }

  const triggeredRef = useRef(false);
  useEffect(() => {
    if (!user || !settings || records === null) return;
    if (settings.targetLanguage !== "english") return;
    if (action !== "generate" && action !== "existing") {
      router.replace("/listening");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, records, action]);

  async function handleSubmit() {
    if (!item) return;
    const duration = Date.now() - sessionStartedAt;
    const score = computeDictationScore({
      difficulty,
      target: item.target,
      typed,
      blanks,
      blankAnswers,
      replayCount: audio.replayCount,
      seekPenaltyTotal: audio.seekPenaltyTotal,
    });
    setDurationMs(duration);
    setFinalScore(score);
    setPhase("result");

    if (!user) return;
    recordDailyActivity(user.uid, item.vocabIds.length).catch((err: unknown) => {
      console.error("Failed to record daily activity", err);
    });
    const quality = sm2QualityFromScore(score);
    const updatedFieldsById = new Map<string, Sm2Fields>();
    for (const vocabId of item.vocabIds) {
      try {
        const record = (records ?? []).find((r) => r.id === vocabId);
        if (!record) continue;
        const fields = computeSm2(record, quality);
        await updateVocabRecordSm2(user.uid, vocabId, fields, record.targetLanguage);
        updatedFieldsById.set(vocabId, fields);
      } catch {
        // best-effort — one record's failure shouldn't block the others
      }
    }
    // Merge the just-written SM-2 fields into local state so a "Câu khác"
    // session started later in this same page visit prioritizes from
    // up-to-date nextReviewAt/repetitions instead of the pre-session
    // snapshot fetched on mount — mirrors practice/page.tsx's handling of
    // the same problem for its own SM-2 writes.
    setRecords((prev) =>
      prev
        ? prev.map((r) => {
            const updated = updatedFieldsById.get(r.id);
            return updated ? { ...r, ...updated } : r;
          })
        : prev
    );
  }

  async function handleSaveExercise() {
    if (saving || !user || !item) return;
    setSaving(true);
    setSaveError(null);
    try {
      const newId = await saveListeningExercise(user.uid, "dictation", item, { difficulty }, "english");
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  function handleBlankChange(blankIndex: number, text: string) {
    setBlankAnswers((prev) => {
      const next = [...prev];
      next[blankIndex] = text;
      return next;
    });
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Nghe chép</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (settings.targetLanguage !== "english") {
    return (
      <div>
        <h2 className="scr-title">Nghe chép</h2>
        <p className="reading-min-words-hint">
          Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.
        </p>
      </div>
    );
  }

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Nghe chép</h2>
        {(generating || fetchingSaved) && <p>{generating ? "Đang tạo bài…" : "Đang tìm bài…"}</p>}
        {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
        {generateError && (
          <>
            <p role="alert">{generateError}</p>
            <div className="reading-result-actions">
              <button type="button" className="btn-secondary" onClick={() => router.push("/listening")}>
                Về trang chính
              </button>
              <button type="button" className="btn-primary" onClick={() => void runAction()}>
                Thử lại
              </button>
            </div>
          </>
        )}
      </div>
    );
  }

  if (phase === "session" && item) {
    const isCloze = difficulty !== "hard";
    const canSubmit =
      audio.hasPlayedOnce && (isCloze ? blankAnswers.every((a) => a.trim().length > 0) : typed.trim().length > 0);
    const words = targetWords(item.target);

    return (
      <div>
        <h2 className="scr-title">Nghe chép</h2>
        <div className="reading-submit-bar">
          <span className="reading-progress-label">
            {audio.hasPlayedOnce ? "Đã nghe — điền đầy đủ để nộp bài" : "Hãy nghe ít nhất 1 lần trước khi nộp"}
          </span>
          <button type="button" className="btn-primary" onClick={() => void handleSubmit()} disabled={!canSubmit}>
            Nộp bài
          </button>
        </div>
        {audio.error && <p role="alert">{audio.error}</p>}
        <div className="dictation-controls">
          <button type="button" className="btn-primary" onClick={() => void audio.play()} disabled={audio.isLoading}>
            {audio.hasPlayedOnce ? `▶ Nghe lại (${audio.replayCount})` : "▶ Phát"}
          </button>
          <div className="dictation-speed-selector">
            <input
              type="range"
              min={MIN_SPEED}
              max={MAX_SPEED}
              step={SPEED_STEP}
              value={audio.speed}
              className="dictation-speed-slider"
              aria-label="Tốc độ phát"
              onChange={(e) => audio.setSpeed(Number(e.target.value))}
            />
            <span className="dictation-speed-label">{audio.speed.toFixed(2)}x</span>
          </div>
        </div>
        {words.length > 1 && (
          <input
            type="range"
            min={0}
            max={words.length - 1}
            step={1}
            value={seekPreviewIndex}
            className="dictation-seek-slider"
            aria-label="Tua theo từ"
            disabled={audio.isLoading}
            onChange={(e) => setSeekPreviewIndex(Number(e.target.value))}
            onMouseDown={() => {
              isDraggingSeekRef.current = true;
            }}
            onTouchStart={() => {
              isDraggingSeekRef.current = true;
            }}
            onKeyDown={() => {
              isDraggingSeekRef.current = true;
            }}
            onMouseUp={(e) => {
              isDraggingSeekRef.current = false;
              void audio.seekTo(Number(e.currentTarget.value));
            }}
            onTouchEnd={(e) => {
              isDraggingSeekRef.current = false;
              void audio.seekTo(Number(e.currentTarget.value));
            }}
            onKeyUp={(e) => {
              isDraggingSeekRef.current = false;
              void audio.seekTo(Number(e.currentTarget.value));
            }}
          />
        )}
        <div className="reading-session-body">
          {isCloze ? (
            <ClozeInput target={item.target} blanks={blanks} answers={blankAnswers} onAnswerChange={handleBlankChange} />
          ) : (
            <textarea
              className="dictation-free-input"
              value={typed}
              onChange={(e) => setTyped(e.target.value)}
              placeholder="Gõ lại những gì bạn nghe được..."
            />
          )}
        </div>
      </div>
    );
  }

  const scorePct = Math.round(finalScore * 100);
  const seekPenaltyPct = Math.round(audio.seekPenaltyTotal * 100);

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <div className="reading-result-stats">
        <div className="reading-stat-card">
          <span className="reading-stat-label">Điểm</span>
          <span className="reading-stat-value">{scorePct}%</span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Nghe lại</span>
          <span className="reading-stat-value">{audio.replayCount}</span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Số lần tua</span>
          <span className="reading-stat-value">
            {audio.seekCount} (−{seekPenaltyPct}%)
          </span>
        </div>
        <div className="reading-stat-card">
          <span className="reading-stat-label">Thời gian</span>
          <span className="reading-stat-value">{formatDuration(durationMs)}</span>
        </div>
      </div>
      <h3>Bạn đã gõ</h3>
      {difficulty === "hard" ? (
        <DiffText typed={typed} target={item?.target ?? ""} />
      ) : (
        <ClozeResult target={item?.target ?? ""} blanks={blanks} answers={blankAnswers} />
      )}
      <h3>Câu đúng</h3>
      <p>{item?.target}</p>
      <h3>Nghĩa</h3>
      <p>{item?.vietnamese}</p>
      <div className="reading-result-actions">
        {sessionMode === "generated" &&
          (justSavedId ? (
            <span className="reading-saved-mark">Đã lưu ✔</span>
          ) : (
            <button type="button" className="btn-secondary" onClick={() => void handleSaveExercise()} disabled={saving}>
              {saving ? "Đang lưu…" : "Lưu bài"}
            </button>
          ))}
        <button type="button" className="btn-secondary" onClick={() => router.push("/listening")}>
          Về trang chính
        </button>
        <button type="button" className="btn-primary" onClick={() => void handleNewSession()}>
          Câu khác
        </button>
      </div>
      {saveError && <p role="alert">{saveError}</p>}
      {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
      {generateError && <p role="alert">{generateError}</p>}
    </div>
  );
}

export default function DictationPage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <DictationPageContent />
    </Suspense>
  );
}
