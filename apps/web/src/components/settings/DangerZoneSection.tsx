"use client";

import { signOutOfFirebase } from "@/lib/auth";

export function DangerZoneSection() {
  return (
    <section>
      <h3 className="scr-title">Vùng nguy hiểm</h3>
      <button className="btn-danger" onClick={() => void signOutOfFirebase()}>
        Đăng xuất
      </button>
    </section>
  );
}
