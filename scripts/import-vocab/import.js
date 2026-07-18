// One-off bulk import: final.json -> Firestore users/{uid}/vocab_records + users/{uid}/topics
// Usage:
//   npm install
//   node import.js --email=you@example.com                (dry run, default)
//   node import.js --email=you@example.com --commit        (writes for real)
//
// Delete this whole scripts/import-vocab/ folder once the import is verified in the app.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');

function parseArgs() {
  const args = { key: './service-account.json', file: './final.json', commit: false };
  for (const arg of process.argv.slice(2)) {
    if (arg === '--commit') args.commit = true;
    else if (arg.startsWith('--email=')) args.email = arg.slice('--email='.length);
    else if (arg.startsWith('--key=')) args.key = arg.slice('--key='.length);
    else if (arg.startsWith('--file=')) args.file = arg.slice('--file='.length);
  }
  if (!args.email) {
    console.error('Missing --email=<your login email>');
    process.exit(1);
  }
  return args;
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

async function main() {
  const args = parseArgs();

  const keyPath = path.resolve(__dirname, args.key);
  const filePath = path.resolve(__dirname, args.file);
  const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const auth = admin.auth();
  const db = admin.firestore();

  const user = await auth.getUserByEmail(args.email);
  const uid = user.uid;
  console.log(`Resolved ${args.email} -> uid ${uid}`);

  const vocabCol = db.collection('users').doc(uid).collection('vocab_records');
  const topicsCol = db.collection('users').doc(uid).collection('topics');

  // Dedup: fetch existing headwords for English
  const existingSnap = await vocabCol.where('targetLanguage', '==', 'english').get();
  const existingHeadwords = new Set();
  existingSnap.forEach((doc) => {
    const hw = (doc.data().headword || '').trim().toLowerCase();
    if (hw) existingHeadwords.add(hw);
  });
  console.log(`Existing English words in Firestore: ${existingHeadwords.size}`);

  const toImport = [];
  const skipped = [];
  for (const rec of data.records) {
    if (existingHeadwords.has(rec.headword.trim().toLowerCase())) {
      skipped.push(rec.headword);
    } else {
      toImport.push(rec);
    }
  }

  console.log(`\n=== DRY RUN SUMMARY ===`);
  console.log(`Total prepared records: ${data.records.length}`);
  console.log(`New topics to create: ${Object.keys(data.newTopics).length} (${Object.values(data.newTopics).map((t) => t.name).join(', ')})`);
  console.log(`Words to import: ${toImport.length}`);
  console.log(`Words skipped (already in Firestore): ${skipped.length}`);
  if (skipped.length) console.log(`  Skipped: ${skipped.join(', ')}`);

  if (!args.commit) {
    console.log(`\nDry run only — no writes made. Re-run with --commit to write for real.`);
    return;
  }

  console.log(`\n=== COMMITTING ===`);

  // 1. Upsert new custom topics (idempotent set)
  for (const [slug, topic] of Object.entries(data.newTopics)) {
    await topicsCol.doc(slug).set({
      id: slug,
      name: topic.name,
      emoji: topic.emoji,
      isPredefined: false,
      createdAt: new Date().toISOString(),
    });
    console.log(`Topic upserted: ${slug} (${topic.name})`);
  }

  // 2. Batch-write vocab records (Firestore batch limit is 500 writes)
  const now = new Date().toISOString();
  const docs = toImport.map((rec) => {
    const id = uuidv4();
    const doc = {
      id,
      headword: rec.headword,
      inputType: rec.inputType,
      ipa: rec.ipa,
      meaning: rec.meaning,
      examples: rec.examples,
      personalNotes: '',
      definition: rec.definition,
      synonyms: rec.synonyms,
      topicIds: [rec.topicSlug],
      targetLanguage: 'english',
      cefrLevel: rec.cefrLevel,
      activeContext: 'general',
      createdAt: now,
      updatedAt: now,
      nextReviewAt: null,
      sm2Repetitions: 0,
      sm2EaseFactor: 2.5,
      sm2Interval: 1,
    };
    return { id, doc };
  });

  for (const batchDocs of chunk(docs, 400)) {
    const batch = db.batch();
    for (const { id, doc } of batchDocs) {
      batch.set(vocabCol.doc(id), doc);
    }
    await batch.commit();
    console.log(`Wrote batch of ${batchDocs.length} words`);
  }

  console.log(`\nDone. Imported ${docs.length} words, ${Object.keys(data.newTopics).length} new topics.`);
  console.log(`Open the app and let it sync — new words/topics will appear via the existing Firestore listener.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
