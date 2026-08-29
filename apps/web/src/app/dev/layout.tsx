import type { ReactNode } from "react";
import { SettingsProvider } from "@/lib/SettingsContext";

export default function DevLayout({ children }: { children: ReactNode }) {
  return <SettingsProvider>{children}</SettingsProvider>;
}
