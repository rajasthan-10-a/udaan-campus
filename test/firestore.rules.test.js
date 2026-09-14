const assert = require('chai').assert;
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

const PROJECT_ID = 'udaan-test';
let testEnv;

describe('Firestore security rules', () => {
  before(async () => {
    const rules = fs.readFileSync('firestore.rules', 'utf8');
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { rules }
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  it('prevents unauthenticated user from updating role field', async () => {
    const unauth = testEnv.unauthenticatedContext();
    const db = unauth.firestore();
    const ref = db.collection('users').doc('userA');
    await assertFails(ref.update({ role: 'super_manager' }));
  });

  it('prevents normal user from escalating their own role to super_manager', async () => {
    const user = testEnv.authenticatedContext('userB', { role: 'student' });
    const db = user.firestore();
    const ref = db.collection('users').doc('userB');
    await assertFails(ref.update({ role: 'super_manager' }));
  });

  it('prevents a new user from creating a privileged profile', async () => {
    const user = testEnv.authenticatedContext('newUser', { role: 'student' });
    const db = user.firestore();
    const ref = db.collection('users').doc('newUser');
    await assertFails(ref.set({
      uid: 'newUser',
      email: 'new@example.com',
      displayName: 'New User',
      role: 'manager',
      normalizedRole: 'manager',
    }));
    await assertSucceeds(ref.set({
      uid: 'newUser',
      email: 'new@example.com',
      displayName: 'New User',
      role: 'student',
      normalizedRole: 'student',
    }));
  });

  it('allows super_manager (via custom claim) to set role on a user', async () => {
    const sm = testEnv.authenticatedContext('ownerUid', { role: 'super_manager' });
    const db = sm.firestore();
    const ref = db.collection('users').doc('userC');
    // create doc first as super_manager should be able
    await assertSucceeds(ref.set({ name: 'User C', role: 'manager' }));
    // super_manager updating role
    await assertSucceeds(ref.update({ role: 'super_manager' }));
  });

  it('prevents regular client from writing audit_logs but allows admin service', async () => {
    const client = testEnv.authenticatedContext('clientUid', { role: 'student' });
    const clientDb = client.firestore();
    const clientRef = clientDb.collection('audit_logs').doc('a1');
    await assertFails(clientRef.set({ type: 'TEST', actor: 'clientUid' }));

    const svc = testEnv.authenticatedContext('svcUid', { admin: true });
    const svcDb = svc.firestore();
    const svcRef = svcDb.collection('audit_logs').doc('a2');
    await assertSucceeds(svcRef.set({ type: 'ROLE_ASSIGNED', actor: 'svcUid' }));
  });
});
