// scripts/migrate-vocab-records-per-language.js
const VALID_LANGUAGES = ["vietnamese", "english", "chinese", "korean", "japanese"];

/**
 * One-time migration: copies every document in each user's flat
 * `vocab_records` subcollection into a new per-language subcollection
 * (`vocab_records_{targetLanguage}`), keyed by each document's own
 * `targetLanguage` field. Does NOT delete the original `vocab_records`
 * collection — left in place as a backup, removed manually later once
 * both apps are confirmed working against the new collections.
 *
 * A record with a missing or invalid `targetLanguage` is skipped and
 * counted, never silently dropped or guessed into a default language.
 *
 * If the destination document (`vocab_records_{language}/{id}`) already
 * exists — e.g. from a prior partial run of this script — it is left
 * untouched and counted as skipped rather than overwritten. This script
 * may need to run more than once against production (a partial failure,
 * a re-run after fixing flagged records, etc.), and silently clobbering
 * whatever already landed at the destination on a later run would risk
 * destroying real data with no way to recover it. Skipping is the
 * conservative choice; anything skipped this way is logged so it can be
 * reviewed manually.
 *
 * Users are discovered via a `collectionGroup("vocab_records")` query
 * rather than by listing the top-level `users` collection. Neither the
 * web app nor the Flutter app ever writes a document directly at
 * `users/{uid}` — every user-scoped collection (`vocab_records`,
 * `settings`, `topics`, `stats`, ...) is a subcollection reached via a
 * `uid` path segment that is never itself materialized as a document.
 * Firestore does not require (or implicitly create) a parent document
 * for a subcollection to exist, so `db.collection("users").get()` finds
 * zero documents in this app's real data model even though thousands of
 * `users/{uid}/vocab_records/*` documents exist — confirmed against the
 * Firestore emulator while developing this script. A migration built on
 * that call would silently do nothing against production (reporting
 * `users: 0, migrated: 0, skipped: 0`, which looks like a clean no-op
 * success) while leaving all real records unmigrated. `collectionGroup`
 * finds documents by subcollection name regardless of whether the
 * intermediate parent document exists, so it reflects the app's actual
 * data model correctly.
 *
 * @param {import("firebase-admin/firestore").Firestore} db
 * @returns {Promise<{migrated: number, skipped: number, users: number}>}
 */
async function migrateVocabRecords(db) {
  const recordsSnapshot = await db.collectionGroup("vocab_records").get();
  let migrated = 0;
  let skipped = 0;

  const recordDocsByUid = new Map();
  for (const recordDoc of recordsSnapshot.docs) {
    const userRef = recordDoc.ref.parent.parent;
    if (!userRef) {
      // Defensive: a `vocab_records` collection not nested under users/{uid}.
      // Shouldn't happen given this app's data model — skip rather than guess.
      console.warn(
        `SKIPPED: ${recordDoc.ref.path} is a "vocab_records" document with no ` +
          `parent user document — cannot determine its owner, needs manual review.`
      );
      skipped++;
      continue;
    }
    const uid = userRef.id;
    if (!recordDocsByUid.has(uid)) recordDocsByUid.set(uid, []);
    recordDocsByUid.get(uid).push(recordDoc);
  }

  for (const [uid, recordDocs] of recordDocsByUid) {
    let batch = db.batch();
    let batchCount = 0;

    for (const recordDoc of recordDocs) {
      const data = recordDoc.data();
      const language = data.targetLanguage;
      if (!VALID_LANGUAGES.includes(language)) {
        console.warn(
          `SKIPPED: users/${uid}/vocab_records/${recordDoc.id} has ` +
            `missing/invalid targetLanguage ("${language}") — needs manual review.`
        );
        skipped++;
        continue;
      }
      const targetRef = db.collection(`users/${uid}/vocab_records_${language}`).doc(recordDoc.id);
      const existingTarget = await targetRef.get();
      if (existingTarget.exists) {
        console.warn(
          `SKIPPED: users/${uid}/vocab_records_${language}/${recordDoc.id} ` +
            `already exists at the destination — not overwriting, needs manual review.`
        );
        skipped++;
        continue;
      }
      batch.set(targetRef, data);
      migrated++;
      batchCount++;
      if (batchCount === 500) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) await batch.commit();
  }

  const users = recordDocsByUid.size;
  console.log(`Migration complete: ${migrated} record(s) migrated, ${skipped} skipped, ${users} user(s) processed.`);
  return { migrated, skipped, users };
}

module.exports = { migrateVocabRecords };

// Run directly (not imported as a module) against real production
// Firestore: `node scripts/migrate-vocab-records-per-language.js`
// Requires GOOGLE_APPLICATION_CREDENTIALS pointing at a service account
// key with Firestore access for the `lexi-core` project, or running
// from an environment already authenticated via `gcloud auth application-default login`.
if (require.main === module) {
  const { initializeApp } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const app = initializeApp();
  const db = getFirestore(app);
  migrateVocabRecords(db)
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Migration failed:", err);
      process.exit(1);
    });
}
