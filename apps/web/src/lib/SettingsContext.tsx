"use client";

import { createContext, useContext, type ReactNode } from "react";
import { useAuthUser } from "./useAuthUser";
import { useSettings } from "./useSettings";
import type { UserSettings } from "./settings";

interface SettingsContextValue {
  settings: UserSettings | null;
  loading: boolean;
  error: string | null;
  save: (next: UserSettings) => Promise<void>;
}

const SettingsContext = createContext<SettingsContextValue | null>(null);

export function SettingsProvider({ children }: { children: ReactNode }) {
  const { user } = useAuthUser();
  const value = useSettings(user?.uid ?? null);
  return <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>;
}

export function useSettingsContext(): SettingsContextValue {
  const ctx = useContext(SettingsContext);
  if (!ctx) {
    throw new Error("useSettingsContext must be used within a SettingsProvider");
  }
  return ctx;
}
