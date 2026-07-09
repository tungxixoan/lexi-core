# Sync Strategy Design

**Goal:** Bidirectional, conflict-safe synchronization of VocabBank data between local Hive storage and Cloud Firestore, supporting multi-device use with a single Google account.

**Scope:** `vocab_records`, `topics`, and user settings. Gemini API key is explicitly excluded from all sync.

---

## Architecture

```
Device (Hive / IndexedDB)  ←→  SyncService  ←→  Firestore
                                    ↑
                              AuthNotifier
                         (triggers start/stop)
```

- **Local store:** Hive boxes (`vocab_records`, `topics`) — persists in IndexedDB on web, file system on mobile.
- **Remote store:** Firestore path `users/{uid}/vocab_records/{id}` and `users/{uid}/topics/{id}`.
- **SyncService** is a plain Dart class instantiated once per sign-in session. It holds no global state between sessions.

---

## Sync Lifecycle

| Event | Action |
|-------|--------|
| User signs in | `startSync(uid, settings, onStatus)` called |
| User signs out | `stopSync()` called — all subscriptions cancelled |
| App restart (already signed in) | `startSync()` called on app init |

---

## Initial Push (Sign-in)

When `startSync()` is called, all local Hive data is batch-pushed to Firestore first.

**Design intent: local is authoritative at sign-in.** The assumption is that the device you are currently signing in on holds the most recent edits. Firestore data from other devices is authoritative only for words that do not exist locally.

**Batch size:** 500 ops per batch (Firestore limit). Large collections are chunked automatically.

**Fields pushed for user doc (settings):**
- `targetLanguage`, `activeContext`, `aiEnabled`, `targetCefrLevel`
- `geminiApiKey` is **never** included

---

## Bidirectional Real-Time Sync

After the initial push, two pairs of subscriptions run simultaneously:

### Firestore → Hive

Listens to Firestore `snapshots()`. For each `docChange`:

**Removed:**
- Delete from Hive
- Remove from headword index

**Modified / Added — same `id` exists in Hive:**
- Compare `updatedAt` timestamps
- Update Hive only if Firestore version is strictly newer

**Modified / Added — `id` not in Hive:**
- Check headword index for collision (see Duplicate Detection below)
- If no collision: write to Hive, add to index
- If collision: apply conflict resolution (see below)

### Hive → Firestore

Listens to `Box.watch()`. For each event:

**Deleted:**
- Delete corresponding Firestore doc
- Remove from headword index

**Added / Updated:**
- Write to Firestore via `doc.set(map)`
- Update headword index

**Echo prevention:** Keys currently being written from Firestore → Hive are tracked in `_firestoreUpdatingVocab` (a `Set<String>`). Hive watcher skips those keys to prevent infinite echo loops.

---

## Conflict Resolution

### Same `id`, different `updatedAt`

**Winner: newer `updatedAt` timestamp.**

The device with the most recent edit wins. Both Hive and Firestore converge to the same value through the subscription loop.

### Clock skew

If a device's system clock is significantly wrong, `updatedAt` comparisons may resolve incorrectly. This is an accepted limitation for a personal-use app. No server-side timestamp correction is applied.

---

## Duplicate Detection (Headword Index)

A race condition can produce two records with the same `headword + targetLanguage` but different `id` values:

```
t=0  Firebase has "record" (id=A)
t=1  Sign in → startSync begins, Hive still empty
t=2  User saves "record" locally before Firebase snapshot arrives → id=B written to Hive
t=3  Firebase snapshot arrives with "record" id=A → collision detected
```

### In-memory headword index

Built once at `startSync()` from all local Hive data:

```
Map<String, String> _headwordIndex   // "headword|language" → local id
Map<String, String> _idToHeadwordKey // local id → "headword|language"  (reverse)
```

Building cost: O(n) JSON parses, one time only. With 10,000 words this takes ~50–100 ms.

Lookup cost: O(1) per incoming Firestore doc.

### Collision resolution

When a Firestore doc arrives with an `id` not in Hive, but its `headword|language` is already indexed:

| Condition | Action |
|-----------|--------|
| `localUpdatedAt >= remoteUpdatedAt` | Keep local. Delete the Firebase doc (remote duplicate). |
| `remoteUpdatedAt > localUpdatedAt` | Keep Firebase version. Delete local Hive entry + its Firestore doc. Write Firebase entry to Hive. Update index. |

Both sides are protected by `_firestoreUpdatingVocab` guards during the async operations to prevent echo-back.

### Index maintenance

- **Add/update in Hive:** `_headwordIndex` and `_idToHeadwordKey` updated in both Hive watcher and Firestore listener.
- **Delete from Hive:** reverse-lookup via `_idToHeadwordKey` to find and remove the headword key.

---

## Topics

Topics follow the same bidirectional sync pattern but with simpler conflict resolution: **remote only adds, never overwrites.** Topics have no `updatedAt` field. A topic is only written to Hive if it doesn't exist locally. Local topics are always pushed to Firestore.

---

## Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

Each user can only read/write their own data. No cross-user access.

---

## Known Limitations

| Limitation | Impact |
|-----------|--------|
| Initial push always overwrites Firebase with local (no per-doc timestamp check) | If Firebase had a newer version of the same `id`, it gets overwritten. Corrected on next Firestore snapshot via `updatedAt` check — but only after local version has already overwritten it. |
| Clock skew | Devices with wrong system time may lose edits. |
| No tombstones for deletions | If word is deleted on device A while device B is offline, and device B re-adds the same word while offline, the delete event from A may arrive later and delete B's re-added word. |
| Firestore snapshot not paginated | Initial snapshot loads all user docs at once. Acceptable up to tens of thousands of words; may be slow for extremely large collections. |
| No offline queue for initial push | If offline at sign-in, Firestore SDK queues writes locally and flushes when connection is restored. Behavior is correct but `onStatus` reports `idle` before the queue is flushed. |

---

## Files

| File | Role |
|------|------|
| `lib/core/services/sync_service.dart` | All sync logic |
| `lib/features/settings/presentation/providers/auth_notifier.dart` | Triggers sign-in / sign-out |
| `lib/core/di/app_providers.dart` | Wires SyncService into provider graph |
