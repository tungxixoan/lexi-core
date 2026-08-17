"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

interface NavItem {
  href: string;
  label: string;
}

interface NavGroup {
  label: string | null;
  items: NavItem[];
}

const NAV_GROUPS: NavGroup[] = [
  {
    label: null,
    items: [
      { href: "/dashboard", label: "🏠 Tổng quan" },
      { href: "/lookup", label: "🔍 Tra từ" },
      { href: "/vocab-bank", label: "📚 Ngân hàng từ vựng" },
      { href: "/practice", label: "🎯 Ôn tập" },
    ],
  },
  { label: "Đọc", items: [{ href: "/reading", label: "📖 Đọc — tổng quan" }] },
  { label: "Nghe", items: [{ href: "/listening", label: "🎧 Nghe — tổng quan" }] },
  { label: "Khác", items: [{ href: "/settings", label: "⚙️ Cài đặt" }] },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="sidebar">
      <div className="brand">
        <span className="leaf" />
        LexiCore
      </div>
      <nav className="sidenav">
        {NAV_GROUPS.map((group, i) => (
          <div key={group.label ?? `group-${i}`}>
            {group.label && <div className="grp-label">{group.label}</div>}
            {group.items.map((item) => {
              const isActive = pathname === item.href || pathname.startsWith(`${item.href}/`);
              return (
                <Link key={item.href} href={item.href} className={isActive ? "active" : undefined}>
                  {item.label}
                </Link>
              );
            })}
          </div>
        ))}
      </nav>
    </aside>
  );
}
