"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import {
  findKnownHeadwords,
  buildVocabSuggestionsPrompt,
  parseVocabSuggestions,
} from "@/lib/vocabSuggestions";
import { buildVocabRecordDraft } from "@/lib/vocabDraft";
import {
  getVocabRecordByHeadword,
  saveVocabRecord,
  type VocabRecord,
  type VocabRecordUpdate,
} from "@/lib/vocabRecords";
import { EditVocabModal } from "@/components/vocab-bank/EditVocabModal";
import type { Topic } from "@/lib/topics";
import type { WordPhraseResult } from "@/lib/lookup";

interface VocabSuggestionsSectionProps {
  text: string;
  existingRecords: VocabRecord[];
  topics: Topic[];
}

export function VocabSuggestionsSection({ text, existingRecords, topics }: VocabSuggestionsSectionProps) {
  const { user } = useAuthUser();
  const { settings } = useSettingsContext();

  const [suggestions, setSuggestions] = useState<WordPhraseResult[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [savedHeadwords, setSavedHeadwords] = useState<Set<string>>(new Set());
  const [dismissedHeadwords, setDismissedHeadwords] = useState<Set<string>>(new Set());
  const [editingSuggestion, setEditingSuggestion] = useState<WordPhraseResult | null>(null);
  const [bulkSaveMessage, setBulkSaveMessage] = useState<string | null>(null);
  const [bulkSaveError, setBulkSaveError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  const activeConfig = settings?.providers[settings.activeProvider];
  const aiEnabled = Boolean(activeConfig?.apiKeyCiphertext);

  useEffect(() => {
    if (!aiEnabled || !settings || !activeConfig?.apiKeyCiphertext) return;
    let cancelled = false;

    async function load() {
      setError(null);
      setSuggestions(null);
      try {
        const knownHeadwords = findKnownHeadwords(text, existingRecords);
        const prompt = buildVocabSuggestionsPrompt(text, settings!.targetLanguage, knownHeadwords);
        const response = await generateContent({
          provider: settings!.activeProvider,
          model: activeConfig!.model,
          apiKeyCiphertext: activeConfig!.apiKeyCiphertext!,
          prompt,
        });
        if (cancelled) return;
        const json = parseAiJsonObject(response.text);
        setSuggestions(parseVocabSuggestions(json));
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : String(err));
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aiEnabled, text, reloadKey]);

  if (!aiEnabled) return null;

  async function handleSaveOne(updates: VocabRecordUpdate) {
    if (!user || !editingSuggestion || !settings) return;
    const draft = buildVocabRecordDraft(editingSuggestion, topics, settings.targetLanguage);
    const merged = { ...draft, ...updates };
    const duplicate = await getVocabRecordByHeadword(user.uid, merged.headword, merged.targetLanguage);
    if (!duplicate) {
      const { id: _omit, ...newRecord } = merged;
      await saveVocabRecord(user.uid, newRecord);
    }
    setSavedHeadwords((prev) => new Set(prev).add(editingSuggestion.headword));
    setEditingSuggestion(null);
  }

  async function handleSaveAll() {
    if (!user || !settings || !suggestions) return;
    const toSave = suggestions.filter(
      (s) => !savedHeadwords.has(s.headword) && !dismissedHeadwords.has(s.headword)
    );
    let savedCount = 0;
    setBulkSaveError(null);
    try {
      for (const s of toSave) {
        const draft = buildVocabRecordDraft(s, topics, settings.targetLanguage);
        const duplicate = await getVocabRecordByHeadword(user.uid, draft.headword, draft.targetLanguage);
        if (!duplicate) {
          const { id: _omit, ...newRecord } = draft;
          await saveVocabRecord(user.uid, newRecord);
          savedCount++;
          setSavedHeadwords((prev) => new Set(prev).add(s.headword));
        }
      }
      setBulkSaveMessage(`Đã lưu ${savedCount}/${toSave.length} từ.`);
    } catch (err) {
      setBulkSaveMessage(`Đã lưu ${savedCount}/${toSave.length} từ.`);
      setBulkSaveError(err instanceof Error ? err.message : String(err));
    }
  }

  const visible = (suggestions ?? []).filter((s) => !dismissedHeadwords.has(s.headword));
  const hasUnsaved = visible.some((s) => !savedHeadwords.has(s.headword));

  return (
    <div className="suggestions-section">
      <div className="suggestions-header">
        <span className="suggestions-title">Gợi ý từ mới</span>
        {hasUnsaved && suggestions && (
          <button type="button" className="link-btn" onClick={() => void handleSaveAll()}>
            Lưu tất cả
          </button>
        )}
      </div>
      {bulkSaveMessage && <p className="suggestions-bulk-message">{bulkSaveMessage}</p>}
      {bulkSaveError && <p role="alert">Không thể lưu tất cả: {bulkSaveError}</p>}
      {error && (
        <div>
          <p role="alert">Không tải được gợi ý từ mới: {error}</p>
          <button type="button" className="link-btn" onClick={() => setReloadKey((k) => k + 1)}>
            Thử lại
          </button>
        </div>
      )}
      {!error && suggestions === null && <p>Đang tải gợi ý…</p>}
      {!error && suggestions !== null && visible.length === 0 && <p>Không có gợi ý mới.</p>}
      {!error && visible.length > 0 && (
        <div className="suggestion-cards">
          {visible.map((s) => {
            const isSaved = savedHeadwords.has(s.headword);
            return (
              <div className="suggestion-card" key={s.headword}>
                <button
                  type="button"
                  className="suggestion-card-main"
                  disabled={isSaved}
                  onClick={() => setEditingSuggestion(s)}
                >
                  <span className="suggestion-headword">{s.headword}</span>
                  <span className="suggestion-meaning">
                    {s.ipa && <span>{s.ipa} • </span>}
                    {s.meaning}
                  </span>
                  {s.cefrLevel && <span className="cefr-pill">{s.cefrLevel.toUpperCase()}</span>}
                </button>
                {isSaved ? (
                  <span className="suggestion-saved-mark">✔</span>
                ) : (
                  <button
                    type="button"
                    className="closex"
                    aria-label="Bỏ qua gợi ý này"
                    onClick={() =>
                      setDismissedHeadwords((prev) => new Set(prev).add(s.headword))
                    }
                  >
                    ✕
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}
      {editingSuggestion && settings && (
        <EditVocabModal
          record={buildVocabRecordDraft(editingSuggestion, topics, settings.targetLanguage)}
          topics={topics}
          mode="create"
          onClose={() => setEditingSuggestion(null)}
          onSave={handleSaveOne}
        />
      )}
    </div>
  );
}
