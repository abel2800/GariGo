import { Router } from 'express';
import { z } from 'zod';
import { query } from '../db/pool.js';
import { signToken, authRequired } from '../middleware/auth.js';
import { generateOtp, sendSms } from '../services/sms.js';

const router = Router();

function normalizePhone(raw) {
  let d = String(raw).replace(/\D/g, '');
  if (d.startsWith('251') && d.length === 12) return `+${d}`;
  if (d.startsWith('0') && d.length === 10) d = d.slice(1);
  if (d.length === 9 && (d.startsWith('9') || d.startsWith('7'))) {
    return `+251${d}`;
  }
  return null;
}

router.post('/otp/request', async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    const role = req.body.role === 'driver' ? 'driver' : 'rider';
    if (!phone) return res.status(400).json({ error: 'Invalid Ethiopian phone' });

    const code = generateOtp();
    await query(
      `INSERT INTO otp_codes (phone, code, role, expires_at)
       VALUES ($1, $2, $3, NOW() + INTERVAL '5 minutes')`,
      [phone, code, role],
    );
    await sendSms(phone, `GariGo code: ${code}`);
    res.json({
      ok: true,
      phone,
      // Dev hint only
      demoCode: process.env.NODE_ENV !== 'production' ? code : undefined,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

router.post('/otp/verify', async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    const { code, role = 'rider', name, isGuest } = req.body;
    if (!phone) return res.status(400).json({ error: 'Invalid phone' });

    if (!isGuest) {
      const otp = await query(
        `SELECT * FROM otp_codes
         WHERE phone = $1 AND role = $2 AND code = $3 AND consumed = FALSE
           AND expires_at > NOW()
         ORDER BY created_at DESC LIMIT 1`,
        [phone, role === 'driver' ? 'driver' : 'rider', String(code)],
      );
      if (!otp.rows[0]) {
        return res.status(400).json({ error: 'Invalid or expired OTP' });
      }
      await query(`UPDATE otp_codes SET consumed = TRUE WHERE id = $1`, [
        otp.rows[0].id,
      ]);
    }

    if (role === 'driver') {
      let { rows } = await query(`SELECT * FROM drivers WHERE phone = $1`, [phone]);
      if (!rows[0]) {
        try {
          ({ rows } = await query(
            `INSERT INTO drivers (phone, name) VALUES ($1, $2) RETURNING *`,
            [phone, name || null],
          ));
        } catch (e) {
          if (e.code === '23505') {
            return res.status(409).json({
              error: 'This phone number is already registered as a driver',
            });
          }
          throw e;
        }
      } else if (name && !rows[0].name) {
        ({ rows } = await query(
          `UPDATE drivers SET name = $2, updated_at = NOW() WHERE id = $1 RETURNING *`,
          [rows[0].id, String(name).trim()],
        ));
      }
      const driver = rows[0];
      const token = signToken({
        sub: driver.id,
        role: 'driver',
        phone: driver.phone,
      });
      return res.json({ token, driver });
    }

    let { rows } = await query(`SELECT * FROM riders WHERE phone = $1`, [phone]);
    if (!rows[0]) {
      try {
        ({ rows } = await query(
          `INSERT INTO riders (phone, name, is_guest)
           VALUES ($1, $2, $3) RETURNING *`,
          [phone, name || (isGuest ? 'Guest' : null), !!isGuest],
        ));
        await query(
          `INSERT INTO wallets (owner_type, owner_id, balance)
           VALUES ('rider', $1, 0) ON CONFLICT DO NOTHING`,
          [rows[0].id],
        );
      } catch (e) {
        if (e.code === '23505') {
          return res.status(409).json({
            error: 'This phone number is already registered as a rider',
          });
        }
        throw e;
      }
    }
    const rider = rows[0];
    const token = signToken({
      sub: rider.id,
      role: 'rider',
      phone: rider.phone,
    });
    const { password_hash: _pw, ...safeRider } = rider;
    res.json({
      token,
      rider: { ...safeRider, has_password: !!_pw },
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message });
  }
});

router.get('/me', authRequired(), async (req, res) => {
  try {
    if (req.user.role === 'driver') {
      const { rows } = await query(
        `SELECT d.*,
                v.plate_number AS plate,
                v.color AS vehicle_color,
                v.model AS vehicle_model,
                v.make AS vehicle_make
         FROM drivers d
         LEFT JOIN vehicles v ON v.driver_id = d.id
         WHERE d.id = $1`,
        [req.user.sub],
      );
      return res.json({ role: 'driver', profile: rows[0] });
    }
    if (req.user.role === 'admin') {
      return res.status(400).json({ error: 'Use admin endpoints' });
    }
    const { rows } = await query(
      `SELECT id, phone, name, email, photo_url, is_guest, wallet_balance,
              rating_avg, total_trips, status, language_pref, created_at,
              (password_hash IS NOT NULL) AS has_password
       FROM riders WHERE id = $1`,
      [req.user.sub],
    );
    res.json({ role: 'rider', profile: rows[0] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
