import { query } from '../db/pool.js';

export async function quoteFare({
  category,
  distanceKm,
  durationMin,
  surge = 1,
  promoCode,
  stops = 0,
}) {
  const { rows } = await query(
    `SELECT * FROM fare_configs WHERE category = $1`,
    [category],
  );
  const cfg = rows[0] || {
    base_fare: 40,
    per_km: 12,
    per_min: 3,
    minimum_fare: 70,
  };

  const surgeCap = Number(process.env.SURGE_CAP || 1.8);
  const surgeMul = Math.min(Number(surge) || 1, surgeCap);
  const stopFee = stops > 0 ? stops * 25 : 0;

  let base = cfg.base_fare;
  let distanceFee = Math.round(distanceKm * cfg.per_km);
  let timeFee = Math.round(durationMin * cfg.per_min);
  let subtotal = Math.round((base + distanceFee + timeFee) * surgeMul) + stopFee;
  const fuelAdjustment = 0;

  let promoDiscount = 0;
  if (promoCode) {
    const promo = await query(
      `SELECT * FROM promos WHERE code = $1 AND (valid_to IS NULL OR valid_to > NOW())`,
      [promoCode.toUpperCase()],
    );
    if (promo.rows[0]) {
      const p = promo.rows[0];
      promoDiscount =
        p.discount_type === 'percent'
          ? Math.round((subtotal * p.value) / 100)
          : p.value;
    }
  }

  let total = Math.max(cfg.minimum_fare, subtotal + fuelAdjustment - promoDiscount);

  return {
    category,
    base,
    distanceFee,
    timeFee,
    surgeMultiplier: surgeMul,
    fuelAdjustment,
    promoDiscount,
    stopFee,
    total,
    etaMin: Math.max(3, Math.round(durationMin * 0.35)),
  };
}

/** Haversine km */
export function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function estimateRoute(distanceKm) {
  // Rough Addis traffic factor
  const durationMin = distanceKm * 3.2 + 4;
  return { distanceKm, durationMin };
}
