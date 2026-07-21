# GariGo

**GariGo** is an Ethiopia-focused ride-hailing platform: rider booking, driver dispatch, operations admin, and a real-time API — all in one monorepo.

Built for local market realities: OTP auth, city landmarks, fare rules, commission, and stubs ready for Telebirr / CBE Birr / HelloCash and SMS providers.

---

## Architecture

```
garigo/
├── backend/                 # Node.js + Express + PostgreSQL + Socket.IO
├── packages/
│   ├── gari_core/           # Shared Flutter design system
│   └── gari_api/            # Shared Dio + Socket.IO client
└── apps/
    ├── garigo_rider/        # Rider app (Flutter)
    ├── garigo_driver/       # Driver app (Flutter)
    └── garigo_admin/        # Operations console (Flutter web)
```

| Layer | Stack |
|-------|--------|
| API | Express, JWT, Zod, Socket.IO |
| Database | PostgreSQL (lat/lng matching; PostGIS optional) |
| Clients | Flutter, Riverpod, GoRouter |
| Maps | OSM / Carto (Mapbox / Google keys optional) |

---

## Features

- **Rider** — request rides, live tracking, trip history, payments flow
- **Driver** — go online, receive offers, navigate trips, earnings
- **Admin** — ops dashboard, users, fares, and oversight
- **Realtime** — Socket.IO for ride offers and live location
- **Geo matching** — expanding radius + Haversine distance
- **Integrations (pluggable)** — SMS OTP, FCM, Telebirr / CBE / HelloCash, masked calling

---

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [Flutter](https://flutter.dev/) 3.x (SDK ^3.12)
- PostgreSQL 14+ (project developed against PostgreSQL 18)
- A local database named `garigo`

---

## Quick start

### 1. Clone

```bash
git clone https://github.com/abel2800/GariGo.git
cd GariGo
```

### 2. Backend

```bash
cd backend
cp .env.example .env
# Edit .env — set DATABASE_URL (user, password, host, port, database)
npm install
npm run db:migrate
npm run db:seed
npm run dev
```

API health check: [http://localhost:4000/health](http://localhost:4000/health)

### 3. Flutter apps

From each app directory (`apps/garigo_rider`, `apps/garigo_driver`, `apps/garigo_admin`):

```bash
flutter pub get
flutter run -d chrome
```

Or use the monorepo launcher (Windows):

```bat
start-all.cmd
```

```bash
npm start
```

| Service | URL |
|---------|-----|
| API | http://localhost:4000/health |
| Admin | http://localhost:5180 |
| Rider | http://localhost:5181 |
| Driver | http://localhost:5182 |

---

## Configuration

Copy `backend/.env.example` to `backend/.env` and set at least:

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Auth token secret (change in production) |
| `SMS_PROVIDER` | `console` (dev) or Twilio / Ethio Telecom |
| `PAYMENTS_MODE` | `stub` until PSP credentials are issued |

Optional: Google Maps / Mapbox keys, Firebase FCM, payment PSP keys, Twilio Proxy for masked calling.

---

## Seed credentials (development)

| Role | Credentials |
|------|-------------|
| Admin | `ops@garigo.et` / `admin123` |
| 2FA / OTP (dev) | `123456` |

Do not use these values in production.

---

## Project status

| Area | Status |
|------|--------|
| Postgres schema + lat/lng matching | Implemented |
| Socket.IO offers & live location | Implemented |
| OSM / Carto maps in apps | Live |
| OTP / SMS | Dev console log — wire provider keys |
| Telebirr / CBE / HelloCash | Stub adapters — wire PSP keys |
| FCM / masked calling | Stub — wire Firebase / Twilio Proxy |

---

## Scripts

| Command | Description |
|---------|-------------|
| `npm start` | Launch API + Flutter web apps (via `start-all.ps1`) |
| `npm run api` | API only (`backend` in watch mode) |
| `npm run db:migrate` | Create / update schema |
| `npm run db:seed` | Landmarks, fares, admin user |

---

## License

Private repository. All rights reserved unless otherwise stated by the owner.
