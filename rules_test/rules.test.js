// Run with: cd rules_test && npm install && npm test
// Needs the Firebase CLI (it starts the Firestore emulator for the test run).
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, deleteDoc, where } =
  require('firebase/firestore');

const ADMIN = { uid: 'admin1', phone: '+919876500001' };
const MEMBER = { uid: 'member1', phone: '+919876500002' };
const STRANGER = { uid: 'stranger1', phone: '+919876500009' };

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-chitmate',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function as(user) {
  return env
    .authenticatedContext(user.uid, { phone_number: user.phone })
    .firestore();
}

function groupDoc(id, { adminUid = ADMIN.uid, phones = [ADMIN.phone, MEMBER.phone] } = {}) {
  return { adminUid, memberPhones: phones, data: { id, name: 'Friends', adminUid } };
}

async function seed(id, overrides) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'groups', id), groupDoc(id, overrides));
  });
}

test('signed-out people cannot read or write', async () => {
  await seed('g1');
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'groups', 'g1')));
  await assertFails(setDoc(doc(db, 'groups', 'g2'), groupDoc('g2')));
});

test('an organiser can create a group they run', async () => {
  await assertSucceeds(setDoc(doc(as(ADMIN), 'groups', 'g1'), groupDoc('g1')));
});

test('nobody can create a group on behalf of someone else', async () => {
  await assertFails(
    setDoc(doc(as(STRANGER), 'groups', 'g1'), groupDoc('g1', { adminUid: ADMIN.uid })),
  );
});

test('the organiser must stay in the member list', async () => {
  await assertFails(
    setDoc(doc(as(ADMIN), 'groups', 'g1'), groupDoc('g1', { phones: [MEMBER.phone] })),
  );
});

test('the document id must match the group id', async () => {
  await assertFails(setDoc(doc(as(ADMIN), 'groups', 'other'), groupDoc('g1')));
});

test('unexpected fields are refused', async () => {
  await assertFails(
    setDoc(doc(as(ADMIN), 'groups', 'g1'), { ...groupDoc('g1'), extra: true }),
  );
});

test('a member can read the group but not change or delete it', async () => {
  await seed('g1');
  const db = as(MEMBER);
  await assertSucceeds(getDoc(doc(db, 'groups', 'g1')));
  await assertFails(updateDoc(doc(db, 'groups', 'g1'), { 'data.name': 'Hacked' }));
  await assertFails(deleteDoc(doc(db, 'groups', 'g1')));
});

test('someone not in the group cannot read it', async () => {
  await seed('g1');
  await assertFails(getDoc(doc(as(STRANGER), 'groups', 'g1')));
});

test('people find their groups by their own phone number only', async () => {
  await seed('g1');
  await seed('g2', { phones: [ADMIN.phone] });
  const mine = query(collection(as(MEMBER), 'groups'), where('memberPhones', 'array-contains', MEMBER.phone));
  const snap = await assertSucceeds(getDocs(mine));
  if (snap.size !== 1) throw new Error(`expected 1 group, got ${snap.size}`);
  const theirs = query(collection(as(MEMBER), 'groups'), where('memberPhones', 'array-contains', ADMIN.phone));
  await assertFails(getDocs(theirs));
});

test('the organiser can update and delete, but not hand the group over', async () => {
  await seed('g1');
  const ref = doc(as(ADMIN), 'groups', 'g1');
  await assertSucceeds(
    setDoc(ref, groupDoc('g1', { phones: [ADMIN.phone, MEMBER.phone, STRANGER.phone] })),
  );
  await assertFails(
    setDoc(ref, groupDoc('g1', { adminUid: MEMBER.uid, phones: [ADMIN.phone] })),
  );
  await assertSucceeds(deleteDoc(ref));
});

test('a signed-in person with no phone number gets nothing', async () => {
  await seed('g1');
  const db = env.authenticatedContext('email-user').firestore();
  await assertFails(getDoc(doc(db, 'groups', 'g1')));
});
