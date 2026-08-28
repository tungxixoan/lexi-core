"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { countVocabRecords } from "@/lib/vocabRecords";

export function VocabRecordCount() {
  const { user } = useAuthUser();
  const { settings } = useSettingsContext();
  const [count, setCount] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setError(null);
    if (!user || !settings) {
      setCount(null);
      return;
    }
    setCount(null);
    countVocabRecords(user.uid, settings.targetLanguage)
      .then(setCount)
      .catch((err: unknown) =>
        setError(err instanceof Error ? err.message : String(err))
      );
  }, [user, settings]);

  if (!user) return null;
  if (error) return <p role="alert">Lỗi đọc Firestore: {error}</p>;
  if (count === null) return <p>Đang tải số từ vựng…</p>;
  return <p>Bạn có {count} từ trong Ngân hàng từ vựng.</p>;
}
