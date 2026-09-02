"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import {
  buildReadingPassagePrompt,
  parseReadingPassage,
  type ReadingPassage,
} from "@/lib/readingPassage";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { recordDailyActivity } from "@/lib/dailyActivity";
import { TypingSentence } from "@/components/reading/TypingSentence";
import { PassageReview } from "@/components/reading/PassageReview";
import {
  computeSentenceStats,
  aggregateSentenceStats,
  countMismatches,
  type SentenceStats,
} from "@/lib/readingScoring";
import {
  getAllUsedVocabIds,
  getRandomSavedExercise,
  saveReadingExercise,
  prioritizeUnusedWords,
  type BilingualFilters,
} from "@/lib/savedReadingExercises";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";
import { PronunciationButton } from "@/components/shared/PronunciationButton";
import { ttsLanguageCode } from "@/lib/pronunciation";

type CefrLevel = VocabRecord["cefrLevel"];
const MIN_VOCAB_WORDS = 5;

export interface ReadingSessionResult {
  vocabIds: string[];
  accuracy: number;
  completedAt: string;
}

function BilingualReadingPageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
  const searchParams = useSearchParams();

  const topicIds = new Set((searchParams.get("topicIds") ?? "").split(",").filter(Boolean));
  const maxCefr = (searchParams.get("maxCefr") as CefrLevel | null) ?? null;
  const wordCountRaw = searchParams.get("wordCount");
  const wordCount = wordCountRaw === null || wordCountRaw === "all" ? null : Number(wordCountRaw);
  const action = searchParams.get("action");

  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [phase, setPhase] = useState<"loading" | "session" | "result">("loading");
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [passage, setPassage] = useState<ReadingPassage | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [typed, setTyped] = useState("");
  const [deletedChars, setDeletedChars] = useState(0);
  const [peakMistakes, setPeakMistakes] = useState(0);
  const [sentenceStartedAt, setSentenceStartedAt] = useState(0);
  const [completedStats, setCompletedStats] = useState<SentenceStats[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (!user || !settings) return;
    setLoadError(null);
    Promise.all([getVocabRecords(user.uid, settings.targetLanguage), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setLoadError(err instanceof Error ? err.message : String(err)));
  }, [user, settings]);

  async function handleGenerate() {
    if (!records || !user || !settings) return;
    const filters: SessionWordFilters = { topicIds, maxCefr, count: null };
    const pool = selectSessionWords(records, filters);
    if (pool.length === 0) {
      setGenerateError("Không tìm thấy từ vựng nào khớp với bộ lọc đã chọn để tạo bài.");
      return;
    }

    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }

    setGenerating(true);
    setGenerateError(null);
    try {
      const usedVocabIds = await getAllUsedVocabIds(user.uid).catch(() => new Set<string>());
      const prioritized = prioritizeUnusedWords(pool, usedVocabIds);
      const words = wordCount === null ? prioritized : prioritized.slice(0, wordCount);
      const prompt = buildReadingPassagePrompt(
        words.map((w) => w.headword),
        settings.targetLanguage,
        maxCefr
      );
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parseReadingPassage(json, words);
      if (generated.sentences.length === 0) {
        throw new Error("AI không trả về đoạn văn hợp lệ.");
      }
      setSessionMode("generated");
      setJustSavedId(null);
      setSaveError(null);
      setPassage(generated);
      setCurrentIndex(0);
      setTyped("");
      setDeletedChars(0);
      setPeakMistakes(0);
      setSentenceStartedAt(Date.now());
      setCompletedStats([]);
      setPhase("session");
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
    } finally {
      setGenerating(false);
      setSavedNotice(null);
    }
  }

  async function fetchSavedExercise(excludeId?: string): Promise<boolean> {
    if (!records || !user || !settings) return false;
    const matchingCount = selectSessionWords(records, { topicIds, maxCefr, count: null }).length;
    setGenerateError(null);
    setSavedNotice(null);
    setFetchingSaved(true);
    let found = false;
    try {
      const filters: BilingualFilters = { topicIds: [...topicIds], maxCefr, wordCount };
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, "bilingual", filters, excludeId);
      if (saved) {
        found = true;
        setSessionMode("reused");
        setJustSavedId(null);
        setSaveError(null);
        setPassage(saved.passage);
        setCurrentIndex(0);
        setTyped("");
        setDeletedChars(0);
        setPeakMistakes(0);
        setSentenceStartedAt(Date.now());
        setCompletedStats([]);
        setPhase("session");
      } else if (matchingCount >= MIN_VOCAB_WORDS) {
        setSavedNotice("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…");
      } else {
        setGenerateError(
          `Hãy lưu ít nhất ${MIN_VOCAB_WORDS} từ khớp với bộ lọc đã chọn vào Ngân hàng từ vựng. Hiện có ${matchingCount} từ.`
        );
      }
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
      return true;
    } finally {
      setFetchingSaved(false);
    }
    if (!found && matchingCount >= MIN_VOCAB_WORDS) {
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
    if (action !== "generate" && action !== "existing") {
      router.replace("/reading");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, records, action]);

  const dailyActivityRecordedRef = useRef(false);
  useEffect(() => {
    if (phase !== "result" || dailyActivityRecordedRef.current || !user || !passage) return;
    dailyActivityRecordedRef.current = true;
    recordDailyActivity(user.uid, passage.vocabIds.length).catch((err: unknown) => {
      console.error("Failed to record daily activity", err);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);

  async function handleSaveExercise() {
    if (saving || !user || !settings || !passage) return;
    setSaving(true);
    setSaveError(null);
    try {
      const generationFilters: BilingualFilters = { topicIds: [...topicIds], maxCefr, wordCount };
      const newId = await saveReadingExercise(user.uid, "bilingual", passage, generationFilters, settings.targetLanguage);
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleTypedChange(value: string) {
    const newDeletedChars =
      value.length < typed.length ? deletedChars + (typed.length - value.length) : deletedChars;
    setTyped(value);
    setDeletedChars(newDeletedChars);

    if (!passage) return;
    const target = passage.sentences[currentIndex].target;
    const newPeakMistakes = Math.max(peakMistakes, countMismatches(target, value));
    setPeakMistakes(newPeakMistakes);

    if (value.length < target.length) return;

    const durationMs = Date.now() - sentenceStartedAt;
    const stats = computeSentenceStats(target, value, newDeletedChars, newPeakMistakes, durationMs);
    setCompletedStats((prev) => [...prev, stats]);

    if (currentIndex + 1 < passage.sentences.length) {
      setCurrentIndex(currentIndex + 1);
      setTyped("");
      setDeletedChars(0);
      setPeakMistakes(0);
      setSentenceStartedAt(Date.now());
    } else {
      setPhase("result");
    }
  }

  function formatDuration(ms: number): string {
    const totalSeconds = Math.round(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${String(seconds).padStart(2, "0")}`;
  }

  async function handleNewSession() {
    dailyActivityRecordedRef.current = false;
    if (sessionMode === "reused") {
      // fetchSavedExercise always leaves user-visible feedback on this same
      // "result" phase now — either a new session, an AI-fallback notice, or
      // generateError — so there is no "silently did nothing" case left to
      // redirect away from, unlike the removed setup-phase fallback this
      // replaces.
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Đọc &amp; gõ</h2>
        <p className="scr-sub">Đăng nhập để luyện đọc.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;
  if (loadError) return <p role="alert">Lỗi: {loadError}</p>;
  if (records === null) return <p>Đang tải từ vựng…</p>;

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Đọc &amp; gõ</h2>
        {(generating || fetchingSaved) && <p>{generating ? "Đang tạo bài…" : "Đang tìm bài…"}</p>}
        {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
        {generateError && (
          <>
            <p role="alert">{generateError}</p>
            <div className="reading-result-actions">
              <button type="button" className="btn-secondary" onClick={() => router.push("/reading")}>
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
    const currentSentence = passage.sentences[currentIndex];
    const completedSentences = passage.sentences.slice(0, currentIndex).map((s) => s.target);
    const progressPct = Math.round(((currentIndex + 1) / passage.sentences.length) * 100);

    return (
      <div>
        <div className="practice-progress-row">
          <span>
            Câu {currentIndex + 1} / {passage.sentences.length}
          </span>
          <span>Đọc &amp; gõ</span>
        </div>
        <div className="practice-progress-track">
          <div className="practice-progress-fill" style={{ width: `${progressPct}%` }} />
        </div>
        <TypingSentence
          completedSentences={completedSentences}
          currentSentence={currentSentence}
          typed={typed}
          onTypedChange={handleTypedChange}
        />
      </div>
    );
  }

  const stats = aggregateSentenceStats(completedStats);
  const totalDurationMs = completedStats.reduce((sum, s) => sum + s.durationMs, 0);
  const usedRecords = (records ?? []).filter((r) => passage?.vocabIds.includes(r.id));
  const fullText = (passage?.sentences ?? []).map((s) => s.target).join(" ");

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <div className="reading-result-row">
        <div className="reading-result-left">
          <div className="reading-result-stats">
            <div className="reading-stat-card">
              <span className="reading-stat-label">Độ chính xác</span>
              <span className="reading-stat-value">{Math.round(stats.typingAccuracy * 100)}%</span>
            </div>
            <div className="reading-stat-card">
              <span className="reading-stat-label">Tốc độ</span>
              <span className="reading-stat-value">{Math.round(stats.wpm)} wpm</span>
            </div>
            <div className="reading-stat-card">
              <span className="reading-stat-label">Thời gian</span>
              <span className="reading-stat-value">{formatDuration(totalDurationMs)}</span>
            </div>
            <div className="reading-stat-card">
              <span className="reading-stat-label">Điểm</span>
              <span className="reading-stat-value">{Math.round(stats.finalScore * 100)}%</span>
            </div>
          </div>
          {usedRecords.length > 0 && (
            <div className="reading-used-words">
              <h3>Từ vựng dùng trong bài</h3>
              {usedRecords.map((r) => (
                <div className="reading-used-word-item" key={r.id}>
                  <span>
                    {r.headword} — {r.meaning}
                  </span>
                  <PronunciationButton
                    text={r.headword}
                    language={ttsLanguageCode(r.targetLanguage)}
                    tier="word"
                  />
                </div>
              ))}
            </div>
          )}
        </div>
        <PassageReview sentences={passage?.sentences ?? []} />
      </div>
      {sessionMode === "generated" && (
        <VocabSuggestionsSection text={fullText} existingRecords={records ?? []} topics={topics} />
      )}
      <div className="reading-result-actions">
        {sessionMode === "generated" &&
          (justSavedId ? (
            <span className="reading-saved-mark">Đã lưu ✔</span>
          ) : (
            <button
              type="button"
              className="btn-secondary"
              onClick={() => void handleSaveExercise()}
              disabled={saving}
            >
              {saving ? "Đang lưu…" : "Lưu bài"}
            </button>
          ))}
        <button type="button" className="btn-secondary" onClick={() => router.push("/reading")}>
          Về trang chính
        </button>
        <button type="button" className="btn-primary" onClick={() => void handleNewSession()}>
          Sinh bài mới
        </button>
      </div>
      {saveError && <p role="alert">{saveError}</p>}
      {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
      {generateError && <p role="alert">{generateError}</p>}
    </div>
  );
}

export default function BilingualReadingPage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <BilingualReadingPageContent />
    </Suspense>
  );
}
