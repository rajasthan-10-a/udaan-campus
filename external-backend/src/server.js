const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const admin = require('firebase-admin');
const helmet = require('helmet');
const crypto = require('crypto');

if (!admin.apps.length) {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const credential = serviceAccountJson
    ? admin.credential.cert(JSON.parse(serviceAccountJson))
    : undefined;
  admin.initializeApp(credential ? { credential } : {});
}

const app = express();
const db = admin.firestore();
const port = Number(process.env.PORT || 8080);
app.disable('x-powered-by');
app.set('trust proxy', 1);
const auditActions = new Set([
  'CREATE_TEST',
  'SAVE_TEST_RESULTS',
  'HOMEWORK_CREATED',
  'HOMEWORK_UPDATED',
  'HOMEWORK_PUBLISHED',
  'ATTENDANCE_UPDATED',
  'QR_ATTENDANCE_RECORDED',
  'PARENT_LINKED',
]);
const sensitiveActionLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
});

app.use(express.json({ limit: '32kb' }));
app.use((req, res, next) => {
  req.requestId = crypto.randomUUID();
  res.setHeader('X-Request-Id', req.requestId);
  next();
});
app.use((req, res, next) => {
  if (req.method !== 'GET' && !req.is('application/json')) {
    return res.status(415).json({ error: 'Content-Type must be application/json' });
  }
  return next();
});
app.use(cors({
  origin: process.env.CORS_ORIGIN
    ? process.env.CORS_ORIGIN.split(',').map((origin) => origin.trim()).filter(Boolean)
    : false,
  methods: ['GET', 'POST'],
}));
app.use(helmet());
app.use(rateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
}));
app.use((req, res, next) => {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  next();
});

function getBearerToken(req) {
  const header = req.get('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}

async function requireAuth(req, res, next) {
  const token = getBearerToken(req);
  if (!token) {
    return res.status(401).json({ error: 'Missing Firebase ID token' });
  }

  try {
    req.user = await admin.auth().verifyIdToken(token);
    return next();
  } catch (error) {
    console.error('Firebase token verification failed', error);
    return res.status(401).json({ error: 'Invalid Firebase ID token' });
  }
}

function requireManager(req, res, next) {
  const role = req.user.role;
  if (role !== 'manager' && role !== 'super_manager') {
    return res.status(403).json({ error: 'Manager role required' });
  }
  return next();
}

function asyncRoute(handler) {
  return (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
}

function isValidUid(value) {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

function isValidEmail(value) {
  return typeof value === 'string' &&
    value.length <= 254 &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function isSafeDisplayName(value) {
  return typeof value === 'string' && value.trim().length >= 2 && value.length <= 120;
}

async function getCallerProfile(uid) {
  const snapshot = await db.collection('users').doc(uid).get();
  return snapshot.exists ? snapshot.data() : null;
}

async function validateStudentScope(req, studentUids) {
  const ids = [...new Set(studentUids)];
  if (ids.length === 0 || ids.length > 50 || ids.some((id) => typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(id))) {
    return { ok: false, status: 400, error: 'Invalid student scope' };
  }
  const callerProfile = await getCallerProfile(req.user.uid);
  const callerSchoolId = req.user.schoolId || callerProfile?.schoolId;
  if (typeof callerSchoolId !== 'string' || callerSchoolId.trim().length === 0) {
    return { ok: false, status: 409, error: 'Caller school scope is not configured' };
  }
  const references = ids.map((id) => db.collection('students').doc(id));
  const records = await db.getAll(...references);
  for (const record of records) {
    if (!record.exists || record.data()?.schoolId !== callerSchoolId) {
      return { ok: false, status: 403, error: 'Student is outside the caller school scope' };
    }
  }
  return { ok: true, ids, schoolId: callerSchoolId };
}

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.post('/v1/auth/sync-user', requireAuth, asyncRoute(async (req, res) => {
  const user = req.user;
  const profile = {
    uid: user.uid,
    email: user.email || null,
    displayName: user.name || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const userRef = db.collection('users').doc(user.uid);
  const existing = await userRef.get();
  if (!existing.exists) {
    profile.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await userRef.set(profile, { merge: true });
  return res.json({ ok: true, uid: user.uid });
}));

app.post('/v1/parent-links', sensitiveActionLimiter, requireAuth, requireManager, asyncRoute(async (req, res) => {
  const { parentUid, studentUid } = req.body || {};
  if (!isValidUid(parentUid) || !isValidUid(studentUid)) {
    return res.status(400).json({ error: 'parentUid and studentUid are required' });
  }
  if (parentUid === studentUid) {
    return res.status(400).json({ error: 'Parent and student must be different users' });
  }

  const [parentRecord, studentRecord] = await Promise.all([
    admin.auth().getUser(parentUid),
    db.collection('students').doc(studentUid).get(),
  ]);
  if (!studentRecord.exists) {
    return res.status(404).json({ error: 'Student profile not found' });
  }
  if ((parentRecord.customClaims || {}).role !== 'parent') {
    return res.status(400).json({ error: 'Target account is not a parent account' });
  }
  const scope = await validateStudentScope(req, [studentUid]);
  if (!scope.ok) return res.status(scope.status).json({ error: scope.error });

  const linkId = `${parentUid}_${studentUid}`;
  const batch = db.batch();
  batch.set(db.collection('users').doc(parentUid), {
    linkedChildren: admin.firestore.FieldValue.arrayUnion(studentUid),
    schoolId: scope.schoolId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(db.collection('parent_links').doc(linkId), {
    parentUid,
    studentUid,
    createdBy: req.user.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    active: true,
  }, { merge: true });
  await batch.commit();

  return res.status(201).json({ ok: true, linkId });
}));

app.post('/v1/parent-accounts', sensitiveActionLimiter, requireAuth, requireManager, asyncRoute(async (req, res) => {
  const { email, password, displayName, linkedChildren } = req.body || {};
  if (!isValidEmail(email) || typeof password !== 'string' ||
      !isSafeDisplayName(displayName) || password.length < 12 ||
      !Array.isArray(linkedChildren) || linkedChildren.length === 0 ||
      linkedChildren.length > 50) {
    return res.status(400).json({
      error: 'Valid email, display name, password (12+ chars), and 1-50 linked children are required',
    });
  }
  const scope = await validateStudentScope(req, linkedChildren);
  if (!scope.ok) return res.status(scope.status).json({ error: scope.error });
  const created = await admin.auth().createUser({ email, password, displayName });
  await admin.auth().setCustomUserClaims(created.uid, { role: 'parent' });
  await db.collection('users').doc(created.uid).set({
    uid: created.uid,
    email,
    displayName,
    role: 'parent',
    normalizedRole: 'parent',
    linkedChildren,
    schoolId: scope.schoolId,
    createdBy: req.user.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return res.status(201).json({ ok: true, uid: created.uid, email });
}));

app.post('/v1/audit-logs', sensitiveActionLimiter, requireAuth, asyncRoute(async (req, res) => {
  const role = req.user.role;
  if (role !== 'teacher' && role !== 'manager' && role !== 'super_manager') {
    return res.status(403).json({ error: 'Staff role required' });
  }
  const { action, targetType, targetId, performedByRole, oldValue, newValue } = req.body || {};
  if (![action, targetType, targetId, performedByRole].every(
    (value) => typeof value === 'string' && value.trim().length > 0,
  )) {
    return res.status(400).json({ error: 'Audit action, target type, and target ID are required' });
  }
  if (performedByRole !== role) {
    return res.status(400).json({ error: 'Audit role does not match authenticated role' });
  }
  if (!auditActions.has(action.trim()) ||
      !/^[a-z_]{2,64}$/.test(targetType.trim()) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(targetId.trim())) {
    return res.status(400).json({ error: 'Unsupported or invalid audit event' });
  }
  const serializedValues = JSON.stringify({ oldValue: oldValue || null, newValue: newValue || null });
  if (serializedValues.length > 12000) {
    return res.status(413).json({ error: 'Audit payload is too large' });
  }
  const auditRef = db.collection('audit_logs').doc();
  await auditRef.set({
    auditId: auditRef.id,
    action: action.trim(),
    targetType: targetType.trim(),
    targetId: targetId.trim(),
    performedBy: req.user.uid,
    performedByRole: role,
    oldValue: oldValue || null,
    newValue: newValue || null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  return res.status(201).json({ ok: true, auditId: auditRef.id });
}));

app.use((error, _req, res, _next) => {
  if (error instanceof SyntaxError && error.status === 400) {
    return res.status(400).json({ error: 'Invalid JSON body' });
  }
  console.error('Unhandled backend error', {
    requestId: _req.requestId,
    name: error?.name,
    message: error?.message,
  });
  return res.status(500).json({
    error: 'Internal server error',
    requestId: _req.requestId,
  });
});

app.listen(port, () => {
  console.log(`External backend listening on port ${port}`);
});
