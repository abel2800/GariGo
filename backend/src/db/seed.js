import bcrypt from 'bcryptjs';
import { query } from './pool.js';

const landmarks = [
  { en: 'Megenagna', am: 'መገናኛ', area: 'Yeka', lat: 9.022, lng: 38.802, tokens: 'megenagna megenagna square መገናኛ' },
  { en: 'Edna Mall', am: 'ኤድና ሞል', area: 'Bole', lat: 8.998, lng: 38.789, tokens: 'edna mall bole ኤድና' },
  { en: 'Bole Medhanialem', am: 'ቦሌ መድሃኒዓለም', area: 'Bole', lat: 9.010, lng: 38.780, tokens: 'bole medhanialem church ቦሌ' },
  { en: 'CMC', am: 'ሲኤምሲ', area: 'CMC', lat: 9.015, lng: 38.830, tokens: 'cmc cmc road ሲኤምሲ' },
  { en: 'Ayat', am: 'አያት', area: 'Ayat', lat: 9.040, lng: 38.860, tokens: 'ayat አያት' },
  { en: 'Summit', am: 'ሳሚት', area: 'Summit', lat: 9.020, lng: 38.850, tokens: 'summit ሳሚት' },
  { en: 'Gerji', am: 'ገርጂ', area: 'Gerji', lat: 8.995, lng: 38.810, tokens: 'gerji ገርጂ' },
];

async function seed() {
  console.log('[seed] Seeding fare configs, places, admin…');

  await query(`
    INSERT INTO fare_configs (category, base_fare, per_km, per_min, minimum_fare) VALUES
      ('moto', 25, 8, 2, 40),
      ('bajaj', 40, 12, 3, 70),
      ('car', 60, 18, 4, 120)
    ON CONFLICT (category) DO UPDATE SET
      base_fare = EXCLUDED.base_fare,
      per_km = EXCLUDED.per_km,
      per_min = EXCLUDED.per_min,
      minimum_fare = EXCLUDED.minimum_fare
  `);

  for (const p of landmarks) {
    await query(
      `INSERT INTO places (name_en, name_am, area, lat, lng, search_tokens)
       SELECT $1, $2, $3, $4, $5, $6
       WHERE NOT EXISTS (SELECT 1 FROM places WHERE name_en = $1)`,
      [p.en, p.am, p.area, p.lat, p.lng, p.tokens],
    );
  }

  await query(
    `INSERT INTO promos (code, discount_type, value, valid_to, usage_limit)
     VALUES ('GARI50', 'fixed', 50, NOW() + INTERVAL '365 days', 10000)
     ON CONFLICT (code) DO NOTHING`,
  );

  const hash = await bcrypt.hash('admin123', 10);
  // Keep exactly one CEO. Soft-remove others (FK-safe), then hard-delete if possible.
  await query(
    `UPDATE admin_users SET active = FALSE, updated_at = NOW()
     WHERE email <> 'ops@garigo.et'`,
  );
  await query(
    `UPDATE trips SET booked_by_admin_id = NULL
     WHERE booked_by_admin_id IN (
       SELECT id FROM admin_users WHERE email <> 'ops@garigo.et'
     )`,
  );
  await query(
    `UPDATE audit_logs SET admin_id = NULL
     WHERE admin_id IN (
       SELECT id FROM admin_users WHERE email <> 'ops@garigo.et'
     )`,
  );
  await query(
    `UPDATE payout_ledger SET processed_by = NULL
     WHERE processed_by IN (
       SELECT id FROM admin_users WHERE email <> 'ops@garigo.et'
     )`,
  );
  await query(
    `UPDATE push_campaigns SET created_by = NULL
     WHERE created_by IN (
       SELECT id FROM admin_users WHERE email <> 'ops@garigo.et'
     )`,
  );
  await query(`DELETE FROM admin_users WHERE email <> 'ops@garigo.et'`);
  await query(
    `INSERT INTO admin_users (email, password_hash, name, role, active)
     VALUES ('ops@garigo.et', $1, 'CEO / Super Admin', 'super_admin', TRUE)
     ON CONFLICT (email) DO UPDATE SET
       password_hash = EXCLUDED.password_hash,
       name = EXCLUDED.name,
       role = 'super_admin',
       active = TRUE,
       updated_at = NOW()`,
    [hash],
  );

  await query(
    `INSERT INTO quests (title_en, title_am, goal, reward_birr, ends_at)
     SELECT 'Complete 20 trips before 6 PM', 'ከምሽቱ 6 በፊት 20 ጉዞዎችን ያጠናቁ', 20, 150,
            date_trunc('day', NOW()) + INTERVAL '18 hours'
     WHERE NOT EXISTS (SELECT 1 FROM quests LIMIT 1)`,
  );

  // Demo rider + approved driver for real-app testing
  const riderHash = await bcrypt.hash('rider123', 10);
  await query(
    `INSERT INTO riders (phone, name, wallet_balance, total_trips, password_hash)
     VALUES ('+251911000001', 'Selam A.', 250, 3, $1)
     ON CONFLICT (phone) DO UPDATE SET
       password_hash = COALESCE(riders.password_hash, EXCLUDED.password_hash),
       name = COALESCE(riders.name, EXCLUDED.name)`,
    [riderHash],
  );
  await query(
    `INSERT INTO drivers (
       phone, name, category, approval_status, rating_avg, total_trips,
       online_status, lat, lng, available_balance, telebirr_merchant_id
     ) VALUES (
       '+251911000009', 'Dawit Tesfaye', 'bajaj', 'approved', 4.92, 142,
       'offline', 9.010, 38.780, 640, '0911000009'
     )
     ON CONFLICT (phone) DO UPDATE SET
       approval_status = 'approved',
       category = 'bajaj',
       name = EXCLUDED.name`,
  );
  await query(
    `INSERT INTO vehicles (driver_id, category, plate_number, color, model)
     SELECT d.id, 'bajaj', 'AA-3241', 'White', 'Bajaj RE'
     FROM drivers d
     WHERE d.phone = '+251911000009'
       AND NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.driver_id = d.id)`,
  );

  const zones = [
    ['Bole', 1.0, 9.01, 38.78, 3.5],
    ['CMC', 1.1, 9.015, 38.83, 3.0],
    ['Ayat', 1.0, 9.04, 38.86, 3.5],
    ['Gerji', 1.2, 8.995, 38.81, 2.5],
    ['Summit', 1.0, 9.02, 38.85, 3.0],
    ['Yeka', 1.0, 9.035, 38.79, 3.0],
  ];
  for (const [name, surge, lat, lng, radius] of zones) {
    await query(
      `INSERT INTO zones (name, surge_multiplier, center_lat, center_lng, radius_km, active)
       SELECT $1, $2, $3, $4, $5, TRUE
       WHERE NOT EXISTS (SELECT 1 FROM zones WHERE name = $1)`,
      [name, surge, lat, lng, radius],
    );
    await query(
      `UPDATE zones SET
         center_lat = COALESCE(center_lat, $2),
         center_lng = COALESCE(center_lng, $3),
         radius_km = COALESCE(radius_km, $4),
         active = COALESCE(active, TRUE)
       WHERE name = $1`,
      [name, lat, lng, radius],
    );
  }

  await query(
    `INSERT INTO promos (code, discount_type, value, usage_limit, active)
     SELECT 'WELCOME50', 'fixed', 50, 1000, TRUE
     WHERE NOT EXISTS (SELECT 1 FROM promos WHERE code = 'WELCOME50')`,
  );

  console.log('[seed] Done. CEO only: ops@garigo.et / admin123 (hire workers from Hire workers)');
  process.exit(0);
}

seed().catch((e) => {
  console.error(e);
  process.exit(1);
});
