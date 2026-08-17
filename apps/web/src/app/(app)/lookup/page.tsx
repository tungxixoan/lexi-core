"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { EditVocabModal } from "@/components/vocab-bank/EditVocabModal";
import { detectInputType } from "@/lib/inputDetector";
import {
  buildSentencePrompt,
  buildWordPhrasePrompt,
  parseLookupResult,
  type LookupResult,
  type WordPhraseResult,
} from "@/lib/lookup";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { generateContent } from "@/lib/generateContent";
import { getTopics, type Topic } from "@/lib/topics";
import {
  getVocabRecordByHeadword,
  saveVocabRecord,
  type NewVocabRecord,
  type VocabRecord,
  type VocabRecordUpdate,
} from "@/lib/vocabRecords";

const MAX_PRESELECTED_TOPICS = 2;

// Loose match instead of a strict case-insensitive equality: the AI is
// prompted with a fixed English topic list ("Food & Drink", "Social/Casual",
// ...) but doesn't always echo it back byte-for-byte (different punctuation,
// "and" instead of "&", extra whitespace) — collapse both sides down to
// bare alphanumerics before comparing so those variations still match.
function normalizeTopicName(name: string): string {
  return name
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function preselectTopicIds(suggestedTopics: string[], topics: Topic[]): string[] {
  const selected: string[] = [];
  for (const suggestion of suggestedTopics) {
    if (selected.length >= MAX_PRESELECTED_TOPICS) break;
    const normalizedSuggestion = normalizeTopicName(suggestion);
    const match = topics.find((t) => normalizeTopicName(t.name) === normalizedSuggestion);
    if (match && !selected.includes(match.id)) selected.push(match.id);
  }
  return selected;
}

export default function LookupPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();

  const [queryText, setQueryText] = useState("");
  const [result, setResult] = useState<LookupResult | null>(null);
  const [existingRecord, setExistingRecord] = useState<VocabRecord | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [saveModalOpen, setSaveModalOpen] = useState(false);

  useEffect(() => {
    if (!user) return;
    getTopics(user.uid).then(setTopics).catch(() => setTopics([]));
  }, [user]);

  async function handleLookup() {
    const trimmed = queryText.trim();
    if (!trimmed || !user || !settings) return;

    setLoading(true);
    setError(null);
    setResult(null);
    setExistingRecord(null);

    try {
      const inputType = detectInputType(trimmed);

      if (inputType !== "sentence") {
        const cached = await getVocabRecordByHeadword(user.uid, trimmed, settings.targetLanguage);
        if (cached) {
          setExistingRecord(cached);
          setResult({
            kind: "wordPhrase",
            headword: cached.headword,
            inputType: cached.inputType === "sentence" ? "word" : cached.inputType,
            ipa: cached.ipa,
            meaning: cached.meaning,
            examples: cached.examples,
            definition: cached.definition,
            synonyms: cached.synonyms,
            suggestedTopics: [],
            cefrLevel: cached.cefrLevel,
          });
          setLoading(false);
          return;
        }
      }

      const activeConfig = settings.providers[settings.activeProvider];
      if (!activeConfig.apiKeyCiphertext) {
        setError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
        setLoading(false);
        return;
      }

      const prompt =
        inputType === "sentence"
          ? buildSentencePrompt(trimmed)
          : buildWordPhrasePrompt(trimmed, settings.targetLanguage);

      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });

      const json = parseAiJsonObject(response.text);
      setResult(parseLookupResult(json, inputType, trimmed));
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  function buildDraftRecord(wordResult: WordPhraseResult): VocabRecord {
    const now = new Date().toISOString();
    return {
      id: "",
      headword: wordResult.headword,
      inputType: wordResult.inputType,
      ipa: wordResult.ipa,
      meaning: wordResult.meaning,
      examples: wordResult.examples,
      personalNotes: "",
      topicIds: preselectTopicIds(wordResult.suggestedTopics, topics),
      // No "ngữ cảnh" (context) setting exists in Cài đặt yet — default to
      // "general" for every web-saved record (see Task 5's plan note).
      targetLanguage: settings?.targetLanguage ?? "english",
      cefrLevel: wordResult.cefrLevel ?? "b1",
      activeContext: "general",
      createdAt: now,
      updatedAt: now,
      nextReviewAt: null,
      sm2Repetitions: 0,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
      definition: wordResult.definition,
      synonyms: wordResult.synonyms,
    };
  }

  async function handleSaveNewRecord(updates: VocabRecordUpdate) {
    if (!user || result?.kind !== "wordPhrase") return;
    const draft = buildDraftRecord(result);
    // Re-check right before writing: the AI can return a re-cased/re-lemmatized
    // headword that differs from what the user typed, so the cache-check done
    // at lookup time (against the raw query) can miss a record that actually
    // already exists under this exact headword — this second check catches
    // that case, and a concurrent save from another tab, before creating a
    // duplicate document.
    const duplicate = await getVocabRecordByHeadword(user.uid, draft.headword, draft.targetLanguage);
    if (duplicate) {
      setSaveModalOpen(false);
      setExistingRecord(duplicate);
      return;
    }
    const { id: _omit, ...newRecord }: { id: string } & NewVocabRecord = { ...draft, ...updates };
    const newId = await saveVocabRecord(user.uid, newRecord);
    setSaveModalOpen(false);
    setExistingRecord({ ...draft, ...updates, id: newId });
  }

  if (authLoading) {
    return (
      <div>
        <h2 className="scr-title">Tra từ</h2>
        <p>Đang tải…</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Tra từ</h2>
        <p className="scr-sub">Đăng nhập để tra từ.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) {
    return (
      <div>
        <h2 className="scr-title">Tra từ</h2>
        <p>Đang tải…</p>
      </div>
    );
  }

  return (
    <div>
      <h2 className="scr-title">Tra từ</h2>
      <p className="scr-sub">Tra từ, cụm từ, hoặc cả câu — dịch bằng AI theo Cài đặt của bạn.</p>
      <div className="lookup-search-row">
        <input
          value={queryText}
          onChange={(e) => setQueryText(e.target.value)}
          placeholder="Nhập từ, cụm từ, hoặc câu…"
        />
        <button className="btn-primary" onClick={() => void handleLookup()} disabled={loading || !queryText.trim()}>
          {loading ? "Đang tra…" : "Tra từ"}
        </button>
      </div>
      {error && <p role="alert">{error}</p>}
      {result?.kind === "sentence" && (
        <div className="lookup-result-card">
          <p className="lookup-sentence-original">{result.original}</p>
          <p className="lookup-sentence-translation">{result.translation}</p>
        </div>
      )}
      {result?.kind === "wordPhrase" && (
        <div className="lookup-result-card">
          {existingRecord && (
            <p className="lookup-already-saved">Từ này đã có trong Ngân hàng từ vựng của bạn.</p>
          )}
          <div className="lookup-headword-row">
            <h3>{result.headword}</h3>
            {result.cefrLevel && <span className="cefr-pill">{result.cefrLevel.toUpperCase()}</span>}
          </div>
          {result.ipa && <p className="lookup-ipa">{result.ipa}</p>}
          <p className="lookup-meaning">{result.meaning}</p>
          {result.definition && <p className="lookup-definition">{result.definition}</p>}
          {result.synonyms.length > 0 && (
            <div className="chip-row">
              {result.synonyms.map((s) => (
                <span className="chip" key={s}>
                  {s}
                </span>
              ))}
            </div>
          )}
          {result.examples.map((ex, i) => (
            <p className="lookup-example" key={i}>
              {ex}
            </p>
          ))}
          {!existingRecord && (
            <button className="btn-primary lookup-save-btn" onClick={() => setSaveModalOpen(true)}>
              Lưu vào Ngân hàng từ vựng
            </button>
          )}
        </div>
      )}
      {saveModalOpen && result?.kind === "wordPhrase" && (
        <EditVocabModal
          record={buildDraftRecord(result)}
          topics={topics}
          mode="create"
          onClose={() => setSaveModalOpen(false)}
          onSave={handleSaveNewRecord}
        />
      )}
    </div>
  );
}
