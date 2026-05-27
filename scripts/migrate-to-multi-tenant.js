#!/usr/bin/env node
/**
 * One-off migration: backfill `turfId` on existing data for the multi-tenant
 * cutover. Assigns every legacy doc to the turf whose `adminPhone` you pass in.
 *
 * What it does:
 *   1. Find the turf doc where adminPhone == <argv>
 *   2. Backfill `turfId` on every `bookings/*` doc that's missing one
 *   3. Backfill `turfId` on every `regular_bookings/*` doc that's missing one
 *   4. Copy `settings/slot_config` (legacy global) to
 *      `turfs/{turfId}/settings/slot_config` if the new path is empty
 *   5. Set `turfId` + `turfName` on every user doc whose phone matches a known
 *      turf's adminPhone (admin users) and optionally on customer users that
 *      have no turfId yet (assigns them to the single default turf).
 *
 * Usage:
 *   1. Download a service account key from Firebase Console:
 *        Project Settings → Service Accounts → "Generate new private key"
 *      Save it as `serviceAccount.json` in the project root.
 *   2. `npm install firebase-admin` (in the scripts/ folder or project root)
 *   3. `node scripts/migrate-to-multi-tenant.js +9779840072995`
 *      (use the full E.164 phone of the turf's admin)
 *
 * The script is idempotent — re-running won't double-write.
 */

const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const PROJECT_ID = 'book-my-game-a9b76';

// ── Initialize firebase-admin ────────────────────────────────────────────────
const saPath = path.resolve(__dirname, '..', 'serviceAccount.json');
if (fs.existsSync(saPath)) {
  admin.initializeApp({
    credential: admin.credential.cert(require(saPath)),
    projectId: PROJECT_ID,
  });
  console.log(`🔐 Using service account: ${saPath}`);
} else {
  // Falls back to Application Default Credentials. Run once:
  //   gcloud auth application-default login
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });
  console.log('🔐 Using Application Default Credentials');
}

const db = admin.firestore();

// ── Helpers ──────────────────────────────────────────────────────────────────
function dieUsage(msg) {
  console.error(`❌ ${msg}`);
  console.error('Usage: node scripts/migrate-to-multi-tenant.js <adminPhoneE164>');
  console.error('Example: node scripts/migrate-to-multi-tenant.js +9779840072995');
  process.exit(1);
}

async function findTurfByAdminPhone(phone) {
  const snap = await db.collection('turfs')
    .where('adminPhone', '==', phone)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() };
}

async function backfillCollectionTurfId(collection, turfId, label) {
  console.log(`📋 ${label}: scanning…`);
  const snap = await db.collection(collection).get();
  let updated = 0;
  let alreadyOk = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.turfId) {
      alreadyOk++;
      continue;
    }
    await doc.ref.update({ turfId });
    updated++;
  }
  console.log(`   ${label}: ${updated} updated, ${alreadyOk} already had turfId, ` +
              `${snap.size} total`);
}

async function migrateSlotConfig(turfId) {
  console.log('⚙️  slot_config: checking legacy doc…');
  const legacy = await db.collection('settings').doc('slot_config').get();
  if (!legacy.exists) {
    console.log('   No legacy slot_config to migrate');
    return;
  }
  const newRef = db
    .collection('turfs').doc(turfId)
    .collection('settings').doc('slot_config');
  const existing = await newRef.get();
  if (existing.exists) {
    console.log('   New per-turf slot_config already exists (skip)');
    return;
  }
  await newRef.set(legacy.data());
  console.log('   Copied legacy slot_config → turfs/' + turfId + '/settings/slot_config');
}

/**
 * Update each user doc:
 *  - If role == ADMIN: match their phone against any turfs.adminPhone and link.
 *  - If role == CUSTOMER without a turfId: assign the default turf passed in.
 */
async function updateUsers(defaultTurf) {
  console.log('👤 users: scanning…');

  // Build phone → turf map (handles future multi-turf case).
  const turfs = await db.collection('turfs').get();
  const phoneToTurf = new Map();
  turfs.forEach((d) => {
    const data = d.data();
    if (data.adminPhone) {
      phoneToTurf.set(data.adminPhone, { id: d.id, name: data.name });
    }
  });

  const users = await db.collection('users').get();
  let adminUpdated = 0;
  let customerUpdated = 0;
  let skipped = 0;

  for (const doc of users.docs) {
    const data = doc.data();
    if (data.turfId) { skipped++; continue; }

    const role = data.role || 'CUSTOMER';
    if (role === 'ADMIN') {
      const turf = phoneToTurf.get(data.phone);
      if (turf) {
        await doc.ref.update({ turfId: turf.id, turfName: turf.name });
        adminUpdated++;
      } else {
        console.log(`   ⚠️  admin ${doc.id} has phone=${data.phone} but no matching turf`);
      }
    } else {
      // Customer with no turfId → assign default.
      await doc.ref.update({
        turfId: defaultTurf.id,
        turfName: defaultTurf.name,
      });
      customerUpdated++;
    }
  }

  console.log(`   ${adminUpdated} admins linked, ${customerUpdated} customers assigned to ` +
              `${defaultTurf.name}, ${skipped} already had turfId`);
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const adminPhone = process.argv[2];
  if (!adminPhone) dieUsage('Missing adminPhone argument');
  if (!adminPhone.startsWith('+')) {
    dieUsage('adminPhone must be in E.164 format (e.g., +9779840072995)');
  }

  const turf = await findTurfByAdminPhone(adminPhone);
  if (!turf) {
    dieUsage(`No turf found with adminPhone=${adminPhone}. ` +
             'Create it in Firestore Console first (turfs collection).');
  }
  console.log(`✅ Target turf: ${turf.name} (${turf.id})`);
  console.log('');

  await backfillCollectionTurfId('bookings', turf.id, 'bookings');
  console.log('');
  await backfillCollectionTurfId('regular_bookings', turf.id, 'regular_bookings');
  console.log('');
  await migrateSlotConfig(turf.id);
  console.log('');
  await updateUsers({ id: turf.id, name: turf.name });
  console.log('');
  console.log('✅ Migration complete.');
}

main().catch((e) => {
  console.error('❌ Migration failed:', e);
  process.exit(1);
});
