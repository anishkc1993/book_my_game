#!/usr/bin/env node
const path = require('path');
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccount.json'))),
  projectId: 'book-my-game-a9b76',
});
const db = admin.firestore();

(async () => {
  const turfs = await db.collection('turfs').get();
  for (const t of turfs.docs) {
    console.log(`\n📍 Turf ${t.id}: ${t.data().name}`);
    const plans = await t.ref.collection('monthly_plans').get();
    console.log(`  ${plans.size} monthly plans:`);
    for (const p of plans.docs) {
      const d = p.data();
      console.log(`  - ${p.id}: ${d.customerName} | days=${JSON.stringify(d.daysOfWeek)} hour=${d.startHour} fee=${d.monthlyFee} active=${d.isActive} lastPaid=${d.lastPaidMonth}`);
    }
    const payments = await t.ref.collection('monthly_plan_payments').get();
    console.log(`  ${payments.size} payment rows`);
  }
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
