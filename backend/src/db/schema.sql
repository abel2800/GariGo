-- GariGo schema — PostgreSQL 18
-- Geo uses lat/lng + Haversine (install PostGIS later for production geospatial)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Distance in meters between two WGS84 points
CREATE OR REPLACE FUNCTION gari_distance_m(
  lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
  SELECT CASE
    WHEN lat1 IS NULL OR lng1 IS NULL OR lat2 IS NULL OR lng2 IS NULL THEN NULL
    ELSE 6371000 * acos(LEAST(1.0, GREATEST(-1.0,
      cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lng2) - radians(lng1))
      + sin(radians(lat1)) * sin(radians(lat2))
    )))
  END;
$$ LANGUAGE SQL IMMUTABLE;

-- Enums
DO $$ BEGIN
  CREATE TYPE user_status AS ENUM ('active', 'suspended', 'banned');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE approval_status AS ENUM ('none', 'pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE vehicle_category AS ENUM ('moto', 'bajaj', 'car');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE online_status AS ENUM ('offline', 'online', 'on_trip');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE trip_status AS ENUM (
    'requested', 'matching', 'matched', 'arriving', 'arrived',
    'verifying', 'in_progress', 'completed', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM ('wallet', 'telebirr', 'cbe_birr', 'hellocash', 'cash');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded', 'cash_owed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE ticket_status AS ENUM ('open', 'in_progress', 'resolved');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE sos_status AS ENUM ('open', 'dispatched', 'resolved');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE owner_type AS ENUM ('rider', 'driver');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Riders
CREATE TABLE IF NOT EXISTS riders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL UNIQUE,
  name TEXT,
  email TEXT,
  language_pref TEXT NOT NULL DEFAULT 'am',
  is_guest BOOLEAN NOT NULL DEFAULT FALSE,
  wallet_balance INTEGER NOT NULL DEFAULT 0,
  rating_avg NUMERIC(3,2) NOT NULL DEFAULT 5.00,
  total_trips INTEGER NOT NULL DEFAULT 0,
  status user_status NOT NULL DEFAULT 'active',
  fcm_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE riders ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE riders ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Drivers
CREATE TABLE IF NOT EXISTS drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL UNIQUE,
  name TEXT,
  national_id_number TEXT,
  license_number TEXT,
  language_pref TEXT NOT NULL DEFAULT 'am',
  category vehicle_category,
  approval_status approval_status NOT NULL DEFAULT 'none',
  rejection_reasons TEXT[] NOT NULL DEFAULT '{}',
  rating_avg NUMERIC(3,2) NOT NULL DEFAULT 5.00,
  total_trips INTEGER NOT NULL DEFAULT 0,
  commission_percent NUMERIC(5,2) NOT NULL DEFAULT 15.00,
  commission_tier TEXT NOT NULL DEFAULT 'standard',
  status user_status NOT NULL DEFAULT 'active',
  online_status online_status NOT NULL DEFAULT 'offline',
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  heading NUMERIC(6,2),
  telebirr_merchant_id TEXT,
  cbe_account TEXT,
  hellocash_wallet_id TEXT,
  cash_debt INTEGER NOT NULL DEFAULT 0,
  available_balance INTEGER NOT NULL DEFAULT 0,
  acceptance_rate NUMERIC(5,2) NOT NULL DEFAULT 100.00,
  fcm_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE drivers ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS tin_number TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS business_reg_number TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS is_vehicle_owner BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS drivers_online_location_idx
  ON drivers (lat, lng)
  WHERE online_status = 'online' AND lat IS NOT NULL;

-- Vehicles
CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  category vehicle_category NOT NULL,
  plate_number TEXT NOT NULL,
  make TEXT,
  model TEXT,
  color TEXT,
  registration_doc_url TEXT,
  insurance_doc_url TEXT,
  insurance_expiry DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One plate can only be registered once (case-insensitive)
CREATE UNIQUE INDEX IF NOT EXISTS vehicles_plate_uq
  ON vehicles (upper(trim(plate_number)));

-- Driver documents
CREATE TABLE IF NOT EXISTS driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL,
  url TEXT,
  expiry_date DATE,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS driver_documents_driver_type_uq
  ON driver_documents (driver_id, doc_type);

-- OTP codes
CREATE TABLE IF NOT EXISTS otp_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL,
  code TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('rider', 'driver', 'admin')),
  expires_at TIMESTAMPTZ NOT NULL,
  consumed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS otp_phone_idx ON otp_codes (phone, role) WHERE consumed = FALSE;

-- Places
CREATE TABLE IF NOT EXISTS places (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_en TEXT NOT NULL,
  name_am TEXT NOT NULL,
  area TEXT,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  search_tokens TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS places_search_idx ON places USING GIN (to_tsvector('simple', search_tokens));

CREATE TABLE IF NOT EXISTS saved_places (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  is_home BOOLEAN NOT NULL DEFAULT FALSE,
  is_work BOOLEAN NOT NULL DEFAULT FALSE,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  landmark_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trusted_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  auto_share BOOLEAN NOT NULL DEFAULT FALSE
);

-- Trips
CREATE TABLE IF NOT EXISTS trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id UUID REFERENCES riders(id),
  driver_id UUID REFERENCES drivers(id),
  vehicle_category vehicle_category NOT NULL,
  pickup_lat DOUBLE PRECISION NOT NULL,
  pickup_lng DOUBLE PRECISION NOT NULL,
  pickup_landmark TEXT,
  pickup_voice_note_url TEXT,
  dropoff_lat DOUBLE PRECISION NOT NULL,
  dropoff_lng DOUBLE PRECISION NOT NULL,
  dropoff_landmark TEXT,
  stops JSONB NOT NULL DEFAULT '[]',
  status trip_status NOT NULL DEFAULT 'requested',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  matched_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  route_polyline TEXT,
  distance_km NUMERIC(10,3),
  duration_min NUMERIC(10,2),
  fare_base INTEGER NOT NULL DEFAULT 0,
  fare_distance INTEGER NOT NULL DEFAULT 0,
  fare_time INTEGER NOT NULL DEFAULT 0,
  surge_multiplier NUMERIC(4,2) NOT NULL DEFAULT 1.00,
  fuel_adjustment INTEGER NOT NULL DEFAULT 0,
  promo_discount INTEGER NOT NULL DEFAULT 0,
  fare_total INTEGER NOT NULL DEFAULT 0,
  payment_method payment_method NOT NULL DEFAULT 'cash',
  payment_status payment_status NOT NULL DEFAULT 'pending',
  rider_pin CHAR(4) NOT NULL,
  cancellation_reason TEXT,
  cancelled_by TEXT,
  rider_rating INTEGER,
  driver_rating INTEGER,
  tip_amount INTEGER NOT NULL DEFAULT 0,
  rating_tags TEXT[] NOT NULL DEFAULT '{}',
  offered_to UUID[],
  search_radius_km NUMERIC(6,2) NOT NULL DEFAULT 1.5
);

CREATE INDEX IF NOT EXISTS trips_status_idx ON trips (status);
CREATE INDEX IF NOT EXISTS trips_rider_idx ON trips (rider_id);
CREATE INDEX IF NOT EXISTS trips_driver_idx ON trips (driver_id);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id),
  method payment_method NOT NULL,
  amount INTEGER NOT NULL,
  commission_amount INTEGER NOT NULL DEFAULT 0,
  driver_net INTEGER NOT NULL DEFAULT 0,
  status payment_status NOT NULL DEFAULT 'pending',
  provider_txn_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Wallets
CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_type owner_type NOT NULL,
  owner_id UUID NOT NULL,
  balance INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'ETB',
  UNIQUE (owner_type, owner_id)
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  txn_type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  related_trip_id UUID,
  meta JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Rider saved bank cards (tokenized — never store full PAN)
DO $$ BEGIN
  ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'card';
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS payment_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
  brand TEXT NOT NULL DEFAULT 'card',
  last4 TEXT NOT NULL,
  exp_month INTEGER NOT NULL CHECK (exp_month BETWEEN 1 AND 12),
  exp_year INTEGER NOT NULL,
  holder_name TEXT NOT NULL,
  provider_token TEXT NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS payment_cards_rider_idx ON payment_cards (rider_id);
CREATE UNIQUE INDEX IF NOT EXISTS payment_cards_rider_token_uq
  ON payment_cards (rider_id, provider_token);

-- Optional link from trip → saved card used for payment
DO $$ BEGIN
  ALTER TABLE trips ADD COLUMN IF NOT EXISTS payment_card_id UUID REFERENCES payment_cards(id);
EXCEPTION
  WHEN undefined_table THEN NULL;
END $$;

-- Promos
CREATE TABLE IF NOT EXISTS promos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('fixed', 'percent')),
  value INTEGER NOT NULL,
  valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_to TIMESTAMPTZ,
  usage_limit INTEGER,
  used_count INTEGER NOT NULL DEFAULT 0,
  zone_restriction TEXT
);

-- Zones
CREATE TABLE IF NOT EXISTS zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  polygon JSONB,
  surge_multiplier NUMERIC(4,2) NOT NULL DEFAULT 1.00,
  base_fare_overrides JSONB NOT NULL DEFAULT '{}'
);

-- Fare config
CREATE TABLE IF NOT EXISTS fare_configs (
  category vehicle_category PRIMARY KEY,
  base_fare INTEGER NOT NULL,
  per_km INTEGER NOT NULL,
  per_min INTEGER NOT NULL,
  minimum_fare INTEGER NOT NULL
);

-- Support
CREATE TABLE IF NOT EXISTS support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id),
  user_id UUID NOT NULL,
  user_type owner_type NOT NULL,
  category TEXT NOT NULL,
  subject TEXT NOT NULL,
  status ticket_status NOT NULL DEFAULT 'open',
  priority TEXT NOT NULL DEFAULT 'normal',
  assigned_agent_id UUID,
  resolution_notes TEXT,
  messages JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sos_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id),
  triggered_by TEXT NOT NULL CHECK (triggered_by IN ('rider', 'driver')),
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  status sos_status NOT NULL DEFAULT 'open',
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

-- Admin users
CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'super_admin',
  totp_secret TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id),
  action TEXT NOT NULL,
  meta JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  audience TEXT NOT NULL DEFAULT 'drivers',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title_en TEXT NOT NULL,
  title_am TEXT NOT NULL,
  goal INTEGER NOT NULL,
  reward_birr INTEGER NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS driver_quest_progress (
  driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
  quest_id UUID REFERENCES quests(id) ON DELETE CASCADE,
  progress INTEGER NOT NULL DEFAULT 0,
  claimed BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (driver_id, quest_id)
);

-- Driver location history (optional telemetry)
CREATE TABLE IF NOT EXISTS driver_locations (
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  heading NUMERIC(6,2),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS driver_locations_time_idx ON driver_locations (driver_id, recorded_at DESC);
