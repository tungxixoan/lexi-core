"use client";

import { useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { detectInputType } from "@/lib/inputDetector";
import {
  buildSentencePrompt,
  buildWordPhrasePrompt,
  parseLookupResult,
  type LookupResult,
} from "@/lib/lookup";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import { generateContent } from "@/lib/generateContent";
import { getVocabRecordByHeadword, type VocabRecord } from "@/lib/vocabRecords";

export default function LookupPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings } = useSettingsContext();

  const [queryText, setQueryText] = useState("");
  const [result, setResult] = useState<LookupResult | null>(null);
  const [existingRecord, setExistingRecord] = useState<VocabRecord | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
        </div>
      )}
    </div>
  );
}
