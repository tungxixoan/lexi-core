"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { type EconomyVolume } from "@/lib/toeicFilters";
import { buildPart6Prompt, parsePart6Set, type Part6Set } from "@/lib/part6";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { getRandomSavedExercise, saveReadingExercise, type ToeicFilters } from "@/lib/savedReadingExercises";
import { McQuestionCard } from "@/components/reading/McQuestionCard";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";
import { formatPassageLines } from "@/lib/formatPassageText";

type Phase = "loading" | "session" | "result";
const QUESTIONS_PER_PASSAGE = 4;

function flatIndex(passageIndex: number, questionIndex: number): number {
  return passageIndex * QUESTIONS_PER_PASSAGE + questionIndex;
}

function Part6PageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
  const searchParams = useSearchParams();

  const topicIds = (searchParams.get("topicIds") ?? "").split(",").filter(Boolean);
  const volumes = (searchParams.get("volumes") ?? "").split(",").filter(Boolean) as EconomyVolume[];
  const action = searchParams.get("action");

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);

  const [phase, setPhase] = useState<Phase>("loading");
  const [generating, setGenerating] = useState(false);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [set, setSet] = useState<Part6Set | null>(null);
  const [answers, setAnswers] = useState<(number | null)[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [contextLoaded, setContextLoaded] = useState(false);
  const [collapsedGroups, setCollapsedGroups] = useState<Set<number>>(new Set());

  function toggleCollapsed(index: number) {
    setCollapsedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(index)) next.delete(index);
      else next.add(index);
      return next;
    });
  }

  useEffect(() => {
    if (!user) return;
    // Best-effort: these only feed VocabSuggestionsSection on the result
    // screen — but the auto-trigger effect below still waits for this to
    // settle (success or failure) via contextLoaded, since resolvedTopicNames()
    // needs `topics` populated before building the generation prompt.
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {})
      .finally(() => setContextLoaded(true));
  }, [user]);

  function resolvedTopicNames(): string[] {
    return topics.filter((t) => topicIds.includes(t.id)).map((t) => t.name);
  }

  function currentFilters(): ToeicFilters {
    return { topicIds, volumes };
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
      const prompt = buildPart6Prompt(resolvedTopicNames(), settings.targetLanguage, volumes);
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parsePart6Set(json);
      if (generated.passages.length === 0) {
        throw new Error("AI không trả về bài luyện hợp lệ.");
      }
      setSessionMode("generated");
      setJustSavedId(null);
      setSaveError(null);
      setSet(generated);
      setAnswers(new Array(generated.passages.length * QUESTIONS_PER_PASSAGE).fill(null));
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
      const saved = await getRandomSavedExercise(user.uid, settings.targetLanguage, "part6", currentFilters(), excludeId);
      if (saved) {
        found = true;
        setSessionMode("reused");
        setJustSavedId(null);
        setSaveError(null);
        setSet(saved.passage);
        setAnswers(new Array(saved.passage.passages.length * QUESTIONS_PER_PASSAGE).fill(null));
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

  async function runAction() {
    if (action === "generate") {
      await handleGenerate();
    } else if (action === "existing") {
      await fetchSavedExercise();
    }
  }

  const triggeredRef = useRef(false);
  useEffect(() => {
    if (!user || !settings || !contextLoaded) return;
    if (action !== "generate" && action !== "existing") {
      router.replace("/reading");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, contextLoaded, action]);

  async function handleSaveExercise() {
    if (saving || !user || !settings || !set) return;
    setSaving(true);
    setSaveError(null);
    try {
      const newId = await saveReadingExercise(user.uid, "part6", set, currentFilters(), settings.targetLanguage);
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleSelectAnswer(passageIndex: number, questionIndex: number, optionIndex: number) {
    setAnswers((prev) => {
      const next = [...prev];
      next[flatIndex(passageIndex, questionIndex)] = optionIndex;
      return next;
    });
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      // fetchSavedExercise always leaves user-visible feedback on this same
      // "result" phase — either a new session, an AI-fallback notice, or
      // generateError — so there is nothing to redirect away from.
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Part 6 — Điền đoạn văn</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Part 6 — Điền đoạn văn</h2>
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

  if (phase === "session" && set) {
    const answeredCount = answers.filter((a) => a !== null).length;
    const canSubmit = answeredCount === answers.length;
    return (
      <div>
        <h2 className="scr-title">Part 6 — Điền đoạn văn</h2>
        <div className="reading-submit-bar">
          <span className="reading-progress-label">
            Đã trả lời {answeredCount}/{answers.length} câu
          </span>
          <button className="btn-primary" onClick={() => setPhase("result")} disabled={!canSubmit}>
            Nộp bài
          </button>
        </div>
        {set.passages.map((passage, p) => {
          const collapsed = collapsedGroups.has(p);
          return (
            <div key={p} className="reading-passage-group">
              <div className="reading-passage-group-header">
                <h3 className="reading-passage-group-title">Đoạn {p + 1}</h3>
                <button type="button" className="reading-collapse-btn" onClick={() => toggleCollapsed(p)}>
                  {collapsed ? "Mở rộng ▾" : "Thu gọn ▴"}
                </button>
              </div>
              {!collapsed && (
                <>
                  {formatPassageLines(passage.passageText).map((line, li) => (
                    <p key={li} className="reading-passage-text">
                      {line}
                    </p>
                  ))}
                  <div className="mc-question-grid">
                    {passage.questions.map((q, qi) => (
                      <McQuestionCard
                        key={qi}
                        label={`Chỗ trống (${qi + 1})`}
                        options={q.options}
                        selected={answers[flatIndex(p, qi)]}
                        onSelect={(optionIndex) => handleSelectAnswer(p, qi, optionIndex)}
                      />
                    ))}
                  </div>
                </>
              )}
            </div>
          );
        })}
      </div>
    );
  }

  const total = (set?.passages.length ?? 0) * QUESTIONS_PER_PASSAGE;
  const correctCount = (set?.passages ?? []).reduce(
    (sum, passage, p) => sum + passage.questions.filter((q, qi) => answers[flatIndex(p, qi)] === q.correctIndex).length,
    0
  );
  const passagesText = (set?.passages ?? []).map((p) => p.passageText).join(" ");

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <p className="mc-score">
        {correctCount}/{total}
      </p>
      {(set?.passages ?? []).map((passage, p) => {
        const collapsed = collapsedGroups.has(p);
        return (
          <div key={p} className="reading-passage-group">
            <div className="reading-passage-group-header">
              <h3 className="reading-passage-group-title">Đoạn {p + 1}</h3>
              <button type="button" className="reading-collapse-btn" onClick={() => toggleCollapsed(p)}>
                {collapsed ? "Mở rộng ▾" : "Thu gọn ▴"}
              </button>
            </div>
            {!collapsed && (
              <>
                {formatPassageLines(passage.passageText).map((line, li) => (
                  <p key={li} className="reading-passage-text">
                    {line}
                  </p>
                ))}
                <div className="mc-question-grid">
                  {passage.questions.map((q, qi) => (
                    <McQuestionCard
                      key={qi}
                      label={`Chỗ trống (${qi + 1})`}
                      options={q.options}
                      selected={answers[flatIndex(p, qi)]}
                      correctIndex={q.correctIndex}
                      explanation={q.explanation}
                    />
                  ))}
                </div>
              </>
            )}
          </div>
        );
      })}
      {sessionMode === "generated" && <VocabSuggestionsSection text={passagesText} existingRecords={records} topics={topics} />}
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

export default function Part6Page() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <Part6PageContent />
    </Suspense>
  );
}
