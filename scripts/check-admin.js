#!/usr/bin/env node
const path = require('path');
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccount.json'))),
  projectId: 'book-my-game-a9b76',
});
const db = admin.firestore();
(async () => {
  const users = await db.collection('users').where('role', '==', 'ADMIN').get();
  console.log(`${users.size} admin user(s):`);
  for (const u of users.docs) {
    const d = u.data();
    console.log(`  uid=${u.id} | role=${d.role} | turfId=${d.turfId} | phone=${d.phone}`);
  }
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
