#!/usr/bin/env node
/**
 * Wipe all booking-related data while preserving users, turfs, academy,
 * and settings.
 *
 * Destructive — only run on a project you're OK starting fresh on.
 *
 * Clears:
 *   - bookings/*                         (every booking doc)
 *   - regular_bookings/*                 (admin recurring templates)
 *   - leaderboard/*                      (cached rankings)
 *   - turfs/{turfId}/rewards/{phone}     (loyalty progress per customer)
 *
 * Preserves: users, turfs/{turfId} itself, turfs/{turfId}/settings/*,
 *            turfs/{turfId}/academy/*.
 *
 * Usage:
 *   1. Ensure serviceAccount.json exists in the project root.
 *   2. cd scripts && npm install (if not already)
 *   3. node wipe-bookings.js --yes-i-know
 */

const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const PROJECT_ID = 'book-my-game-a9b76';

if (!process.argv.includes('--yes-i-know')) {
  console.error('❌ Refusing to wipe without the --yes-i-know flag.');
  console.error('Usage: node wipe-bookings.js --yes-i-know');
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

async function deleteCollection(name) {
  console.log(`📋 Deleting collection: ${name}`);
  const snap = await db.collection(name).get();
  if (snap.empty) {
    console.log('   (empty)');
    return 0;
  }
  let count = 0;
  // Batch deletes in chunks of 400 (Firestore batch limit is 500).
  let batch = db.batch();
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    count++;
    if (count % 400 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  await batch.commit();
  console.log(`   removed ${count} docs`);
  return count;
}

async function deleteRewardsForAllTurfs() {
  console.log('📋 Deleting rewards under every turf…');
  const turfs = await db.collection('turfs').get();
  let total = 0;
  for (const turf of turfs.docs) {
    const rewards = await turf.ref.collection('rewards').get();
    if (rewards.empty) continue;
    let batch = db.batch();
    let n = 0;
    for (const r of rewards.docs) {
      batch.delete(r.ref);
      n++;
      if (n % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    await batch.commit();
    total += n;
    console.log(`   turfs/${turf.id}/rewards: removed ${n}`);
  }
  console.log(`   done, ${total} reward docs gone`);
  return total;
}

async function main() {
  console.log('⚠️  Wiping bookings + regulars + leaderboard + rewards…');
  console.log('');

  const a = await deleteCollection('bookings');
  const b = await deleteCollection('regular_bookings');
  const c = await deleteCollection('leaderboard');
  const d = await deleteRewardsForAllTurfs();

  console.log('');
  console.log(
    `✅ Done. bookings=${a}, regulars=${b}, leaderboard=${c}, rewards=${d}.`
  );
  console.log('Users, turfs, settings, and academy preserved.');
}

main().catch((e) => {
  console.error('❌ Wipe failed:', e);
  process.exit(1);
});
