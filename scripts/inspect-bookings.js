#!/usr/bin/env node
/**
 * Diagnostic — print all booking docs with key fields so we can see
 * what's actually in the DB vs what the UI shows.
 */
const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const saPath = path.resolve(__dirname, '..', 'serviceAccount.json');
if (!fs.existsSync(saPath)) {
  console.error('serviceAccount.json missing');
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(require(saPath)),
  projectId: 'book-my-game-a9b76',
});

const db = admin.firestore();

async function main() {
  const now = new Date();
  const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  console.log('Today key:', today, '— weekday:', now.toLocaleDateString('en', { weekday: 'long' }));
  console.log('');

  const bookings = await db.collection('bookings').get();
  console.log(`Total bookings: ${bookings.size}\n`);
  if (bookings.empty) {
    console.log('No bookings in collection.');
  } else {
    for (const doc of bookings.docs) {
      const d = doc.data();
      const start = d.startTime?.toDate?.() ?? null;
      const end = d.endTime?.toDate?.() ?? null;
      console.log(`- ${doc.id}`);
      console.log(`  turfId      : ${d.turfId}`);
      console.log(`  dateKey     : ${d.dateKey}`);
      console.log(`  startTime   : ${start?.toISOString()} (weekday=${start?.toLocaleDateString('en', { weekday: 'short' })})`);
      console.log(`  endTime     : ${end?.toISOString()}`);
      console.log(`  status      : ${d.status}`);
      console.log(`  isPaid      : ${d.isPaid}, amountPaid=${d.amountPaid}, basePrice=${d.basePrice}`);
      console.log(`  userPhone   : ${d.userPhone}, customerName=${d.customerName}`);
      console.log(`  isAdmin     : ${d.createdByAdmin}`);
      console.log('');
    }
  }

  const regulars = await db.collection('regular_bookings').get();
  console.log(`Total regular_bookings: ${regulars.size}`);
  for (const doc of regulars.docs) {
    const d = doc.data();
    console.log(`- ${doc.id}: hour=${d.startHour}, days=${JSON.stringify(d.daysOfWeek)}, price=${d.basePrice}, active=${d.isActive}, turf=${d.turfId}`);
  }

  const turfs = await db.collection('turfs').get();
  console.log(`\nTurfs: ${turfs.size}`);
  for (const doc of turfs.docs) {
    console.log(`- ${doc.id}: ${doc.data().name}`);
  }

  const leaderboard = await db.collection('leaderboard').get();
  console.log(`\nLeaderboard rows: ${leaderboard.size}`);
  for (const doc of leaderboard.docs) {
    const d = doc.data();
    console.log(`- ${doc.id}: phone=${d.userPhone}, count=${d.totalBookings ?? d.count}, turf=${d.turfId}`);
  }
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
