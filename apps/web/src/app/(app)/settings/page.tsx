"use client";

import { useAuthUser } from "@/lib/useAuthUser";
import { useSettings } from "@/lib/useSettings";
import { SignInButton } from "@/components/SignInButton";
import { AccountSection } from "@/components/settings/AccountSection";
import { AiProviderSection } from "@/components/settings/AiProviderSection";
import { AppearanceSection } from "@/components/settings/AppearanceSection";
import { DangerZoneSection } from "@/components/settings/DangerZoneSection";

export default function SettingsPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading, error, save } = useSettings(user?.uid ?? null);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Cài đặt</h2>
        <p className="scr-sub">Đăng nhập để xem cài đặt.</p>
        <SignInButton />
      </div>
    );
  }

  if (error) return <p role="alert">Lỗi: {error}</p>;
  if (settingsLoading || !settings) return <p>Đang tải cài đặt…</p>;

  return (
    <>
      <h2 className="scr-title">Cài đặt</h2>
      <AccountSection user={user} />
      <AiProviderSection settings={settings} onSave={save} />
      <AppearanceSection settings={settings} onSave={save} />
      <DangerZoneSection />
    </>
  );
}
