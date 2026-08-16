import type { ReactNode } from "react";
import { AppShell } from "@/components/shell/AppShell";
import { SettingsProvider } from "@/lib/SettingsContext";

export default function AppGroupLayout({ children }: { children: ReactNode }) {
  return (
    <SettingsProvider>
      <AppShell>{children}</AppShell>
    </SettingsProvider>
  );
}
