# GariGo

**GariGo** is an Ethiopia-focused ride-hailing platform: rider booking, driver dispatch, KYC onboarding, operations admin, payments, and a real-time API — all in one monorepo.

Built for local market realities: OTP auth, Ethiopian phone numbers, city landmarks, fare rules, commission, document-based driver KYC, and stubs ready for Telebirr / CBE Birr / HelloCash, Chapa / Stripe, and SMS providers.

---

## Architecture

```
garigo/
├── backend/                 # Node.js + Express + PostgreSQL + Socket.IO
├── packages/
│   ├── gari_core/           # Shared Flutter models + design system
│   └── gari_api/            # Shared Dio HTTP + Socket.IO client
└── apps/
    ├── garigo_rider/        # Rider app (Flutter)
    ├── garigo_driver/       # Driver app (Flutter)
    └── garigo_admin/        # Operations console (Flutter web)
```

| Layer | Stack |
|-------|--------|
| API | Express, JWT, Zod, Multer uploads, Socket.IO |
| Database | PostgreSQL (lat/lng matching; PostGIS optional) |
| Clients | Flutter, Riverpod, GoRouter |
| Maps | OSM / Carto tiles (Mapbox / Google keys optional) |
| Uploads | Images + PDF for KYC (`/uploads`, max 12 MB) |

---

## What’s included

### Rider app
- Phone OTP login / registration with name, photo, and password
- Request rides, live tracking, trip history
- Wallet and saved payment cards (vaulted; stub or live PSP)
- Profile and support entry points

### Driver app
- Apply to drive: phone OTP → account → vehicle → KYC documents → selfie → payout → training quiz → pending review
- KYC uploads accept common **image formats** (JPG, PNG, WEBP, HEIC, GIF, BMP, TIFF, AVIF, …) and **PDF**
- If admin declines a specific document, the driver re-uploads **only that document**
- Go online, receive trip offers, navigate trips, earnings / cash-out flows
- Seeded approved driver for quick demos

### Admin console
- Live ops snapshot, driver KYC queue, document review
- **Fullscreen** image / PDF viewer to inspect KYC papers
- Per-document **Verify** / **Decline** (with reason) — decline notifies the driver to re-upload that file only
- Simplified account actions: **Suspend** / **Activate** / **Ban**, plus **Approve KYC** when docs are clear
- Trips, tickets, pricing, zones, promos, finance / payouts, analytics, push / announcements, roles & audit

### Backend API
- Auth for riders, drivers, and admins (JWT + optional TOTP for admins)
- Driver & rider profiles, vehicles, documents, trips, matching
- Card vault (HMAC; optional Stripe / Chapa)
- Payment / SMS / FCM / voice-proxy stubs with env switches
- Static file hosting for uploaded KYC media

---

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [Flutter](https://flutter.dev/) 3.x (SDK ^3.12)
- PostgreSQL 14+ (developed against PostgreSQL 18)
- A local database named `garigo`
- Python 3 (optional) — used by `start-all` to serve built Flutter web apps

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

Health check: [http://localhost:4000/health](http://localhost:4000/health)

### 3. Flutter apps

From each app directory (`apps/garigo_rider`, `apps/garigo_driver`, `apps/garigo_admin`):

```bash
flutter pub get
flutter run -d chrome
# or: flutter build web --release  then serve build/web
```

### One-command Windows preview

```bat
start-all.cmd
```

or:

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
| `CARD_VAULT_SECRET` | HMAC secret for stored card fingerprints |
| `STRIPE_SECRET_KEY` / `CHAPA_*` | Optional live card / payment rails |
| `CORS_ORIGIN` | Allowed web origins (`*` for local demos) |

Optional: Google Maps / Mapbox keys, Firebase FCM, Telebirr / CBE / HelloCash keys, Twilio Proxy for masked calling.

---

## Seed credentials (development)

| Role | Credentials |
|------|-------------|
| Admin | `ops@garigo.et` / `admin123` |
| Admin 2FA / OTP (dev) | `123456` |
| Demo rider | phone `911000001` · password `rider123` |
| Demo approved driver | phone ending `9` (`911000009`) · OTP `123456` |

Do not use these values in production.

---

## KYC & document review (current flow)

1. **Driver** completes onboarding and uploads required docs (ID, licence, vehicle photos, libre, TIN, business reg, selfie, …).
2. Status becomes **pending** — driver waits on the status screen.
3. **Admin** opens Driver KYC → driver detail → taps a document for **fullscreen** review.
4. Admin **Verifies** good docs or **Declines** a bad one with a reason.
5. Declined docs put KYC back to **rejected**; the driver sees the reason and re-uploads **only** those files.
6. After re-upload, status returns to **pending**; admin can **Approve KYC** when nothing is declined.

Supported upload types: common images + PDF · max **12 MB** per file.

---

## Project status

| Area | Status |
|------|--------|
| Postgres schema + lat/lng matching | Implemented |
| Socket.IO offers & live location | Implemented |
| OSM / Carto maps in apps | Live |
| Rider registration (photo + password) | Implemented |
| Driver KYC uploads (image + PDF) | Implemented |
| Admin fullscreen doc review + per-doc decline | Implemented |
| Payment cards vault (stub / Stripe / Chapa) | Implemented (mode via env) |
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
| `npm run db:seed` | Landmarks, fares, admin, demo rider / driver |

---

## Repository

- GitHub: [https://github.com/abel2800/GariGo](https://github.com/abel2800/GariGo)

---

## License

Private repository. All rights reserved unless otherwise stated by the owner.
