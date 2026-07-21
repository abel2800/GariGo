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
  await query(
    `INSERT INTO admin_users (email, password_hash, name, role)
     VALUES ('ops@garigo.et', $1, 'Super Admin', 'super_admin')
     ON CONFLICT (email) DO NOTHING`,
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
    ['Bole', 1.0],
    ['CMC', 1.1],
    ['Ayat', 1.0],
    ['Gerji', 1.2],
    ['Summit', 1.0],
    ['Yeka', 1.0],
  ];
  for (const [name, surge] of zones) {
    await query(
      `INSERT INTO zones (name, surge_multiplier)
       SELECT $1, $2
       WHERE NOT EXISTS (SELECT 1 FROM zones WHERE name = $1)`,
      [name, surge],
    );
  }

  console.log('[seed] Done. Admin: ops@garigo.et / admin123');
  process.exit(0);
}

seed().catch((e) => {
  console.error(e);
  process.exit(1);
});
