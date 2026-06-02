-- ============================================================
-- CHILL CODERS – Smart Fridge IoT System
-- Supabase Database Schema (ITT569)
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. SENSOR READINGS (written by ESP32 via HTTP POST)
CREATE TABLE sensor_readings (
  id            BIGSERIAL PRIMARY KEY,
  temperature   FLOAT      NOT NULL,   -- °C from DHT22
  humidity      FLOAT      NOT NULL,   -- % from DHT22
  total_weight_grams FLOAT DEFAULT 0, -- g from HX711 + Load Cell
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Realtime for live updates in Flutter
ALTER PUBLICATION supabase_realtime ADD TABLE sensor_readings;

-- 2. FRIDGE ITEMS (managed by Flutter app)
CREATE TABLE fridge_items (
  id            BIGSERIAL PRIMARY KEY,
  user_id       UUID       REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT       NOT NULL,
  category      TEXT       NOT NULL DEFAULT 'Other',
  weight_grams  FLOAT      NOT NULL,
  expiry_date   DATE       NOT NULL,
  added_date    DATE       NOT NULL DEFAULT CURRENT_DATE,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE fridge_items;

-- 3. ROW LEVEL SECURITY
ALTER TABLE fridge_items ENABLE ROW LEVEL SECURITY;

-- Users can only see/modify their own items
CREATE POLICY "Users manage own items"
  ON fridge_items FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ESP32 can insert sensor data (uses anon key)
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can insert sensor data"
  ON sensor_readings FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can read sensor data"
  ON sensor_readings FOR SELECT USING (true);

-- 4. INDEXES
CREATE INDEX idx_sensor_readings_created_at ON sensor_readings(created_at DESC);
CREATE INDEX idx_fridge_items_user_expiry ON fridge_items(user_id, expiry_date);

-- ============================================================
-- ESP32 Arduino Code Snippet (for reference):
-- POST to: https://YOUR_PROJECT.supabase.co/rest/v1/sensor_readings
-- Headers:
--   apikey: YOUR_ANON_KEY
--   Content-Type: application/json
-- Body:
--   {"temperature": 4.5, "humidity": 65.2, "total_weight_grams": 1200}
-- ============================================================
