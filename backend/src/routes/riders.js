import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { query } from '../db/pool.js';
import { authRequired, signToken } from '../middleware/auth.js';
import { upload, publicUploadUrl } from '../middleware/upload.js';
import { tokenizeCard, CardVaultError } from '../services/cardVault.js';

const router = Router();

router.get('/cards', authRequired(['rider']), async (req, res) => {
  try {
    const { rows } = await query(
      `SELECT id, brand, last4, exp_month, exp_year, holder_name, is_default, created_at
       FROM payment_cards
       WHERE rider_id = $1
       ORDER BY is_default DESC, created_at DESC`,
      [req.user.sub],
    );
    res.json({
      cards: rows.map((c) => ({
        id: c.id,
        brand: c.brand,
        last4: c.last4,
        expMonth: c.exp_month,
        expYear: c.exp_year,
        holderName: c.holder_name,
        isDefault: c.is_default,
        createdAt: c.created_at,
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/cards', authRequired(['rider']), async (req, res) => {
  try {
    const {
      number,
      expMonth,
      expYear,
      cvc,
      holderName,
      setDefault = true,
    } = req.body;

    const tokenized = await tokenizeCard({
      number,
      expMonth,
      expYear,
      cvc,
      holderName,
    });

    const existing = await query(
      `SELECT id, brand, last4, exp_month, exp_year, holder_name, is_default
       FROM payment_cards
       WHERE rider_id = $1 AND provider_token = $2`,
      [req.user.sub, tokenized.providerToken],
    );
    if (existing.rows[0]) {
      const c = existing.rows[0];
      return res.status(200).json({
        card: {
          id: c.id,
          brand: c.brand,
          last4: c.last4,
          expMonth: c.exp_month,
          expYear: c.exp_year,
          holderName: c.holder_name,
          isDefault: c.is_default,
        },
        alreadySaved: true,
      });
    }

    if (setDefault) {
      await query(
        `UPDATE payment_cards SET is_default = FALSE WHERE rider_id = $1`,
        [req.user.sub],
      );
    }

    const { rows } = await query(
      `INSERT INTO payment_cards
         (rider_id, brand, last4, exp_month, exp_year, holder_name, provider_token, is_default)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, brand, last4, exp_month, exp_year, holder_name, is_default`,
      [
        req.user.sub,
        tokenized.brand,
        tokenized.last4,
        tokenized.expMonth,
        tokenized.expYear,
        tokenized.holderName,
        tokenized.providerToken,
        !!setDefault,
      ],
    );

    const c = rows[0];
    res.status(201).json({
      card: {
        id: c.id,
        brand: c.brand,
        last4: c.last4,
        expMonth: c.exp_month,
        expYear: c.exp_year,
        holderName: c.holder_name,
        isDefault: c.is_default,
      },
      provider: tokenized.provider,
    });
  } catch (e) {
    if (e instanceof CardVaultError) {
      return res.status(e.status).json({ error: e.message });
    }
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

router.patch('/cards/:id/default', authRequired(['rider']), async (req, res) => {
  try {
    await query(
      `UPDATE payment_cards SET is_default = FALSE WHERE rider_id = $1`,
      [req.user.sub],
    );
    const { rows } = await query(
      `UPDATE payment_cards SET is_default = TRUE
       WHERE id = $1 AND rider_id = $2
       RETURNING id`,
      [req.params.id, req.user.sub],
    );
    if (!rows[0]) return res.status(404).json({ error: 'Card not found' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/cards/:id', authRequired(['rider']), async (req, res) => {
  try {
    const { rowCount } = await query(
      `DELETE FROM payment_cards WHERE id = $1 AND rider_id = $2`,
      [req.params.id, req.user.sub],
    );
    if (!rowCount) return res.status(404).json({ error: 'Card not found' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/** Complete rider registration — name, password, optional email */
router.post('/register', authRequired(['rider']), async (req, res) => {
  try {
    const { name, password, email } = req.body;
    const n = String(name || '').trim();
    if (n.length < 2) {
      return res.status(400).json({ error: 'Full name required' });
    }
    const pwd = String(password || '');
    if (pwd.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }
    const hash = await bcrypt.hash(pwd, 10);
    const { rows } = await query(
      `UPDATE riders SET
         name = $2,
         password_hash = $3,
         email = COALESCE($4, email),
         is_guest = FALSE,
         updated_at = NOW()
       WHERE id = $1
       RETURNING id, phone, name, email, photo_url, is_guest, wallet_balance,
                 rating_avg, total_trips, status, created_at`,
      [req.user.sub, n, hash, email ? String(email).trim() : null],
    );
    res.json({ rider: rows[0], profileComplete: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

router.patch('/profile', authRequired(['rider']), async (req, res) => {
  try {
    const { name, email } = req.body;
    const { rows } = await query(
      `UPDATE riders SET
         name = COALESCE($2, name),
         email = COALESCE($3, email),
         updated_at = NOW()
       WHERE id = $1
       RETURNING id, phone, name, email, photo_url, is_guest, wallet_balance,
                 rating_avg, total_trips, status`,
      [
        req.user.sub,
        name ? String(name).trim() : null,
        email ? String(email).trim() : null,
      ],
    );
    res.json({ rider: rows[0] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post(
  '/photo',
  authRequired(['rider']),
  upload.single('file'),
  async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ error: 'Photo required' });
      const url = publicUploadUrl(req.file.filename);
      const { rows } = await query(
        `UPDATE riders SET photo_url = $2, updated_at = NOW() WHERE id = $1
         RETURNING id, phone, name, email, photo_url, is_guest, wallet_balance,
                   rating_avg, total_trips, status`,
        [req.user.sub, url],
      );
      res.json({ rider: rows[0], photoUrl: url });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: e.message });
    }
  },
);

/** Password login (after registration) — still needs phone */
router.post('/login-password', async (req, res) => {
  try {
    const phone = String(req.body.phone || '');
    let d = phone.replace(/\D/g, '');
    if (d.startsWith('251') && d.length === 12) d = d;
    else if (d.startsWith('0') && d.length === 10) d = `251${d.slice(1)}`;
    else if (d.length === 9) d = `251${d}`;
    const normalized = `+${d}`;
    const password = String(req.body.password || '');
    const { rows } = await query(`SELECT * FROM riders WHERE phone = $1`, [
      normalized,
    ]);
    const rider = rows[0];
    if (!rider?.password_hash) {
      return res.status(401).json({ error: 'Use OTP login or register first' });
    }
    const ok = await bcrypt.compare(password, rider.password_hash);
    if (!ok) return res.status(401).json({ error: 'Wrong password' });
    const token = signToken({
      sub: rider.id,
      role: 'rider',
      phone: rider.phone,
    });
    const { password_hash: _, ...safe } = rider;
    res.json({ token, rider: safe });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
