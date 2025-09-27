-- Factory Telemetry Schema
-- Migration 003: Add Production Management tables

-- Production Lines
CREATE TABLE IF NOT EXISTS factory_telemetry.production_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    equipment_codes TEXT[] NOT NULL, -- Array of equipment codes on this line
    target_speed REAL,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Product Types
CREATE TABLE IF NOT EXISTS factory_telemetry.product_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    target_speed REAL,
    cycle_time_seconds REAL,
    quality_specs JSONB,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Production Schedules
CREATE TABLE IF NOT EXISTS factory_telemetry.production_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    product_type_id UUID REFERENCES factory_telemetry.product_types(id),
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end TIMESTAMPTZ NOT NULL,
    target_quantity INTEGER NOT NULL,
    priority INTEGER DEFAULT 1,
    status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled', 'paused')),
    created_by UUID REFERENCES factory_telemetry.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Job Assignments
CREATE TABLE IF NOT EXISTS factory_telemetry.job_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID REFERENCES factory_telemetry.production_schedules(id),
    user_id UUID REFERENCES factory_telemetry.users(id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    accepted_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    status TEXT DEFAULT 'assigned' CHECK (status IN ('assigned', 'accepted', 'in_progress', 'completed', 'cancelled')),
    notes TEXT
);

-- Pre-start Checklists
CREATE TABLE IF NOT EXISTS factory_telemetry.checklist_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    equipment_codes TEXT[] NOT NULL,
    checklist_items JSONB NOT NULL, -- Array of {item, required, type}
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Checklist Completions
CREATE TABLE IF NOT EXISTS factory_telemetry.checklist_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_assignment_id UUID REFERENCES factory_telemetry.job_assignments(id),
    template_id UUID REFERENCES factory_telemetry.checklist_templates(id),
    completed_by UUID REFERENCES factory_telemetry.users(id),
    completed_at TIMESTAMPTZ DEFAULT NOW(),
    responses JSONB NOT NULL, -- {item_id: {checked: bool, notes: text}}
    signature_data JSONB, -- Digital signature data
    status TEXT DEFAULT 'completed' CHECK (status IN ('completed', 'failed'))
);

-- Downtime Events
CREATE TABLE IF NOT EXISTS factory_telemetry.downtime_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    equipment_code TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_seconds INTEGER,
    reason_code TEXT NOT NULL,
    reason_description TEXT,
    category TEXT CHECK (category IN ('planned', 'unplanned', 'changeover', 'maintenance')),
    subcategory TEXT,
    reported_by UUID REFERENCES factory_telemetry.users(id),
    confirmed_by UUID REFERENCES factory_telemetry.users(id),
    confirmed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- OEE Calculations (Time-series)
CREATE TABLE IF NOT EXISTS factory_telemetry.oee_calculations (
    id BIGSERIAL PRIMARY KEY,
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    equipment_code TEXT NOT NULL,
    calculation_time TIMESTAMPTZ NOT NULL,
    availability REAL NOT NULL,
    performance REAL NOT NULL,
    quality REAL NOT NULL,
    oee REAL NOT NULL,
    planned_production_time INTEGER, -- seconds
    actual_production_time INTEGER, -- seconds
    ideal_cycle_time REAL, -- seconds
    actual_cycle_time REAL, -- seconds
    good_parts INTEGER,
    total_parts INTEGER
);

-- Production Reports
CREATE TABLE IF NOT EXISTS factory_telemetry.production_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    report_date DATE NOT NULL,
    shift TEXT,
    total_production INTEGER DEFAULT 0,
    good_parts INTEGER DEFAULT 0,
    scrap_parts INTEGER DEFAULT 0,
    rework_parts INTEGER DEFAULT 0,
    total_downtime_minutes INTEGER DEFAULT 0,
    oee_average REAL,
    report_data JSONB, -- Detailed report data
    generated_by UUID REFERENCES factory_telemetry.users(id),
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    pdf_path TEXT -- Path to generated PDF
);

-- Andon Events
CREATE TABLE IF NOT EXISTS factory_telemetry.andon_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    equipment_code TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('stop', 'quality', 'maintenance', 'material')),
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    description TEXT NOT NULL,
    reported_by UUID REFERENCES factory_telemetry.users(id),
    reported_at TIMESTAMPTZ DEFAULT NOW(),
    acknowledged_by UUID REFERENCES factory_telemetry.users(id),
    acknowledged_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES factory_telemetry.users(id),
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'resolved', 'escalated'))
);

-- Extend users table with additional fields
ALTER TABLE factory_telemetry.users 
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT,
ADD COLUMN IF NOT EXISTS employee_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS department TEXT,
ADD COLUMN IF NOT EXISTS shift TEXT,
ADD COLUMN IF NOT EXISTS skills TEXT[],
ADD COLUMN IF NOT EXISTS certifications TEXT[],
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_production_lines_enabled ON factory_telemetry.production_lines (enabled);
CREATE INDEX IF NOT EXISTS idx_production_schedules_line_id ON factory_telemetry.production_schedules (line_id);
CREATE INDEX IF NOT EXISTS idx_production_schedules_status ON factory_telemetry.production_schedules (status);
CREATE INDEX IF NOT EXISTS idx_production_schedules_scheduled_start ON factory_telemetry.production_schedules (scheduled_start);
CREATE INDEX IF NOT EXISTS idx_job_assignments_user_id ON factory_telemetry.job_assignments (user_id);
CREATE INDEX IF NOT EXISTS idx_job_assignments_status ON factory_telemetry.job_assignments (status);
CREATE INDEX IF NOT EXISTS idx_downtime_events_line_id ON factory_telemetry.downtime_events (line_id);
CREATE INDEX IF NOT EXISTS idx_downtime_events_start_time ON factory_telemetry.downtime_events (start_time);
CREATE INDEX IF NOT EXISTS idx_oee_calculations_line_id ON factory_telemetry.oee_calculations (line_id);
CREATE INDEX IF NOT EXISTS idx_oee_calculations_calculation_time ON factory_telemetry.oee_calculations (calculation_time);
CREATE INDEX IF NOT EXISTS idx_andon_events_line_id ON factory_telemetry.andon_events (line_id);
CREATE INDEX IF NOT EXISTS idx_andon_events_status ON factory_telemetry.andon_events (status);
CREATE INDEX IF NOT EXISTS idx_andon_events_priority ON factory_telemetry.andon_events (priority);

-- Create hypertable for OEE calculations (TimescaleDB)
SELECT create_hypertable('factory_telemetry.oee_calculations', 'calculation_time', if_not_exists => TRUE);

-- Insert default production line
INSERT INTO factory_telemetry.production_lines (line_code, name, description, equipment_codes, target_speed)
VALUES 
    ('L-BAG1', 'Bagger Line 1', 'Primary bagging production line', 
     ARRAY['BP01.PACK.BAG1', 'BP01.PACK.BAG1.BL'], 100.0)
ON CONFLICT (line_code) DO NOTHING;

-- Insert default product types
INSERT INTO factory_telemetry.product_types (product_code, name, description, target_speed, cycle_time_seconds)
VALUES 
    ('PROD-001', 'Standard Bread Bags', 'Standard 500g bread bags', 100.0, 0.6),
    ('PROD-002', 'Large Bread Bags', 'Large 750g bread bags', 80.0, 0.75),
    ('PROD-003', 'Specialty Bags', 'Specialty packaging bags', 60.0, 1.0)
ON CONFLICT (product_code) DO NOTHING;

-- Insert default checklist template
INSERT INTO factory_telemetry.checklist_templates (name, equipment_codes, checklist_items)
VALUES 
    ('Bagger Pre-Start Checklist', 
     ARRAY['BP01.PACK.BAG1', 'BP01.PACK.BAG1.BL'],
     '[
         {
             "id": "safety_guards",
             "item": "Check all safety guards are in place",
             "required": true,
             "type": "checkbox"
         },
         {
             "id": "emergency_stops",
             "item": "Test emergency stop buttons",
             "required": true,
             "type": "checkbox"
         },
         {
             "id": "air_pressure",
             "item": "Check air pressure is within range (4-6 bar)",
             "required": true,
             "type": "measurement",
             "unit": "bar"
         },
         {
             "id": "bag_supply",
             "item": "Verify bag supply is adequate",
             "required": true,
             "type": "checkbox"
         },
         {
             "id": "product_supply",
             "item": "Check product supply is ready",
             "required": true,
             "type": "checkbox"
         },
         {
             "id": "general_notes",
             "item": "General observations and notes",
             "required": false,
             "type": "text"
         }
     ]'::jsonb)
ON CONFLICT DO NOTHING;

-- Create views for convenient consumption
CREATE OR REPLACE VIEW public.v_production_dashboard AS
SELECT 
    pl.id as line_id,
    pl.line_code,
    pl.name as line_name,
    pl.target_speed,
    ps.id as schedule_id,
    ps.scheduled_start,
    ps.scheduled_end,
    ps.target_quantity,
    ps.status as schedule_status,
    pt.product_code,
    pt.name as product_name,
    pt.cycle_time_seconds,
    ja.id as job_assignment_id,
    ja.user_id,
    ja.status as job_status,
    ja.assigned_at,
    ja.accepted_at,
    ja.started_at,
    ja.completed_at,
    u.username,
    u.first_name,
    u.last_name
FROM factory_telemetry.production_lines pl
LEFT JOIN factory_telemetry.production_schedules ps ON pl.id = ps.line_id
LEFT JOIN factory_telemetry.product_types pt ON ps.product_type_id = pt.id
LEFT JOIN factory_telemetry.job_assignments ja ON ps.id = ja.schedule_id
LEFT JOIN factory_telemetry.users u ON ja.user_id = u.id
WHERE pl.enabled = true
ORDER BY pl.name, ps.scheduled_start;

CREATE OR REPLACE VIEW public.v_downtime_summary AS
SELECT 
    pl.line_code,
    pl.name as line_name,
    de.equipment_code,
    de.category,
    de.subcategory,
    de.reason_code,
    de.reason_description,
    de.start_time,
    de.end_time,
    de.duration_seconds,
    de.duration_seconds / 60.0 as duration_minutes,
    u1.username as reported_by,
    u2.username as confirmed_by
FROM factory_telemetry.downtime_events de
JOIN factory_telemetry.production_lines pl ON de.line_id = pl.id
LEFT JOIN factory_telemetry.users u1 ON de.reported_by = u1.id
LEFT JOIN factory_telemetry.users u2 ON de.confirmed_by = u2.id
WHERE de.end_time IS NOT NULL
ORDER BY de.start_time DESC;

CREATE OR REPLACE VIEW public.v_oee_summary AS
SELECT 
    pl.line_code,
    pl.name as line_name,
    oc.equipment_code,
    oc.calculation_time,
    oc.availability,
    oc.performance,
    oc.quality,
    oc.oee,
    oc.good_parts,
    oc.total_parts,
    CASE 
        WHEN oc.oee >= 0.85 THEN 'Excellent'
        WHEN oc.oee >= 0.70 THEN 'Good'
        WHEN oc.oee >= 0.50 THEN 'Fair'
        ELSE 'Poor'
    END as oee_rating
FROM factory_telemetry.oee_calculations oc
JOIN factory_telemetry.production_lines pl ON oc.line_id = pl.id
ORDER BY oc.calculation_time DESC;

-- Grant permissions (comment out for local PostgreSQL, uncomment for Supabase)
-- GRANT USAGE ON SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON ALL TABLES IN SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON public.v_production_dashboard, public.v_downtime_summary, public.v_oee_summary TO anon, authenticated;
