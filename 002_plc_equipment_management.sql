-- Factory Telemetry Schema
-- Migration 002: Add PLC and Equipment Management tables

-- PLC Configuration Table
CREATE TABLE IF NOT EXISTS factory_telemetry.plc_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    ip_address TEXT NOT NULL,
    plc_type TEXT NOT NULL CHECK (plc_type IN ('LOGIX', 'SLC')),
    port INTEGER DEFAULT 44818,
    enabled BOOLEAN DEFAULT TRUE,
    poll_interval_s FLOAT DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(ip_address, port)
);

-- Equipment Configuration Table
CREATE TABLE IF NOT EXISTS factory_telemetry.equipment_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    plc_id UUID REFERENCES factory_telemetry.plc_config(id),
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Management Table
CREATE TABLE IF NOT EXISTS factory_telemetry.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'operator' CHECK (role IN ('admin', 'operator', 'viewer')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ
);

-- Extend metric_def table with additional fields
ALTER TABLE factory_telemetry.metric_def 
ADD COLUMN IF NOT EXISTS enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS display_name TEXT,
ADD COLUMN IF NOT EXISTS min_value REAL,
ADD COLUMN IF NOT EXISTS max_value REAL,
ADD COLUMN IF NOT EXISTS warning_threshold REAL,
ADD COLUMN IF NOT EXISTS alarm_threshold REAL,
ADD COLUMN IF NOT EXISTS unit_display TEXT;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_plc_config_enabled ON factory_telemetry.plc_config (enabled);
CREATE INDEX IF NOT EXISTS idx_equipment_config_enabled ON factory_telemetry.equipment_config (enabled);
CREATE INDEX IF NOT EXISTS idx_equipment_config_plc_id ON factory_telemetry.equipment_config (plc_id);
CREATE INDEX IF NOT EXISTS idx_users_username ON factory_telemetry.users (username);
CREATE INDEX IF NOT EXISTS idx_users_email ON factory_telemetry.users (email);

-- Migrate existing equipment to new schema
INSERT INTO factory_telemetry.plc_config (name, ip_address, plc_type, enabled)
VALUES 
    ('Bagger 1 PLC', '16.191.1.131', 'LOGIX', TRUE),
    ('Basket Loader 1 PLC', '16.191.1.140', 'SLC', TRUE)
ON CONFLICT (ip_address, port) DO NOTHING;

-- Create equipment entries for existing equipment codes
INSERT INTO factory_telemetry.equipment_config (equipment_code, name, plc_id)
SELECT 
    'BP01.PACK.BAG1',
    'Bagger 1',
    (SELECT id FROM factory_telemetry.plc_config WHERE name = 'Bagger 1 PLC')
WHERE NOT EXISTS (SELECT 1 FROM factory_telemetry.equipment_config WHERE equipment_code = 'BP01.PACK.BAG1')
UNION ALL
SELECT 
    'BP01.PACK.BAG1.BL',
    'Basket Loader 1',
    (SELECT id FROM factory_telemetry.plc_config WHERE name = 'Basket Loader 1 PLC')
WHERE NOT EXISTS (SELECT 1 FROM factory_telemetry.equipment_config WHERE equipment_code = 'BP01.PACK.BAG1.BL');

-- Create default admin user (password: admin123 - should be changed in production)
INSERT INTO factory_telemetry.users (username, email, password_hash, role)
VALUES 
    ('admin', 'admin@factory.local', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4J/8KzKz2K', 'admin')
ON CONFLICT (username) DO NOTHING;
