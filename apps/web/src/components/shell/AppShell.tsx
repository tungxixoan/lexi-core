"use client";

import { useEffect } from "react";
import type { ReactNode } from "react";
import { Sidebar } from "./Sidebar";
import { useSettingsContext } from "@/lib/SettingsContext";

export function AppShell({ children }: { children: ReactNode }) {
  const { settings } = useSettingsContext();

  useEffect(() => {
    if (!settings) return;
    if (settings.theme === "system") {
      document.documentElement.removeAttribute("data-theme");
    } else {
      document.documentElement.setAttribute("data-theme", settings.theme);
    }
  }, [settings]);

  const fontSizeClass =
    settings?.fontSize === "small"
      ? " fs-small"
      : settings?.fontSize === "large"
        ? " fs-large"
        : "";

  return (
    <div className={`app-frame${fontSizeClass}`}>
      <Sidebar />
      <main className="main">{children}</main>
    </div>
  );
}
