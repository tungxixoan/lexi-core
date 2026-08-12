"use client";

import { signInWithGoogle, signOutOfFirebase } from "@/lib/auth";
import { useAuthUser } from "@/lib/useAuthUser";

export function SignInButton() {
  const { user, loading } = useAuthUser();

  if (loading) {
    return <button disabled>Đang tải…</button>;
  }

  if (user) {
    return (
      <button onClick={() => void signOutOfFirebase()}>
        Đăng xuất ({user.displayName ?? user.email})
      </button>
    );
  }

  return (
    <button onClick={() => void signInWithGoogle()}>
      Đăng nhập với Google
    </button>
  );
}
