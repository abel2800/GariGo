import crypto from 'crypto';
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { query } from '../db/pool.js';
import { signToken, authRequired } from '../middleware/auth.js';
import { sendPush } from '../services/push.js';
import { upload, publicUploadUrl } from '../middleware/upload.js';
import {
  quoteFare,
  haversineKm,
  estimateRoute,
} from '../services/fare.js';

const router = Router();

/** Set by createAdminRouter so booking can start matching. */
let matchingEngine = null;

const secret = () => process.env.JWT_SECRET || 'garigo_dev_secret';

/** Role → allowed permission keys (workers never get '*') */
const ROLE_PERMS = {
  super_admin: ['*'],
  city_ops: [
    'ops',
    'drivers',
    'docs',
    'trips',
    'sos',
    'zones',
    'announcements',
    'quests',
    'analytics',
    'push',
    'booking',
    'riders',
  ],
  support: ['ops', 'tickets', 'trips', 'riders', 'sos', 'booking'],
  call_center: ['ops', 'booking', 'riders', 'trips', 'tickets'],
  finance: ['finance', 'payouts', 'promos', 'pricing', 'analytics'],
  trust_safety: ['drivers', 'docs', 'sos', 'riders', 'audit', 'trips', 'ops'],
};

/** Roles that can be assigned when hiring workers (not CEO). */
const HIREABLE_ROLES = [
  'city_ops',
  'support',
  'call_center',
  'finance',
  'trust_safety',
];

const STAFF_ROLES = Object.keys(ROLE_PERMS);

function permsFor(role) {
  return ROLE_PERMS[role] || ROLE_PERMS.support;
}

function normalizePhone(raw) {
  let d = String(raw || '').replace(/\D/g, '');
  if (d.startsWith('251') && d.length === 12) return `+${d}`;
  if (d.startsWith('0') && d.length === 10) d = d.slice(1);
  if (d.length === 9 && (d.startsWith('9') || d.startsWith('7'))) {
    return `+251${d}`;
  }
  return null;
}

function adminPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    role: row.role,
    phone: row.phone || null,
    photoUrl: row.photo_url || null,
    active: row.active !== false,
    permissions: permsFor(row.role),
    hasTotp: !!(row.totp_secret || row.has_totp),
    createdAt: row.created_at || null,
  };
}

function requirePerm(...needed) {
  return async (req, res, next) => {
    try {
      const { rows } = await query(
        `SELECT id, email, name, role, totp_secret FROM admin_users WHERE id = $1`,
        [req.user.sub],
      );
      const admin = rows[0];
      if (!admin) return res.status(401).json({ error: 'Admin not found' });
      req.admin = admin;
      const perms = permsFor(admin.role);
      if (perms.includes('*') || needed.some((p) => perms.includes(p))) {
        return next();
      }
      return res.status(403).json({ error: 'Insufficient role permission' });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  };
}

async function audit(adminId, action, meta = {}) {
  await query(
    `INSERT INTO audit_logs (admin_id, action, meta) VALUES ($1, $2, $3)`,
    [adminId, action, JSON.stringify(meta)],
  );
}

/* ── TOTP (RFC 6238) helpers ─────────────────────────────────────────── */

const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function toBase32(buf) {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of buf) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += B32[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += B32[(value << (5 - bits)) & 31];
  return out;
}

function fromBase32(str) {
  const clean = str.replace(/=+$/, '').toUpperCase();
  let bits = 0;
  let value = 0;
  const out = [];
  for (const c of clean) {
    const idx = B32.indexOf(c);
    if (idx < 0) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

function hotp(key, counter) {
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64BE(BigInt(counter));
  const hmac = crypto.createHmac('sha1', key).update(buf).digest();
  const offset = hmac[hmac.length - 1] & 0xf;
  const code =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);
  return String(code % 1_000_000).padStart(6, '0');
}

function verifyTotp(secretB32, code, window = 1) {
  const key = fromBase32(secretB32);
  const step = Math.floor(Date.now() / 1000 / 30);
  for (let w = -window; w <= window; w++) {
    if (hotp(key, step + w) === String(code)) return true;
  }
  return false;
}

function money(n) {
  return Number(n) || 0;
}

/* ── Auth ────────────────────────────────────────────────────────────── */

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const { rows } = await query(`SELECT * FROM admin_users WHERE email = $1`, [
    email,
  ]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  if (user.active === false) {
    return res.status(403).json({ error: 'Account deactivated' });
  }
  res.json({
    requires2fa: true,
    hasTotp: !!user.totp_secret,
    tempToken: signToken({ sub: user.id, role: 'admin_pending' }, '10m'),
  });
});

router.post('/2fa', async (req, res) => {
  const { tempToken, code } = req.body;
  try {
    const decoded = jwt.verify(tempToken, secret());
    if (decoded.role !== 'admin_pending') {
      return res.status(401).json({ error: 'Invalid temp token' });
    }
    const { rows } = await query(
      `SELECT id, email, name, role, totp_secret, phone, photo_url, active
       FROM admin_users WHERE id = $1`,
      [decoded.sub],
    );
    const user = rows[0];
    if (!user) return res.status(401).json({ error: 'Admin not found' });
    if (user.active === false) {
      return res.status(403).json({ error: 'Account deactivated' });
    }

    let ok = false;
    if (user.totp_secret) {
      ok = verifyTotp(user.totp_secret, code);
    } else {
      // Dev fallback until TOTP is enrolled
      ok = String(code) === '123456';
    }
    if (!ok) return res.status(401).json({ error: 'Invalid 2FA code' });

    const token = signToken({ sub: user.id, role: 'admin' });
    await audit(user.id, 'admin_login', { email: user.email });
    res.json({
      token,
      admin: adminPublic(user),
    });
  } catch {
    res.status(401).json({ error: 'Invalid temp token' });
  }
});

router.get('/me', authRequired(['admin']), async (req, res) => {
  const { rows } = await query(
    `SELECT id, email, name, role, phone, photo_url, active,
            totp_secret IS NOT NULL AS has_totp, created_at
     FROM admin_users WHERE id = $1`,
    [req.user.sub],
  );
  const user = rows[0];
  if (!user) return res.status(404).json({ error: 'Not found' });
  if (user.active === false) {
    return res.status(403).json({ error: 'Account deactivated' });
  }
  res.json(adminPublic(user));
});

router.patch('/me', authRequired(['admin']), async (req, res) => {
  try {
    const { name, phone, password, currentPassword } = req.body;
    const { rows } = await query(`SELECT * FROM admin_users WHERE id = $1`, [
      req.user.sub,
    ]);
    const user = rows[0];
    if (!user) return res.status(404).json({ error: 'Not found' });

    let passwordHash = user.password_hash;
    if (password) {
      if (!currentPassword || !(await bcrypt.compare(currentPassword, user.password_hash))) {
        return res.status(400).json({ error: 'Current password required' });
      }
      if (String(password).length < 6) {
        return res.status(400).json({ error: 'Password must be at least 6 characters' });
      }
      passwordHash = await bcrypt.hash(String(password), 10);
    }

    const { rows: updated } = await query(
      `UPDATE admin_users SET
         name = COALESCE($2, name),
         phone = COALESCE($3, phone),
         password_hash = $4,
         updated_at = NOW()
       WHERE id = $1
       RETURNING id, email, name, role, phone, photo_url, active,
                 totp_secret IS NOT NULL AS has_totp, created_at`,
      [
        req.user.sub,
        name != null ? String(name).trim() : null,
        phone != null ? String(phone).trim() : null,
        passwordHash,
      ],
    );
    await audit(req.user.sub, 'admin_self_profile', {});
    res.json({ admin: adminPublic(updated[0]) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post(
  '/me/photo',
  authRequired(['admin']),
  upload.single('file'),
  async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ error: 'Photo required' });
      const url = publicUploadUrl(req.file.filename, req);
      const { rows } = await query(
        `UPDATE admin_users SET photo_url = $2, updated_at = NOW()
         WHERE id = $1
         RETURNING id, email, name, role, phone, photo_url, active,
                   totp_secret IS NOT NULL AS has_totp, created_at`,
        [req.user.sub, url],
      );
      await audit(req.user.sub, 'admin_self_photo', {});
      res.json({ admin: adminPublic(rows[0]), photoUrl: url });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  },
);

router.post(
  '/2fa/setup',
  authRequired(['admin']),
  requirePerm('*'),
  async (req, res) => {
    const secretB32 = toBase32(crypto.randomBytes(20));
    await query(`UPDATE admin_users SET totp_secret = $2 WHERE id = $1`, [
      req.user.sub,
      secretB32,
    ]);
    await audit(req.user.sub, 'totp_setup', {});
    const email = req.admin.email;
    res.json({
      secret: secretB32,
      otpauthUrl: `otpauth://totp/GariGo:${encodeURIComponent(email)}?secret=${secretB32}&issuer=GariGo&digits=6&period=30`,
      note: 'Scan with an authenticator app. Dev fallback 123456 is disabled after setup.',
    });
  },
);

/* ── Ops snapshot ────────────────────────────────────────────────────── */

router.get(
  '/ops/snapshot',
  authRequired(['admin']),
  requirePerm('ops'),
  async (req, res) => {
    const online = await query(
      `SELECT COUNT(*)::int AS c FROM drivers WHERE online_status = 'online'`,
    );
    const trips = await query(
      `SELECT COUNT(*)::int AS c FROM trips WHERE status IN ('matched','arriving','arrived','in_progress','verifying')`,
    );
    const matching = await query(
      `SELECT COUNT(*)::int AS c FROM trips WHERE status IN ('requested','matching')`,
    );
    const sos = await query(
      `SELECT s.*, t.pickup_landmark, t.vehicle_category
       FROM sos_alerts s
       LEFT JOIN trips t ON t.id = s.trip_id
       WHERE s.status IN ('open','dispatched')
       ORDER BY s.created_at DESC LIMIT 20`,
    );
    const drivers = await query(
      `SELECT id, name, category, online_status, lat, lng, heading
       FROM drivers
       WHERE lat IS NOT NULL AND online_status IN ('online','on_trip')
       LIMIT 500`,
    );
    const pending = await query(
      `SELECT id, name, phone, category, approval_status, created_at
       FROM drivers
       WHERE approval_status = 'pending'
       ORDER BY created_at DESC LIMIT 50`,
    );
    const activeTrips = await query(
      `SELECT t.id, t.status, t.vehicle_category, t.pickup_landmark, t.dropoff_landmark,
              t.fare_total, t.requested_at,
              r.name AS rider_name, d.name AS driver_name
       FROM trips t
       LEFT JOIN riders r ON r.id = t.rider_id
       LEFT JOIN drivers d ON d.id = t.driver_id
       WHERE t.status IN ('matched','arriving','arrived','in_progress','verifying','matching','requested')
       ORDER BY t.requested_at DESC LIMIT 30`,
    );
    const recentReq = await query(
      `SELECT COUNT(*)::int AS c FROM trips
       WHERE requested_at > NOW() - INTERVAL '1 minute'`,
    );
    const demand = await query(
      `SELECT pickup_lat AS lat, pickup_lng AS lng
       FROM trips
       WHERE requested_at > NOW() - INTERVAL '2 hours'
         AND pickup_lat IS NOT NULL AND pickup_lng IS NOT NULL
       ORDER BY requested_at DESC
       LIMIT 200`,
    );
    res.json({
      kpis: {
        online: online.rows[0].c,
        activeTrips: trips.rows[0].c,
        matching: matching.rows[0].c,
        sos: sos.rows.length,
        reqPerMin: recentReq.rows[0].c,
      },
      sos: sos.rows,
      drivers: drivers.rows,
      pendingDrivers: pending.rows,
      activeTrips: activeTrips.rows,
      demandHeat: demand.rows,
    });
  },
);

/* ── Drivers KYC / moderation ────────────────────────────────────────── */

router.post(
  '/drivers/:id/approve',
  authRequired(['admin']),
  requirePerm('drivers'),
  async (req, res) => {
    const rejected = await query(
      `SELECT COUNT(*)::int AS c FROM driver_documents
       WHERE driver_id = $1 AND rejection_reason IS NOT NULL`,
      [req.params.id],
    );
    if ((rejected.rows[0]?.c || 0) > 0) {
      return res.status(400).json({
        error: 'Clear declined documents first (or wait for driver re-upload)',
      });
    }
    await query(
      `UPDATE driver_documents
       SET verified = TRUE, rejection_reason = NULL
       WHERE driver_id = $1`,
      [req.params.id],
    );
    await query(
      `UPDATE drivers SET approval_status = 'approved', rejection_reasons = '{}', updated_at = NOW() WHERE id = $1`,
      [req.params.id],
    );
    await audit(req.user.sub, 'approve_driver', { driverId: req.params.id });
    res.json({ ok: true });
  },
);

router.post(
  '/drivers/:id/reject',
  authRequired(['admin']),
  requirePerm('drivers'),
  async (req, res) => {
    const reasons = req.body.reasons || ['Rejected by admin'];
    await query(
      `UPDATE drivers SET approval_status = 'rejected', rejection_reasons = $2, updated_at = NOW() WHERE id = $1`,
      [req.params.id, reasons],
    );
    await audit(req.user.sub, 'reject_driver', {
      driverId: req.params.id,
      reasons,
    });
    res.json({ ok: true });
  },
);

router.get(
  '/drivers/:id',
  authRequired(['admin']),
  requirePerm('drivers'),
  async (req, res) => {
    const { rows } = await query(`SELECT * FROM drivers WHERE id = $1`, [
      req.params.id,
    ]);
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    const docs = await query(
      `SELECT * FROM driver_documents WHERE driver_id = $1 ORDER BY created_at DESC`,
      [req.params.id],
    );
    const vehicles = await query(
      `SELECT * FROM vehicles WHERE driver_id = $1`,
      [req.params.id],
    );
    res.json({ driver: rows[0], documents: docs.rows, vehicles: vehicles.rows });
  },
);

router.post(
  '/drivers/:id/status',
  authRequired(['admin']),
  requirePerm('drivers', 'riders'),
  async (req, res) => {
    const status = req.body.status;
    if (!['active', 'suspended', 'banned'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    await query(
      `UPDATE drivers SET status = $2, online_status = CASE WHEN $2 = 'active' THEN online_status ELSE 'offline' END, updated_at = NOW() WHERE id = $1`,
      [req.params.id, status],
    );
    await audit(req.user.sub, 'driver_status', {
      driverId: req.params.id,
      status,
    });
    res.json({ ok: true });
  },
);

router.get(
  '/documents/pending',
  authRequired(['admin']),
  requirePerm('docs', 'drivers'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT dd.*, d.name AS driver_name, d.phone AS driver_phone
       FROM driver_documents dd
       JOIN drivers d ON d.id = dd.driver_id
       WHERE dd.verified = FALSE AND dd.rejection_reason IS NULL
       ORDER BY dd.created_at DESC LIMIT 100`,
    );
    res.json({ documents: rows });
  },
);

router.post(
  '/documents/:id/verify',
  authRequired(['admin']),
  requirePerm('docs', 'drivers'),
  async (req, res) => {
    const { verified = true, rejectionReason = null } = req.body;
    const docRes = await query(
      `SELECT id, driver_id, doc_type FROM driver_documents WHERE id = $1`,
      [req.params.id],
    );
    const doc = docRes.rows[0];
    if (!doc) return res.status(404).json({ error: 'Document not found' });

    const isVerified = !!verified;
    const reason = isVerified
      ? null
      : String(rejectionReason || 'Unclear or invalid document').trim();

    await query(
      `UPDATE driver_documents
       SET verified = $2, rejection_reason = $3
       WHERE id = $1`,
      [req.params.id, isVerified, reason],
    );

    if (!isVerified) {
      const label = doc.doc_type;
      await query(
        `UPDATE drivers
         SET approval_status = 'rejected',
             rejection_reasons = $2,
             updated_at = NOW()
         WHERE id = $1`,
        [
          doc.driver_id,
          [`Please re-upload: ${label} — ${reason}`],
        ],
      );
    }

    await audit(req.user.sub, 'verify_document', {
      documentId: req.params.id,
      driverId: doc.driver_id,
      docType: doc.doc_type,
      verified: isVerified,
      rejectionReason: reason,
    });
    res.json({ ok: true });
  },
);

/* ── Riders ──────────────────────────────────────────────────────────── */

router.get(
  '/riders/lookup',
  authRequired(['admin']),
  requirePerm('booking', 'riders', '*'),
  async (req, res) => {
    try {
      const phone = normalizePhone(req.query.phone);
      if (!phone) return res.status(400).json({ error: 'Invalid Ethiopian phone' });
      const { rows } = await query(
        `SELECT id, phone, name, photo_url, rating_avg, total_trips, status, created_at
         FROM riders WHERE phone = $1`,
        [phone],
      );
      res.json({
        phone,
        rider: rows[0]
          ? {
              id: rows[0].id,
              phone: rows[0].phone,
              name: rows[0].name,
              photoUrl: rows[0].photo_url,
              rating: Number(rows[0].rating_avg),
              totalTrips: rows[0].total_trips,
              status: rows[0].status,
            }
          : null,
      });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  },
);

router.post(
  '/riders',
  authRequired(['admin']),
  requirePerm('booking', 'riders', '*'),
  async (req, res) => {
    try {
      const phone = normalizePhone(req.body.phone);
      const name = String(req.body.name || '').trim() || 'Caller';
      if (!phone) return res.status(400).json({ error: 'Invalid Ethiopian phone' });
      const existing = await query(`SELECT * FROM riders WHERE phone = $1`, [phone]);
      if (existing.rows[0]) {
        const r = existing.rows[0];
        return res.json({
          created: false,
          rider: {
            id: r.id,
            phone: r.phone,
            name: r.name,
            photoUrl: r.photo_url,
            rating: Number(r.rating_avg),
          },
        });
      }
      const { rows } = await query(
        `INSERT INTO riders (phone, name, is_guest)
         VALUES ($1, $2, TRUE)
         RETURNING id, phone, name, photo_url, rating_avg`,
        [phone, name],
      );
      const r = rows[0];
      await audit(req.user.sub, 'rider_create_callcenter', { riderId: r.id, phone });
      res.status(201).json({
        created: true,
        rider: {
          id: r.id,
          phone: r.phone,
          name: r.name,
          photoUrl: r.photo_url,
          rating: Number(r.rating_avg),
        },
      });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  },
);

router.get(
  '/riders/:id',
  authRequired(['admin']),
  requirePerm('riders'),
  async (req, res) => {
    const { rows } = await query(`SELECT * FROM riders WHERE id = $1`, [
      req.params.id,
    ]);
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json({ rider: rows[0] });
  },
);

router.post(
  '/riders/:id/status',
  authRequired(['admin']),
  requirePerm('riders'),
  async (req, res) => {
    const status = req.body.status;
    if (!['active', 'suspended', 'banned'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    await query(`UPDATE riders SET status = $2, updated_at = NOW() WHERE id = $1`, [
      req.params.id,
      status,
    ]);
    await audit(req.user.sub, 'rider_status', {
      riderId: req.params.id,
      status,
    });
    res.json({ ok: true });
  },
);

/* ── SOS ─────────────────────────────────────────────────────────────── */

router.patch(
  '/sos/:id',
  authRequired(['admin']),
  requirePerm('sos'),
  async (req, res) => {
    const { status, adminNotes } = req.body;
    if (!['open', 'dispatched', 'resolved'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    await query(
      `UPDATE sos_alerts
       SET status = $2,
           admin_notes = COALESCE($3, admin_notes),
           resolved_at = CASE WHEN $2 = 'resolved' THEN NOW() ELSE resolved_at END
       WHERE id = $1`,
      [req.params.id, status, adminNotes ?? null],
    );
    await audit(req.user.sub, 'sos_update', {
      sosId: req.params.id,
      status,
    });
    res.json({ ok: true });
  },
);

/* ── Trips ───────────────────────────────────────────────────────────── */

router.get(
  '/trips',
  authRequired(['admin']),
  requirePerm('trips'),
  async (req, res) => {
    const q = (req.query.q || '').toString().trim();
    const status = (req.query.status || '').toString().trim();
    const params = [];
    const where = [];
    if (q) {
      params.push(`%${q}%`);
      where.push(
        `(t.id::text ILIKE $${params.length} OR t.pickup_landmark ILIKE $${params.length} OR t.dropoff_landmark ILIKE $${params.length} OR r.name ILIKE $${params.length} OR d.name ILIKE $${params.length})`,
      );
    }
    if (status) {
      params.push(status);
      where.push(`t.status = $${params.length}`);
    }
    const sql = `
      SELECT t.id, t.status, t.vehicle_category, t.pickup_landmark, t.dropoff_landmark,
             t.fare_total, t.payment_method, t.payment_status, t.requested_at, t.completed_at,
             r.name AS rider_name, r.id AS rider_id,
             d.name AS driver_name, d.id AS driver_id
      FROM trips t
      LEFT JOIN riders r ON r.id = t.rider_id
      LEFT JOIN drivers d ON d.id = t.driver_id
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY t.requested_at DESC
      LIMIT 100`;
    const { rows } = await query(sql, params);
    res.json({ trips: rows });
  },
);

router.get(
  '/trips/:id',
  authRequired(['admin']),
  requirePerm('trips'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT t.*,
              r.name AS rider_name, r.phone AS rider_phone, r.photo_url AS rider_photo_url,
              d.name AS driver_name, d.phone AS driver_phone, d.photo_url AS driver_photo_url
       FROM trips t
       LEFT JOIN riders r ON r.id = t.rider_id
       LEFT JOIN drivers d ON d.id = t.driver_id
       WHERE t.id = $1`,
      [req.params.id],
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    const payments = await query(
      `SELECT * FROM payments WHERE trip_id = $1 ORDER BY created_at DESC`,
      [req.params.id],
    );
    res.json({ trip: rows[0], payments: payments.rows });
  },
);

/* ── Support tickets ─────────────────────────────────────────────────── */

router.get(
  '/tickets',
  authRequired(['admin']),
  requirePerm('tickets'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT * FROM support_tickets
       ORDER BY
         CASE status WHEN 'open' THEN 0 WHEN 'in_progress' THEN 1 ELSE 2 END,
         created_at DESC
       LIMIT 100`,
    );
    res.json({ tickets: rows });
  },
);

router.get(
  '/tickets/:id',
  authRequired(['admin']),
  requirePerm('tickets'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT * FROM support_tickets WHERE id = $1`,
      [req.params.id],
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json({ ticket: rows[0] });
  },
);

router.patch(
  '/tickets/:id',
  authRequired(['admin']),
  requirePerm('tickets'),
  async (req, res) => {
    const { status, resolutionNotes, priority } = req.body;
    await query(
      `UPDATE support_tickets SET
         status = COALESCE($2, status),
         resolution_notes = COALESCE($3, resolution_notes),
         priority = COALESCE($4, priority),
         assigned_agent_id = $5,
         resolved_at = CASE WHEN $2 = 'resolved' THEN NOW() ELSE resolved_at END
       WHERE id = $1`,
      [
        req.params.id,
        status || null,
        resolutionNotes || null,
        priority || null,
        req.user.sub,
      ],
    );
    await audit(req.user.sub, 'ticket_update', {
      ticketId: req.params.id,
      status,
    });
    res.json({ ok: true });
  },
);

router.post(
  '/tickets',
  authRequired(['admin']),
  requirePerm('tickets'),
  async (req, res) => {
    const {
      userId,
      userType = 'rider',
      category = 'general',
      subject,
      priority = 'normal',
      tripId,
      message,
    } = req.body;
    if (!userId || !subject) {
      return res.status(400).json({ error: 'userId and subject required' });
    }
    const messages = message
      ? [{ from: 'admin', body: message, at: new Date().toISOString() }]
      : [];
    const { rows } = await query(
      `INSERT INTO support_tickets
         (trip_id, user_id, user_type, category, subject, priority, messages)
       VALUES ($1,$2,$3,$4,$5,$6,$7::jsonb)
       RETURNING *`,
      [
        tripId || null,
        userId,
        userType,
        category,
        subject,
        priority,
        JSON.stringify(messages),
      ],
    );
    await audit(req.user.sub, 'ticket_create', { ticketId: rows[0].id });
    res.status(201).json({ ticket: rows[0] });
  },
);

/* ── Pricing / zones / promos ────────────────────────────────────────── */

router.get(
  '/fares',
  authRequired(['admin']),
  requirePerm('pricing'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT * FROM fare_configs ORDER BY category`,
    );
    res.json({ fares: rows });
  },
);

router.put(
  '/fares/:category',
  authRequired(['admin']),
  requirePerm('pricing'),
  async (req, res) => {
    const { baseFare, perKm, perMin, minimumFare } = req.body;
    await query(
      `INSERT INTO fare_configs (category, base_fare, per_km, per_min, minimum_fare)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (category) DO UPDATE SET
         base_fare = EXCLUDED.base_fare,
         per_km = EXCLUDED.per_km,
         per_min = EXCLUDED.per_min,
         minimum_fare = EXCLUDED.minimum_fare`,
      [req.params.category, baseFare, perKm, perMin, minimumFare],
    );
    await audit(req.user.sub, 'fare_update', {
      category: req.params.category,
      ...req.body,
    });
    res.json({ ok: true });
  },
);

router.get(
  '/zones',
  authRequired(['admin']),
  requirePerm('zones'),
  async (req, res) => {
    const { rows } = await query(`SELECT * FROM zones ORDER BY name`);
    res.json({ zones: rows });
  },
);

router.put(
  '/zones/:id',
  authRequired(['admin']),
  requirePerm('zones'),
  async (req, res) => {
    const {
      surgeMultiplier,
      name,
      centerLat,
      centerLng,
      radiusKm,
      active,
      baseFareOverrides,
      polygon,
    } = req.body;
    await query(
      `UPDATE zones SET
         surge_multiplier = COALESCE($2, surge_multiplier),
         name = COALESCE($3, name),
         center_lat = COALESCE($4, center_lat),
         center_lng = COALESCE($5, center_lng),
         radius_km = COALESCE($6, radius_km),
         active = COALESCE($7, active),
         base_fare_overrides = COALESCE($8::jsonb, base_fare_overrides),
         polygon = COALESCE($9::jsonb, polygon)
       WHERE id = $1`,
      [
        req.params.id,
        surgeMultiplier ?? null,
        name ?? null,
        centerLat ?? null,
        centerLng ?? null,
        radiusKm ?? null,
        active ?? null,
        baseFareOverrides != null ? JSON.stringify(baseFareOverrides) : null,
        polygon != null ? JSON.stringify(polygon) : null,
      ],
    );
    await audit(req.user.sub, 'zone_update', { zoneId: req.params.id, ...req.body });
    res.json({ ok: true });
  },
);

router.post(
  '/zones',
  authRequired(['admin']),
  requirePerm('zones'),
  async (req, res) => {
    const {
      name,
      surgeMultiplier = 1.0,
      polygon = null,
      centerLat = null,
      centerLng = null,
      radiusKm = 3,
      baseFareOverrides = {},
    } = req.body;
    const { rows } = await query(
      `INSERT INTO zones
         (name, surge_multiplier, polygon, center_lat, center_lng, radius_km, base_fare_overrides)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb) RETURNING *`,
      [
        name,
        surgeMultiplier,
        polygon ? JSON.stringify(polygon) : null,
        centerLat,
        centerLng,
        radiusKm,
        JSON.stringify(baseFareOverrides || {}),
      ],
    );
    await audit(req.user.sub, 'zone_create', { zoneId: rows[0].id, name });
    res.json({ zone: rows[0] });
  },
);

router.get(
  '/promos',
  authRequired(['admin']),
  requirePerm('promos'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT * FROM promos ORDER BY valid_from DESC`,
    );
    res.json({ promos: rows });
  },
);

router.post(
  '/promos',
  authRequired(['admin']),
  requirePerm('promos'),
  async (req, res) => {
    const {
      code,
      discountType = 'fixed',
      value,
      validTo,
      usageLimit,
      zoneRestriction,
      active = true,
    } = req.body;
    const { rows } = await query(
      `INSERT INTO promos (code, discount_type, value, valid_to, usage_limit, zone_restriction, active)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [
        String(code).toUpperCase(),
        discountType,
        value,
        validTo || null,
        usageLimit || null,
        zoneRestriction || null,
        active !== false,
      ],
    );
    await audit(req.user.sub, 'promo_create', { code });
    res.json({ promo: rows[0] });
  },
);

router.patch(
  '/promos/:id',
  authRequired(['admin']),
  requirePerm('promos'),
  async (req, res) => {
    const { active, value, usageLimit, validTo, discountType } = req.body;
    await query(
      `UPDATE promos SET
         active = COALESCE($2, active),
         value = COALESCE($3, value),
         usage_limit = COALESCE($4, usage_limit),
         valid_to = COALESCE($5, valid_to),
         discount_type = COALESCE($6, discount_type)
       WHERE id = $1`,
      [
        req.params.id,
        active ?? null,
        value ?? null,
        usageLimit ?? null,
        validTo ?? null,
        discountType ?? null,
      ],
    );
    await audit(req.user.sub, 'promo_update', { promoId: req.params.id, ...req.body });
    res.json({ ok: true });
  },
);

/* ── Finance ─────────────────────────────────────────────────────────── */

router.get(
  '/finance/summary',
  authRequired(['admin']),
  requirePerm('finance'),
  async (req, res) => {
    const gross = await query(
      `SELECT COALESCE(SUM(amount),0)::int AS c FROM payments WHERE status IN ('paid','cash_owed')`,
    );
    const commission = await query(
      `SELECT COALESCE(SUM(commission_amount),0)::int AS c FROM payments WHERE status IN ('paid','cash_owed')`,
    );
    const byMethod = await query(
      `SELECT method, COALESCE(SUM(amount),0)::int AS total
       FROM payments WHERE status IN ('paid','cash_owed')
       GROUP BY method`,
    );
    const cashDebt = await query(
      `SELECT COALESCE(SUM(cash_debt),0)::int AS c FROM drivers WHERE cash_debt > 0`,
    );
    const driverBalance = await query(
      `SELECT COALESCE(SUM(available_balance),0)::int AS c FROM drivers`,
    );
    res.json({
      grossFares: money(gross.rows[0].c),
      commission: money(commission.rows[0].c),
      byMethod: byMethod.rows,
      cashDebtTotal: money(cashDebt.rows[0].c),
      driverBalances: money(driverBalance.rows[0].c),
    });
  },
);

router.get(
  '/finance/cash-debt',
  authRequired(['admin']),
  requirePerm('finance'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT id, name, phone, cash_debt, available_balance
       FROM drivers WHERE cash_debt > 0
       ORDER BY cash_debt DESC LIMIT 100`,
    );
    res.json({ drivers: rows });
  },
);

router.post(
  '/finance/cash-debt/:driverId/settle',
  authRequired(['admin']),
  requirePerm('finance'),
  async (req, res) => {
    const driverId = req.params.driverId;
    const { rows } = await query(
      `SELECT id, cash_debt, available_balance, name FROM drivers WHERE id = $1`,
      [driverId],
    );
    const driver = rows[0];
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    const owed = Number(driver.cash_debt) || 0;
    if (owed <= 0) return res.status(400).json({ error: 'No cash debt' });

    const amount =
      req.body.amount != null ? Number(req.body.amount) : owed;
    if (!Number.isFinite(amount) || amount <= 0 || amount > owed) {
      return res.status(400).json({ error: 'Invalid settle amount' });
    }

    const fromBalance = req.body.fromBalance !== false;
    const bal = Number(driver.available_balance) || 0;
    let deducted = 0;
    if (fromBalance && bal > 0) {
      deducted = Math.min(bal, amount);
    }

    await query(
      `UPDATE drivers SET
         cash_debt = cash_debt - $2,
         available_balance = available_balance - $3,
         updated_at = NOW()
       WHERE id = $1`,
      [driverId, amount, deducted],
    );
    await audit(req.user.sub, 'cash_debt_settle', {
      driverId,
      amount,
      deductedFromBalance: deducted,
      collectedExternally: amount - deducted,
    });
    res.json({
      ok: true,
      settled: amount,
      deductedFromBalance: deducted,
      remainingDebt: owed - amount,
    });
  },
);

router.get(
  '/finance/payouts',
  authRequired(['admin']),
  requirePerm('payouts', 'finance'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT id, name, phone, available_balance, telebirr_merchant_id, cbe_account, hellocash_wallet_id
       FROM drivers WHERE available_balance > 0
       ORDER BY available_balance DESC LIMIT 500`,
    );
    const total = rows.reduce((s, d) => s + money(d.available_balance), 0);
    const history = await query(
      `SELECT pl.*, d.name AS driver_name
       FROM payout_ledger pl
       JOIN drivers d ON d.id = pl.driver_id
       ORDER BY pl.created_at DESC LIMIT 50`,
    );
    res.json({
      drivers: rows,
      count: rows.length,
      totalBr: total,
      recentPayouts: history.rows,
    });
  },
);

router.post(
  '/finance/payouts/process',
  authRequired(['admin']),
  requirePerm('payouts', 'finance'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT id, available_balance, telebirr_merchant_id, cbe_account, hellocash_wallet_id
       FROM drivers WHERE available_balance > 0`,
    );
    const total = rows.reduce((s, d) => s + money(d.available_balance), 0);
    for (const d of rows) {
      const amount = money(d.available_balance);
      const method = d.telebirr_merchant_id
        ? 'telebirr'
        : d.cbe_account
          ? 'cbe_birr'
          : d.hellocash_wallet_id
            ? 'hellocash'
            : 'internal';
      await query(
        `INSERT INTO payout_ledger (driver_id, amount, method, status, processed_by, meta)
         VALUES ($1, $2, $3, 'paid', $4, $5::jsonb)`,
        [
          d.id,
          amount,
          method,
          req.user.sub,
          JSON.stringify({
            note: 'Batch payout — recorded in ledger; wire to PSP when credentials set',
          }),
        ],
      );
      await query(
        `UPDATE drivers SET available_balance = 0, updated_at = NOW() WHERE id = $1`,
        [d.id],
      );
    }
    await audit(req.user.sub, 'payout_batch', {
      count: rows.length,
      totalBr: total,
      driverIds: rows.map((r) => r.id),
    });
    res.json({ ok: true, count: rows.length, totalBr: total });
  },
);

/* ── Analytics ───────────────────────────────────────────────────────── */

router.get(
  '/analytics',
  authRequired(['admin']),
  requirePerm('analytics'),
  async (req, res) => {
    const completed = await query(
      `SELECT COUNT(*)::int AS c FROM trips WHERE status = 'completed'
       AND completed_at > NOW() - INTERVAL '7 days'`,
    );
    const cancelled = await query(
      `SELECT COUNT(*)::int AS c FROM trips WHERE status = 'cancelled'
       AND requested_at > NOW() - INTERVAL '7 days'`,
    );
    const gmv = await query(
      `SELECT COALESCE(SUM(fare_total),0)::int AS c FROM trips
       WHERE status = 'completed' AND completed_at > NOW() - INTERVAL '7 days'`,
    );
    const acceptance = await query(
      `SELECT COALESCE(AVG(acceptance_rate),0)::float AS c FROM drivers
       WHERE approval_status = 'approved'`,
    );
    const series = await query(
      `SELECT date_trunc('day', completed_at)::date AS day,
              COUNT(*)::int AS trips,
              COALESCE(SUM(fare_total),0)::int AS gmv
       FROM trips
       WHERE status = 'completed' AND completed_at > NOW() - INTERVAL '14 days'
       GROUP BY 1 ORDER BY 1`,
    );
    const total7 = completed.rows[0].c + cancelled.rows[0].c;
    res.json({
      last7Days: {
        completed: completed.rows[0].c,
        cancelled: cancelled.rows[0].c,
        cancelRate: total7 ? cancelled.rows[0].c / total7 : 0,
        gmv: gmv.rows[0].c,
        avgAcceptance: acceptance.rows[0].c,
      },
      series: series.rows,
    });
  },
);

/* ── Comms ───────────────────────────────────────────────────────────── */

router.post(
  '/push',
  authRequired(['admin']),
  requirePerm('push'),
  async (req, res) => {
    const { title, body, audience = 'drivers' } = req.body;
    if (!title || !body) {
      return res.status(400).json({ error: 'title and body required' });
    }
    let tokens = [];
    if (audience === 'drivers' || audience === 'all') {
      const d = await query(
        `SELECT fcm_token FROM drivers WHERE fcm_token IS NOT NULL`,
      );
      tokens = tokens.concat(d.rows.map((r) => r.fcm_token));
    }
    if (audience === 'riders' || audience === 'all') {
      const r = await query(
        `SELECT fcm_token FROM riders WHERE fcm_token IS NOT NULL`,
      );
      tokens = tokens.concat(r.rows.map((x) => x.fcm_token));
    }
    let sent = 0;
    for (const t of tokens) {
      const result = await sendPush(t, { title, body });
      if (result.ok) sent += 1;
    }
    const { rows: camp } = await query(
      `INSERT INTO push_campaigns (title, body, audience, targeted, sent, created_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [title, body, audience, tokens.length, sent, req.user.sub],
    );
    await audit(req.user.sub, 'push_broadcast', {
      title,
      audience,
      tokens: tokens.length,
      sent,
      campaignId: camp[0].id,
    });
    res.json({
      ok: true,
      targeted: tokens.length,
      sent,
      campaign: camp[0],
    });
  },
);

router.get(
  '/push',
  authRequired(['admin']),
  requirePerm('push'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT * FROM push_campaigns ORDER BY created_at DESC LIMIT 50`,
    );
    res.json({ campaigns: rows });
  },
);

router.get(
  '/announcements',
  authRequired(['admin']),
  requirePerm('announcements'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT * FROM announcements ORDER BY created_at DESC LIMIT 50`,
    );
    res.json({ announcements: rows });
  },
);

router.post(
  '/announcements',
  authRequired(['admin']),
  requirePerm('announcements'),
  async (req, res) => {
    const { title, body, audience = 'drivers' } = req.body;
    const { rows } = await query(
      `INSERT INTO announcements (title, body, audience)
       VALUES ($1, $2, $3) RETURNING *`,
      [title, body, audience],
    );
    await audit(req.user.sub, 'announcement_create', { id: rows[0].id });
    res.json({ announcement: rows[0] });
  },
);

/* ── Quests ──────────────────────────────────────────────────────────── */

router.get(
  '/quests',
  authRequired(['admin']),
  requirePerm('quests'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT * FROM quests ORDER BY ends_at DESC`,
    );
    res.json({ quests: rows });
  },
);

router.post(
  '/quests',
  authRequired(['admin']),
  requirePerm('quests'),
  async (req, res) => {
    const { titleEn, titleAm, goal, rewardBirr, endsAt, active = true } =
      req.body;
    const { rows } = await query(
      `INSERT INTO quests (title_en, title_am, goal, reward_birr, ends_at, active)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [titleEn, titleAm || titleEn, goal, rewardBirr, endsAt, active],
    );
    await audit(req.user.sub, 'quest_create', { id: rows[0].id });
    res.json({ quest: rows[0] });
  },
);

router.patch(
  '/quests/:id',
  authRequired(['admin']),
  requirePerm('quests'),
  async (req, res) => {
    const { active, goal, rewardBirr, endsAt } = req.body;
    await query(
      `UPDATE quests SET
         active = COALESCE($2, active),
         goal = COALESCE($3, goal),
         reward_birr = COALESCE($4, reward_birr),
         ends_at = COALESCE($5, ends_at)
       WHERE id = $1`,
      [req.params.id, active ?? null, goal ?? null, rewardBirr ?? null, endsAt ?? null],
    );
    res.json({ ok: true });
  },
);

/* ── RBAC + audit ────────────────────────────────────────────────────── */

router.get(
  '/roles',
  authRequired(['admin']),
  requirePerm('*'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT id, email, name, role, phone, photo_url, active, created_at
       FROM admin_users ORDER BY created_at`,
    );
    res.json({
      roles: Object.entries(ROLE_PERMS).map(([role, permissions]) => ({
        role,
        permissions,
        hireable: HIREABLE_ROLES.includes(role),
      })),
      hireableRoles: HIREABLE_ROLES,
      admins: rows.map((a) => adminPublic({ ...a, has_totp: false })),
    });
  },
);

router.post(
  '/admins',
  authRequired(['admin']),
  requirePerm('*'),
  async (req, res) => {
    try {
      const { email, password, name, role = 'call_center', phone } = req.body;
      if (!email || !password || !name) {
        return res.status(400).json({ error: 'name, email, password required' });
      }
      if (!HIREABLE_ROLES.includes(role)) {
        return res.status(400).json({
          error:
            'Workers cannot be hired as super_admin. Only one CEO exists — pick a worker role.',
        });
      }
      if (String(password).length < 6) {
        return res.status(400).json({ error: 'Password must be at least 6 characters' });
      }
      const hash = await bcrypt.hash(String(password), 10);
      const { rows } = await query(
        `INSERT INTO admin_users (email, password_hash, name, role, phone)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, email, name, role, phone, photo_url, active, created_at`,
        [
          String(email).trim().toLowerCase(),
          hash,
          String(name).trim(),
          role,
          phone ? String(phone).trim() : null,
        ],
      );
      await audit(req.user.sub, 'admin_create', {
        targetId: rows[0].id,
        email: rows[0].email,
        role,
      });
      res.status(201).json({ admin: adminPublic(rows[0]) });
    } catch (e) {
      if (e.code === '23505') {
        return res.status(409).json({ error: 'Email already exists' });
      }
      res.status(500).json({ error: e.message });
    }
  },
);

router.patch(
  '/admins/:id',
  authRequired(['admin']),
  requirePerm('*'),
  async (req, res) => {
    try {
      const { name, email, role, phone, active, password } = req.body;
      const existing = (
        await query(`SELECT * FROM admin_users WHERE id = $1`, [req.params.id])
      ).rows[0];
      if (!existing) return res.status(404).json({ error: 'Not found' });

      if (role != null) {
        if (role === 'super_admin') {
          return res.status(400).json({
            error: 'Cannot promote workers to super_admin — only one CEO is allowed',
          });
        }
        if (!HIREABLE_ROLES.includes(role) && role !== existing.role) {
          return res.status(400).json({ error: 'Unknown worker role' });
        }
      }

      // Never deactivate or demote the last / only CEO
      if (existing.role === 'super_admin') {
        if (active === false) {
          return res.status(400).json({ error: 'Cannot deactivate the CEO account' });
        }
        if (role != null && role !== 'super_admin') {
          return res.status(400).json({ error: 'Cannot demote the CEO account' });
        }
      }

      let passwordHash = null;
      if (password) {
        if (String(password).length < 6) {
          return res.status(400).json({ error: 'Password must be at least 6 characters' });
        }
        passwordHash = await bcrypt.hash(String(password), 10);
      }
      const { rows } = await query(
        `UPDATE admin_users SET
           name = COALESCE($2, name),
           email = COALESCE($3, email),
           role = COALESCE($4, role),
           phone = COALESCE($5, phone),
           active = COALESCE($6, active),
           password_hash = COALESCE($7, password_hash),
           updated_at = NOW()
         WHERE id = $1
         RETURNING id, email, name, role, phone, photo_url, active, created_at`,
        [
          req.params.id,
          name != null ? String(name).trim() : null,
          email != null ? String(email).trim().toLowerCase() : null,
          existing.role === 'super_admin' ? 'super_admin' : (role ?? null),
          phone !== undefined ? (phone ? String(phone).trim() : null) : null,
          typeof active === 'boolean' ? active : null,
          passwordHash,
        ],
      );
      await audit(req.user.sub, 'admin_update', { targetId: req.params.id });
      res.json({ admin: adminPublic(rows[0]) });
    } catch (e) {
      if (e.code === '23505') {
        return res.status(409).json({ error: 'Email already exists' });
      }
      res.status(500).json({ error: e.message });
    }
  },
);

router.patch(
  '/admins/:id/role',
  authRequired(['admin']),
  requirePerm('*'),
  async (req, res) => {
    const { role } = req.body;
    if (role === 'super_admin') {
      return res.status(400).json({
        error: 'Cannot assign super_admin — only one CEO account is allowed',
      });
    }
    if (!HIREABLE_ROLES.includes(role)) {
      return res.status(400).json({ error: 'Unknown role' });
    }
    const target = (
      await query(`SELECT role FROM admin_users WHERE id = $1`, [req.params.id])
    ).rows[0];
    if (!target) return res.status(404).json({ error: 'Not found' });
    if (target.role === 'super_admin') {
      return res.status(400).json({ error: 'Cannot change the CEO role' });
    }
    await query(`UPDATE admin_users SET role = $2, updated_at = NOW() WHERE id = $1`, [
      req.params.id,
      role,
    ]);
    await audit(req.user.sub, 'admin_role_change', {
      targetId: req.params.id,
      role,
    });
    res.json({ ok: true });
  },
);

router.post(
  '/admins/:id/photo',
  authRequired(['admin']),
  requirePerm('*'),
  upload.single('file'),
  async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ error: 'Photo required' });
      const url = publicUploadUrl(req.file.filename, req);
      const { rows } = await query(
        `UPDATE admin_users SET photo_url = $2, updated_at = NOW()
         WHERE id = $1
         RETURNING id, email, name, role, phone, photo_url, active, created_at`,
        [req.params.id, url],
      );
      if (!rows[0]) return res.status(404).json({ error: 'Not found' });
      res.json({ admin: adminPublic(rows[0]), photoUrl: url });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  },
);

/* ── Call center / book for caller ───────────────────────────────────── */

router.post(
  '/trips/book',
  authRequired(['admin']),
  requirePerm('booking', '*'),
  async (req, res) => {
    try {
      if (!matchingEngine) {
        return res.status(503).json({ error: 'Matching engine unavailable' });
      }
      const {
        riderId,
        phone,
        riderName,
        pickupLat,
        pickupLng,
        pickupLandmark,
        dropoffLat,
        dropoffLng,
        dropoffLandmark,
        category = 'bajaj',
        paymentMethod = 'cash',
        promoCode,
        notes,
        stops = [],
      } = req.body;

      let resolvedRiderId = riderId;
      if (!resolvedRiderId) {
        const e164 = normalizePhone(phone);
        if (!e164) {
          return res.status(400).json({ error: 'riderId or valid phone required' });
        }
        const found = await query(`SELECT id FROM riders WHERE phone = $1`, [e164]);
        if (found.rows[0]) {
          resolvedRiderId = found.rows[0].id;
          if (riderName) {
            await query(
              `UPDATE riders SET name = COALESCE(NULLIF(name, ''), $2), updated_at = NOW()
               WHERE id = $1`,
              [resolvedRiderId, String(riderName).trim()],
            );
          }
        } else {
          const created = await query(
            `INSERT INTO riders (phone, name, is_guest)
             VALUES ($1, $2, TRUE)
             RETURNING id`,
            [e164, String(riderName || 'Caller').trim()],
          );
          resolvedRiderId = created.rows[0].id;
        }
      }

      if (
        pickupLat == null ||
        pickupLng == null ||
        dropoffLat == null ||
        dropoffLng == null
      ) {
        return res.status(400).json({ error: 'Pickup and dropoff coordinates required' });
      }

      const distanceKm = haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
      const { durationMin } = estimateRoute(distanceKm);
      const fare = await quoteFare({
        category,
        distanceKm,
        durationMin,
        promoCode,
        stops: Array.isArray(stops) ? stops.length : 0,
        pickupLat,
        pickupLng,
      });
      const pin = String(Math.floor(1000 + Math.random() * 9000));
      const startRadius = Number(process.env.MATCH_RADIUS_START_KM || 0.5);

      const { rows } = await query(
        `INSERT INTO trips (
           rider_id, vehicle_category,
           pickup_lat, pickup_lng, pickup_landmark,
           dropoff_lat, dropoff_lng, dropoff_landmark, stops,
           status, distance_km, duration_min,
           fare_base, fare_distance, fare_time, surge_multiplier,
           fuel_adjustment, promo_discount, fare_total,
           payment_method, rider_pin, search_radius_km,
           booked_by_admin_id, booking_channel, booking_notes
         ) VALUES (
           $1, $2,
           $3, $4, $5,
           $6, $7, $8, $9::jsonb,
           'requested', $10, $11,
           $12, $13, $14, $15,
           $16, $17, $18,
           $19, $20, $21,
           $22, 'call_center', $23
         ) RETURNING *`,
        [
          resolvedRiderId,
          category,
          pickupLat,
          pickupLng,
          pickupLandmark || 'Pickup',
          dropoffLat,
          dropoffLng,
          dropoffLandmark || 'Drop-off',
          JSON.stringify(stops || []),
          distanceKm,
          durationMin,
          fare.base,
          fare.distanceFee,
          fare.timeFee,
          fare.surgeMultiplier,
          fare.fuelAdjustment,
          fare.promoDiscount,
          fare.total,
          paymentMethod || 'cash',
          pin,
          startRadius,
          req.user.sub,
          notes ? String(notes).trim() : null,
        ],
      );
      const trip = rows[0];
      matchingEngine.start(trip.id);
      await audit(req.user.sub, 'callcenter_book', {
        tripId: trip.id,
        riderId: resolvedRiderId,
      });
      res.status(201).json({ trip, riderPin: pin });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: e.message });
    }
  },
);

router.get(
  '/audit',
  authRequired(['admin']),
  requirePerm('audit', '*'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT a.*, u.email AS admin_email, u.name AS admin_name
       FROM audit_logs a
       LEFT JOIN admin_users u ON u.id = a.admin_id
       ORDER BY a.created_at DESC LIMIT 200`,
    );
    res.json({ logs: rows });
  },
);

export function createAdminRouter(matching) {
  matchingEngine = matching;
  return router;
}

export { ROLE_PERMS, STAFF_ROLES, HIREABLE_ROLES };
export default createAdminRouter;
