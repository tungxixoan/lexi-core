# Flutter: Drop Hive, Firestore-Direct + Mandatory Sign-In — Design

## Context

This is sub-project 1 of a 3-item cleanup list the user approved (item #1: per-language `vocab_records` split; item #2: sync Flutter's AI settings to Firestore; item #3: production domain cutover from Flutter Web to the React web app). While scoping item #1, exploration revealed that Flutter's Firestore/Hive sync layer (`lib/core/services/sync_service.dart`) is a real-time bidirectional listener engine (Firestore `.snapshots().listen()` ↔ Hive `.watch().listen()`, with headword-based dedup and race-condition handling) — splitting `vocab_records` into per-language Firestore subcollections would require rewriting this engine to fan out across N collections, since Flutter's Hive box holds every language mixed together.

The user chose a cheaper, more robust alternative instead: **drop Hive entirely** and have Flutter read/write Firestore directly, exactly like `apps/web/` already does (web has no local-storage layer at all — confirmed by prior sessions and re-verified this session). This is decomposed into its own sub-project, sequenced **before** the per-language split (item #1 proper), since it removes the entire class of multi-collection sync-engine complexity that split would otherwise require.

**Current Flutter architecture, confirmed by reading the real source (not assumed):**
- `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart` implements the `VocabRepository` interface entirely against 2 local Hive boxes (`vocab_records`, `topics`) — no Firestore calls at all. Screens/providers consume vocab data exclusively through this interface, never touching Hive directly (with the 3 exceptions below).
- `lib/core/services/sync_service.dart` is the actual Firestore bridge: on `startSync(uid, ...)`, does a one-time batched push of all local Hive data to Firestore (`users/{uid}/vocab_records`, `users/{uid}/topics`), then opens bidirectional listeners (Firestore→Hive, Hive→Firestore) that keep both in sync in real time, including a headword+language dedup index to resolve race-condition duplicates.
- `lib/features/settings/presentation/providers/sync_notifier.dart` starts/stops `SyncService` based on `authNotifierProvider`'s auth state, and clears Hive when a different account signs in on the same device (to prevent cross-account data leakage) — this whole concern disappears once Firestore is the only data store, since every query is already scoped by `uid`.
- Two more direct-Hive touch points bypass the `VocabRepository` interface entirely: `lib/features/practice/presentation/providers/notification_notifier.dart`'s `_computeNextDueAt()` (scans the Hive box synchronously to schedule local reminder notifications) and `lib/core/di/app_providers.dart`'s `statsService` provider, which constructs `StatsService` with a direct `Hive.box<String>('vocab_records')` reference (used for the "Tiến độ học tập" progress screen's due/mastered/CEFR stats).
- **Grep-confirmed complete list — no other Hive usage exists anywhere in `lib/`:** `main.dart` (init + open boxes), `vocab_repository_impl.dart`, `sync_service.dart`, `sync_notifier.dart`, `notification_notifier.dart`, `app_providers.dart` (StatsService wiring). 6 files total.
- **Sign-in is currently optional on Flutter** — confirmed by grepping the router and vocab screens for any auth check: none exist. A user can use the entire Vocab Bank/Practice/Reading/Listening feature set fully offline, without ever signing in; signing in (via `AuthNotifier.signInWithGoogle()`, already implemented, reused as-is) is opt-in, purely to enable Firestore sync. Removing Hive removes this offline-guest mode entirely, since Firestore requires `users/{uid}/...` paths with no anonymous/local fallback in this app's design.

## Decisions made during brainstorming

- **Mandatory sign-in, confirmed with the user**: Flutter will require sign-in to use the app at all, same as `apps/web/` already does on every page. This is an accepted, deliberate product change — not an oversight.
- **Online-required for due-count/notification computations, confirmed with the user**: `notification_notifier.dart`'s reminder scheduling and `StatsService`'s progress stats will require network access once they read from Firestore instead of an in-memory Hive box (best-effort — a failed fetch skips that recompute cycle silently, doesn't crash, retries next trigger). Both are the same accepted tradeoff, applied consistently.
- **Existing real users' offline-only data must not be lost.** Any user who has already signed in at least once has their Hive data continuously mirrored to Firestore already (via the currently-running `SyncService`) — no migration needed for them. But a user who has **never** signed in has data that exists **only** in local Hive — see Architecture's one-time migration step below for how this is preserved.

## Architecture

### `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart` (rewritten)

Reimplemented against Firestore (`users/{uid}/vocab_records`, `users/{uid}/topics`), **keeping the exact same `VocabRepository` interface** (`save`, `getAll`, `getById`, `update`, `delete`, `existsByHeadword`, `getByHeadword`, `getTopics`, `addTopic`, `deleteTopic`) — every consumer of this interface (screens, use cases, providers) needs zero changes, since they already go through the abstraction rather than touching Hive directly. Needs the current signed-in `uid`, obtained via a Riverpod provider that reads `authNotifierProvider`'s resolved user (the router guarantees a non-null user by the time any vocab-consuming screen renders — see below).

### `lib/core/services/sync_service.dart` — deleted

No longer needed: with Firestore as the single source of truth, there is nothing to keep in sync.

### `lib/features/settings/presentation/providers/sync_notifier.dart` — deleted

No longer needed for the same reason. Its account-isolation logic (clearing Hive on a different account sign-in) becomes moot — Firestore queries are inherently scoped by `uid`, so switching accounts on the same device just means the next query targets a different path, no local state to clear.

### One-time Hive→Firestore migration on first sign-in (new, small piece of logic)

Preserves data for users who have never signed in before this update. On the mandatory sign-in screen, right after a successful `signInWithGoogle()` and before the app proceeds to any vocab-consuming screen: if the local Hive boxes (`vocab_records`/`topics`) still exist and are non-empty, batch-push their contents into the newly-authenticated `uid`'s Firestore collections (reusing the batching logic already proven in `SyncService.startSync`'s initial push, lines 56-96 of the current file — same 500-doc batch-commit chunking — but only the "push," not the ongoing bidirectional listeners, since those no longer exist). Then clear/stop using the Hive boxes. If Hive is empty (fresh install, or a user who already signed in before and thus already has this data on Firestore), skip the push entirely — no wasted writes.

### `lib/features/practice/presentation/providers/notification_notifier.dart` (modified)

`_computeNextDueAt()` changes from a synchronous Hive box scan to `await ref.read(vocabRepositoryProvider).getAll()`, then finds the earliest `nextReviewAt` in the returned list exactly as before. `reschedule()` (already `async`) awaits this. A Firestore failure here is caught and the notification schedule simply isn't updated this cycle — no crash, no user-visible error (this already runs silently/best-effort today).

### `lib/core/di/app_providers.dart`'s `statsService` provider + `lib/core/services/stats_service.dart` (modified)

`StatsService` changes from holding a `Box<String>` reference to holding a `VocabRepository` reference, and `computeStats()` becomes `Future<LearningStats>` instead of a synchronous return. `learningStats` provider (and its one consumer, the progress screen) becomes an `AsyncValue`-based provider (`FutureProvider` or equivalent), rendering a loading state while the Firestore fetch is in flight — same "Đang tải…" pattern already used everywhere else in this app when data is fetched asynchronously.

### `lib/core/router/app_router.dart` (modified) — mandatory sign-in gate

Add a top-level `redirect` callback on the router (checked before per-route redirects already in the file) that reads `authNotifierProvider`: if the resolved user is `null`, redirect to a sign-in screen (new, minimal — a centered "Đăng nhập với Google" button calling the existing `AuthNotifier.signInWithGoogle()`, styled consistently with the app's existing screens). Once signed in, the redirect stops firing and normal routing resumes. This mirrors exactly how every `apps/web/` page already gates on `useAuthUser()` — same pattern, different framework.

### `lib/main.dart` (modified)

Remove `Hive.initFlutter()` and the two `Hive.openBox<String>(...)` calls — no longer needed.

## Error Handling

- Firestore fetch failures in `notification_notifier.dart` / `StatsService`: caught, silently skip that computation cycle, retry on the next trigger (settings change, screen revisit) — matches this app's existing best-effort conventions for background/derived computations.
- Screens that used to read Hive synchronously (instant, no loading state) now show a brief "Đang tải…" state while Firestore resolves — consistent with how every `apps/web/` page and every other async Flutter screen in this app already handles this.
- One-time migration push failure (network drop mid-push): the sign-in screen shows a Vietnamese error and a "Thử lại" retry button rather than silently discarding local data or proceeding as if the push succeeded — this is the one path in this whole sub-project that touches irreplaceable local-only data, so it does not get best-effort silent-failure treatment like the others.

## Testing

- `VocabRepositoryFirestoreImpl`: one test per interface method, run against a Firestore test double (`fake_cloud_firestore` package, not currently a dependency — add it, or use the Firebase Local Emulator Suite if that proves more consistent with this app's existing test conventions; resolve which at plan-writing time by checking how this app's other Firestore-touching code is currently tested, if at all).
- One-time migration: Hive-has-data → pushes correctly to Firestore → Hive cleared afterward; Hive-is-empty → skipped, no Firestore writes attempted; push failure → error state shown, Hive left untouched (not cleared) so a retry can succeed later.
- Router: signed-out → redirected to sign-in screen; signed-in → normal routing, no redirect loop.
- `notification_notifier`/`StatsService`: Firestore failure path doesn't crash and leaves the prior schedule/stats value in place (or an empty/loading state if there was no prior value yet).
