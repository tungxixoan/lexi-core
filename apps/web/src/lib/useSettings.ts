"use client";

import { useCallback, useEffect, useState } from "react";
import { DEFAULT_SETTINGS, getSettings, saveSettings, type UserSettings } from "./settings";

export function useSettings(uid: string | null) {
  const [settings, setSettings] = useState<UserSettings | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!uid) {
      setSettings(DEFAULT_SETTINGS);
      setError(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    getSettings(uid)
      .then((s) => setSettings(s))
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)))
      .finally(() => setLoading(false));
  }, [uid]);

  const save = useCallback(
    async (next: UserSettings) => {
      if (!uid) return;
      await saveSettings(uid, next);
      setSettings(next);
    },
    [uid]
  );

  return { settings, loading, error, save };
}
