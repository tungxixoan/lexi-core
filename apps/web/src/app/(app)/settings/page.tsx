"use client";

import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { AccountSection } from "@/components/settings/AccountSection";
import { LanguageSection } from "@/components/settings/LanguageSection";
import { AiProviderSection } from "@/components/settings/AiProviderSection";
import { AppearanceSection } from "@/components/settings/AppearanceSection";
import { DangerZoneSection } from "@/components/settings/DangerZoneSection";

export default function SettingsPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading, error, save } = useSettingsContext();

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

  if (error) {
    return (
      <div>
        <h2 className="scr-title">Cài đặt</h2>
        <p role="alert">Lỗi: {error}</p>
      </div>
    );
  }

  if (settingsLoading || !settings) {
    return (
      <div>
        <h2 className="scr-title">Cài đặt</h2>
        <p>Đang tải cài đặt…</p>
      </div>
    );
  }

  return (
    <div className="settings-page">
      <h2 className="scr-title">Cài đặt</h2>
      <AccountSection user={user} />
      <LanguageSection settings={settings} onSave={save} />
      <AiProviderSection settings={settings} onSave={save} />
      <AppearanceSection settings={settings} onSave={save} />
      <DangerZoneSection />
    </div>
  );
}
