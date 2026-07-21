import 'dotenv/config';
import http from 'http';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { Server } from 'socket.io';

import { pool } from './db/pool.js';
import authRoutes from './routes/auth.js';
import driverRoutes from './routes/drivers.js';
import riderRoutes from './routes/riders.js';
import adminRoutes from './routes/admin.js';
import { createTripRouter } from './routes/trips.js';
import { setupSockets } from './socket.js';
import { uploadsDir } from './middleware/upload.js';

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: process.env.CORS_ORIGIN || '*' },
});

const matching = setupSockets(io);

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    // Allow admin web (:5180) to embed KYC PDFs/images from /uploads in fullscreen.
    frameguard: false,
    crossOriginEmbedderPolicy: false,
  }),
);
app.use(cors({ origin: process.env.CORS_ORIGIN || true }));
app.use(express.json({ limit: '5mb' }));
app.use(morgan('dev'));
app.use('/uploads', (req, res, next) => {
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  next();
}, express.static(uploadsDir));

/** Proxy map tiles so Flutter web can paint them (Carto/OSM lack CORS). */
app.get('/tiles/:style/:z/:x/:y.png', async (req, res) => {
  try {
    const { style, z, x, y } = req.params;
    const zNum = Number(z);
    const xNum = Number(x);
    const yNum = Number(y);
    if (
      !Number.isInteger(zNum) ||
      !Number.isInteger(xNum) ||
      !Number.isInteger(yNum) ||
      zNum < 0 ||
      zNum > 22
    ) {
      return res.status(400).send('bad tile');
    }
    const host = ['a', 'b', 'c', 'd'][(xNum + yNum) % 4];
    const upstream =
      style === 'dark'
        ? `https://${host}.basemaps.cartocdn.com/dark_all/${zNum}/${xNum}/${yNum}.png`
        : `https://${host}.basemaps.cartocdn.com/rastertiles/voyager/${zNum}/${xNum}/${yNum}.png`;
    const r = await fetch(upstream, {
      headers: { 'User-Agent': 'GariGo/1.0 (dev tile proxy)' },
    });
    if (!r.ok) return res.status(r.status).send('tile upstream error');
    const buf = Buffer.from(await r.arrayBuffer());
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.send(buf);
  } catch (e) {
    console.error('[tiles]', e.message);
    res.status(502).send('tile proxy failed');
  }
});

app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    let postgis = false;
    try {
      const r = await pool.query(`SELECT PostGIS_Version() AS v`);
      postgis = !!r.rows[0]?.v;
    } catch {
      postgis = false;
    }
    res.json({
      ok: true,
      service: 'garigo-api',
      postgis,
      maps: {
        google: !!process.env.GOOGLE_MAPS_API_KEY,
        mapbox: !!process.env.MAPBOX_ACCESS_TOKEN,
      },
      paymentsMode: process.env.PAYMENTS_MODE || 'stub',
      smsProvider: process.env.SMS_PROVIDER || 'console',
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.get('/config/public', (_req, res) => {
  res.json({
    googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || null,
    mapboxToken: process.env.MAPBOX_ACCESS_TOKEN || null,
    commissionPercent: Number(process.env.COMMISSION_PERCENT || 15),
    surgeCap: Number(process.env.SURGE_CAP || 1.8),
  });
});

app.use('/auth', authRoutes);
app.use('/drivers', driverRoutes);
app.use('/riders', riderRoutes);
app.use('/trips', createTripRouter(matching));
app.use('/admin', adminRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal error' });
});

const port = Number(process.env.PORT || 4000);
server.listen(port, () => {
  console.log(`[garigo-api] http://localhost:${port}`);
  console.log(`[garigo-api] Socket.IO ready`);
});
