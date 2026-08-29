// scripts/migrate-vocab-records-per-language.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { migrateVocabRecords } = require("./migrate-vocab-records-per-language");

// Run against the Firestore emulator — start it first with:
//   firebase emulators:start --only firestore
// and set FIRESTORE_EMULATOR_HOST=localhost:8080 (or whatever port the
// emulator config uses) in the environment before running this test.

test("migrates each user's records into their own per-language collection, keyed by each record's targetLanguage", async () => {
  const app = initializeApp({ projectId: "test-migration" });
  const db = getFirestore(app);

  await db.collection("users/u1/vocab_records").doc("v1").set({
    id: "v1",
    headword: "apple",
    targetLanguage: "english",
  });
  await db.collection("users/u1/vocab_records").doc("v2").set({
    id: "v2",
    headword: "苹果",
    targetLanguage: "chinese",
  });

  const result = await migrateVocabRecords(db);

  const englishDocs = await db.collection("users/u1/vocab_records_english").get();
  const chineseDocs = await db.collection("users/u1/vocab_records_chinese").get();
  assert.equal(englishDocs.docs.length, 1);
  assert.equal(englishDocs.docs[0].data().headword, "apple");
  assert.equal(chineseDocs.docs.length, 1);
  assert.equal(chineseDocs.docs[0].data().headword, "苹果");
  assert.deepEqual(result, { migrated: 2, skipped: 0, users: 1 });
});

test("leaves the original vocab_records collection untouched (not deleted)", async () => {
  const app = initializeApp({ projectId: "test-migration-2" }, "app2");
  const db = getFirestore(app);

  await db.collection("users/u2/vocab_records").doc("v1").set({
    id: "v1",
    headword: "hello",
    targetLanguage: "english",
  });

  await migrateVocabRecords(db);

  const originalDocs = await db.collection("users/u2/vocab_records").get();
  assert.equal(originalDocs.docs.length, 1);
});

test("flags a record with a missing or invalid targetLanguage instead of silently dropping or guessing", async () => {
  const app = initializeApp({ projectId: "test-migration-3" }, "app3");
  const db = getFirestore(app);

  await db.collection("users/u3/vocab_records").doc("bad1").set({
    id: "bad1",
    headword: "mystery",
    // no targetLanguage field at all
  });

  const result = await migrateVocabRecords(db);

  assert.equal(result.skipped, 1);
  assert.equal(result.migrated, 0);
  const englishDocs = await db.collection("users/u3/vocab_records_english").get();
  assert.equal(englishDocs.docs.length, 0);
});

test("migrates every user found under the top-level users collection, not just one", async () => {
  const app = initializeApp({ projectId: "test-migration-4" }, "app4");
  const db = getFirestore(app);

  await db.collection("users/u4/vocab_records").doc("v1").set({
    id: "v1",
    headword: "one",
    targetLanguage: "english",
  });
  await db.collection("users/u5/vocab_records").doc("v1").set({
    id: "v1",
    headword: "two",
    targetLanguage: "vietnamese",
  });

  const result = await migrateVocabRecords(db);

  assert.equal(result.users, 2);
  assert.equal(result.migrated, 2);
});
