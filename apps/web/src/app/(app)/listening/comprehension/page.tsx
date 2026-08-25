"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { recordDailyActivity } from "@/lib/dailyActivity";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import {
  buildListeningPassagePrompt,
  parseListeningPassage,
  assignVoices,
  scoreComprehension,
  type ListeningPassage,
  type Speaker,
  type VoiceId,
} from "@/lib/listeningPassage";
import {
  saveListeningExercise,
  getRandomSavedListeningExercise,
  type ComprehensionItem,
} from "@/lib/savedListeningExercises";
import { APP_CONTEXTS, type AppContext } from "@/lib/appContext";
import { useComprehensionAudio } from "@/lib/useComprehensionAudio";
import { McQuestionCard } from "@/components/reading/McQuestionCard";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";

type Phase = "loading" | "session" | "result";
type CefrLevel = VocabRecord["cefrLevel"];
const MIN_SPEED = 0.5;
const MAX_SPEED = 2;
const SPEED_STEP = 0.05;

function isCefrLevel(value: string | null): value is CefrLevel {
  return value === "a1" || value === "a2" || value === "b1" || value === "b2" || value === "c1" || value === "c2";
}

function isAppContext(value: string | null): value is AppContext {
  return (APP_CONTEXTS as string[]).includes(value ?? "");
}

function ComprehensionPageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
  const searchParams = useSearchParams();

  const contextParamRaw = searchParams.get("context");
  const contextParam: AppContext = isAppContext(contextParamRaw) ? contextParamRaw : "general";
  const levelParam = searchParams.get("level");
  // `level` (defaulted to "b1") feeds GENERATION only — an LLM prompt needs
  // *some* level. The saved-exercise LOOKUP path must NOT coerce an absent
  // level to "b1" (that would make saved exercises at any other level
  // unreachable via "Lấy bài có sẵn") — it uses `savedLevelFilter` instead,
  // which stays null when the URL has no level param.
  const level: CefrLevel = isCefrLevel(levelParam) ? levelParam : "b1";
  const savedLevelFilter: CefrLevel | null = isCefrLevel(levelParam) ? levelParam : null;
  const action = searchParams.get("action");

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);

  const [phase, setPhase] = useState<Phase>("loading");
  const [generating, setGenerating] = useState(false);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [passage, setPassage] = useState<ListeningPassage | null>(null);
  const [voices, setVoices] = useState<Partial<Record<Speaker, VoiceId>>>({});
  const [selectedAnswers, setSelectedAnswers] = useState<(number | null)[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [finalScore, setFinalScore] = useState(0);
  const [seekPreviewIndex, setSeekPreviewIndex] = useState(0);

  const sessionKeyRef = useRef(0);
  const isDraggingSeekRef = useRef(false);
  const audio = useComprehensionAudio(passage, voices, sessionKeyRef.current);

  useEffect(() => {
    if (!isDraggingSeekRef.current) {
      setSeekPreviewIndex(audio.estimatedGlobalWordIndex);
    }
  }, [audio.estimatedGlobalWordIndex]);

  useEffect(() => {
    if (!user) return;
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {});
  }, [user]);

  function startSession(newPassage: ListeningPassage, mode: "generated" | "reused") {
    sessionKeyRef.current += 1;
    isDraggingSeekRef.current = false;
    setSessionMode(mode);
    setJustSavedId(null);
    setSaveError(null);
    setPassage(newPassage);
    setVoices(assignVoices(newPassage));
    setSelectedAnswers(new Array(newPassage.questions.length).fill(null));
    setSeekPreviewIndex(0);
    setPhase("session");
  }

  async function handleGenerate() {
    if (!user || !settings) return;
    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }
    setGenerating(true);
    setGenerateError(null);
    try {
      const prompt = buildListeningPassagePrompt(level, contextParam, "english");
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parseListeningPassage(json, level, contextParam, "english");
      if (generated.turns.length === 0 || generated.questions.length === 0) {
        throw new Error("AI không trả về bài luyện hợp lệ.");
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
    if (!user) return false;
    setGenerateError(null);
    setSavedNotice(null);
    setFetchingSaved(true);
    let found = false;
    try {
      const saved = await getRandomSavedListeningExercise(
        user.uid,
        "english",
        "comprehension",
        { context: contextParam, level: savedLevelFilter },
        excludeId
      );
      if (saved) {
        found = true;
        // Built directly, not via parseListeningPassage — that function
        // expects raw AI JSON (with a per-turn "gender" field to derive
        // speakerGenders from), which a saved doc doesn't have. The saved
        // doc already carries speakerGenders as its own persisted field
        // (see ComprehensionItem) — assignVoices still picks a fresh
        // *slot* (male1 vs male2) each time, but the underlying gender
        // per speaker is the passage's own content, not re-derived.
        const restored: ListeningPassage = {
          kind: saved.item.kind,
          turns: saved.item.turns,
          questions: saved.item.questions,
          speakerGenders: saved.item.speakerGenders,
          // A saved doc's own generationFilters.level is always concrete —
          // handleSaveExercise never persists a null level (only the LOOKUP
          // filter can be null, for "match any level"). The `?? "b1"` here
          // is just to satisfy ComprehensionFilters' now-widened (nullable)
          // type; it should never actually trigger at runtime.
          level: saved.generationFilters.level ?? "b1",
          context: saved.generationFilters.context,
          targetLanguage: "english",
        };
        startSession(restored, "reused");
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
    if (!user || !settings) return;
    if (settings.targetLanguage !== "english") return;
    if (action !== "generate" && action !== "existing") {
      router.replace("/listening");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, action]);

  async function handleSaveExercise() {
    if (saving || !user || !passage) return;
    setSaving(true);
    setSaveError(null);
    try {
      const item: ComprehensionItem = {
        kind: passage.kind,
        turns: passage.turns,
        questions: passage.questions,
        speakerGenders: passage.speakerGenders,
      };
      const newId = await saveListeningExercise(
        user.uid,
        "comprehension",
        item,
        { context: contextParam, level },
        "english"
      );
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleSelectAnswer(questionIndex: number, optionIndex: number) {
    setSelectedAnswers((prev) => {
      const next = [...prev];
      next[questionIndex] = optionIndex;
      return next;
    });
  }

  function handleSubmit() {
    if (!passage) return;
    audio.stop();
    const score = scoreComprehension(passage, selectedAnswers);
    setFinalScore(score);
    setPhase("result");
    if (user) {
      recordDailyActivity(user.uid, passage.questions.length).catch((err: unknown) => {
        console.error("Failed to record daily activity", err);
      });
    }
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Nghe hiểu</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (settings.targetLanguage !== "english") {
    return (
      <div>
        <h2 className="scr-title">Nghe hiểu</h2>
        <p className="reading-min-words-hint">
          Nghe hiểu hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.
        </p>
      </div>
    );
  }

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Nghe hiểu</h2>
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

  if (phase === "session" && passage) {
    const turn = passage.turns[audio.currentTurnIndex];
    const canSubmit = selectedAnswers.every((a) => a !== null);
    const totalWords = passage.turns.reduce((sum, t) => sum + t.text.split(/\s+/).filter(Boolean).length, 0);

    return (
      <div>
        <h2 className="scr-title">Nghe hiểu</h2>
        <div className="reading-submit-bar">
          <span className="reading-progress-label">
            {selectedAnswers.filter((a) => a !== null).length}/{selectedAnswers.length} câu đã trả lời
          </span>
          <button type="button" className="btn-primary" onClick={handleSubmit} disabled={!canSubmit}>
            Nộp bài
          </button>
        </div>
        {audio.error && <p role="alert">{audio.error}</p>}
        <div className="dictation-controls">
          <button type="button" className="btn-secondary" onClick={audio.previousTurn} disabled={audio.currentTurnIndex === 0}>
            ⏮
          </button>
          <button type="button" className="btn-primary" onClick={audio.isSpeaking ? audio.stop : audio.play}>
            {audio.isSpeaking ? "⏹ Dừng" : "▶ Phát"}
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={audio.nextTurn}
            disabled={audio.currentTurnIndex >= passage.turns.length - 1}
          >
            ⏭
          </button>
          <button type="button" className="btn-secondary" onClick={audio.replayFromStart}>
            ↺
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
        <p className="reading-progress-label">
          Lượt {audio.currentTurnIndex + 1}/{passage.turns.length}
          {turn?.speaker ? ` — Người nói ${turn.speaker}` : ""}
        </p>
        {totalWords > 1 && (
          <input
            type="range"
            min={0}
            max={totalWords - 1}
            step={1}
            value={seekPreviewIndex}
            className="dictation-seek-slider"
            aria-label="Tua theo từ"
            disabled={audio.isSeeking}
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
              void audio.seekToGlobalWord(Number(e.currentTarget.value));
            }}
            onTouchEnd={(e) => {
              isDraggingSeekRef.current = false;
              void audio.seekToGlobalWord(Number(e.currentTarget.value));
            }}
            onKeyUp={(e) => {
              isDraggingSeekRef.current = false;
              void audio.seekToGlobalWord(Number(e.currentTarget.value));
            }}
          />
        )}
        <div className="reading-session-body">
          <div className="mc-question-grid">
            {passage.questions.map((q, i) => (
              <McQuestionCard
                key={i}
                label={`${i + 1}. ${q.question}`}
                options={q.options}
                selected={selectedAnswers[i]}
                onSelect={(optionIndex) => handleSelectAnswer(i, optionIndex)}
              />
            ))}
          </div>
        </div>
      </div>
    );
  }

  const correctCount = Math.round(finalScore * (passage?.questions.length ?? 0));
  const transcriptText = (passage?.turns ?? []).map((t) => t.text).join(" ");

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <p className="mc-score">
        {correctCount}/{passage?.questions.length ?? 0}
      </p>
      <div className="mc-question-grid">
        {(passage?.questions ?? []).map((q, i) => (
          <McQuestionCard
            key={i}
            label={`${i + 1}. ${q.question}`}
            options={q.options}
            selected={selectedAnswers[i]}
            correctIndex={q.correctIndex}
          />
        ))}
      </div>
      <div>
        <h3>Bản ghi âm</h3>
        {(passage?.turns ?? []).map((t, i) => (
          <p key={i}>{t.speaker ? `${t.speaker}: ${t.text}` : t.text}</p>
        ))}
      </div>
      {sessionMode === "generated" && (
        <VocabSuggestionsSection text={transcriptText} existingRecords={records} topics={topics} />
      )}
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
          Bài khác
        </button>
      </div>
      {saveError && <p role="alert">{saveError}</p>}
      {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
      {generateError && <p role="alert">{generateError}</p>}
    </div>
  );
}

export default function ComprehensionPage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <ComprehensionPageContent />
    </Suspense>
  );
}
