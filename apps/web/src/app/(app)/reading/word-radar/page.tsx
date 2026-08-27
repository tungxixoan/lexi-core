"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { HighlightedText } from "@/components/shared/HighlightedText";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { ttsLanguageCode } from "@/lib/pronunciation";

const MAX_INPUT_LENGTH = 3000;

export default function WordRadarPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [text, setText] = useState("");
  const [scannedText, setScannedText] = useState<string | null>(null);
  const [scanId, setScanId] = useState(0);

  useEffect(() => {
    if (!user) return;
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {});
  }, [user]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Quét từ vựng</h2>
        <p className="scr-sub">Đăng nhập để quét văn bản.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  const knownRecords = records.filter((r) => r.targetLanguage === settings.targetLanguage);
  const activeConfig = settings.providers[settings.activeProvider];
  const aiEnabled = Boolean(activeConfig.apiKeyCiphertext);
  const ttsLang = ttsLanguageCode(settings.targetLanguage);

  return (
    <div>
      <h2 className="scr-title">Quét từ vựng</h2>
      <p className="scr-sub">
        Dán bất kỳ văn bản nào — tô sáng ngay từ bạn đã học, và (nếu bật AI) nhận bản dịch cùng gợi
        ý từ mới.
      </p>

      <div className="word-radar-input-card">
        <textarea
          className="word-radar-textarea"
          value={text}
          maxLength={MAX_INPUT_LENGTH}
          placeholder="Dán văn bản vào đây…"
          onChange={(e) => setText(e.target.value)}
        />
        <div className="word-radar-input-footer">
          <span className="word-radar-char-count">
            {text.length} / {MAX_INPUT_LENGTH}
          </span>
          <button
            type="button"
            className="btn-primary"
            disabled={text.length === 0}
            onClick={() => {
              setScannedText(text);
              setScanId((id) => id + 1);
            }}
          >
            Quét
          </button>
        </div>
      </div>

      {scannedText !== null && (
        <>
          <div className="word-radar-result-card">
            <p className="suggestions-title">Văn bản</p>
            <HighlightedText
              key={scanId}
              text={scannedText}
              variant="interactive"
              records={knownRecords}
              ttsLanguage={ttsLang}
            />
          </div>

          {aiEnabled ? (
            <VocabSuggestionsSection
              key={scanId}
              text={scannedText}
              existingRecords={knownRecords}
              topics={topics}
              includeTranslation
            />
          ) : (
            <p className="word-radar-ai-hint">Bật AI trong Cài đặt để nhận gợi ý từ mới.</p>
          )}
        </>
      )}
    </div>
  );
}
