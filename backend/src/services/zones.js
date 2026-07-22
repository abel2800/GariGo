import { query } from '../db/pool.js';

function haversineKm(lat1, lng1, lat2, lng2) {
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

/** Ray-cast point-in-polygon. polygon = [[lng,lat], ...] or [{lat,lng}, ...] */
function pointInPolygon(lat, lng, polygon) {
  if (!Array.isArray(polygon) || polygon.length < 3) return false;
  const pts = polygon.map((p) => {
    if (Array.isArray(p)) return { lng: Number(p[0]), lat: Number(p[1]) };
    return { lat: Number(p.lat), lng: Number(p.lng) };
  });
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const xi = pts[i].lng;
    const yi = pts[i].lat;
    const xj = pts[j].lng;
    const yj = pts[j].lat;
    const intersect =
      yi > lat !== yj > lat &&
      lng < ((xj - xi) * (lat - yi)) / (yj - yi + 1e-12) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

/**
 * Resolve surge + optional base fare overrides for a pickup point.
 * Prefers polygon zones, then center+radius, else city-wide max active surge.
 */
export async function resolveSurgeAt(lat, lng) {
  if (lat == null || lng == null || Number.isNaN(Number(lat))) {
    return { surge: 1, zone: null, overrides: {} };
  }
  const { rows } = await query(
    `SELECT * FROM zones WHERE COALESCE(active, TRUE) = TRUE ORDER BY name`,
  );
  if (!rows.length) {
    return { surge: 1, zone: null, overrides: {} };
  }

  let matched = null;
  let bestDist = Infinity;

  for (const z of rows) {
    let poly = z.polygon;
    if (typeof poly === 'string') {
      try {
        poly = JSON.parse(poly);
      } catch {
        poly = null;
      }
    }
    if (poly && Array.isArray(poly) && poly.length >= 3) {
      if (pointInPolygon(Number(lat), Number(lng), poly)) {
        matched = z;
        break;
      }
      continue;
    }
    if (z.center_lat != null && z.center_lng != null) {
      const d = haversineKm(
        Number(lat),
        Number(lng),
        Number(z.center_lat),
        Number(z.center_lng),
      );
      const radius = Number(z.radius_km) || 3;
      if (d <= radius && d < bestDist) {
        bestDist = d;
        matched = z;
      }
    }
  }

  if (!matched) {
    return { surge: 1, zone: null, overrides: {} };
  }

  let overrides = matched.base_fare_overrides || {};
  if (typeof overrides === 'string') {
    try {
      overrides = JSON.parse(overrides);
    } catch {
      overrides = {};
    }
  }

  return {
    surge: Number(matched.surge_multiplier) || 1,
    zone: {
      id: matched.id,
      name: matched.name,
      surgeMultiplier: Number(matched.surge_multiplier),
    },
    overrides: overrides && typeof overrides === 'object' ? overrides : {},
  };
}
