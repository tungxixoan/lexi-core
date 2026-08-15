# Plan 3 / Phase A — Bloom Foundation + Vocab Bank Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Next.js web app (`apps/web/`) its first real screens: the Bloom design-system tokens, the persistent-sidebar app shell, and the Ngân hàng từ vựng (Vocab Bank) list + Side Drawer detail screen, reading real Firestore data from the existing `users/{uid}/vocab_records` and `users/{uid}/topics` collections that the Flutter mobile app already writes to.

**Architecture:** Global CSS custom properties (`apps/web/src/styles/bloom.css`) implement the Bloom color tokens for light/dark/system themes plus the reusable `.app-frame`/`.sidebar`/`.vb-*` component classes, copied verbatim from the approved mockup artifact. A `(app)` Next.js route group wraps every real screen in an `AppShell` (sidebar + main content area); the Vocab Bank page is the first (and for this phase, only) screen mounted inside it. All data access is client-side via the Firebase JS SDK, matching the existing Plan 1 pattern (`getFirebaseDb()`) — no new Cloud Functions in this phase.

**Tech Stack:** Next.js 16 (App Router) on `apps/web/`, React 19, Firebase JS SDK v12 (`firebase/firestore`), Vitest + React Testing Library + jsdom (existing setup), plain CSS (no framework/preprocessor — matches the repo's "no custom webfont, dependency-free build" choice).

## Global Constraints

- All user-facing text is Vietnamese, matching every existing component (`SignInButton`, `VocabRecordCount`) and the approved Bloom mockup copy exactly where quoted.
- Font stack: `"Trebuchet MS", "Segoe UI", -apple-system, system-ui, sans-serif` (headings 700, body 400) — no webfont files, no new npm dependency for typography.
- Import alias `@/` maps to `apps/web/src/` (already configured in `tsconfig.json` and `vitest.config.mts`) — use it for all cross-file imports.
- Every new/changed file gets a colocated Vitest test (`*.test.ts` / `*.test.tsx`), following the existing mock style: `vi.mock("firebase/firestore", ...)`, `vi.mock("./firebase", () => ({ getFirebaseDb: vi.fn(() => "mock-db") }))`.
- Firestore documents for `vocab_records` and `topics` are written by the Flutter app's `SyncService` as plain JSON (dates as ISO 8601 **strings**, not Firestore `Timestamp` objects, and enum fields as their Dart `.name` lowercase string) — TypeScript types in this plan mirror that shape exactly; do not introduce `Timestamp` parsing.
- No new Cloud Functions, no new backend calls in this phase — Firestore reads/writes only, client-side, via `getFirebaseDb()`. Pronunciation playback (the drawer's speaker icon) and the "Sửa" (edit) flow are explicitly deferred (see Non-Goals below); render their UI per the mockup but leave them inert.
- Verify each task with `npm --prefix apps/web test` (full suite) and finish the plan with `npm --prefix apps/web run typecheck` and `npm --prefix apps/web run build`.

## Scope for this phase (and what's deferred)

This is Phase A of Plan 3 (see `docs/superpowers/specs/2026-08-11-react-web-redesign-design.md` §10.3): design tokens + app shell + Vocab Bank + Side Drawer only. Explicitly **not** in this phase (deferred to later phases per the spec's own dependency ordering):

- Dashboard, Tra từ (Lookup), Luyện tập (Practice hub), Đọc/Nghe hubs, Cài đặt — later phases. Their sidebar links are wired (real hrefs) but the routes don't exist yet in this phase, so they 404 until built — expected during incremental frontend build, not a regression.
- The 5 nav items that only appear "for demo purposes" in the mockup (Đọc & gõ, Part 7 · Làm bài, Part 7 · Kết quả, Nghe chép, Nghe hiểu — each suffixed "(ví dụ)" in the mockup's sidebar HTML) are **not** real sidebar entries. They're reached from their hub's mode cards once those hubs exist, not from the sidebar directly. The production sidebar has 7 items, not the mockup demo's 12.
- The sidebar's `.card-mini` streak widget (mockup shows hardcoded "7🔥 ngày liên tiếp") — streak computation is a Dashboard/stats concern, not built here.
- "Gợi ý từ mới" (new-word suggestion grid, spec §7.2) below the Vocab Bank list — in Flutter this is a generic `VocabSuggestionsSection` widget fed by a suggestion source elsewhere (Word Radar, a just-finished practice session); no such source exists yet in the web app. Building a real trigger for it here would mean inventing scope with no upstream data. Deferred to whichever later phase first produces suggestion-worthy results.
- Pronunciation playback (the drawer's `▶` speaker button) — needs the `getPronunciation` onCall function (Plan 2, already deployed) wired up; spec §10.3 attaches that dependency to the *next* phase (Dashboard/Lookup/Practice hub), not this one. Button renders per the mockup but is inert.
- "Sửa" (edit) — no edit-form mockup exists anywhere in the spec. Button renders (disabled, with a tooltip) but does nothing yet.
- Responsive/mobile breakpoints — spec's own non-goal, desktop-only for all phases.

---

## Task 1: Bloom design tokens

**Files:**
- Create: `apps/web/src/styles/bloom.css`
- Modify: `apps/web/src/app/layout.tsx`
- Test: `apps/web/src/styles/bloom.test.ts`

**Interfaces:**
- Produces: CSS custom properties (`--bg-a`, `--bg-b`, `--surface`, `--surface-2`, `--surface-3`, `--ink`, `--ink-soft`, `--ink-faint`, `--accent`, `--accent-ink`, `--sage`, `--sage-bg`, `--amber`, `--amber-bg`, `--success`, `--success-bg`, `--danger`, `--danger-bg`, `--border`) available globally to every component from Task 2 onward.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/styles/bloom.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const css = readFileSync(fileURLToPath(new URL("./bloom.css", import.meta.url)), "utf-8");

describe("bloom.css design tokens", () => {
  it("defines the light-mode Bloom color tokens with exact values", () => {
    expect(css).toContain("--bg-a: #FFF3EE;");
    expect(css).toContain("--bg-b: #F1EEFF;");
    expect(css).toContain("--surface: #FFFFFF;");
    expect(css).toContain("--accent: #C9587A;");
    expect(css).toContain("--sage: #6F9A87;");
    expect(css).toContain("--danger: #C15B4E;");
    expect(css).toContain("--border: #EFDDE3;");
  });

  it("defines the dark-mode tokens under both a prefers-color-scheme block and a [data-theme=dark] block", () => {
    expect(css).toContain('@media (prefers-color-scheme: dark) {');
    expect(css).toContain(':root:not([data-theme="light"])');
    expect(css).toContain(':root[data-theme="dark"]');
    expect(css).toContain("--accent: #E693AC;");
  });

  it("sets the Bloom font stack on body with no external font import", () => {
    expect(css).toContain(
      'font-family: "Trebuchet MS", "Segoe UI", -apple-system, system-ui, sans-serif;'
    );
    expect(css).not.toContain("@import");
    expect(css).not.toContain("fonts.googleapis.com");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `bloom.css` does not exist yet (`ENOENT`).

- [ ] **Step 3: Create the tokens file**

Create `apps/web/src/styles/bloom.css`:

```css
:root {
  --bg-a: #FFF3EE;
  --bg-b: #F1EEFF;
  --surface: #FFFFFF;
  --surface-2: #FBF3F7;
  --surface-3: #F5E9EF;
  --ink: #362A33;
  --ink-soft: #7A6B76;
  --ink-faint: #A493A0;
  --accent: #C9587A;
  --accent-ink: #FFFFFF;
  --sage: #6F9A87;
  --sage-bg: #E7F1EB;
  --amber: #D9A441;
  --amber-bg: #FBF0DC;
  --success: #4C8F6E;
  --success-bg: #E7F1EB;
  --danger: #C15B4E;
  --danger-bg: #FBEAE6;
  --border: #EFDDE3;
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg-a: #241923;
    --bg-b: #1C1B2B;
    --surface: #2A2028;
    --surface-2: #322730;
    --surface-3: #3A2C36;
    --ink: #F3E9EE;
    --ink-soft: #C2AEB9;
    --ink-faint: #8B7783;
    --accent: #E693AC;
    --accent-ink: #2A121B;
    --sage: #8FC1AA;
    --sage-bg: #203228;
    --amber: #E8C173;
    --amber-bg: #3A2E17;
    --success: #7DCBA6;
    --success-bg: #1E3128;
    --danger: #E38A79;
    --danger-bg: #3A241F;
    --border: #43323C;
  }
}

:root[data-theme="dark"] {
  --bg-a: #241923;
  --bg-b: #1C1B2B;
  --surface: #2A2028;
  --surface-2: #322730;
  --surface-3: #3A2C36;
  --ink: #F3E9EE;
  --ink-soft: #C2AEB9;
  --ink-faint: #8B7783;
  --accent: #E693AC;
  --accent-ink: #2A121B;
  --sage: #8FC1AA;
  --sage-bg: #203228;
  --amber: #E8C173;
  --amber-bg: #3A2E17;
  --success: #7DCBA6;
  --success-bg: #1E3128;
  --danger: #E38A79;
  --danger-bg: #3A241F;
  --border: #43323C;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  padding: 24px;
  color: var(--ink);
  background:
    radial-gradient(1200px 700px at 10% -10%, var(--bg-a), transparent),
    radial-gradient(1200px 800px at 100% 10%, var(--bg-b), transparent),
    var(--surface-2);
  font-family: "Trebuchet MS", "Segoe UI", -apple-system, system-ui, sans-serif;
  line-height: 1.5;
}

.mono {
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  font-variant-numeric: tabular-nums;
}
```

- [ ] **Step 4: Import it globally in the root layout**

Modify `apps/web/src/app/layout.tsx` (add the import; nothing else changes):

```tsx
import type { ReactNode } from "react";
import "@/styles/bloom.css";

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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS (3/3 new tests), plus the existing suite still green.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/styles/bloom.css apps/web/src/styles/bloom.test.ts apps/web/src/app/layout.tsx
git commit -m "feat(web): add Bloom design-system color tokens"
```

---

## Task 2: App shell — sidebar + routing, and relocate the Plan 1 verification page

**Files:**
- Create: `apps/web/src/components/shell/Sidebar.tsx`
- Create: `apps/web/src/components/shell/Sidebar.test.tsx`
- Create: `apps/web/src/components/shell/AppShell.tsx`
- Create: `apps/web/src/components/shell/AppShell.test.tsx`
- Create: `apps/web/src/app/(app)/layout.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append shell CSS)
- Modify: `apps/web/src/app/page.tsx` (becomes a redirect)
- Modify: `apps/web/src/app/page.test.tsx` → move to `apps/web/src/app/dev/verify/page.test.tsx`
- Create: `apps/web/src/app/dev/verify/page.tsx` (the old `HomePage` content, relocated)

**Interfaces:**
- Consumes: nothing new (uses `next/navigation`'s `usePathname`, `next/link`'s `Link`).
- Produces: `<Sidebar />` (no props), `<AppShell>{children: ReactNode}</AppShell>` — both used by every later screen task via the `(app)` route group layout.

- [ ] **Step 1: Write the failing Sidebar test**

Create `apps/web/src/components/shell/Sidebar.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { Sidebar } from "./Sidebar";
import { usePathname } from "next/navigation";

vi.mock("next/navigation", () => ({
  usePathname: vi.fn(),
}));

describe("Sidebar", () => {
  it("renders all 7 nav items with the 3 group labels, and marks the current route active", () => {
    vi.mocked(usePathname).mockReturnValue("/vocab-bank");
    render(<Sidebar />);

    expect(screen.getByText("Đọc")).toBeInTheDocument();
    expect(screen.getByText("Nghe")).toBeInTheDocument();
    expect(screen.getByText("Khác")).toBeInTheDocument();

    const active = screen.getByRole("link", { name: /Ngân hàng từ vựng/ });
    expect(active).toHaveClass("active");
    expect(active).toHaveAttribute("href", "/vocab-bank");

    const inactive = screen.getByRole("link", { name: /Tổng quan/ });
    expect(inactive).not.toHaveClass("active");
    expect(inactive).toHaveAttribute("href", "/dashboard");
  });

  it("renders exactly 7 nav links (not the mockup's 12 demo entries)", () => {
    vi.mocked(usePathname).mockReturnValue("/vocab-bank");
    render(<Sidebar />);
    expect(screen.getAllByRole("link")).toHaveLength(7);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./Sidebar` does not exist.

- [ ] **Step 3: Implement Sidebar**

Create `apps/web/src/components/shell/Sidebar.tsx`:

```tsx
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
      { href: "/practice", label: "🎯 Luyện tập" },
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Write the failing AppShell test**

Create `apps/web/src/components/shell/AppShell.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { AppShell } from "./AppShell";
import { usePathname } from "next/navigation";

vi.mock("next/navigation", () => ({
  usePathname: vi.fn(() => "/vocab-bank"),
}));

describe("AppShell", () => {
  it("renders the sidebar brand and the children inside the main content area", () => {
    render(
      <AppShell>
        <p>Screen content</p>
      </AppShell>
    );
    expect(screen.getByText("LexiCore")).toBeInTheDocument();
    const main = screen.getByText("Screen content").closest("main");
    expect(main).toHaveClass("main");
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./AppShell` does not exist.

- [ ] **Step 7: Implement AppShell**

Create `apps/web/src/components/shell/AppShell.tsx`:

```tsx
import type { ReactNode } from "react";
import { Sidebar } from "./Sidebar";

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="app-frame">
      <Sidebar />
      <main className="main">{children}</main>
    </div>
  );
}
```

- [ ] **Step 8: Append the shell CSS to bloom.css**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.app-frame {
  max-width: 1440px;
  margin: 0 auto;
  min-height: calc(100vh - 48px);
  background: var(--surface);
  border-radius: 26px;
  border: 1px solid var(--border);
  box-shadow: 0 32px 76px -36px rgba(120, 70, 90, 0.38);
  overflow: hidden;
  display: flex;
  position: relative;
}

.app-frame::before {
  content: "";
  position: absolute;
  width: 320px;
  height: 320px;
  border-radius: 50%;
  background: radial-gradient(circle, color-mix(in srgb, var(--accent) 16%, transparent), transparent 70%);
  top: -140px;
  right: -90px;
  pointer-events: none;
}

.sidebar {
  width: 226px;
  flex-shrink: 0;
  padding: 24px 14px;
  display: flex;
  flex-direction: column;
  background: var(--surface-2);
  border-right: 1px solid var(--border);
  z-index: 1;
}

.brand {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 18px;
  font-weight: 700;
  margin-bottom: 22px;
  padding: 0 8px;
}

.brand .leaf {
  width: 22px;
  height: 22px;
  border-radius: 50% 50% 50% 4px;
  background: linear-gradient(135deg, var(--accent), var(--sage));
  flex-shrink: 0;
}

.sidenav {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.sidenav a {
  font-size: 13.5px;
  padding: 10px 13px;
  border-radius: 999px;
  color: var(--ink-soft);
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 9px;
  text-decoration: none;
}

.sidenav a.active {
  background: var(--surface);
  color: var(--accent);
  box-shadow: 0 4px 14px -6px rgba(120, 70, 90, 0.3);
}

.sidenav .grp-label {
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--ink-faint);
  font-weight: 700;
  margin: 14px 0 4px 13px;
}

.main {
  flex: 1;
  min-width: 0;
  padding: 30px 36px;
  z-index: 1;
  overflow-y: auto;
}

h2.scr-title {
  font-size: 21px;
  margin: 0 0 4px;
}

p.scr-sub {
  color: var(--ink-soft);
  font-size: 13.5px;
  margin: 0 0 22px;
}
```

- [ ] **Step 9: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 10: Wire the `(app)` route group layout**

Create `apps/web/src/app/(app)/layout.tsx`:

```tsx
import type { ReactNode } from "react";
import { AppShell } from "@/components/shell/AppShell";

export default function AppGroupLayout({ children }: { children: ReactNode }) {
  return <AppShell>{children}</AppShell>;
}
```

- [ ] **Step 11: Relocate the Plan 1 verification page out of `/`**

Create `apps/web/src/app/dev/verify/page.tsx` with exactly the current contents of `apps/web/src/app/page.tsx`:

```tsx
import { SignInButton } from "@/components/SignInButton";
import { VocabRecordCount } from "@/components/VocabRecordCount";
import { GenerateContentPanel } from "@/components/GenerateContentPanel";

export default function HomePage() {
  return (
    <main>
      <h1>LexiCore Web</h1>
      <SignInButton />
      <VocabRecordCount />
      <GenerateContentPanel />
    </main>
  );
}
```

Move `apps/web/src/app/page.test.tsx` to `apps/web/src/app/dev/verify/page.test.tsx` unchanged (same file contents — the `import HomePage from "./page"` relative import still resolves correctly at the new location).

- [ ] **Step 12: Turn `/` into a redirect, with its own test**

Replace `apps/web/src/app/page.tsx`:

```tsx
import { redirect } from "next/navigation";

export default function HomePage() {
  redirect("/vocab-bank");
}
```

Create `apps/web/src/app/page.test.tsx` (a new, small test replacing the one just moved):

```tsx
import { describe, expect, it, vi } from "vitest";
import { redirect } from "next/navigation";
import HomePage from "./page";

vi.mock("next/navigation", () => ({
  redirect: vi.fn(),
}));

describe("HomePage (/)", () => {
  it("redirects to /vocab-bank", () => {
    HomePage();
    expect(redirect).toHaveBeenCalledWith("/vocab-bank");
  });
});
```

- [ ] **Step 13: Run the full suite to verify everything passes**

Run: `npm --prefix apps/web test`
Expected: PASS — includes the relocated `dev/verify/page.test.tsx`, the new `page.test.tsx`, and both shell tests.

- [ ] **Step 14: Commit**

```bash
git add apps/web/src/components/shell apps/web/src/app/\(app\) apps/web/src/app/dev apps/web/src/app/page.tsx apps/web/src/app/page.test.tsx apps/web/src/styles/bloom.css
git commit -m "feat(web): add Bloom app shell with sidebar routing, move Plan 1 scaffold to /dev/verify"
```

---

## Task 3: Vocab Bank + Topics data layer

**Files:**
- Modify: `apps/web/src/lib/vocabRecords.ts`
- Modify: `apps/web/src/lib/vocabRecords.test.ts`
- Create: `apps/web/src/lib/topics.ts`
- Create: `apps/web/src/lib/topics.test.ts`

**Interfaces:**
- Produces: `VocabRecord` type, `getVocabRecords(uid): Promise<VocabRecord[]>`, `deleteVocabRecord(uid, id): Promise<void>` (all from `@/lib/vocabRecords`); `Topic` type, `getTopics(uid): Promise<Topic[]>` (from `@/lib/topics`). Used by Task 4 (`resolveTopicNames` needs `Topic`), Task 5 (list screen), Task 6 (drawer + delete).

- [ ] **Step 1: Write the failing tests**

Replace `apps/web/src/lib/vocabRecords.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { deleteDoc, doc, getDocs, orderBy, query } from "firebase/firestore";
import { countVocabRecords, deleteVocabRecord, getVocabRecords } from "./vocabRecords";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  doc: vi.fn(() => "mock-doc-ref"),
  deleteDoc: vi.fn(),
  getDocs: vi.fn(),
  orderBy: vi.fn(() => "mock-order-by"),
  query: vi.fn(() => "mock-query"),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

describe("countVocabRecords", () => {
  it("returns the number of documents in the user's vocab_records subcollection", async () => {
    vi.mocked(getDocs).mockResolvedValue({ size: 3 } as never);
    const count = await countVocabRecords("user-123");
    expect(count).toBe(3);
  });
});

const RECORD = {
  id: "abc",
  headword: "meticulous",
  inputType: "word",
  ipa: "/məˈtɪkjələs/",
  meaning: "tỉ mỉ, cẩn thận",
  examples: ["She reviewed the contract with meticulous attention to detail."],
  personalNotes: "",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "c1",
  activeContext: "business",
  createdAt: "2026-08-10T00:00:00.000Z",
  updatedAt: "2026-08-10T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 0,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

describe("getVocabRecords", () => {
  it("queries the subcollection ordered by createdAt desc and returns the raw docs", async () => {
    vi.mocked(getDocs).mockResolvedValue({
      docs: [{ data: () => RECORD }],
    } as never);

    const records = await getVocabRecords("user-123");

    expect(orderBy).toHaveBeenCalledWith("createdAt", "desc");
    expect(query).toHaveBeenCalledWith("mock-collection-ref", "mock-order-by");
    expect(records).toEqual([RECORD]);
  });
});

describe("deleteVocabRecord", () => {
  it("deletes the record document by id", async () => {
    await deleteVocabRecord("user-123", "abc");
    expect(doc).toHaveBeenCalledWith("mock-db", "users", "user-123", "vocab_records", "abc");
    expect(deleteDoc).toHaveBeenCalledWith("mock-doc-ref");
  });
});
```

Create `apps/web/src/lib/topics.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { getDocs } from "firebase/firestore";
import { getTopics } from "./topics";

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(() => "mock-collection-ref"),
  getDocs: vi.fn(),
}));

vi.mock("./firebase", () => ({
  getFirebaseDb: vi.fn(() => "mock-db"),
}));

const TOPIC = {
  id: "business",
  name: "Business",
  emoji: "💼",
  isPredefined: true,
  createdAt: "2026-01-01T00:00:00.000",
};

describe("getTopics", () => {
  it("returns the user's topics subcollection docs", async () => {
    vi.mocked(getDocs).mockResolvedValue({ docs: [{ data: () => TOPIC }] } as never);
    const topics = await getTopics("user-123");
    expect(topics).toEqual([TOPIC]);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm --prefix apps/web test`
Expected: FAIL — `getVocabRecords`/`deleteVocabRecord` not exported yet, `./topics` does not exist.

- [ ] **Step 3: Implement**

Replace `apps/web/src/lib/vocabRecords.ts`:

```ts
import { collection, deleteDoc, doc, getDocs, orderBy, query } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";

export interface VocabRecord {
  id: string;
  headword: string;
  inputType: "word" | "phrase" | "sentence";
  ipa: string;
  meaning: string;
  examples: string[];
  personalNotes: string;
  topicIds: string[];
  targetLanguage: "vietnamese" | "english" | "chinese" | "korean" | "japanese";
  cefrLevel: "a1" | "a2" | "b1" | "b2" | "c1" | "c2";
  activeContext:
    | "general"
    | "business"
    | "technology"
    | "travel"
    | "foodAndDrink"
    | "health"
    | "academic"
    | "socialCasual";
  createdAt: string;
  updatedAt: string;
  nextReviewAt: string | null;
  sm2Repetitions: number;
  sm2EaseFactor: number;
  sm2Interval: number;
  definition: string;
  synonyms: string[];
}

export async function countVocabRecords(uid: string): Promise<number> {
  const col = collection(getFirebaseDb(), "users", uid, "vocab_records");
  const snapshot = await getDocs(col);
  return snapshot.size;
}

export async function getVocabRecords(uid: string): Promise<VocabRecord[]> {
  const col = collection(getFirebaseDb(), "users", uid, "vocab_records");
  const q = query(col, orderBy("createdAt", "desc"));
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => d.data() as VocabRecord);
}

export async function deleteVocabRecord(uid: string, id: string): Promise<void> {
  const ref = doc(getFirebaseDb(), "users", uid, "vocab_records", id);
  await deleteDoc(ref);
}
```

Create `apps/web/src/lib/topics.ts`:

```ts
import { collection, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";

export interface Topic {
  id: string;
  name: string;
  emoji: string;
  isPredefined: boolean;
  createdAt: string;
}

export async function getTopics(uid: string): Promise<Topic[]> {
  const col = collection(getFirebaseDb(), "users", uid, "topics");
  const snapshot = await getDocs(col);
  return snapshot.docs.map((d) => d.data() as Topic);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/vocabRecords.ts apps/web/src/lib/vocabRecords.test.ts apps/web/src/lib/topics.ts apps/web/src/lib/topics.test.ts
git commit -m "feat(web): add Vocab Bank and Topics Firestore read/delete functions"
```

**Note:** this assumes `users/{uid}/topics` is already populated (synced from the Flutter app's local predefined-topics seed, per `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`'s `_seedTopics`). The web app deliberately does not duplicate that seeding logic — reasonable for this single-account personal project where the Flutter app has already run at least once.

---

## Task 4: Vocab Bank presentation helpers (mastery %, due label, topic-name resolution)

**Files:**
- Create: `apps/web/src/lib/vocabDisplay.ts`
- Create: `apps/web/src/lib/vocabDisplay.test.ts`

**Interfaces:**
- Consumes: `Topic` type from `@/lib/topics` (Task 3).
- Produces: `computeMasteryPercent(record): number`, `formatDueLabel(nextReviewAt, now): string`, `resolveTopicNames(topicIds, topics): string[]` — all used by Task 5 (list) and Task 6 (drawer).

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/vocabDisplay.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { computeMasteryPercent, formatDueLabel, resolveTopicNames } from "./vocabDisplay";
import type { Topic } from "./topics";

describe("computeMasteryPercent", () => {
  it("is 0% for a brand-new word (0 repetitions, default ease)", () => {
    expect(computeMasteryPercent({ sm2Repetitions: 0, sm2EaseFactor: 2.5 })).toBe(0);
  });

  it("is 100% at 6+ repetitions with the default (max) ease factor", () => {
    expect(computeMasteryPercent({ sm2Repetitions: 6, sm2EaseFactor: 2.5 })).toBe(100);
    expect(computeMasteryPercent({ sm2Repetitions: 9, sm2EaseFactor: 2.5 })).toBe(100);
  });

  it("is 50% halfway through the repetitions ramp at max ease", () => {
    expect(computeMasteryPercent({ sm2Repetitions: 3, sm2EaseFactor: 2.5 })).toBe(50);
  });

  it("scales down when ease factor has dropped (many correct-but-difficult reviews)", () => {
    expect(computeMasteryPercent({ sm2Repetitions: 6, sm2EaseFactor: 1.3 })).toBe(52);
  });
});

describe("formatDueLabel", () => {
  const now = new Date("2026-08-15T12:00:00.000Z");

  it("shows 'chưa ôn' when the word has never been reviewed", () => {
    expect(formatDueLabel(null, now)).toBe("chưa ôn");
  });

  it("shows 'ôn hôm nay' when the review date is today or in the past", () => {
    expect(formatDueLabel("2026-08-15T00:00:00.000Z", now)).toBe("ôn hôm nay");
    expect(formatDueLabel("2026-08-10T00:00:00.000Z", now)).toBe("ôn hôm nay");
  });

  it("shows the day count when the review date is in the future", () => {
    expect(formatDueLabel("2026-08-18T12:00:00.000Z", now)).toBe("ôn sau 3 ngày");
  });
});

describe("resolveTopicNames", () => {
  const topics: Topic[] = [
    { id: "business", name: "Business", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
    { id: "academic", name: "Academic", emoji: "🎓", isPredefined: true, createdAt: "2026-01-01" },
  ];

  it("maps known topic ids to their names", () => {
    expect(resolveTopicNames(["business", "academic"], topics)).toEqual(["Business", "Academic"]);
  });

  it("falls back to the raw id for an unknown topic", () => {
    expect(resolveTopicNames(["ghost-id"], topics)).toEqual(["ghost-id"]);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./vocabDisplay` does not exist.

- [ ] **Step 3: Implement**

Create `apps/web/src/lib/vocabDisplay.ts`:

```ts
import type { Topic } from "./topics";

const FULL_MASTERY_REPETITIONS = 6;
const DEFAULT_EASE_FACTOR = 2.5;

/**
 * SM-2 doesn't produce a 0-100 mastery score directly (see
 * ComputeSm2UseCase in the Flutter app — it only tracks repetitions/ease/
 * interval). This blends how many successful reviews a word has survived
 * with how easy those reviews were, so a word reviewed many times but
 * always graded "barely correct" reads as partially mastered rather than
 * fully mastered.
 */
export function computeMasteryPercent(record: {
  sm2Repetitions: number;
  sm2EaseFactor: number;
}): number {
  const repetitionsRatio =
    Math.min(record.sm2Repetitions, FULL_MASTERY_REPETITIONS) / FULL_MASTERY_REPETITIONS;
  const easeRatio = record.sm2EaseFactor / DEFAULT_EASE_FACTOR;
  return Math.round(100 * repetitionsRatio * easeRatio);
}

export function formatDueLabel(nextReviewAt: string | null, now: Date): string {
  if (nextReviewAt === null) return "chưa ôn";
  const due = new Date(nextReviewAt);
  if (due.getTime() <= now.getTime()) return "ôn hôm nay";
  const days = Math.ceil((due.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  return `ôn sau ${days} ngày`;
}

export function resolveTopicNames(topicIds: string[], topics: Topic[]): string[] {
  const byId = new Map(topics.map((t) => [t.id, t.name]));
  return topicIds.map((id) => byId.get(id) ?? id);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/vocabDisplay.ts apps/web/src/lib/vocabDisplay.test.ts
git commit -m "feat(web): add Vocab Bank presentation helpers (mastery %, due label, topic names)"
```

---

## Task 5: Vocab Bank list screen

**Files:**
- Create: `apps/web/src/app/(app)/vocab-bank/page.tsx`
- Create: `apps/web/src/app/(app)/vocab-bank/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css` (append vocab-bank list CSS)

**Interfaces:**
- Consumes: `useAuthUser` (`@/lib/useAuthUser`), `getVocabRecords`/`VocabRecord` (`@/lib/vocabRecords`), `getTopics`/`Topic` (`@/lib/topics`), `formatDueLabel` (`@/lib/vocabDisplay`), `SignInButton` (`@/components/SignInButton`).
- Produces: the `/vocab-bank` route. Task 6 modifies this same file to add row-selection and the Side Drawer.

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/app/(app)/vocab-bank/page.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import VocabBankPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const RECORD_DUE_TODAY = {
  id: "1",
  headword: "relocate",
  inputType: "word",
  ipa: "",
  meaning: "dời đi",
  examples: [],
  personalNotes: "",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "b2",
  activeContext: "business",
  createdAt: "2026-08-01T00:00:00.000Z",
  updatedAt: "2026-08-01T00:00:00.000Z",
  nextReviewAt: "2026-01-01T00:00:00.000Z",
  sm2Repetitions: 1,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "",
  synonyms: [],
};

const RECORD_NOT_DUE = {
  ...RECORD_DUE_TODAY,
  id: "2",
  headword: "meticulous",
  meaning: "tỉ mỉ, cẩn thận",
  cefrLevel: "c1",
  nextReviewAt: "2099-01-01T00:00:00.000Z",
};

describe("VocabBankPage", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false });
    render(<VocabBankPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });

  it("loads and lists the user's vocab records with due labels", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);

    expect(await screen.findByText("relocate")).toBeInTheDocument();
    expect(screen.getByText("meticulous")).toBeInTheDocument();
    expect(screen.getByText("Tất cả (2)")).toBeInTheDocument();
    expect(screen.getByText("Cần ôn hôm nay (1)")).toBeInTheDocument();
  });

  it("filters to due-today words when that chip is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    fireEvent.click(screen.getByText("Cần ôn hôm nay (1)"));

    expect(screen.getByText("relocate")).toBeInTheDocument();
    expect(screen.queryByText("meticulous")).not.toBeInTheDocument();
  });

  it("shows an alert on a Firestore read error", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockRejectedValue(new Error("boom"));
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);

    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("boom"));
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./page` does not exist under `vocab-bank/`.

- [ ] **Step 3: Implement**

Create `apps/web/src/app/(app)/vocab-bank/page.tsx`:

```tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { formatDueLabel } from "@/lib/vocabDisplay";
import { SignInButton } from "@/components/SignInButton";

type FilterKey = "all" | "due" | `topic:${string}` | `cefr:${string}`;

export default function VocabBankPage() {
  const { user, loading: authLoading } = useAuthUser();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<FilterKey>("all");

  useEffect(() => {
    setError(null);
    if (!user) {
      setRecords(null);
      return;
    }
    setRecords(null);
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [user]);

  const now = useMemo(() => new Date(), [records]);

  const isDue = (r: VocabRecord) =>
    r.nextReviewAt === null || new Date(r.nextReviewAt).getTime() <= now.getTime();

  const topicChips = useMemo(() => {
    if (!records) return [];
    const idsWithWords = new Set(records.flatMap((r) => r.topicIds));
    return topics.filter((t) => idsWithWords.has(t.id));
  }, [records, topics]);

  const cefrChips = useMemo(() => {
    if (!records) return [];
    return Array.from(new Set(records.map((r) => r.cefrLevel))).sort();
  }, [records]);

  const filtered = useMemo(() => {
    if (!records) return [];
    if (filter === "all") return records;
    if (filter === "due") return records.filter(isDue);
    if (filter.startsWith("topic:")) {
      const topicId = filter.slice("topic:".length);
      return records.filter((r) => r.topicIds.includes(topicId));
    }
    if (filter.startsWith("cefr:")) {
      const level = filter.slice("cefr:".length);
      return records.filter((r) => r.cefrLevel === level);
    }
    return records;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [records, filter, now]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Ngân hàng từ vựng</h2>
        <p className="scr-sub">Đăng nhập để xem từ vựng đã lưu.</p>
        <SignInButton />
      </div>
    );
  }

  if (error) return <p role="alert">Lỗi đọc Firestore: {error}</p>;
  if (records === null) return <p>Đang tải từ vựng…</p>;

  return (
    <>
      <h2 className="scr-title">Ngân hàng từ vựng</h2>
      <p className="scr-sub">{records.length} từ trong Ngân hàng từ vựng.</p>
      <div className="vb-toolbar">
        <button className={`vb-chip${filter === "all" ? " active" : ""}`} onClick={() => setFilter("all")}>
          Tất cả ({records.length})
        </button>
        <button className={`vb-chip${filter === "due" ? " active" : ""}`} onClick={() => setFilter("due")}>
          Cần ôn hôm nay ({records.filter(isDue).length})
        </button>
        {topicChips.map((t) => (
          <button
            key={t.id}
            className={`vb-chip${filter === `topic:${t.id}` ? " active" : ""}`}
            onClick={() => setFilter(`topic:${t.id}`)}
          >
            {t.name}
          </button>
        ))}
        {cefrChips.map((level) => (
          <button
            key={level}
            className={`vb-chip${filter === `cefr:${level}` ? " active" : ""}`}
            onClick={() => setFilter(`cefr:${level}`)}
          >
            {level.toUpperCase()}
          </button>
        ))}
      </div>
      <div className="vb-shell">
        <div className="vb-list-wrap">
          {filtered.length === 0 && <p>Không có từ nào phù hợp.</p>}
          {filtered.map((r) => (
            <div key={r.id} className="vrow">
              <span className="dot">{r.cefrLevel.toUpperCase()}</span>
              <span className="word">{r.headword}</span>
              <span className="meaning">{r.meaning}</span>
              <span className="due">{formatDueLabel(r.nextReviewAt, now)}</span>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
```

- [ ] **Step 4: Append the list CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.vb-toolbar {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.vb-chip {
  font-size: 12.5px;
  font-weight: 700;
  padding: 7px 14px;
  border-radius: 999px;
  background: var(--surface-2);
  border: 1px solid var(--border);
  color: var(--ink-soft);
  cursor: pointer;
}

.vb-chip.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #fff;
}

.vb-shell {
  display: flex;
  gap: 0;
  border: 1px solid var(--border);
  border-radius: 20px;
  overflow: hidden;
}

.vb-list-wrap {
  flex: 1;
  min-width: 0;
  padding: 6px;
}

.vrow {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 12px;
  border-radius: 14px;
  cursor: pointer;
}

.vrow:hover {
  background: var(--surface-2);
}

.vrow .dot {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--sage-bg);
  color: var(--sage);
  font-size: 10.5px;
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.vrow .word {
  font-weight: 700;
  font-size: 14.5px;
}

.vrow .meaning {
  color: var(--ink-soft);
  font-size: 13px;
  margin-left: 6px;
}

.vrow .due {
  margin-left: auto;
  font-size: 11.5px;
  color: var(--ink-faint);
}

.vrow.selected {
  background: var(--surface-3);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/src/app/(app)/vocab-bank" apps/web/src/styles/bloom.css
git commit -m "feat(web): add Vocab Bank list screen with filter chips"
```

---

## Task 6: Side Drawer (vocab detail) + wiring row selection and delete

**Files:**
- Create: `apps/web/src/components/vocab-bank/VocabDrawer.tsx`
- Create: `apps/web/src/components/vocab-bank/VocabDrawer.test.tsx`
- Modify: `apps/web/src/app/(app)/vocab-bank/page.tsx` (add selection state + drawer + delete)
- Modify: `apps/web/src/app/(app)/vocab-bank/page.test.tsx` (add selection/delete test cases)
- Modify: `apps/web/src/styles/bloom.css` (append drawer CSS)

**Interfaces:**
- Consumes: `VocabRecord` (`@/lib/vocabRecords`), `Topic` (`@/lib/topics`), `computeMasteryPercent`/`resolveTopicNames` (`@/lib/vocabDisplay`), `deleteVocabRecord` (`@/lib/vocabRecords`).
- Produces: `<VocabDrawer record topics onClose onDelete />`.

- [ ] **Step 1: Write the failing VocabDrawer test**

Create `apps/web/src/components/vocab-bank/VocabDrawer.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { VocabDrawer } from "./VocabDrawer";
import type { VocabRecord } from "@/lib/vocabRecords";
import type { Topic } from "@/lib/topics";

const RECORD: VocabRecord = {
  id: "1",
  headword: "meticulous",
  inputType: "word",
  ipa: "/məˈtɪkjələs/",
  meaning: "tỉ mỉ, cẩn thận",
  examples: ["She reviewed the contract with meticulous attention to detail."],
  personalNotes: "Hay gặp trong đề TOEIC Part 7.",
  topicIds: ["business"],
  targetLanguage: "english",
  cefrLevel: "c1",
  activeContext: "business",
  createdAt: "2026-08-01T00:00:00.000Z",
  updatedAt: "2026-08-01T00:00:00.000Z",
  nextReviewAt: null,
  sm2Repetitions: 3,
  sm2EaseFactor: 2.5,
  sm2Interval: 1,
  definition: "Showing great attention to detail.",
  synonyms: ["thorough", "careful"],
};

const TOPICS: Topic[] = [
  { id: "business", name: "Kinh doanh", emoji: "💼", isPredefined: true, createdAt: "2026-01-01" },
];

describe("VocabDrawer", () => {
  it("renders the headword, IPA, CEFR pill, meaning, examples, synonyms, resolved topic names, and notes", () => {
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={vi.fn()} />);

    expect(screen.getByRole("heading", { name: "meticulous" })).toBeInTheDocument();
    expect(screen.getByText("/məˈtɪkjələs/")).toBeInTheDocument();
    expect(screen.getByText("C1")).toBeInTheDocument();
    expect(screen.getByText("tỉ mỉ, cẩn thận")).toBeInTheDocument();
    expect(
      screen.getByText(/She reviewed the contract with meticulous attention to detail\./)
    ).toBeInTheDocument();
    expect(screen.getByText("thorough")).toBeInTheDocument();
    expect(screen.getByText("Kinh doanh")).toBeInTheDocument();
    expect(screen.getByText("Hay gặp trong đề TOEIC Part 7.")).toBeInTheDocument();
  });

  it("shows the computed mastery percentage", () => {
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={vi.fn()} />);
    // sm2Repetitions=3, sm2EaseFactor=2.5 -> 50% (see vocabDisplay.test.ts)
    expect(screen.getByText("50%")).toBeInTheDocument();
  });

  it("calls onClose when the close button is clicked", () => {
    const onClose = vi.fn();
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={onClose} onDelete={vi.fn()} />);
    fireEvent.click(screen.getByLabelText("Đóng"));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it("calls onDelete when Xoá is clicked", () => {
    const onDelete = vi.fn();
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={onDelete} />);
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));
    expect(onDelete).toHaveBeenCalledOnce();
  });

  it("renders Sửa as disabled (deferred — no edit-flow mockup exists yet)", () => {
    render(<VocabDrawer record={RECORD} topics={TOPICS} onClose={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByRole("button", { name: "Sửa" })).toBeDisabled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix apps/web test`
Expected: FAIL — `./VocabDrawer` does not exist.

- [ ] **Step 3: Implement VocabDrawer**

Create `apps/web/src/components/vocab-bank/VocabDrawer.tsx`:

```tsx
"use client";

import type { Topic } from "@/lib/topics";
import type { VocabRecord } from "@/lib/vocabRecords";
import { computeMasteryPercent, resolveTopicNames } from "@/lib/vocabDisplay";

interface VocabDrawerProps {
  record: VocabRecord;
  topics: Topic[];
  onClose: () => void;
  onDelete: () => void;
}

export function VocabDrawer({ record, topics, onClose, onDelete }: VocabDrawerProps) {
  const mastery = computeMasteryPercent(record);
  const topicNames = resolveTopicNames(record.topicIds, topics);

  return (
    <aside className="vb-drawer">
      <div className="vb-drawer-inner">
        <div className="dh">
          <div className="titles">
            <h3>{record.headword}</h3>
            <div className="pr">{record.ipa}</div>
          </div>
          <span className="cefr-pill">{record.cefrLevel.toUpperCase()}</span>
          <button className="closex" onClick={onClose} aria-label="Đóng">
            ✕
          </button>
        </div>
        <div className="db">
          <details className="sect" open>
            <summary>Nghĩa &amp; định nghĩa</summary>
            <div className="ct">
              <p>{record.meaning}</p>
              {record.definition && <p style={{ fontStyle: "italic" }}>{record.definition}</p>}
            </div>
          </details>
          <details className="sect" open>
            <summary>Ví dụ</summary>
            <div className="ct">
              {record.examples.length === 0 && <p>Chưa có ví dụ.</p>}
              {record.examples.map((ex, i) => (
                <div className="ex-item" key={ex}>
                  {i + 1}. {ex}
                </div>
              ))}
            </div>
          </details>
          <details className="sect">
            <summary>Từ đồng nghĩa &amp; chủ đề</summary>
            <div className="ct">
              <div className="chip-row">
                {record.synonyms.map((s) => (
                  <span className="chip" key={s}>
                    {s}
                  </span>
                ))}
              </div>
              <div className="chip-row">
                {topicNames.map((name) => (
                  <span className="chip topic" key={name}>
                    {name}
                  </span>
                ))}
              </div>
            </div>
          </details>
          <details className="sect">
            <summary>Ghi chú của bạn</summary>
            <div className="ct">{record.personalNotes || "Chưa có ghi chú."}</div>
          </details>
        </div>
        <div className="df">
          <div className="pm">
            <div className="l">
              <span>Độ thành thạo</span>
              <span>{mastery}%</span>
            </div>
            <div className="ptrack">
              <div className="pfill" style={{ width: `${mastery}%` }} />
            </div>
          </div>
          <div className="fa">
            <button disabled title="Sắp ra mắt">
              Sửa
            </button>
            <button className="danger" onClick={onDelete}>
              Xoá
            </button>
          </div>
        </div>
      </div>
    </aside>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 5: Wire selection + delete into the Vocab Bank page**

Modify `apps/web/src/app/(app)/vocab-bank/page.tsx`:

Add to the imports:

```tsx
import { useEffect, useMemo, useState } from "react";
import { useAuthUser } from "@/lib/useAuthUser";
import { deleteVocabRecord, getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { formatDueLabel } from "@/lib/vocabDisplay";
import { SignInButton } from "@/components/SignInButton";
import { VocabDrawer } from "@/components/vocab-bank/VocabDrawer";
```

Add selection state right after the existing `filter` state:

```tsx
  const [selectedId, setSelectedId] = useState<string | null>(null);
```

Add a delete handler after the `filtered` memo:

```tsx
  const selected = records?.find((r) => r.id === selectedId) ?? null;

  const handleDelete = async (id: string) => {
    if (!user) return;
    if (!window.confirm("Xoá từ này khỏi Ngân hàng từ vựng?")) return;
    await deleteVocabRecord(user.uid, id);
    setRecords((prev) => (prev ? prev.filter((r) => r.id !== id) : prev));
    setSelectedId(null);
  };
```

Replace the `.vrow` row rendering to add the click handler and selected state:

```tsx
          {filtered.map((r) => (
            <div
              key={r.id}
              className={`vrow${r.id === selectedId ? " selected" : ""}`}
              onClick={() => setSelectedId(r.id)}
              role="button"
              tabIndex={0}
            >
              <span className="dot">{r.cefrLevel.toUpperCase()}</span>
              <span className="word">{r.headword}</span>
              <span className="meaning">{r.meaning}</span>
              <span className="due">{formatDueLabel(r.nextReviewAt, now)}</span>
            </div>
          ))}
```

Add the drawer right after the closing `</div>` of `.vb-list-wrap`, still inside `.vb-shell`:

```tsx
        {selected && (
          <VocabDrawer
            record={selected}
            topics={topics}
            onClose={() => setSelectedId(null)}
            onDelete={() => void handleDelete(selected.id)}
          />
        )}
```

- [ ] **Step 6: Add the selection/delete test cases**

Modify `apps/web/src/app/(app)/vocab-bank/page.test.tsx` — add these imports at the top:

```tsx
import { deleteVocabRecord } from "@/lib/vocabRecords";
```

and add `deleteVocabRecord: vi.fn()` to the existing `vi.mock("@/lib/vocabRecords", ...)` factory so it becomes:

```tsx
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn(), deleteVocabRecord: vi.fn() }));
```

Append these test cases inside the existing `describe("VocabBankPage", ...)` block:

```tsx
  it("opens the Side Drawer with the clicked word's detail when a row is clicked", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);

    render(<VocabBankPage />);
    await screen.findByText("relocate");

    fireEvent.click(screen.getByText("meticulous"));

    expect(screen.getByRole("heading", { name: "meticulous" })).toBeInTheDocument();
  });

  it("deletes the selected word after confirmation and closes the drawer", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY, RECORD_NOT_DUE] as never);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.mocked(deleteVocabRecord).mockResolvedValue(undefined);
    vi.spyOn(window, "confirm").mockReturnValue(true);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("meticulous"));
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));

    await waitFor(() => expect(deleteVocabRecord).toHaveBeenCalledWith("u1", "2"));
    await waitFor(() => expect(screen.queryByText("meticulous")).not.toBeInTheDocument());
  });

  it("does not delete when the confirmation is cancelled", async () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" } as never, loading: false });
    vi.mocked(getVocabRecords).mockResolvedValue([RECORD_DUE_TODAY] as never);
    vi.mocked(getTopics).mockResolvedValue([]);
    vi.spyOn(window, "confirm").mockReturnValue(false);

    render(<VocabBankPage />);
    await screen.findByText("relocate");
    fireEvent.click(screen.getByText("relocate"));
    fireEvent.click(screen.getByRole("button", { name: "Xoá" }));

    expect(deleteVocabRecord).not.toHaveBeenCalled();
  });
```

- [ ] **Step 7: Run test to verify it passes**

Run: `npm --prefix apps/web test`
Expected: PASS.

- [ ] **Step 8: Append the drawer CSS**

Modify `apps/web/src/styles/bloom.css` — append at the end:

```css

.vb-drawer {
  width: 320px;
  flex-shrink: 0;
  background: var(--surface-2);
  border-left: 1px solid var(--border);
}

.vb-drawer-inner {
  width: 320px;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.dh {
  padding: 18px 20px 12px;
  background: linear-gradient(160deg, var(--surface), var(--surface-2));
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.dh .titles {
  flex: 1;
}

.dh h3 {
  margin: 0;
  font-size: 21px;
}

.dh .pr {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 4px;
  color: var(--ink-soft);
  font-family: ui-monospace, monospace;
  font-size: 12.5px;
}

.cefr-pill {
  font-size: 10px;
  font-weight: 800;
  background: var(--sage);
  color: #fff;
  padding: 3px 8px;
  border-radius: 999px;
}

.closex {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: var(--surface);
  border: 1px solid var(--border);
  cursor: pointer;
  color: var(--ink-soft);
  font-size: 11px;
}

.db {
  flex: 1;
  overflow-y: auto;
  padding: 14px 20px;
}

.sect {
  border-bottom: 1px solid var(--border);
}

.sect summary {
  list-style: none;
  cursor: pointer;
  padding: 11px 0;
  font-size: 11.5px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--ink-faint);
  font-weight: 700;
  display: flex;
  justify-content: space-between;
}

.sect summary::-webkit-details-marker {
  display: none;
}

.sect summary::after {
  content: "＋";
}

.sect[open] summary::after {
  content: "－";
}

.sect .ct {
  padding-bottom: 13px;
  font-size: 13.5px;
}

.ex-item {
  display: flex;
  gap: 7px;
  font-size: 13px;
  margin-bottom: 6px;
  padding: 8px 10px;
  background: var(--surface);
  border-radius: 9px;
}

.chip-row {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.chip {
  font-size: 11.5px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 4px 10px;
}

.chip.topic {
  background: var(--sage-bg);
  color: var(--sage);
  border: none;
  font-weight: 700;
}

.df {
  padding: 12px 20px;
  border-top: 1px solid var(--border);
}

.pm .l {
  font-size: 11px;
  color: var(--ink-soft);
  margin-bottom: 4px;
  display: flex;
  justify-content: space-between;
}

.ptrack {
  height: 6px;
  background: var(--surface);
  border-radius: 99px;
  overflow: hidden;
  margin-bottom: 10px;
}

.pfill {
  height: 100%;
  background: linear-gradient(90deg, var(--sage), var(--accent));
  border-radius: 99px;
}

.fa {
  display: flex;
  gap: 7px;
}

.fa button {
  flex: 1;
  font-size: 12px;
  font-weight: 700;
  border-radius: 999px;
  padding: 8px 0;
  cursor: pointer;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--ink);
}

.fa button.danger {
  color: var(--accent);
}

.fa button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
```

- [ ] **Step 9: Run the full suite**

Run: `npm --prefix apps/web test`
Expected: PASS — full suite green.

- [ ] **Step 10: Commit**

```bash
git add apps/web/src/components/vocab-bank "apps/web/src/app/(app)/vocab-bank" apps/web/src/styles/bloom.css
git commit -m "feat(web): add Vocab Bank Side Drawer with mastery bar and delete"
```

---

## Final verification (whole phase)

- [ ] Run the full test suite: `npm --prefix apps/web test` — expect all tests (existing Plan 1 tests + every test added in this plan) to pass.
- [ ] Run typecheck: `npm --prefix apps/web run typecheck` — expect no errors.
- [ ] Run the production build: `npm --prefix apps/web run build` — expect a clean build (this also catches any Server/Client Component boundary mistakes that tests alone wouldn't).
- [ ] Manually verify in the emulator or against production Firebase (per `CLAUDE.md`'s Deploy gotchas): `npm --prefix apps/web run dev`, sign in, confirm `/` redirects to `/vocab-bank`, the sidebar shows all 7 items with a pill highlight on "Ngân hàng từ vựng", the real saved words render with correct due labels, clicking a row opens the Side Drawer with correct accordion content and mastery %, and Xoá actually removes a (test) word from Firestore after confirming.
