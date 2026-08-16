"use client";

import { useEffect } from "react";
import type { ReactNode } from "react";
import { Sidebar } from "./Sidebar";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettings } from "@/lib/useSettings";

export function AppShell({ children }: { children: ReactNode }) {
  const { user } = useAuthUser();
  const { settings } = useSettings(user?.uid ?? null);

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
