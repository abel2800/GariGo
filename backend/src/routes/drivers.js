import { Router } from 'express';
import { query } from '../db/pool.js';
import { authRequired } from '../middleware/auth.js';
import { payoutDriver } from '../services/payments.js';
import { upload, publicUploadUrl } from '../middleware/upload.js';

const router = Router();

const DOC_LABELS = {
  selfie: 'Driver photo / selfie',
  national_id_front: 'National ID (front)',
  national_id_back: 'National ID (back)',
  license_front: 'Driver licence (front)',
  license_back: 'Driver licence (back)',
  vehicle_front: 'Vehicle photo — front',
  vehicle_back: 'Vehicle photo — back',
  vehicle_left: 'Vehicle photo — left side',
  vehicle_right: 'Vehicle photo — right side',
  vehicle_libre: 'Vehicle libre / certification',
  insurance: 'Insurance',
  tin_certificate: 'TIN certificate',
  business_registration: 'Business registration',
  owner_authorization: 'Owner authorization letter',
  helmet_vest: 'Helmet / vest',
};

function requiredDocs({ isOwner, category }) {
  const base = [
    'selfie',
    'national_id_front',
    'license_front',
    'vehicle_front',
    'vehicle_back',
    'vehicle_left',
    'vehicle_right',
    'vehicle_libre',
    'tin_certificate',
    'business_registration',
  ];
  if (!isOwner) base.push('owner_authorization');
  if (category === 'moto') base.push('helmet_vest');
  return base;
}

router.patch('/online', authRequired(['driver']), async (req, res) => {
  const online = !!req.body.online;
  const { rows } = await query(
    `SELECT approval_status FROM drivers WHERE id = $1`,
    [req.user.sub],
  );
  if (online && rows[0]?.approval_status !== 'approved') {
    return res.status(403).json({ error: 'Driver not approved yet' });
  }
  await query(
    `UPDATE drivers SET online_status = $2, updated_at = NOW() WHERE id = $1`,
    [req.user.sub, online ? 'online' : 'offline'],
  );
  res.json({ ok: true, online });
});

router.post('/location', authRequired(['driver']), async (req, res) => {
  const { lat, lng, heading } = req.body;
  await query(
    `UPDATE drivers SET
       lat = $2, lng = $3,
       heading = $4,
       updated_at = NOW()
     WHERE id = $1`,
    [req.user.sub, lat, lng, heading ?? null],
  );
  await query(
    `INSERT INTO driver_locations (driver_id, lat, lng, heading)
     VALUES ($1, $2, $3, $4)`,
    [req.user.sub, lat, lng, heading ?? null],
  );
  res.json({ ok: true });
});

router.post('/vehicle-category', authRequired(['driver']), async (req, res) => {
  await query(`UPDATE drivers SET category = $2 WHERE id = $1`, [
    req.user.sub,
    req.body.category,
  ]);
  res.json({ ok: true });
});

router.post('/vehicle', authRequired(['driver']), async (req, res) => {
  try {
    const {
      category,
      plateNumber,
      make,
      model,
      color,
      isVehicleOwner = true,
      tinNumber,
      businessRegNumber,
      licenseNumber,
      nationalIdNumber,
      name,
    } = req.body;

    if (!plateNumber || String(plateNumber).trim().length < 3) {
      return res.status(400).json({ error: 'Plate number required' });
    }
    if (!category) {
      return res.status(400).json({ error: 'Vehicle category required' });
    }

    const plate = String(plateNumber).trim().toUpperCase();

    // Plate uniqueness — one plate can only be applied once
    const plateTaken = await query(
      `SELECT v.id, v.driver_id FROM vehicles v
       WHERE upper(trim(v.plate_number)) = $1 AND v.driver_id <> $2
       LIMIT 1`,
      [plate, req.user.sub],
    );
    if (plateTaken.rows[0]) {
      return res.status(409).json({
        error: 'This plate number is already registered by another driver',
      });
    }

    await query(
      `UPDATE drivers SET
         category = $2,
         name = COALESCE($3, name),
         license_number = COALESCE($4, license_number),
         national_id_number = COALESCE($5, national_id_number),
         tin_number = COALESCE($6, tin_number),
         business_reg_number = COALESCE($7, business_reg_number),
         is_vehicle_owner = $8,
         updated_at = NOW()
       WHERE id = $1`,
      [
        req.user.sub,
        category,
        name || null,
        licenseNumber || null,
        nationalIdNumber || null,
        tinNumber || null,
        businessRegNumber || null,
        !!isVehicleOwner,
      ],
    );

    const existing = await query(
      `SELECT id FROM vehicles WHERE driver_id = $1 ORDER BY created_at DESC LIMIT 1`,
      [req.user.sub],
    );
    let vehicle;
    if (existing.rows[0]) {
      const { rows } = await query(
        `UPDATE vehicles SET
           category = $2, plate_number = $3, make = $4, model = $5, color = $6
         WHERE id = $1 RETURNING *`,
        [
          existing.rows[0].id,
          category,
          plate,
          make || null,
          model || null,
          color || null,
        ],
      );
      vehicle = rows[0];
    } else {
      const { rows } = await query(
        `INSERT INTO vehicles (driver_id, category, plate_number, make, model, color)
         VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
        [
          req.user.sub,
          category,
          plate,
          make || null,
          model || null,
          color || null,
        ],
      );
      vehicle = rows[0];
    }
    res.json({ ok: true, vehicle });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

router.get('/documents', authRequired(['driver']), async (req, res) => {
  try {
    const driver = (
      await query(
        `SELECT category, is_vehicle_owner, photo_url, tin_number, business_reg_number,
                license_number, national_id_number, name, approval_status
         FROM drivers WHERE id = $1`,
        [req.user.sub],
      )
    ).rows[0];
    const { rows } = await query(
      `SELECT id, doc_type, url, expiry_date, verified, rejection_reason, created_at
       FROM driver_documents WHERE driver_id = $1 ORDER BY created_at DESC`,
      [req.user.sub],
    );
    const required = requiredDocs({
      isOwner: driver?.is_vehicle_owner !== false,
      category: driver?.category,
    });
    res.json({
      driver,
      required,
      documents: rows.map((d) => ({
        id: d.id,
        docType: d.doc_type,
        label: DOC_LABELS[d.doc_type] || d.doc_type,
        url: d.url,
        verified: d.verified,
        rejectionReason: d.rejection_reason,
        expiryDate: d.expiry_date,
        createdAt: d.created_at,
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post(
  '/documents',
  authRequired(['driver']),
  (req, res, next) => {
    upload.single('file')(req, res, (err) => {
      if (err) {
        return res.status(400).json({
          error: err.message || 'Upload failed',
        });
      }
      next();
    });
  },
  async (req, res) => {
    try {
      const docType = String(req.body.docType || '')
        .trim()
        .toLowerCase()
        .replace(/-/g, '_');
      if (!docType || !DOC_LABELS[docType]) {
        return res.status(400).json({ error: 'Invalid document type' });
      }
      if (!req.file) {
        return res.status(400).json({ error: 'File required' });
      }
      const url = publicUploadUrl(req.file.filename);

      const { rows } = await query(
        `INSERT INTO driver_documents (driver_id, doc_type, url, verified, rejection_reason)
         VALUES ($1, $2, $3, FALSE, NULL)
         ON CONFLICT (driver_id, doc_type) DO UPDATE
           SET url = EXCLUDED.url,
               verified = FALSE,
               rejection_reason = NULL,
               created_at = NOW()
         RETURNING *`,
        [req.user.sub, docType, url],
      );

      if (docType === 'selfie') {
        await query(`UPDATE drivers SET photo_url = $2 WHERE id = $1`, [
          req.user.sub,
          url,
        ]);
      }

      const d = rows[0];

      // After re-uploading a declined doc, if nothing is still declined,
      // put the driver back into KYC review queue.
      const left = await query(
        `SELECT COUNT(*)::int AS c FROM driver_documents
         WHERE driver_id = $1 AND rejection_reason IS NOT NULL`,
        [req.user.sub],
      );
      if ((left.rows[0]?.c || 0) === 0) {
        await query(
          `UPDATE drivers
           SET approval_status = CASE
                 WHEN approval_status = 'rejected' THEN 'pending'
                 ELSE approval_status
               END,
               rejection_reasons = CASE
                 WHEN approval_status = 'rejected' THEN '{}'::text[]
                 ELSE rejection_reasons
               END,
               updated_at = NOW()
           WHERE id = $1`,
          [req.user.sub],
        );
      }

      res.status(201).json({
        document: {
          id: d.id,
          docType: d.doc_type,
          label: DOC_LABELS[d.doc_type],
          url: d.url,
          verified: d.verified,
        },
      });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: e.message });
    }
  },
);

router.post('/payout-method', authRequired(['driver']), async (req, res) => {
  const { type, details } = req.body;
  if (type === 'telebirr') {
    await query(`UPDATE drivers SET telebirr_merchant_id = $2 WHERE id = $1`, [
      req.user.sub,
      details,
    ]);
  } else if (type === 'cbe_birr') {
    await query(`UPDATE drivers SET cbe_account = $2 WHERE id = $1`, [
      req.user.sub,
      details,
    ]);
  } else {
    await query(`UPDATE drivers SET hellocash_wallet_id = $2 WHERE id = $1`, [
      req.user.sub,
      details,
    ]);
  }
  res.json({ ok: true });
});

router.post('/submit-for-approval', authRequired(['driver']), async (req, res) => {
  try {
    const driver = (
      await query(`SELECT * FROM drivers WHERE id = $1`, [req.user.sub])
    ).rows[0];
    if (!driver) return res.status(404).json({ error: 'Driver not found' });

    const vehicle = (
      await query(
        `SELECT * FROM vehicles WHERE driver_id = $1 ORDER BY created_at DESC LIMIT 1`,
        [req.user.sub],
      )
    ).rows[0];
    if (!vehicle) {
      return res.status(400).json({ error: 'Add vehicle details first' });
    }

    const required = requiredDocs({
      isOwner: driver.is_vehicle_owner !== false,
      category: driver.category || vehicle.category,
    });
    const { rows: docs } = await query(
      `SELECT doc_type, url FROM driver_documents
       WHERE driver_id = $1 AND url IS NOT NULL`,
      [req.user.sub],
    );
    const have = new Set(docs.map((d) => d.doc_type));
    const missing = required.filter((t) => !have.has(t));
    if (missing.length) {
      return res.status(400).json({
        error: 'Missing required documents',
        missing: missing.map((t) => ({ type: t, label: DOC_LABELS[t] })),
      });
    }
    if (!driver.tin_number && !req.body.tinNumber) {
      return res.status(400).json({ error: 'TIN number required' });
    }

    await query(
      `UPDATE drivers SET
         approval_status = 'pending',
         name = COALESCE($2, name, 'Driver'),
         tin_number = COALESCE($3, tin_number),
         business_reg_number = COALESCE($4, business_reg_number),
         rejection_reasons = '{}',
         updated_at = NOW()
       WHERE id = $1`,
      [
        req.user.sub,
        req.body.name || null,
        req.body.tinNumber || null,
        req.body.businessRegNumber || null,
      ],
    );
    res.json({ ok: true, status: 'pending' });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

router.get('/earnings', authRequired(['driver']), async (req, res) => {
  const { rows } = await query(
    `SELECT id, fare_total, completed_at, pickup_landmark, dropoff_landmark
     FROM trips
     WHERE driver_id = $1 AND status = 'completed'
     ORDER BY completed_at DESC LIMIT 50`,
    [req.user.sub],
  );
  const driver = (
    await query(
      `SELECT available_balance, cash_debt, commission_percent FROM drivers WHERE id = $1`,
      [req.user.sub],
    )
  ).rows[0];
  res.json({ trips: rows, balance: driver });
});

router.post('/payout/instant', authRequired(['driver']), async (req, res) => {
  const driver = (
    await query(`SELECT * FROM drivers WHERE id = $1`, [req.user.sub])
  ).rows[0];
  const amount = Math.min(
    Number(req.body.amount || driver.available_balance),
    driver.available_balance,
  );
  if (amount <= 0) return res.status(400).json({ error: 'Nothing to cash out' });

  const method = req.body.method || 'telebirr';
  const dest =
    method === 'telebirr'
      ? driver.telebirr_merchant_id
      : method === 'cbe_birr'
        ? driver.cbe_account
        : driver.hellocash_wallet_id;

  const result = await payoutDriver({
    method,
    amount,
    destination: dest,
    reference: driver.id,
  });
  const net = amount - result.fee;
  await query(
    `UPDATE drivers SET available_balance = available_balance - $2 WHERE id = $1`,
    [driver.id, amount],
  );
  res.json({ ok: true, paid: net, fee: result.fee, txn: result.providerTxnId });
});

export default router;
