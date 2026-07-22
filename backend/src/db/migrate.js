import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from './pool.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function migrate() {
  const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  console.log('[migrate] Applying schema to garigo…');
  await pool.query(sql);

  // Additive columns for existing DBs (CREATE IF NOT EXISTS won't alter tables)
  const alters = [
    `ALTER TABLE zones ADD COLUMN IF NOT EXISTS center_lat DOUBLE PRECISION`,
    `ALTER TABLE zones ADD COLUMN IF NOT EXISTS center_lng DOUBLE PRECISION`,
    `ALTER TABLE zones ADD COLUMN IF NOT EXISTS radius_km NUMERIC(6,2) DEFAULT 3.0`,
    `ALTER TABLE zones ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE`,
    `ALTER TABLE promos ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE`,
    `ALTER TABLE drivers ADD COLUMN IF NOT EXISTS match_radius_km NUMERIC(4,2) NOT NULL DEFAULT 2.00`,
    `CREATE TABLE IF NOT EXISTS trip_messages (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
      sender_role TEXT NOT NULL CHECK (sender_role IN ('rider', 'driver')),
      sender_id UUID NOT NULL,
      body TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )`,
    `CREATE INDEX IF NOT EXISTS trip_messages_trip_idx ON trip_messages (trip_id, created_at)`,
    `ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS photo_url TEXT`,
    `ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS phone TEXT`,
    `ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE`,
    `ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
    `ALTER TABLE trips ADD COLUMN IF NOT EXISTS booked_by_admin_id UUID REFERENCES admin_users(id)`,
    `ALTER TABLE trips ADD COLUMN IF NOT EXISTS booking_channel TEXT NOT NULL DEFAULT 'app'`,
    `ALTER TABLE trips ADD COLUMN IF NOT EXISTS booking_notes TEXT`,
  ];
  for (const a of alters) {
    await pool.query(a);
  }

  console.log('[migrate] Done.');
  await pool.end();
}

migrate().catch((err) => {
  console.error('[migrate] Failed:', err.message);
  console.error(
    'Check DATABASE_URL in backend/.env (garigo DB is on port 5433 for PG 18).',
  );
  process.exit(1);
});
