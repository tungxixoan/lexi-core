import type { User } from "firebase/auth";

interface AccountSectionProps {
  user: User;
}

export function AccountSection({ user }: AccountSectionProps) {
  return (
    <section className="settings-card">
      <h3 className="scr-title">Tài khoản</h3>
      <p className="settings-account-name">{user.displayName}</p>
      <p className="settings-account-email">{user.email}</p>
    </section>
  );
}
