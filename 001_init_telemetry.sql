-- Factory Telemetry Schema
-- Migration 001: Initialize telemetry tables

-- Create schema
CREATE SCHEMA IF NOT EXISTS factory_telemetry;

-- Canonical metric definition per equipment
CREATE TABLE IF NOT EXISTS factory_telemetry.metric_def (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_code TEXT NOT NULL,
  metric_key TEXT NOT NULL,
  value_type TEXT NOT NULL CHECK (value_type IN ('BOOL','INT','REAL','TEXT','JSON')),
  unit TEXT NULL,
  description TEXT NOT NULL,
  UNIQUE (equipment_code, metric_key)
);

-- Binding from metric to PLC source address/name
CREATE TABLE IF NOT EXISTS factory_telemetry.metric_binding (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_def_id UUID NOT NULL REFERENCES factory_telemetry.metric_def(id) ON DELETE CASCADE,
  plc_kind TEXT NOT NULL CHECK (plc_kind IN ('LOGIX','SLC','COMPUTED')),
  address TEXT NOT NULL,
  bit_index INT NULL,
  parse_hint TEXT NULL,
  transform_sql TEXT NULL
);

-- Latest (realtime) value per metric (1 row per metric, upsert each second)
CREATE TABLE IF NOT EXISTS factory_telemetry.metric_latest (
  metric_def_id UUID PRIMARY KEY
    REFERENCES factory_telemetry.metric_def(id) ON DELETE CASCADE,
  ts TIMESTAMPTZ NOT NULL,
  value_bool BOOLEAN NULL,
  value_int BIGINT NULL,
  value_real DOUBLE PRECISION NULL,
  value_text TEXT NULL,
  value_json JSONB NULL
);

-- Historical values (append a row every second)
CREATE TABLE IF NOT EXISTS factory_telemetry.metric_hist (
  id BIGSERIAL PRIMARY KEY,
  metric_def_id UUID NOT NULL
    REFERENCES factory_telemetry.metric_def(id) ON DELETE CASCADE,
  ts TIMESTAMPTZ NOT NULL,
  value_bool BOOLEAN NULL,
  value_int BIGINT NULL,
  value_real DOUBLE PRECISION NULL,
  value_text TEXT NULL,
  value_json JSONB NULL
);
CREATE INDEX IF NOT EXISTS ix_metric_hist_def_ts ON factory_telemetry.metric_hist (metric_def_id, ts DESC);

-- Fault catalog (from fault messages file)
CREATE TABLE IF NOT EXISTS factory_telemetry.fault_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_code TEXT NOT NULL,
  bit_index INT NOT NULL CHECK (bit_index BETWEEN 0 AND 63),
  name TEXT NOT NULL,
  description TEXT NULL,
  marker TEXT NOT NULL CHECK (marker IN ('INTERNAL','UPSTREAM','DOWNSTREAM')),
  UNIQUE (equipment_code, bit_index)
);

-- Active fault snapshots (current second)
CREATE TABLE IF NOT EXISTS factory_telemetry.fault_active (
  equipment_code TEXT NOT NULL,
  bit_index INT NOT NULL,
  ts TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL,
  PRIMARY KEY (equipment_code, bit_index)
);

-- Fault events (edges: rising=on, falling=off)
CREATE TABLE IF NOT EXISTS factory_telemetry.fault_event (
  id BIGSERIAL PRIMARY KEY,
  equipment_code TEXT NOT NULL,
  bit_index INT NOT NULL,
  ts_on TIMESTAMPTZ NOT NULL,
  ts_off TIMESTAMPTZ NULL,
  duration_s DOUBLE PRECISION
);

-- Operator context & planned stop (control from UI/REST if not from PLC)
CREATE TABLE IF NOT EXISTS factory_telemetry.context (
  equipment_code TEXT PRIMARY KEY,
  current_operator TEXT NULL,
  current_shift TEXT NULL,
  planned_stop BOOLEAN NOT NULL DEFAULT FALSE,
  planned_stop_reason TEXT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Views for convenient consumption
CREATE OR REPLACE VIEW public.v_equipment_latest AS
SELECT md.equipment_code, md.metric_key, ml.ts,
       COALESCE(ml.value_text,
                TO_JSONB(COALESCE(ml.value_bool::TEXT, ml.value_int::TEXT, ml.value_real::TEXT))::TEXT) AS value,
       ml.value_bool, ml.value_int, ml.value_real, ml.value_json
FROM factory_telemetry.metric_def md
JOIN factory_telemetry.metric_latest ml ON ml.metric_def_id = md.id;

CREATE OR REPLACE VIEW public.v_faults_active AS
SELECT f.*, c.name, c.description, c.marker
FROM factory_telemetry.fault_active f
LEFT JOIN factory_telemetry.fault_catalog c
  ON c.equipment_code=f.equipment_code AND c.bit_index=f.bit_index
WHERE f.is_active = TRUE;

-- Grant permissions (comment out for local PostgreSQL, uncomment for Supabase)
-- GRANT USAGE ON SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON ALL TABLES IN SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON public.v_equipment_latest, public.v_faults_active TO anon, authenticated;