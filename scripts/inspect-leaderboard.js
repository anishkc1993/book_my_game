#!/usr/bin/env node
const path = require('path');
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccount.json'))),
  projectId: 'book-my-game-a9b76',
});
const db = admin.firestore();

(async () => {
  const months = await db.collection('leaderboard').get();
  for (const m of months.docs) {
    console.log(`📅 ${m.id}:`, JSON.stringify(m.data()));
    const entries = await m.ref.collection('entries').orderBy('rank').get();
    console.log(`  ${entries.size} entries:`);
    for (const e of entries.docs) {
      console.log(`  -`, JSON.stringify(e.data()));
    }
  }
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
