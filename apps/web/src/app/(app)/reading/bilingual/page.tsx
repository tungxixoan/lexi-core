"use client";

import { useEffect, useState } from "react";
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

export default function BilingualReadingPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();

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
    const filters: SessionWordFilters = { topicIds: selectedTopicIds, maxCefr, count: wordCount };
    const words = selectSessionWords(records, filters);
    if (words.length === 0) return;

    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }

    setGenerating(true);
    setGenerateError(null);
    try {
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
      setPassage(generated);
      setPhase("session");
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
    } finally {
      setGenerating(false);
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
        {canGenerate ? (
          <button className="btn-primary" onClick={() => void handleGenerate()} disabled={generating}>
            {generating ? "Đang tạo bài…" : "Tạo bài luyện"}
          </button>
        ) : (
          <p className="reading-min-words-hint">
            Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ khớp với bộ lọc trên vào Ngân hàng từ vựng. Hiện có{" "}
            {matchingCount} từ.
          </p>
        )}
        {generateError && <p role="alert">{generateError}</p>}
      </div>
    );
  }

  // "session"/"result" phases wired in Tasks 9-10.
  return null;
}
