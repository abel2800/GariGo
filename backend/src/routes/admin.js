import crypto from 'crypto';
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { query } from '../db/pool.js';
import { signToken, authRequired } from '../middleware/auth.js';
import { sendPush } from '../services/push.js';

const router = Router();

const secret = () => process.env.JWT_SECRET || 'garigo_dev_secret';

/** Role → allowed permission keys */
const ROLE_PERMS = {
  super_admin: ['*'],
  city_ops: [
    'ops',
    'drivers',
    'trips',
    'sos',
    'zones',
    'announcements',
    'quests',
    'analytics',
    'push',
  ],
  support: ['ops', 'tickets', 'trips', 'riders', 'sos'],
  finance: ['finance', 'payouts', 'promos', 'pricing', 'analytics'],
  trust_safety: ['drivers', 'docs', 'sos', 'riders', 'audit', 'trips'],
};

function permsFor(role) {
  return ROLE_PERMS[role] || ROLE_PERMS.support;
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
      `SELECT id, email, name, role, totp_secret FROM admin_users WHERE id = $1`,
      [decoded.sub],
    );
    const user = rows[0];
    if (!user) return res.status(401).json({ error: 'Admin not found' });

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
      admin: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        permissions: permsFor(user.role),
        hasTotp: !!user.totp_secret,
      },
    });
  } catch {
    res.status(401).json({ error: 'Invalid temp token' });
  }
});

router.get('/me', authRequired(['admin']), async (req, res) => {
  const { rows } = await query(
    `SELECT id, email, name, role, totp_secret IS NOT NULL AS has_totp
     FROM admin_users WHERE id = $1`,
    [req.user.sub],
  );
  const user = rows[0];
  if (!user) return res.status(404).json({ error: 'Not found' });
  res.json({
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    permissions: permsFor(user.role),
    hasTotp: user.has_totp,
  });
});

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
              r.name AS rider_name, r.phone AS rider_phone,
              d.name AS driver_name, d.phone AS driver_phone
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
    const { surgeMultiplier, name } = req.body;
    await query(
      `UPDATE zones SET
         surge_multiplier = COALESCE($2, surge_multiplier),
         name = COALESCE($3, name)
       WHERE id = $1`,
      [req.params.id, surgeMultiplier ?? null, name ?? null],
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
    const { name, surgeMultiplier = 1.0, polygon = null } = req.body;
    const { rows } = await query(
      `INSERT INTO zones (name, surge_multiplier, polygon)
       VALUES ($1, $2, $3) RETURNING *`,
      [name, surgeMultiplier, polygon ? JSON.stringify(polygon) : null],
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
    } = req.body;
    const { rows } = await query(
      `INSERT INTO promos (code, discount_type, value, valid_to, usage_limit, zone_restriction)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [
        String(code).toUpperCase(),
        discountType,
        value,
        validTo || null,
        usageLimit || null,
        zoneRestriction || null,
      ],
    );
    await audit(req.user.sub, 'promo_create', { code });
    res.json({ promo: rows[0] });
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
    res.json({
      drivers: rows,
      count: rows.length,
      totalBr: total,
    });
  },
);

router.post(
  '/finance/payouts/process',
  authRequired(['admin']),
  requirePerm('payouts', 'finance'),
  async (req, res) => {
    const { rows } = await query(
      `SELECT id, available_balance FROM drivers WHERE available_balance > 0`,
    );
    const total = rows.reduce((s, d) => s + money(d.available_balance), 0);
    await query(
      `UPDATE drivers SET available_balance = 0, updated_at = NOW() WHERE available_balance > 0`,
    );
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
    await audit(req.user.sub, 'push_broadcast', {
      title,
      audience,
      tokens: tokens.length,
      sent,
    });
    res.json({ ok: true, targeted: tokens.length, sent });
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
  requirePerm('*', 'audit'),
  async (req, res) => {
    const roles = Object.entries(ROLE_PERMS).map(([role, permissions]) => ({
      role,
      permissions,
    }));
    const { rows } = await query(
      `SELECT id, email, name, role, created_at FROM admin_users ORDER BY created_at`,
    );
    res.json({ roles, admins: rows });
  },
);

router.patch(
  '/admins/:id/role',
  authRequired(['admin']),
  requirePerm('*'),
  async (req, res) => {
    const { role } = req.body;
    if (!ROLE_PERMS[role]) {
      return res.status(400).json({ error: 'Unknown role' });
    }
    await query(`UPDATE admin_users SET role = $2 WHERE id = $1`, [
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

export default router;
