import { query } from '../db/pool.js';
import { sendPush } from './push.js';
import { sendSms } from './sms.js';

/**
 * Expanding-radius matching engine.
 * Rank: ETA (distance) > acceptance_rate > rating > idle fairness (updated_at older = higher).
 */
export class MatchingEngine {
  constructor(io) {
    this.io = io;
    this.timers = new Map(); // tripId -> interval
  }

  async start(tripId) {
    await this.tick(tripId);
    const every = Number(process.env.MATCH_EXPAND_EVERY_SEC || 15) * 1000;
    const handle = setInterval(() => this.tick(tripId), every);
    this.timers.set(tripId, handle);

    const timeout = Number(process.env.MATCH_TIMEOUT_SEC || 90) * 1000;
    setTimeout(() => this.onTimeout(tripId), timeout);
  }

  stop(tripId) {
    const h = this.timers.get(tripId);
    if (h) clearInterval(h);
    this.timers.delete(tripId);
  }

  async tick(tripId) {
    const { rows } = await query(`SELECT * FROM trips WHERE id = $1`, [tripId]);
    const trip = rows[0];
    if (!trip || !['requested', 'matching'].includes(trip.status)) {
      this.stop(tripId);
      return;
    }

    const maxR = Number(process.env.MATCH_RADIUS_MAX_KM || 8);
    const expand = Number(process.env.MATCH_RADIUS_EXPAND_KM || 1.5);
    let radius = Number(trip.search_radius_km) || Number(process.env.MATCH_RADIUS_START_KM || 1.5);

    const offered = trip.offered_to || [];

    const candidates = await query(
      `SELECT d.*,
              gari_distance_m(d.lat, d.lng, t.pickup_lat, t.pickup_lng) AS dist_m
       FROM drivers d
       CROSS JOIN trips t
       WHERE t.id = $1
         AND d.online_status = 'online'
         AND d.approval_status = 'approved'
         AND d.category = t.vehicle_category
         AND d.status = 'active'
         AND d.lat IS NOT NULL AND d.lng IS NOT NULL
         AND gari_distance_m(d.lat, d.lng, t.pickup_lat, t.pickup_lng) <= $2
         AND NOT (d.id = ANY($3::uuid[]))
       ORDER BY
         gari_distance_m(d.lat, d.lng, t.pickup_lat, t.pickup_lng) ASC,
         d.acceptance_rate DESC,
         d.rating_avg DESC,
         d.updated_at ASC
       LIMIT 5`,
      [tripId, radius * 1000, offered],
    );

    if (candidates.rows.length === 0) {
      if (radius < maxR) {
        radius = Math.min(maxR, radius + expand);
        await query(`UPDATE trips SET search_radius_km = $2, status = 'matching' WHERE id = $1`, [
          tripId,
          radius,
        ]);
        this.io.to(`trip:${tripId}`).emit('matching_progress', {
          tripId,
          radiusKm: radius,
        });
      }
      return;
    }

    const driver = candidates.rows[0];
    const windowSec = Number(process.env.ACCEPT_WINDOW_SEC || 14);

    await query(
      `UPDATE trips SET offered_to = array_append(COALESCE(offered_to, '{}'), $2), status = 'matching'
       WHERE id = $1`,
      [tripId, driver.id],
    );

    const offer = {
      tripId,
      pickupLandmark: trip.pickup_landmark,
      pickupDistanceKm: Number(driver.dist_m) / 1000,
      destinationArea: trip.dropoff_landmark,
      estimatedFare: trip.fare_total,
      estimatedDurationMin: Number(trip.duration_min) || 18,
      acceptWindowSec: windowSec,
      riderPin: trip.rider_pin,
      category: trip.vehicle_category,
    };

    this.io.to(`driver:${driver.id}`).emit('ride_request', offer);
    await sendPush(driver.fcm_token, {
      title: 'New trip request',
      body: `${offer.pickupLandmark} · ${offer.estimatedFare} Br`,
      data: { tripId },
    });

    // Auto-skip if no accept
    setTimeout(async () => {
      const check = await query(`SELECT status, driver_id FROM trips WHERE id = $1`, [tripId]);
      if (check.rows[0]?.status === 'matching' && !check.rows[0].driver_id) {
        // already in offered_to; next tick will pick next driver
        this.tick(tripId);
      }
    }, (windowSec + 1) * 1000);
  }

  async onTimeout(tripId) {
    const { rows } = await query(`SELECT status FROM trips WHERE id = $1`, [tripId]);
    if (!rows[0] || !['requested', 'matching'].includes(rows[0].status)) return;
    this.stop(tripId);
    await query(`UPDATE trips SET status = 'cancelled', cancellation_reason = 'no_drivers', cancelled_by = 'system' WHERE id = $1`, [
      tripId,
    ]);
    this.io.to(`trip:${tripId}`).emit('match_timeout', { tripId });
  }

  async accept(tripId, driverId) {
    try {
      await query('BEGIN');
      const { rows } = await query(
        `SELECT * FROM trips WHERE id = $1 FOR UPDATE`,
        [tripId],
      );
      const trip = rows[0];
      if (!trip || !['requested', 'matching'].includes(trip.status)) {
        await query('ROLLBACK');
        return { ok: false, error: 'Trip not available' };
      }

      await query(
        `UPDATE trips SET driver_id = $2, status = 'matched', matched_at = NOW() WHERE id = $1`,
        [tripId, driverId],
      );
      await query(
        `UPDATE drivers SET online_status = 'on_trip', updated_at = NOW() WHERE id = $1`,
        [driverId],
      );
      await query('COMMIT');
      this.stop(tripId);

      const driver = (
        await query(
          `SELECT d.*, v.plate_number, v.color, v.model
           FROM drivers d
           LEFT JOIN vehicles v ON v.driver_id = d.id
           WHERE d.id = $1`,
          [driverId],
        )
      ).rows[0];

      const payload = {
        tripId,
        driver: {
          id: driver.id,
          name: driver.name,
          rating: Number(driver.rating_avg),
          plate: driver.plate_number,
          vehicleColor: driver.color,
          vehicleModel: driver.model,
          category: driver.category,
          phoneMasked: true,
        },
        riderPin: trip.rider_pin,
        etaMin: 5,
      };

      this.io.to(`trip:${tripId}`).emit('driver_matched', payload);
      this.io.to(`rider:${trip.rider_id}`).emit('driver_matched', payload);

      const rider = (
        await query(`SELECT phone, fcm_token FROM riders WHERE id = $1`, [
          trip.rider_id,
        ])
      ).rows[0];
      if (rider) {
        await sendPush(rider.fcm_token, {
          title: 'Driver matched',
          body: `${driver.name} · ${driver.plate_number}`,
          data: { tripId },
        });
        await sendSms(
          rider.phone,
          `GariGo: Driver ${driver.name} (${driver.plate_number}) is on the way. PIN ${trip.rider_pin}`,
        );
      }

      return { ok: true, ...payload };
    } catch (e) {
      try {
        await query('ROLLBACK');
      } catch (_) {}
      throw e;
    }
  }
}
