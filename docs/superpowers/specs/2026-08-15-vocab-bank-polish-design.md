# LexiCore — Vocab Bank Polish (full-width shell, multi-select pagination, edit modal)

**Date:** 2026-08-15
**Status:** Approved
**Covers:** Three follow-up enhancements to the already-shipped Plan 3 Phase A Vocab Bank screen (`apps/web/src/app/(app)/vocab-bank/page.tsx`), raised after live-testing the real screen against production data (290 saved words): (1) the app shell no longer caps at 1440px, (2) filter chips become multi-select with a client-side, cached, page-jumpable pagination mechanism, (3) a "Sửa" (edit) modal for vocab records, closing the gap Plan 3 Phase A deliberately left open.
**Depends on:** Plan 3 Phase A (`docs/superpowers/plans/2026-08-15-plan3-phase-a-bloom-foundation-vocab-bank.md`) — modifies files it created.

---

## 1. Goal

Address three pieces of live-testing feedback on the Vocab Bank screen, without re-opening any of Phase A's already-reviewed architecture:
1. The Bloom app-frame's 1440px cap leaves visible dead space (gradient background) on wide monitors.
2. The filter chips are single-select today; real usage wants combining multiple topics/levels at once, and the list needs to stop rendering all 290 rows into the DOM at once.
3. "Sửa" is currently a disabled stub (Phase A explicitly deferred it — no edit-form mockup existed at the time).

## 2. Scope & Non-Goals

**In scope:** the three items above, and only for the Vocab Bank screen.

**Non-goals:**
- **Font-size adjustment** — already planned as part of Cài đặt (Settings, Phase D) per the umbrella spec's screen #12 ("Giao diện: theme + font-size"). Not duplicated here.
- **Server-side/Firestore pagination** — explicitly rejected (see §3.2) in favor of client-side pagination over the already-fully-loaded 290-record set. Revisit only if the vocab bank ever grows large enough (thousands of records) that a single `getDocs()` becomes genuinely expensive — not the case at this project's scale.
- **Editing headword, IPA, definition, synonyms, CEFR level, or target language** — these stay read-only in the edit modal, matching the existing Flutter `SaveVocabSheet`'s treatment of the same fields (see §3.3).
- Any other screen (Dashboard, Lookup, Practice hub, Đọc/Nghe hubs, Cài đặt) — untouched.

---

## 3. Design

### 3.1 Full-width app shell

`.app-frame`'s `max-width: 1440px` cap is removed. The rounded/bordered/shadowed floating-card look (border-radius, border, box-shadow, the top-right gradient blob) is unchanged — only the width constraint goes, so the frame fills the available viewport width (minus the existing `body` padding) on any screen size.

### 3.2 Multi-select filters + client-side paginated/cached scroll list

**Filter semantics:**
- Three independent filter facets: `dueOnly` (boolean toggle — the "Cần ôn hôm nay" chip), `selectedTopicIds` (a `Set<string>`, multi-select), `selectedCefrLevels` (a `Set<string>`, multi-select).
- Within a facet: **OR** (selecting "Business" and "Technology" shows words in either topic).
- Across facets: **AND** (selecting a topic and a CEFR level shows only words matching both; "Cần ôn hôm nay" ANDs with whatever else is selected too).
- "Tất cả" is a reset action, not a fourth facet: clicking it clears `dueOnly`/`selectedTopicIds`/`selectedCefrLevels` to their empty state. It's visually "active" whenever all three are empty.
- A "Xoá lọc" (clear) chip/button appears whenever any facet is non-empty, and does the same reset as "Tất cả".

**Why client-side, not Firestore-side pagination:** at 290 records (small, personal-scale JSON documents), a single `getDocs()` — what Phase A already does — is fast and cheap. Building genuine server-side pagination for an arbitrary combination of multi-select facets would require a Firestore composite index per facet combination and per-combination cursor state, for zero real performance benefit at this data size. Instead, all 290 records stay loaded in memory (exactly as Phase A already built it — no change to `getVocabRecords`), and every piece of "loading"/"pagination" behavior described below operates on the in-memory array.

**List rendering — infinite-scroll-with-page-jump, entirely client-side:**
- The row list renders inside its own scroll container (fixed max-height, `overflow-y: auto`) — not the whole page scrolling.
- `PAGE_SIZE = 10`. A `visibleCount` state starts at 10 for the current filtered set and governs how many of the filtered+sorted records are actually rendered as DOM rows.
- Scrolling the container near its bottom bumps `visibleCount` by 10 (an `IntersectionObserver` on a sentinel row at the end of the rendered list, not a scroll-position listener) — this is a pure client-side reveal of already-loaded data, no network call.
- Changing any filter (topic/CEFR/due toggle, or Tất cả/Xoá lọc) resets `visibleCount` back to 10 for the new filtered set.
- A page-number bar renders below the scroll container: `totalPages = Math.ceil(filtered.length / PAGE_SIZE)`. Clicking page N: if `N * PAGE_SIZE <= visibleCount` (already revealed), scroll the container to that row's position immediately; otherwise first raise `visibleCount` to `N * PAGE_SIZE`, then scroll to the newly-revealed row once it's rendered.
- Because everything operates on the one in-memory `records` array, "already loaded" rows never need to be re-fetched when scrolling back up or re-visiting a lower page number — there is nothing to re-fetch.

### 3.3 Edit modal

Clicking "Sửa" in the Side Drawer opens a modal (not inline editing within the drawer). Editable fields and their UI, matching the existing Flutter `SaveVocabSheet` (`lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart`) field-for-field for consistency between apps:

| Field | Editable? | UI |
| --- | --- | --- |
| Nghĩa (meaning) | Yes | Text input |
| Ví dụ (examples) | Yes | List of text inputs, add/remove rows |
| Chủ đề (topicIds) | Yes, **max 2** | Multi-select chips (same visual language as the existing `.vb-chip`), capped at 2 selections like the Flutter picker |
| Ghi chú cá nhân (personalNotes) | Yes | Textarea |
| Từ gốc, phiên âm, định nghĩa, từ đồng nghĩa, CEFR, ngôn ngữ | No | Not shown as inputs in the modal (read-only, matches Flutter's treatment of definition/synonyms as display-only) |

Saving calls a new `updateVocabRecord(uid, id, updates)` Firestore write (does not exist yet — Task 3 of Phase A only built `getVocabRecords`/`getTopics`/`deleteVocabRecord`, no update path). On success, the modal closes and the in-memory `records` state updates in place (no refetch) so the list and drawer immediately reflect the edit.

---

## 4. Key Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Pagination data source | Client-side over the already-fully-loaded 290 records | Avoids Firestore composite-index/cursor complexity for combinatorial multi-select filters, at zero real cost given the data scale |
| Filter boolean logic | OR within a facet, AND across facets | Matches how the user actually wants to narrow results (e.g. "Business or Technology, but only C1 words") |
| Edit UI location | Modal, not inline-in-drawer | Simpler state management (drawer keeps showing the current record while an edit is in flight; modal has a clear Lưu/Huỷ boundary) |
| Edit modal field set | Meaning, examples, topics (max 2), personal notes only | Matches the existing Flutter `SaveVocabSheet` exactly — same fields editable, same max-2-topics constraint, same read-only fields |
| Font-size control | Not built here | Already planned in Cài đặt (Phase D) per the umbrella spec |

---

## 5. Deferred / Open Follow-ups

- If the Vocab Bank ever needs to scale past a few thousand records, revisit §3.2's client-side-only decision.
- A "sửa trước khi lưu" modal for the future Lookup (Tra từ) screen (Phase B) is a separate, not-yet-designed piece of work — this doc only covers editing an *already-saved* record from the Vocab Bank drawer.
