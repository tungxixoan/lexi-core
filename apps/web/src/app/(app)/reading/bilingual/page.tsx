"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";
import { selectSessionWords, type SessionWordFilters } from "@/lib/practiceSession";
import {
  buildReadingPassagePrompt,
  parseReadingPassage,
  type ReadingPassage,
} from "@/lib/readingPassage";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
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
  type SavedExerciseFilters,
} from "@/lib/savedReadingExercises";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";

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

type Phase = "setup" | "session" | "result";

export interface ReadingSessionResult {
  vocabIds: string[];
  accuracy: number;
  completedAt: string;
}

export default function BilingualReadingPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();

  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [maxCefr, setMaxCefr] = useState<CefrLevel | null>(null);
  const [wordCount, setWordCount] = useState<number | null>(DEFAULT_WORD_COUNT);

  const [phase, setPhase] = useState<Phase>("setup");
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
    if (!user) return;
    setLoadError(null);
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setLoadError(err instanceof Error ? err.message : String(err)));
  }, [user]);

  async function handleGenerate() {
    if (!records || !user || !settings) return;
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: null };
    const pool = selectSessionWords(records, filters);
    if (pool.length === 0) return;

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

  // Returns true if a session was started (saved match, or a successful AI
  // fallback) or an error was surfaced to the user; false only when nothing
  // matched AND there weren't even enough live words to attempt the AI
  // fallback — the caller decides what "false" means for it (Task 5 resets
  // to setup in that case; Task 3's own handleGetSaved has nothing further
  // to do, the existing min-words hint is already visible on this screen).
  async function fetchSavedExercise(excludeId?: string): Promise<boolean> {
    if (!records || !user || !settings) return false;
    const matchingCount = selectSessionWords(records, {
      topicIds: selectedTopicIds,
      maxCefr,
      count: null,
    }).length;
    setGenerateError(null);
    setSavedNotice(null);
    setFetchingSaved(true);
    let found = false;
    try {
      const filters: SavedExerciseFilters = { topicIds: [...selectedTopicIds], maxCefr, wordCount };
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, filters, excludeId);
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

  async function handleGetSaved() {
    await fetchSavedExercise();
  }

  async function handleSaveExercise() {
    if (saving || !user || !settings || !passage) return;
    setSaving(true);
    setSaveError(null);
    try {
      const generationFilters: SavedExerciseFilters = {
        topicIds: [...selectedTopicIds],
        maxCefr,
        wordCount,
      };
      const newId = await saveReadingExercise(user.uid, passage, generationFilters, settings.targetLanguage);
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
    // Peak, not cumulative: a mismatch only counts once even if it sits
    // uncorrected for several keystrokes — this is "how wrong did it get",
    // not "how many wrong keystrokes total".
    const newPeakMistakes = Math.max(peakMistakes, countMismatches(target, value));
    setPeakMistakes(newPeakMistakes);

    if (value !== target) return;

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

  function resetToSetup() {
    setPassage(null);
    setCurrentIndex(0);
    setTyped("");
    setDeletedChars(0);
    setPeakMistakes(0);
    setCompletedStats([]);
    setGenerateError(null);
    setSavedNotice(null);
    setJustSavedId(null);
    setSaveError(null);
    setPhase("setup");
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      const handled = await fetchSavedExercise(justSavedId ?? undefined);
      if (!handled) resetToSetup();
      return;
    }
    const matchingCount = records
      ? selectSessionWords(records, { topicIds: selectedTopicIds, maxCefr, count: null }).length
      : 0;
    if (matchingCount >= MIN_VOCAB_WORDS) {
      await handleGenerate();
    } else {
      resetToSetup();
    }
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

  if (phase === "setup") {
    // count: null bypasses truncation so this reflects every matching word,
    // not just the ones a fixed session size would keep.
    const matchingCount = selectSessionWords(records, {
      topicIds: selectedTopicIds,
      maxCefr,
      count: null,
    }).length;
    const canGenerate = matchingCount >= MIN_VOCAB_WORDS;

    return (
      <div>
        <h2 className="scr-title">Đọc &amp; gõ</h2>
        <p className="scr-sub">Chọn bộ lọc rồi tạo bài luyện từ từ vựng của bạn.</p>
        <div className="practice-filters">
          <TopicFilterPopover
            topics={topics}
            selectedTopicIds={selectedTopicIds}
            onApply={setSelectedTopicIds}
          />
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
        <div className="reading-setup-actions">
          {canGenerate ? (
            <button
              className="btn-primary"
              onClick={() => void handleGenerate()}
              disabled={generating || fetchingSaved}
            >
              {generating ? "Đang tạo bài…" : "Tạo bài luyện"}
            </button>
          ) : (
            <p className="reading-min-words-hint">
              Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có{" "}
              {matchingCount} từ.
            </p>
          )}
          <button
            type="button"
            className="btn-secondary"
            onClick={() => void handleGetSaved()}
            disabled={generating || fetchingSaved}
          >
            {fetchingSaved ? "Đang tìm bài…" : "🔀 Lấy bài có sẵn"}
          </button>
        </div>
        {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
        {generateError && <p role="alert">{generateError}</p>}
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
  // Streak-hook shape (design spec §3.3) — Dashboard/streak is its own
  // deferred phase and nothing writes this anywhere yet, but every piece a
  // future feature would need is right here: passage?.vocabIds (already
  // computed above as usedRecords' source), stats.typingAccuracy, and
  // `new Date().toISOString()` at this exact point in time. See
  // ReadingSessionResult below for the exact shape that data would take.

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
                <p className="reading-used-word-item" key={r.id}>
                  {r.headword} — {r.meaning}
                </p>
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
