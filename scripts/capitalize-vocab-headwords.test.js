// scripts/capitalize-vocab-headwords.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const {
  capitalizeHeadword,
  capitalizeVocabHeadwords,
} = require("./capitalize-vocab-headwords");

// The migration tests run against the Firestore emulator — start it first with:
//   firebase emulators:start --only firestore
// and set FIRESTORE_EMULATOR_HOST=localhost:8080 (or whatever port the
// emulator config uses) in the environment before running this test, or run
// the whole file under `firebase emulators:exec --only firestore`.
//
// The `capitalizeHeadword rules` test needs no emulator — it is a plain unit
// test of the local helper and must match the Task 6 shared table exactly.

test("capitalizeHeadword rules (shared table — must match the web/Flutter helper)", () => {
  assert.equal(capitalizeHeadword("follow up"), "Follow up");
  assert.equal(capitalizeHeadword("Follow up"), "Follow up");
  assert.equal(capitalizeHeadword("TOEIC"), "TOEIC");
  assert.equal(capitalizeHeadword("3D printing"), "3D printing");
  assert.equal(capitalizeHeadword(""), "");
});

test("dry run reports changes without writing; --apply writes; re-run is a no-op", async () => {
  const app = initializeApp({ projectId: "test-capitalize-1" }, "app1");
  const db = getFirestore(app);

  await db.doc("users/u1/vocab_records_english/a").set({ headword: "apple" });
  await db.doc("users/u1/vocab_records_english/b").set({ headword: "Banana" });
  await db.doc("users/u2/vocab_records_vietnamese/c").set({ headword: "cam" });
  await db.doc("users/u1/vocab_records/d").set({ headword: "date" });

  const dry = await capitalizeVocabHeadwords(db, { apply: false });
  assert.equal(dry.toChange, 3); // apple, cam, date
  assert.equal(dry.changed, 0);
  assert.equal(dry.scanned, 4);
  // store unchanged
  assert.equal(
    (await db.doc("users/u1/vocab_records_english/a").get()).data().headword,
    "apple"
  );

  const applied = await capitalizeVocabHeadwords(db, { apply: true });
  assert.equal(applied.changed, 3);
  assert.equal(
    (await db.doc("users/u1/vocab_records_english/a").get()).data().headword,
    "Apple"
  );
  assert.equal(
    (await db.doc("users/u2/vocab_records_vietnamese/c").get()).data().headword,
    "Cam"
  );
  assert.equal(
    (await db.doc("users/u1/vocab_records/d").get()).data().headword,
    "Date"
  );
  // an updatedAt stamp is written alongside
  assert.equal(
    typeof (await db.doc("users/u1/vocab_records_english/a").get()).data()
      .updatedAt,
    "string"
  );

  const again = await capitalizeVocabHeadwords(db, { apply: true });
  assert.equal(again.toChange, 0);
  assert.equal(again.changed, 0);
});

test("a missing or non-string headword is skipped, not thrown", async () => {
  const app = initializeApp({ projectId: "test-capitalize-2" }, "app2");
  const db = getFirestore(app);

  await db.doc("users/u1/vocab_records_english/x").set({ note: "no headword" });
  await db.doc("users/u1/vocab_records_english/y").set({ headword: 42 });

  const r = await capitalizeVocabHeadwords(db, { apply: true });
  assert.equal(r.skipped >= 2, true);
  assert.equal(r.changed, 0);
});

test("scans every supported per-language collection group plus the flat backup", async () => {
  const app = initializeApp({ projectId: "test-capitalize-3" }, "app3");
  const db = getFirestore(app);

  await db.doc("users/u1/vocab_records_vietnamese/a").set({ headword: "một" });
  await db.doc("users/u1/vocab_records_english/b").set({ headword: "two" });
  await db.doc("users/u1/vocab_records_chinese/c").set({ headword: "三" });
  await db.doc("users/u1/vocab_records_korean/d").set({ headword: "넷" });
  await db.doc("users/u1/vocab_records_japanese/e").set({ headword: "ご" });
  await db.doc("users/u9/vocab_records/f").set({ headword: "six" });

  const applied = await capitalizeVocabHeadwords(db, { apply: true });
  assert.equal(applied.scanned, 6);
  // the latin-script lowercase-initial headwords change ("một", "two", "six");
  // the CJK-script headwords ("三", "넷", "ご") have no distinct uppercase form
  assert.equal(applied.changed, 3);
  assert.equal(
    (await db.doc("users/u1/vocab_records_vietnamese/a").get()).data().headword,
    "Một"
  );
  assert.equal(
    (await db.doc("users/u1/vocab_records_english/b").get()).data().headword,
    "Two"
  );
  assert.equal(
    (await db.doc("users/u9/vocab_records/f").get()).data().headword,
    "Six"
  );
  assert.equal(
    (await db.doc("users/u1/vocab_records_chinese/c").get()).data().headword,
    "三"
  );
});
