// Apply spellcheck corrections to already-imported records.
// Usage: node update_spellfix.js --email=you@example.com [--commit]

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs() {
  const args = { key: './service-account.json', commit: false };
  for (const arg of process.argv.slice(2)) {
    if (arg === '--commit') args.commit = true;
    else if (arg.startsWith('--email=')) args.email = arg.slice('--email='.length);
  }
  if (!args.email) {
    console.error('Missing --email=<login email>');
    process.exit(1);
  }
  return args;
}

async function main() {
  const args = parseArgs();
  const serviceAccount = JSON.parse(fs.readFileSync(path.resolve(__dirname, args.key), 'utf8'));
  const final = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'final.json'), 'utf8'));
  const affected = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'affected.json'), 'utf8'));
  const finalByHeadword = new Map(final.records.map((r) => [r.headword, r]));

  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const user = await admin.auth().getUserByEmail(args.email);
  const uid = user.uid;
  console.log(`Resolved ${args.email} -> uid ${uid}`);

  const vocabCol = admin.firestore().collection('users').doc(uid).collection('vocab_records');
  const snap = await vocabCol.where('targetLanguage', '==', 'english').get();
  const byHeadwordLower = new Map();
  snap.forEach((doc) => byHeadwordLower.set((doc.data().headword || '').toLowerCase(), doc));

  let matched = 0;
  let notFound = [];
  const updates = [];

  for (const { firestoreHeadword, currentHeadword } of affected) {
    const doc = byHeadwordLower.get(firestoreHeadword.toLowerCase());
    if (!doc) {
      notFound.push(firestoreHeadword);
      continue;
    }
    const rec = finalByHeadword.get(currentHeadword);
    matched++;
    updates.push({
      ref: doc.ref,
      data: {
        headword: rec.headword,
        definition: rec.definition,
        meaning: rec.meaning,
        examples: rec.examples,
        synonyms: rec.synonyms,
        updatedAt: new Date().toISOString(),
      },
    });
  }

  console.log(`\n=== DRY RUN SUMMARY ===`);
  console.log(`Affected records: ${affected.length}`);
  console.log(`Matched in Firestore: ${matched}`);
  console.log(`Not found (skipped): ${notFound.length}`);
  if (notFound.length) console.log(`  ${notFound.join(', ')}`);

  if (!args.commit) {
    console.log(`\nDry run only. Re-run with --commit to write for real.`);
    return;
  }

  console.log(`\n=== COMMITTING ===`);
  for (let i = 0; i < updates.length; i += 400) {
    const batch = admin.firestore().batch();
    for (const { ref, data } of updates.slice(i, i + 400)) {
      batch.update(ref, data);
    }
    await batch.commit();
    console.log(`Updated batch of ${Math.min(400, updates.length - i)}`);
  }
  console.log(`\nDone. Updated ${updates.length} records.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
