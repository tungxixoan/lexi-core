"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { TopicFilterPopover } from "@/components/vocab-bank/TopicFilterPopover";
import { ECONOMY_VOLUMES, VOLUME_LABELS, type EconomyVolume } from "@/lib/toeicFilters";
import { buildPart5Prompt, parsePart5Set, type Part5Set } from "@/lib/part5";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { getRandomSavedExercise, saveReadingExercise, type ToeicFilters } from "@/lib/savedReadingExercises";
import { McQuestionCard } from "@/components/reading/McQuestionCard";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";

type Phase = "setup" | "session" | "result";

export default function Part5Page() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);

  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(new Set());
  const [selectedVolumes, setSelectedVolumes] = useState<Set<EconomyVolume>>(new Set());

  const [phase, setPhase] = useState<Phase>("setup");
  const [generating, setGenerating] = useState(false);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [set, setSet] = useState<Part5Set | null>(null);
  const [answers, setAnswers] = useState<(number | null)[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    // Best-effort: these only feed VocabSuggestionsSection on the result
    // screen, unlike Đọc & gõ they are never a hard requirement for this
    // page to function, so a failure here doesn't block anything.
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

  function resolvedTopicNames(): string[] {
    return topics.filter((t) => selectedTopicIds.has(t.id)).map((t) => t.name);
  }

  function currentFilters(): ToeicFilters {
    return { topicIds: [...selectedTopicIds], volumes: [...selectedVolumes] };
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
      const prompt = buildPart5Prompt(resolvedTopicNames(), settings.targetLanguage, [...selectedVolumes]);
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parsePart5Set(json);
      if (generated.questions.length === 0) {
        throw new Error("AI không trả về bài luyện hợp lệ.");
      }
      setSessionMode("generated");
      setJustSavedId(null);
      setSaveError(null);
      setSet(generated);
      setAnswers(new Array(generated.questions.length).fill(null));
      setPhase("session");
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
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, "part5", currentFilters(), excludeId);
      if (saved) {
        found = true;
        setSessionMode("reused");
        setJustSavedId(null);
        setSaveError(null);
        setSet(saved.passage);
        setAnswers(new Array(saved.passage.questions.length).fill(null));
        setPhase("session");
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

  async function handleGetSaved() {
    await fetchSavedExercise();
  }

  async function handleSaveExercise() {
    if (saving || !user || !settings || !set) return;
    setSaving(true);
    setSaveError(null);
    try {
      const newId = await saveReadingExercise(user.uid, "part5", set, currentFilters(), settings.targetLanguage);
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleSelectAnswer(questionIndex: number, optionIndex: number) {
    setAnswers((prev) => {
      const next = [...prev];
      next[questionIndex] = optionIndex;
      return next;
    });
  }

  function resetToSetup() {
    setSet(null);
    setAnswers([]);
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
    await handleGenerate();
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Part 5 — Điền câu</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (phase === "setup") {
    return (
      <div>
        <h2 className="scr-title">Part 5 — Điền câu</h2>
        <p className="scr-sub">AI tạo 15 câu điền từ/ngữ pháp kiểu TOEIC Part 5.</p>
        <div className="practice-filters">
          <TopicFilterPopover topics={topics} selectedTopicIds={selectedTopicIds} onApply={setSelectedTopicIds} />
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
        <div className="reading-setup-actions">
          <button className="btn-primary" onClick={() => void handleGenerate()} disabled={generating || fetchingSaved}>
            {generating ? "Đang tạo bài…" : "Tạo bài luyện"}
          </button>
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

  if (phase === "session" && set) {
    const canSubmit = answers.every((a) => a !== null);
    return (
      <div>
        <h2 className="scr-title">Part 5 — Điền câu</h2>
        {set.questions.map((q, i) => (
          <McQuestionCard
            key={i}
            label={`${i + 1}. ${q.sentenceWithBlank}`}
            options={q.options}
            selected={answers[i]}
            onSelect={(optionIndex) => handleSelectAnswer(i, optionIndex)}
          />
        ))}
        <button className="btn-primary" onClick={() => setPhase("result")} disabled={!canSubmit}>
          Nộp bài
        </button>
      </div>
    );
  }

  const total = set?.questions.length ?? 0;
  const correctCount = (set?.questions ?? []).filter((q, i) => answers[i] === q.correctIndex).length;
  const questionsText = (set?.questions ?? []).map((q) => q.sentenceWithBlank).join(" ");

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <p className="mc-score">
        {correctCount}/{total}
      </p>
      {(set?.questions ?? []).map((q, i) => (
        <McQuestionCard
          key={i}
          label={`${i + 1}. ${q.sentenceWithBlank}`}
          options={q.options}
          selected={answers[i]}
          correctIndex={q.correctIndex}
          explanation={q.explanation}
        />
      ))}
      {sessionMode === "generated" && <VocabSuggestionsSection text={questionsText} existingRecords={records} topics={topics} />}
      <div className="reading-result-actions">
        {sessionMode === "generated" &&
          (justSavedId ? (
            <span className="reading-saved-mark">Đã lưu ✔</span>
          ) : (
            <button type="button" className="btn-secondary" onClick={() => void handleSaveExercise()} disabled={saving}>
              {saving ? "Đang lưu…" : "Lưu bài"}
            </button>
          ))}
        <button type="button" className="btn-secondary" onClick={() => router.push("/reading")}>
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
