-- Factory Telemetry Schema
-- Migration 004: Add Advanced Production Management Features

-- Production Shifts
CREATE TABLE IF NOT EXISTS factory_telemetry.production_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    description TEXT,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Shift Assignments
CREATE TABLE IF NOT EXISTS factory_telemetry.shift_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES factory_telemetry.users(id),
    shift_id UUID REFERENCES factory_telemetry.production_shifts(id),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    assigned_date DATE NOT NULL,
    is_primary BOOLEAN DEFAULT TRUE, -- Primary operator vs backup
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Production Targets
CREATE TABLE IF NOT EXISTS factory_telemetry.production_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    product_type_id UUID REFERENCES factory_telemetry.product_types(id),
    target_date DATE NOT NULL,
    shift_id UUID REFERENCES factory_telemetry.production_shifts(id),
    target_quantity INTEGER NOT NULL,
    target_oee REAL CHECK (target_oee >= 0 AND target_oee <= 1),
    target_availability REAL CHECK (target_availability >= 0 AND target_availability <= 1),
    target_performance REAL CHECK (target_performance >= 0 AND target_performance <= 1),
    target_quality REAL CHECK (target_quality >= 0 AND target_quality <= 1),
    created_by UUID REFERENCES factory_telemetry.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(line_id, product_type_id, target_date, shift_id)
);

-- Quality Checks
CREATE TABLE IF NOT EXISTS factory_telemetry.quality_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    product_type_id UUID REFERENCES factory_telemetry.product_types(id),
    check_time TIMESTAMPTZ NOT NULL,
    check_type TEXT NOT NULL CHECK (check_type IN ('incoming', 'in_process', 'final', 'audit')),
    check_result TEXT NOT NULL CHECK (check_result IN ('pass', 'fail', 'conditional')),
    quantity_checked INTEGER NOT NULL,
    quantity_passed INTEGER NOT NULL,
    quantity_failed INTEGER NOT NULL,
    defect_codes TEXT[], -- Array of defect codes found
    notes TEXT,
    checked_by UUID REFERENCES factory_telemetry.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Defect Codes
CREATE TABLE IF NOT EXISTS factory_telemetry.defect_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('dimensional', 'visual', 'functional', 'packaging')),
    severity TEXT NOT NULL CHECK (severity IN ('minor', 'major', 'critical')),
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Maintenance Work Orders
CREATE TABLE IF NOT EXISTS factory_telemetry.maintenance_work_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_number TEXT UNIQUE NOT NULL,
    equipment_code TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'assigned', 'in_progress', 'completed', 'cancelled')),
    work_type TEXT NOT NULL CHECK (work_type IN ('preventive', 'corrective', 'predictive', 'emergency')),
    scheduled_start TIMESTAMPTZ,
    scheduled_end TIMESTAMPTZ,
    actual_start TIMESTAMPTZ,
    actual_end TIMESTAMPTZ,
    estimated_duration_hours REAL,
    actual_duration_hours REAL,
    assigned_to UUID REFERENCES factory_telemetry.users(id),
    created_by UUID REFERENCES factory_telemetry.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Maintenance Tasks
CREATE TABLE IF NOT EXISTS factory_telemetry.maintenance_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_id UUID REFERENCES factory_telemetry.maintenance_work_orders(id),
    task_name TEXT NOT NULL,
    description TEXT,
    task_order INTEGER NOT NULL,
    estimated_duration_minutes INTEGER,
    actual_duration_minutes INTEGER,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'skipped')),
    completed_by UUID REFERENCES factory_telemetry.users(id),
    completed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Material Consumption
CREATE TABLE IF NOT EXISTS factory_telemetry.material_consumption (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    material_code TEXT NOT NULL,
    material_name TEXT NOT NULL,
    consumption_date DATE NOT NULL,
    shift_id UUID REFERENCES factory_telemetry.production_shifts(id),
    quantity_consumed REAL NOT NULL,
    unit_of_measure TEXT NOT NULL,
    cost_per_unit REAL,
    total_cost REAL,
    recorded_by UUID REFERENCES factory_telemetry.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Energy Consumption
CREATE TABLE IF NOT EXISTS factory_telemetry.energy_consumption (
    id BIGSERIAL PRIMARY KEY,
    equipment_code TEXT NOT NULL,
    consumption_time TIMESTAMPTZ NOT NULL,
    power_consumption_kw REAL NOT NULL,
    energy_consumption_kwh REAL NOT NULL,
    voltage_v REAL,
    current_a REAL,
    power_factor REAL,
    temperature_c REAL,
    humidity_percent REAL
);

-- Production Alerts
CREATE TABLE IF NOT EXISTS factory_telemetry.production_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    equipment_code TEXT,
    alert_type TEXT NOT NULL CHECK (alert_type IN ('oee_low', 'downtime_high', 'quality_issue', 'maintenance_due', 'target_missed')),
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    threshold_value REAL,
    actual_value REAL,
    is_acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by UUID REFERENCES factory_telemetry.users(id),
    acknowledged_at TIMESTAMPTZ,
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_by UUID REFERENCES factory_telemetry.users(id),
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Production KPIs
CREATE TABLE IF NOT EXISTS factory_telemetry.production_kpis (
    id BIGSERIAL PRIMARY KEY,
    line_id UUID REFERENCES factory_telemetry.production_lines(id),
    kpi_date DATE NOT NULL,
    shift_id UUID REFERENCES factory_telemetry.production_shifts(id),
    oee REAL,
    availability REAL,
    performance REAL,
    quality REAL,
    total_production INTEGER,
    good_parts INTEGER,
    scrap_parts INTEGER,
    rework_parts INTEGER,
    total_downtime_minutes INTEGER,
    planned_downtime_minutes INTEGER,
    unplanned_downtime_minutes INTEGER,
    changeover_time_minutes INTEGER,
    maintenance_time_minutes INTEGER,
    energy_consumption_kwh REAL,
    material_waste_percent REAL,
    first_pass_yield REAL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_shift_assignments_user_id ON factory_telemetry.shift_assignments (user_id);
CREATE INDEX IF NOT EXISTS idx_shift_assignments_date ON factory_telemetry.shift_assignments (assigned_date);
CREATE INDEX IF NOT EXISTS idx_production_targets_line_date ON factory_telemetry.production_targets (line_id, target_date);
CREATE INDEX IF NOT EXISTS idx_quality_checks_line_date ON factory_telemetry.quality_checks (line_id, check_time);
CREATE INDEX IF NOT EXISTS idx_quality_checks_result ON factory_telemetry.quality_checks (check_result);
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_equipment ON factory_telemetry.maintenance_work_orders (equipment_code);
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_status ON factory_telemetry.maintenance_work_orders (status);
CREATE INDEX IF NOT EXISTS idx_maintenance_work_orders_priority ON factory_telemetry.maintenance_work_orders (priority);
CREATE INDEX IF NOT EXISTS idx_material_consumption_line_date ON factory_telemetry.material_consumption (line_id, consumption_date);
CREATE INDEX IF NOT EXISTS idx_energy_consumption_equipment_time ON factory_telemetry.energy_consumption (equipment_code, consumption_time);
CREATE INDEX IF NOT EXISTS idx_production_alerts_line_id ON factory_telemetry.production_alerts (line_id);
CREATE INDEX IF NOT EXISTS idx_production_alerts_severity ON factory_telemetry.production_alerts (severity);
CREATE INDEX IF NOT EXISTS idx_production_alerts_acknowledged ON factory_telemetry.production_alerts (is_acknowledged);
CREATE INDEX IF NOT EXISTS idx_production_kpis_line_date ON factory_telemetry.production_kpis (line_id, kpi_date);

-- Create hypertables for time-series data (TimescaleDB)
SELECT create_hypertable('factory_telemetry.energy_consumption', 'consumption_time', if_not_exists => TRUE);
SELECT create_hypertable('factory_telemetry.production_kpis', 'created_at', if_not_exists => TRUE);

-- Insert default shifts
INSERT INTO factory_telemetry.production_shifts (name, start_time, end_time, description)
VALUES 
    ('Day Shift', '06:00:00', '14:00:00', 'Primary production shift'),
    ('Afternoon Shift', '14:00:00', '22:00:00', 'Secondary production shift'),
    ('Night Shift', '22:00:00', '06:00:00', 'Overnight production shift')
ON CONFLICT DO NOTHING;

-- Insert default defect codes
INSERT INTO factory_telemetry.defect_codes (code, name, description, category, severity)
VALUES 
    ('DIM-001', 'Length Too Short', 'Product length below specification', 'dimensional', 'major'),
    ('DIM-002', 'Length Too Long', 'Product length above specification', 'dimensional', 'major'),
    ('VIS-001', 'Print Quality Poor', 'Print quality below standard', 'visual', 'minor'),
    ('VIS-002', 'Color Variation', 'Color outside acceptable range', 'visual', 'minor'),
    ('FUN-001', 'Seal Failure', 'Package seal not properly formed', 'functional', 'critical'),
    ('FUN-002', 'Leakage', 'Package leaks during testing', 'functional', 'critical'),
    ('PAC-001', 'Label Misaligned', 'Product label not properly aligned', 'packaging', 'minor'),
    ('PAC-002', 'Tear in Package', 'Physical damage to package', 'packaging', 'major')
ON CONFLICT (code) DO NOTHING;

-- Create additional views
CREATE OR REPLACE VIEW public.v_production_performance AS
SELECT 
    pl.line_code,
    pl.name as line_name,
    pk.kpi_date,
    s.name as shift_name,
    pk.oee,
    pk.availability,
    pk.performance,
    pk.quality,
    pk.total_production,
    pk.good_parts,
    pk.scrap_parts,
    pk.rework_parts,
    pk.total_downtime_minutes,
    pk.unplanned_downtime_minutes,
    pk.energy_consumption_kwh,
    pk.material_waste_percent,
    pk.first_pass_yield
FROM factory_telemetry.production_kpis pk
JOIN factory_telemetry.production_lines pl ON pk.line_id = pl.id
LEFT JOIN factory_telemetry.production_shifts s ON pk.shift_id = s.id
ORDER BY pk.kpi_date DESC, pl.line_code;

CREATE OR REPLACE VIEW public.v_maintenance_overview AS
SELECT 
    mwo.id,
    mwo.work_order_number,
    mwo.equipment_code,
    mwo.title,
    mwo.priority,
    mwo.status,
    mwo.work_type,
    mwo.scheduled_start,
    mwo.scheduled_end,
    mwo.actual_start,
    mwo.actual_end,
    mwo.estimated_duration_hours,
    mwo.actual_duration_hours,
    u1.username as assigned_to,
    u2.username as created_by,
    COUNT(mt.id) as total_tasks,
    COUNT(CASE WHEN mt.status = 'completed' THEN 1 END) as completed_tasks
FROM factory_telemetry.maintenance_work_orders mwo
LEFT JOIN factory_telemetry.users u1 ON mwo.assigned_to = u1.id
LEFT JOIN factory_telemetry.users u2 ON mwo.created_by = u2.id
LEFT JOIN factory_telemetry.maintenance_tasks mt ON mwo.id = mt.work_order_id
GROUP BY mwo.id, mwo.work_order_number, mwo.equipment_code, mwo.title, 
         mwo.priority, mwo.status, mwo.work_type, mwo.scheduled_start, 
         mwo.scheduled_end, mwo.actual_start, mwo.actual_end, 
         mwo.estimated_duration_hours, mwo.actual_duration_hours, 
         u1.username, u2.username
ORDER BY mwo.created_at DESC;

CREATE OR REPLACE VIEW public.v_quality_summary AS
SELECT 
    pl.line_code,
    pl.name as line_name,
    pt.product_code,
    pt.name as product_name,
    qc.check_time,
    qc.check_type,
    qc.check_result,
    qc.quantity_checked,
    qc.quantity_passed,
    qc.quantity_failed,
    ROUND((qc.quantity_passed::REAL / qc.quantity_checked::REAL) * 100, 2) as pass_rate_percent,
    qc.defect_codes,
    u.username as checked_by
FROM factory_telemetry.quality_checks qc
JOIN factory_telemetry.production_lines pl ON qc.line_id = pl.id
JOIN factory_telemetry.product_types pt ON qc.product_type_id = pt.id
LEFT JOIN factory_telemetry.users u ON qc.checked_by = u.id
ORDER BY qc.check_time DESC;

-- Grant permissions (comment out for local PostgreSQL, uncomment for Supabase)
-- GRANT USAGE ON SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON ALL TABLES IN SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON public.v_production_performance, public.v_maintenance_overview, public.v_quality_summary TO anon, authenticated;
