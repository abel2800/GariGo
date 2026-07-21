# GariGo API

Node/Express + PostgreSQL/PostGIS + Socket.IO matching.

## Setup

1. In pgAdmin, ensure database **`garigo`** exists (you already have this).
2. Enable PostGIS on it (pgAdmin → garigo → Extensions → Create → `postgis`), **or** the migrate script will try `CREATE EXTENSION postgis`.
3. Copy env and set your Postgres password:

```bash
cd garigo/backend
copy .env.example .env
# edit DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/garigo
npm install
npm run db:migrate
npm run db:seed
npm run dev
```

Health check: http://localhost:4000/health

## Demo credentials

| What | Value |
|------|--------|
| OTP (dev) | always `123456` (logged to console via SMS stub) |
| Admin | `ops@garigo.et` / `admin123` then 2FA `123456` |

## API surface (MVP)

- `POST /auth/otp/request` `{ phone, role: rider|driver }`
- `POST /auth/otp/verify` `{ phone, code, role }`
- `POST /trips/quote` — fare compare all classes
- `POST /trips/request` — start matching (Bearer rider)
- `POST /trips/:id/accept` — driver accept
- `POST /trips/:id/verify-pin` / `complete` / `rate` / `sos`
- `PATCH /drivers/online` + `POST /drivers/location`
- `GET /admin/ops/snapshot`
- Socket.IO events: `ride_request`, `driver_matched`, `driver_location_update`, `sos_alert`, …

## Integrations (env-gated)

| Feature | Env | Status |
|---------|-----|--------|
| SMS OTP | `SMS_PROVIDER=console\|twilio\|ethio_telecom` | console works now |
| Telebirr/CBE/HelloCash | `PAYMENTS_MODE=stub\|live` + keys | stub returns success |
| FCM | `FIREBASE_*` | stub logs |
| Masked calling | `VOICE_PROXY_MODE` + Twilio Proxy | stub |
| Maps keys for apps | `GOOGLE_MAPS_API_KEY` / `MAPBOX_ACCESS_TOKEN` | exposed at `/config/public` |

Plug real PSP/NBE credentials when issued — adapters live in `src/services/`.
