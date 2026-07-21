import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from './pool.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function migrate() {
  const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  console.log('[migrate] Applying schema to garigo…');
  await pool.query(sql);
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
