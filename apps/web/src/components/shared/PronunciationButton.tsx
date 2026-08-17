"use client";

import { useState } from "react";
import { getPronunciationUrl, type TtsLanguage } from "@/lib/pronunciation";

interface PronunciationButtonProps {
  text: string;
  language: TtsLanguage | null;
  tier: "word" | "sentence";
}

export function PronunciationButton({ text, language, tier }: PronunciationButtonProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const [cachedUrl, setCachedUrl] = useState<string | null>(null);

  async function handlePlay(lang: TtsLanguage) {
    setError(false);
    setLoading(true);
    try {
      const url = cachedUrl ?? (await getPronunciationUrl({ text, language: lang, tier }));
      if (!cachedUrl) setCachedUrl(url);
      await new Audio(url).play();
    } catch {
      setError(true);
    } finally {
      setLoading(false);
    }
  }

  if (!language || !text.trim()) return null;

  return (
    <button
      type="button"
      className="pron-btn"
      onClick={() => void handlePlay(language)}
      disabled={loading}
      aria-label={`Nghe phát âm: ${text}`}
      title="Nghe phát âm"
    >
      {loading ? "…" : error ? "⚠️" : "🔊"}
    </button>
  );
}
