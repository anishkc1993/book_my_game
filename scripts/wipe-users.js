#!/usr/bin/env node
/**
 * Wipe all Firebase Auth users + Firestore user/booking docs.
 *
 * Destructive — only run on a project you're OK starting fresh on.
 * Preserves: turfs collection, leaderboard cache.
 *
 * Usage:
 *   1. Ensure serviceAccount.json exists in the project root.
 *   2. cd scripts && npm install (if not already)
 *   3. node wipe-users.js --yes-i-know
 *      (the flag is a safety guard; the script refuses to run without it)
 */

const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const PROJECT_ID = 'book-my-game-a9b76';

if (!process.argv.includes('--yes-i-know')) {
  console.error('❌ Refusing to wipe without the --yes-i-know flag.');
  console.error('Usage: node wipe-users.js --yes-i-know');
  process.exit(1);
}

const saPath = path.resolve(__dirname, '..', 'serviceAccount.json');
if (!fs.existsSync(saPath)) {
  console.error('❌ serviceAccount.json not found at: ' + saPath);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(saPath)),
  projectId: PROJECT_ID,
});

const db = admin.firestore();
const auth = admin.auth();

async function deleteCollection(name) {
  console.log(`📋 Deleting collection: ${name}`);
  const snap = await db.collection(name).get();
  if (snap.empty) {
    console.log(`   (empty)`);
    return;
  }
  let count = 0;
  for (const doc of snap.docs) {
    await doc.ref.delete();
    count++;
  }
  console.log(`   removed ${count} docs`);
}

async function deleteAllAuthUsers() {
  console.log('🔐 Deleting all Firebase Auth users…');
  let total = 0;
  let pageToken;
  do {
    const res = await auth.listUsers(1000, pageToken);
    if (res.users.length === 0) break;
    const uids = res.users.map((u) => u.uid);
    await auth.deleteUsers(uids);
    total += uids.length;
    console.log(`   removed ${uids.length} (running total: ${total})`);
    pageToken = res.pageToken;
  } while (pageToken);
  console.log(`   done, ${total} users gone`);
}

async function main() {
  console.log('⚠️  Wiping users + bookings…');
  console.log('');

  await deleteAllAuthUsers();
  console.log('');

  await deleteCollection('users');
  await deleteCollection('bookings');
  await deleteCollection('regular_bookings');
  console.log('');
  console.log('✅ Wipe complete. Turfs collection preserved.');
  console.log('Customers and admins will need to re-sign up with phone + password.');
}

main().catch((e) => {
  console.error('❌ Wipe failed:', e);
  process.exit(1);
});
