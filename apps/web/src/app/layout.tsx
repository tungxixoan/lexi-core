import type { ReactNode } from "react";

export const metadata = {
  title: "LexiCore",
  description: "Personal Vietnamese-first language-learning app",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="vi">
      <body>{children}</body>
    </html>
  );
}
