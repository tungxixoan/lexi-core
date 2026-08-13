"use client";

import { useEffect, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { countVocabRecords } from "@/lib/vocabRecords";

export function VocabRecordCount() {
  const { user } = useAuthUser();
  const [count, setCount] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) {
      setCount(null);
      return;
    }
    countVocabRecords(user.uid)
      .then(setCount)
      .catch((err: unknown) =>
        setError(err instanceof Error ? err.message : String(err))
      );
  }, [user]);

  if (!user) return null;
  if (error) return <p role="alert">Lỗi đọc Firestore: {error}</p>;
  if (count === null) return <p>Đang tải số từ vựng…</p>;
  return <p>Bạn có {count} từ trong Ngân hàng từ vựng.</p>;
}
