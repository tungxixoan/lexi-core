"use client";

import Link from "next/link";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";

export default function ReadingHubPage() {
  const { user, loading: authLoading } = useAuthUser();

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Đọc</h2>
        <p className="scr-sub">Đăng nhập để luyện đọc.</p>
        <SignInButton />
      </div>
    );
  }

  return (
    <div>
      <h2 className="scr-title">Đọc</h2>
      <p className="scr-sub">Chọn một chế độ luyện đọc.</p>
      <div className="reading-hub-cards">
        <Link href="/reading/bilingual" className="reading-hub-card">
          <span className="reading-hub-card-title">✍️ Đọc &amp; gõ</span>
          <span className="reading-hub-card-desc">
            Gõ lại đoạn văn song ngữ được tạo từ từ vựng của bạn.
          </span>
        </Link>
        <Link href="/reading/part5" className="reading-hub-card">
          <span className="reading-hub-card-title">📝 Part 5 — Điền câu</span>
          <span className="reading-hub-card-desc">
            15 câu điền từ/ngữ pháp kiểu TOEIC, AI tạo theo chủ đề và độ khó bạn chọn.
          </span>
        </Link>
      </div>
    </div>
  );
}
