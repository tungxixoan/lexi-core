import type { User } from "firebase/auth";

interface AccountSectionProps {
  user: User;
}

export function AccountSection({ user }: AccountSectionProps) {
  return (
    <section>
      <h3 className="scr-title">Tài khoản</h3>
      <p>{user.displayName}</p>
      <p>{user.email}</p>
    </section>
  );
}
