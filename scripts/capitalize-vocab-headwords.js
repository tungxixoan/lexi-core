// scripts/capitalize-vocab-headwords.js
//
// One-time, idempotent migration: capitalize the first letter of every vocab
// `headword` across all users. Runs against:
//   - users/{uid}/vocab_records_{lang}  for lang in the 5 supported languages
//   - users/{uid}/vocab_records         (the deprecated flat backup collection)
//
// DRY RUN BY DEFAULT: prints "from -> to" for every change and the totals,
// writes nothing. Pass --apply to actually write (batched, updatedAt bumped).
// No backup collection is taken — the transform (lowercase first letter ->
// uppercase) is trivially inspectable and reversible, and the dry run is the
// safety net. Discovers docs via collectionGroup (see the sibling
// migrate-vocab-records-per-language.js for why users/ is not listable).
//
// `capitalizeHeadword` is re-implemented locally on purpose: this script is a
// standalone package (`lexicore-scripts`) and cannot import the web
// (`apps/web`) or Flutter helper. There are three copies of this rule; all
// three are checked against the same shared test table (Task 6).
//
// @typedef {import("firebase-admin/firestore").Firestore} Firestore

const LANGUAGES = ["vietnamese", "english", "chinese", "korean", "japanese"];
const COLLECTION_IDS = [...LANGUAGES.map((l) => `vocab_records_${l}`), "vocab_records"];

/**
 * Capitalize the first character of `s` when it is a lowercase letter that has
 * a distinct uppercase form (so "TOEIC", "3D printing", "苹果" and "" are all
 * left untouched). Non-strings pass straight through unchanged.
 */
function capitalizeHeadword(s) {
  if (typeof s !== "string" || s.length === 0) return s;
  const first = s[0];
  if (first.toLowerCase() === first && first.toUpperCase() !== first) {
    return first.toUpperCase() + s.slice(1);
  }
  return s;
}

/**
 * @param {Firestore} db
 * @param {{ apply?: boolean }} [opts]
 * @returns {Promise<{ scanned: number, toChange: number, changed: number, skipped: number }>}
 */
async function capitalizeVocabHeadwords(db, { apply } = { apply: false }) {
  let scanned = 0;
  let skipped = 0;
  const changes = []; // { ref, from, to }

  for (const collectionId of COLLECTION_IDS) {
    const snap = await db.collectionGroup(collectionId).get();
    for (const doc of snap.docs) {
      scanned++;
      const from = doc.get("headword");
      if (typeof from !== "string" || from.length === 0) {
        skipped++;
        continue;
      }
      const to = capitalizeHeadword(from);
      if (to === from) {
        skipped++;
        continue;
      }
      changes.push({ ref: doc.ref, from, to });
    }
  }

  for (const c of changes) {
    console.log(
      `${apply ? "CHANGE" : "would change"}  ${c.ref.path}  ${JSON.stringify(
        c.from
      )} -> ${JSON.stringify(c.to)}`
    );
  }

  let changed = 0;
  if (apply) {
    for (let i = 0; i < changes.length; i += 400) {
      const batch = db.batch();
      for (const c of changes.slice(i, i + 400)) {
        batch.update(c.ref, { headword: c.to, updatedAt: new Date().toISOString() });
      }
      await batch.commit();
      changed += Math.min(400, changes.length - i);
    }
  }

  console.log(
    `\n${apply ? "Applied" : "Dry run"}: scanned ${scanned}, ${
      apply ? "changed" : "would change"
    } ${changes.length}, skipped ${skipped}.`
  );
  return { scanned, toChange: changes.length, changed, skipped };
}

module.exports = { capitalizeHeadword, capitalizeVocabHeadwords };

// Run directly against real Firestore:
//   node scripts/capitalize-vocab-headwords.js            (dry run)
//   node scripts/capitalize-vocab-headwords.js --apply    (write)
// Requires GOOGLE_APPLICATION_CREDENTIALS or `gcloud auth application-default login`.
if (require.main === module) {
  const { initializeApp } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const app = initializeApp();
  const db = getFirestore(app);
  const apply = process.argv.includes("--apply");

  // Target-environment guard: this script can write real data, so the operator
  // must be able to visually confirm — before any writes happen — which
  // project it actually resolved to and whether a stray FIRESTORE_EMULATOR_HOST
  // is redirecting every read and write.
  console.log(`Resolved Firebase project id: ${app.options.projectId}`);
  console.log(
    `FIRESTORE_EMULATOR_HOST: ${
      process.env.FIRESTORE_EMULATOR_HOST
        ? `${process.env.FIRESTORE_EMULATOR_HOST} (EMULATOR — not production!)`
        : "(not set — targeting real Firestore)"
    }`
  );
  console.log(
    apply
      ? "MODE: --apply (writing)\n"
      : "MODE: dry run (no writes) — pass --apply to write\n"
  );

  capitalizeVocabHeadwords(db, { apply })
    .then((r) => {
      if (r.scanned === 0) {
        // Zero documents scanned is not a plausible outcome against real
        // production data — it means the script is pointed at the wrong
        // project or environment (check the project id and
        // FIRESTORE_EMULATOR_HOST logged above), not that there is genuinely
        // nothing to migrate. Flag loudly rather than exiting 0 as a no-op
        // success.
        console.error(
          "WARNING: 0 documents scanned. This is unexpected against real " +
            "production data and likely means this script is targeting the " +
            "wrong Firestore project or environment (check the project id and " +
            "FIRESTORE_EMULATOR_HOST logged above). Treating as a failure — " +
            "no changes were made."
        );
        process.exit(1);
      }
      process.exit(0);
    })
    .catch((err) => {
      console.error("Failed:", err);
      process.exit(1);
    });
}
