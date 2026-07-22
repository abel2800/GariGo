import { Router } from 'express';
import { query } from '../db/pool.js';
import { authRequired } from '../middleware/auth.js';
import {
  quoteFare,
  haversineKm,
  estimateRoute,
} from '../services/fare.js';
import { chargePayment } from '../services/payments.js';
import { createMaskedSession } from '../services/voice.js';
import { bumpDriverQuests } from '../services/quests.js';

export function createTripRouter(matching) {
  const router = Router();

  router.get('/places/search', async (req, res) => {
    const q = String(req.query.q || '').trim();
    const { rows } = await query(
      `SELECT id, name_en, name_am, area, lat, lng
       FROM places
       WHERE search_tokens ILIKE $1 OR name_en ILIKE $1 OR name_am ILIKE $1
       ORDER BY name_en
       LIMIT 20`,
      [`%${q}%`],
    );
    res.json({ places: rows });
  });

  router.post('/quote', async (req, res) => {
    try {
      const {
        pickupLat,
        pickupLng,
        dropoffLat,
        dropoffLng,
        promoCode,
        stops = [],
      } = req.body;
      const distanceKm = haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
      const { durationMin } = estimateRoute(distanceKm);
      const categories = ['moto', 'bajaj', 'car'];
      const quotes = [];
      for (const category of categories) {
        quotes.push(
          await quoteFare({
            category,
            distanceKm,
            durationMin,
            promoCode,
            stops: stops.length,
            pickupLat,
            pickupLng,
          }),
        );
      }
      res.json({
        distanceKm,
        durationMin,
        quotes,
        surgeMultiplier: quotes[0]?.surgeMultiplier ?? 1,
        zone: quotes[0]?.zone ?? null,
      });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  router.get('/mine', authRequired(), async (req, res) => {
    try {
      const col = req.user.role === 'driver' ? 'driver_id' : 'rider_id';
      const { rows } = await query(
        `SELECT id, status, vehicle_category, pickup_landmark, dropoff_landmark,
                fare_total, rider_rating, completed_at, created_at, payment_method
         FROM trips
         WHERE ${col} = $1
         ORDER BY COALESCE(completed_at, created_at) DESC
         LIMIT 50`,
        [req.user.sub],
      );
      res.json({ trips: rows });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  router.post('/request', authRequired(['rider']), async (req, res) => {
    try {
      const {
        pickupLat,
        pickupLng,
        pickupLandmark,
        dropoffLat,
        dropoffLng,
        dropoffLandmark,
        category,
        paymentMethod = 'cash',
        cardId,
        promoCode,
        stops = [],
        voiceNoteUrl,
      } = req.body;

      if (paymentMethod === 'card' && !cardId) {
        return res.status(400).json({ error: 'Select a saved bank card' });
      }
      if (cardId) {
        const cardCheck = await query(
          `SELECT id FROM payment_cards WHERE id = $1 AND rider_id = $2`,
          [cardId, req.user.sub],
        );
        if (!cardCheck.rows[0]) {
          return res.status(400).json({ error: 'Card not found' });
        }
      }

      const distanceKm = haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
      const { durationMin } = estimateRoute(distanceKm);
      const fare = await quoteFare({
        category,
        distanceKm,
        durationMin,
        promoCode,
        stops: stops.length,
        pickupLat,
        pickupLng,
      });

      const pin = String(Math.floor(1000 + Math.random() * 9000));

      const { rows } = await query(
        `INSERT INTO trips (
           rider_id, vehicle_category,
           pickup_lat, pickup_lng, pickup_landmark, pickup_voice_note_url,
           dropoff_lat, dropoff_lng, dropoff_landmark, stops,
           status, distance_km, duration_min,
           fare_base, fare_distance, fare_time, surge_multiplier,
           fuel_adjustment, promo_discount, fare_total,
           payment_method, payment_card_id, rider_pin, search_radius_km
         ) VALUES (
           $1, $2,
           $3, $4, $5, $6,
           $7, $8, $9, $10::jsonb,
           'requested', $11, $12,
           $13, $14, $15, $16,
           $17, $18, $19,
           $20, $21, $22, $23
         ) RETURNING *`,
        [
          req.user.sub,
          category,
          pickupLat,
          pickupLng,
          pickupLandmark,
          voiceNoteUrl || null,
          dropoffLat,
          dropoffLng,
          dropoffLandmark,
          JSON.stringify(stops),
          distanceKm,
          durationMin,
          fare.base,
          fare.distanceFee,
          fare.timeFee,
          fare.surgeMultiplier,
          fare.fuelAdjustment,
          fare.promoDiscount,
          fare.total,
          paymentMethod,
          cardId || null,
          pin,
          Number(process.env.MATCH_RADIUS_START_KM || 0.5),
        ],
      );

      const trip = rows[0];
      if (fare.promoId) {
        await query(
          `UPDATE promos SET used_count = used_count + 1
           WHERE id = $1
             AND (usage_limit IS NULL OR used_count < usage_limit)`,
          [fare.promoId],
        );
      }
      matching.start(trip.id);
      res.status(201).json({ trip });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: e.message });
    }
  });

  router.post('/:id/accept', authRequired(['driver']), async (req, res) => {
    try {
      const result = await matching.accept(req.params.id, req.user.sub);
      if (!result.ok) return res.status(409).json(result);
      res.json(result);
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  router.post('/:id/decline', authRequired(['driver']), async (req, res) => {
    // Already tracked in offered_to; matching continues
    res.json({ ok: true });
  });

  router.post('/:id/arrived', authRequired(['driver']), async (req, res) => {
    await query(
      `UPDATE trips SET status = 'arrived' WHERE id = $1 AND driver_id = $2`,
      [req.params.id, req.user.sub],
    );
    matching.io.to(`trip:${req.params.id}`).emit('driver_arrived', {
      tripId: req.params.id,
    });
    res.json({ ok: true });
  });

  router.post('/:id/verify-pin', authRequired(['driver']), async (req, res) => {
    const { rows } = await query(`SELECT * FROM trips WHERE id = $1`, [
      req.params.id,
    ]);
    const trip = rows[0];
    if (!trip || trip.driver_id !== req.user.sub) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    if (String(req.body.pin) !== String(trip.rider_pin).trim()) {
      return res.status(400).json({ error: 'Wrong PIN' });
    }
    await query(
      `UPDATE trips SET status = 'in_progress', started_at = NOW() WHERE id = $1`,
      [trip.id],
    );
    matching.io.to(`trip:${trip.id}`).emit('trip_started', { tripId: trip.id });
    res.json({ ok: true });
  });

  router.post('/:id/complete', authRequired(['driver']), async (req, res) => {
    try {
      const { rows } = await query(`SELECT * FROM trips WHERE id = $1`, [
        req.params.id,
      ]);
      const trip = rows[0];
      if (!trip || trip.driver_id !== req.user.sub) {
        return res.status(404).json({ error: 'Trip not found' });
      }

      const commissionPct = Number(process.env.COMMISSION_PERCENT || 15);
      const commission = Math.round((trip.fare_total * commissionPct) / 100);
      const net = trip.fare_total - commission;

      let cardToken;
      if (trip.payment_method === 'card' && trip.payment_card_id) {
        const cardRes = await query(
          `SELECT provider_token FROM payment_cards WHERE id = $1 AND rider_id = $2`,
          [trip.payment_card_id, trip.rider_id],
        );
        cardToken = cardRes.rows[0]?.provider_token;
        if (!cardToken) {
          return res.status(400).json({ error: 'Payment card missing' });
        }
      }

      const pay = await chargePayment({
        method: trip.payment_method,
        amount: trip.fare_total,
        reference: trip.id,
        cardToken,
      });

      await query(
        `UPDATE trips SET status = 'completed', completed_at = NOW(), payment_status = $2
         WHERE id = $1`,
        [trip.id, pay.status],
      );
      await query(
        `INSERT INTO payments (trip_id, method, amount, commission_amount, driver_net, status, provider_txn_id)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [
          trip.id,
          trip.payment_method,
          trip.fare_total,
          commission,
          net,
          pay.status,
          pay.providerTxnId,
        ],
      );

      if (trip.payment_method === 'cash') {
        await query(
          `UPDATE drivers SET cash_debt = cash_debt + $2, available_balance = available_balance + $3,
             online_status = 'online', total_trips = total_trips + 1, updated_at = NOW()
           WHERE id = $1`,
          [req.user.sub, commission, net],
        );
      } else {
        await query(
          `UPDATE drivers SET available_balance = available_balance + $2,
             online_status = 'online', total_trips = total_trips + 1, updated_at = NOW()
           WHERE id = $1`,
          [req.user.sub, net],
        );
      }

      await query(
        `UPDATE riders SET total_trips = total_trips + 1, updated_at = NOW() WHERE id = $1`,
        [trip.rider_id],
      );

      await bumpDriverQuests(req.user.sub);

      matching.io.to(`trip:${trip.id}`).emit('trip_completed', {
        tripId: trip.id,
        fareTotal: trip.fare_total,
        commissionPercent: commissionPct,
        driverNet: net,
      });

      res.json({
        ok: true,
        fare: {
          gross: trip.fare_total,
          commissionPercent: commissionPct,
          commissionAmount: commission,
          net,
        },
      });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: e.message });
    }
  });

  router.post('/:id/rate', authRequired(['rider']), async (req, res) => {
    const { stars, tags = [], note, tipAmount = 0 } = req.body;
    await query(
      `UPDATE trips SET rider_rating = $2, rating_tags = $3, tip_amount = $4
       WHERE id = $1 AND rider_id = $5`,
      [req.params.id, stars, tags, tipAmount, req.user.sub],
    );
    res.json({ ok: true });
  });

  router.post('/:id/sos', authRequired(), async (req, res) => {
    const by = req.user.role === 'driver' ? 'driver' : 'rider';
    const { lat, lng } = req.body;
    const { rows } = await query(
      `INSERT INTO sos_alerts (trip_id, triggered_by, lat, lng)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [req.params.id, by, lat, lng],
    );
    matching.io.to('admin:ops').emit('sos_alert', rows[0]);
    res.status(201).json({ alert: rows[0] });
  });

  async function loadTripParty(tripId, user) {
    const { rows } = await query(`SELECT * FROM trips WHERE id = $1`, [tripId]);
    const trip = rows[0];
    if (!trip) return { error: 'Not found', status: 404 };
    const isRider = user.role === 'rider' && trip.rider_id === user.sub;
    const isDriver = user.role === 'driver' && trip.driver_id === user.sub;
    if (!isRider && !isDriver) return { error: 'Forbidden', status: 403 };
    return { trip, isRider, isDriver };
  }

  /** Counterpart contact after match — photo, phone, vehicle details. */
  router.get('/:id/contact', authRequired(), async (req, res) => {
    try {
      const loaded = await loadTripParty(req.params.id, req.user);
      if (loaded.error) return res.status(loaded.status).json({ error: loaded.error });
      const { trip, isRider } = loaded;
      if (!trip.driver_id || ['requested', 'matching', 'cancelled'].includes(trip.status)) {
        return res.status(409).json({ error: 'Trip not matched yet' });
      }

      if (isRider) {
        const { rows } = await query(
          `SELECT d.id, d.name, d.phone, d.photo_url, d.rating_avg, d.category,
                  v.plate_number, v.color, v.model
           FROM drivers d
           LEFT JOIN vehicles v ON v.driver_id = d.id
           WHERE d.id = $1`,
          [trip.driver_id],
        );
        const d = rows[0];
        return res.json({
          role: 'driver',
          contact: d
            ? {
                id: d.id,
                name: d.name,
                phone: d.phone,
                photoUrl: d.photo_url,
                rating: Number(d.rating_avg),
                plate: d.plate_number,
                vehicleColor: d.color,
                vehicleModel: d.model,
                category: d.category,
              }
            : null,
        });
      }

      const { rows } = await query(
        `SELECT id, name, phone, photo_url, rating_avg FROM riders WHERE id = $1`,
        [trip.rider_id],
      );
      const r = rows[0];
      return res.json({
        role: 'rider',
        contact: r
          ? {
              id: r.id,
              name: r.name || 'Rider',
              phone: r.phone,
              photoUrl: r.photo_url,
              rating: Number(r.rating_avg),
            }
          : null,
      });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  router.get('/:id/messages', authRequired(), async (req, res) => {
    try {
      const loaded = await loadTripParty(req.params.id, req.user);
      if (loaded.error) return res.status(loaded.status).json({ error: loaded.error });
      const { rows } = await query(
        `SELECT id, trip_id, sender_role, sender_id, body, created_at
         FROM trip_messages
         WHERE trip_id = $1
         ORDER BY created_at ASC
         LIMIT 200`,
        [req.params.id],
      );
      res.json({
        messages: rows.map((m) => ({
          id: m.id,
          tripId: m.trip_id,
          senderRole: m.sender_role,
          senderId: m.sender_id,
          body: m.body,
          createdAt: m.created_at,
        })),
      });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  router.post('/:id/messages', authRequired(), async (req, res) => {
    try {
      const loaded = await loadTripParty(req.params.id, req.user);
      if (loaded.error) return res.status(loaded.status).json({ error: loaded.error });
      const { trip, isRider } = loaded;
      if (!['matched', 'arrived', 'in_progress'].includes(trip.status)) {
        return res.status(409).json({ error: 'Chat only available during active trip' });
      }
      const body = String(req.body.body || '').trim();
      if (!body || body.length > 1000) {
        return res.status(400).json({ error: 'Message required (max 1000 chars)' });
      }
      const role = isRider ? 'rider' : 'driver';
      const { rows } = await query(
        `INSERT INTO trip_messages (trip_id, sender_role, sender_id, body)
         VALUES ($1, $2, $3, $4)
         RETURNING id, trip_id, sender_role, sender_id, body, created_at`,
        [trip.id, role, req.user.sub, body],
      );
      const m = rows[0];
      const payload = {
        id: m.id,
        tripId: m.trip_id,
        senderRole: m.sender_role,
        senderId: m.sender_id,
        body: m.body,
        createdAt: m.created_at,
      };
      matching.io.to(`trip:${trip.id}`).emit('trip_message', payload);
      if (isRider && trip.driver_id) {
        matching.io.to(`driver:${trip.driver_id}`).emit('trip_message', payload);
      } else if (!isRider && trip.rider_id) {
        matching.io.to(`rider:${trip.rider_id}`).emit('trip_message', payload);
      }
      res.status(201).json({ message: payload });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  router.post('/:id/call-session', authRequired(), async (req, res) => {
    try {
      const loaded = await loadTripParty(req.params.id, req.user);
      if (loaded.error) return res.status(loaded.status).json({ error: loaded.error });
      const { trip } = loaded;
      if (!trip.driver_id) {
        return res.status(409).json({ error: 'Trip not matched yet' });
      }
      const rider = (
        await query(`SELECT phone FROM riders WHERE id = $1`, [trip.rider_id])
      ).rows[0];
      const driver = (
        await query(`SELECT phone FROM drivers WHERE id = $1`, [trip.driver_id])
      ).rows[0];
      const session = await createMaskedSession({
        tripId: trip.id,
        riderPhone: rider?.phone,
        driverPhone: driver?.phone,
      });
      // Local/stub: also return direct counterpart number so apps can dial.
      const counterpartPhone =
        req.user.role === 'rider' ? driver?.phone : rider?.phone;
      res.json({
        ...session,
        counterpartPhone: counterpartPhone || null,
        dialDirect: process.env.VOICE_PROXY_MODE === 'stub',
      });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  router.get('/:id', authRequired(), async (req, res) => {
    try {
      const loaded = await loadTripParty(req.params.id, req.user);
      if (loaded.error) return res.status(loaded.status).json({ error: loaded.error });
      const { trip, isRider } = loaded;
      let driver = null;
      let rider = null;
      if (trip.driver_id) {
        const { rows } = await query(
          `SELECT d.id, d.name, d.phone, d.photo_url, d.rating_avg, d.category,
                  v.plate_number, v.color, v.model
           FROM drivers d
           LEFT JOIN vehicles v ON v.driver_id = d.id
           WHERE d.id = $1`,
          [trip.driver_id],
        );
        const d = rows[0];
        if (d) {
          driver = {
            id: d.id,
            name: d.name,
            phone: d.phone,
            photoUrl: d.photo_url,
            rating: Number(d.rating_avg),
            plate: d.plate_number,
            vehicleColor: d.color,
            vehicleModel: d.model,
            category: d.category,
          };
        }
      }
      {
        const { rows } = await query(
          `SELECT id, name, phone, photo_url, rating_avg FROM riders WHERE id = $1`,
          [trip.rider_id],
        );
        const r = rows[0];
        if (r) {
          rider = {
            id: r.id,
            name: r.name || 'Rider',
            phone: r.phone,
            photoUrl: r.photo_url,
            rating: Number(r.rating_avg),
          };
        }
      }
      res.json({
        trip,
        driver,
        rider,
        viewAs: isRider ? 'rider' : 'driver',
      });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  return router;
}
