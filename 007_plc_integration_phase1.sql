-- Factory Telemetry Schema
-- Migration 007: PLC Integration Phase 1 - Database Schema Extensions
-- This migration extends the existing PLC telemetry schema to support production management integration

-- Extend equipment_config table to support production lines
ALTER TABLE factory_telemetry.equipment_config 
ADD COLUMN IF NOT EXISTS production_line_id UUID REFERENCES factory_telemetry.production_lines(id),
ADD COLUMN IF NOT EXISTS equipment_type TEXT DEFAULT 'production' CHECK (equipment_type IN ('production', 'utility', 'support', 'conveyor', 'packaging')),
ADD COLUMN IF NOT EXISTS criticality_level INTEGER DEFAULT 3 CHECK (criticality_level BETWEEN 1 AND 5),
ADD COLUMN IF NOT EXISTS target_speed REAL,
ADD COLUMN IF NOT EXISTS oee_targets JSONB DEFAULT '{"availability": 0.90, "performance": 0.85, "quality": 0.95, "oee": 0.73}',
ADD COLUMN IF NOT EXISTS fault_thresholds JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS andon_settings JSONB DEFAULT '{"auto_generate_events": true, "escalation_timeout_minutes": 15}',
ADD COLUMN IF NOT EXISTS location TEXT,
ADD COLUMN IF NOT EXISTS department TEXT,
ADD COLUMN IF NOT EXISTS maintenance_interval_hours INTEGER DEFAULT 168, -- 1 week default
ADD COLUMN IF NOT EXISTS last_maintenance_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS next_maintenance_date TIMESTAMPTZ;

-- Extend context table for production management
ALTER TABLE factory_telemetry.context
ADD COLUMN IF NOT EXISTS current_job_id UUID REFERENCES factory_telemetry.job_assignments(id),
ADD COLUMN IF NOT EXISTS production_schedule_id UUID REFERENCES factory_telemetry.production_schedules(id),
ADD COLUMN IF NOT EXISTS target_speed REAL,
ADD COLUMN IF NOT EXISTS current_product_type_id UUID REFERENCES factory_telemetry.product_types(id),
ADD COLUMN IF NOT EXISTS production_line_id UUID REFERENCES factory_telemetry.production_lines(id),
ADD COLUMN IF NOT EXISTS shift_id UUID REFERENCES factory_telemetry.production_shifts(id),
ADD COLUMN IF NOT EXISTS target_quantity INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS actual_quantity INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS production_efficiency REAL DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS quality_rate REAL DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS changeover_status TEXT DEFAULT 'none' CHECK (changeover_status IN ('none', 'in_progress', 'completed', 'failed')),
ADD COLUMN IF NOT EXISTS changeover_start_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS changeover_end_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_production_update TIMESTAMPTZ DEFAULT NOW();

-- Add indexes for new columns
CREATE INDEX IF NOT EXISTS idx_equipment_config_production_line ON factory_telemetry.equipment_config (production_line_id);
CREATE INDEX IF NOT EXISTS idx_equipment_config_equipment_type ON factory_telemetry.equipment_config (equipment_type);
CREATE INDEX IF NOT EXISTS idx_equipment_config_criticality ON factory_telemetry.equipment_config (criticality_level);
CREATE INDEX IF NOT EXISTS idx_context_production_line ON factory_telemetry.context (production_line_id);
CREATE INDEX IF NOT EXISTS idx_context_current_job ON factory_telemetry.context (current_job_id);
CREATE INDEX IF NOT EXISTS idx_context_production_schedule ON factory_telemetry.context (production_schedule_id);
CREATE INDEX IF NOT EXISTS idx_context_shift ON factory_telemetry.context (shift_id);

-- Create equipment-to-production-line mapping table for easier management
CREATE TABLE IF NOT EXISTS factory_telemetry.equipment_line_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_code TEXT NOT NULL REFERENCES factory_telemetry.equipment_config(equipment_code),
    production_line_id UUID NOT NULL REFERENCES factory_telemetry.production_lines(id),
    position_in_line INTEGER, -- Order of equipment in the production line
    is_primary BOOLEAN DEFAULT FALSE, -- Primary equipment for the line
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(equipment_code, production_line_id)
);

-- Create index for equipment line mapping
CREATE INDEX IF NOT EXISTS idx_equipment_line_mapping_equipment ON factory_telemetry.equipment_line_mapping (equipment_code);
CREATE INDEX IF NOT EXISTS idx_equipment_line_mapping_line ON factory_telemetry.equipment_line_mapping (production_line_id);

-- Create production context history table for tracking changes over time
CREATE TABLE IF NOT EXISTS factory_telemetry.production_context_history (
    id BIGSERIAL PRIMARY KEY,
    equipment_code TEXT NOT NULL,
    context_data JSONB NOT NULL,
    change_reason TEXT,
    changed_by UUID REFERENCES factory_telemetry.users(id),
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for production context history
CREATE INDEX IF NOT EXISTS idx_production_context_history_equipment ON factory_telemetry.production_context_history (equipment_code);
CREATE INDEX IF NOT EXISTS idx_production_context_history_changed_at ON factory_telemetry.production_context_history (changed_at);

-- Create hypertable for production context history (TimescaleDB)
SELECT create_hypertable('factory_telemetry.production_context_history', 'changed_at', if_not_exists => TRUE);

-- Update existing equipment with production line associations
-- Map Bagger 1 and Basket Loader 1 to the default production line
UPDATE factory_telemetry.equipment_config 
SET production_line_id = (
    SELECT id FROM factory_telemetry.production_lines 
    WHERE line_code = 'L-BAG1'
),
equipment_type = 'production',
criticality_level = 4,
target_speed = 100.0,
location = 'Production Floor - Line 1',
department = 'Packaging'
WHERE equipment_code IN ('BP01.PACK.BAG1', 'BP01.PACK.BAG1.BL');

-- Insert equipment line mappings
INSERT INTO factory_telemetry.equipment_line_mapping (equipment_code, production_line_id, position_in_line, is_primary)
SELECT 
    ec.equipment_code,
    ec.production_line_id,
    CASE 
        WHEN ec.equipment_code = 'BP01.PACK.BAG1' THEN 1
        WHEN ec.equipment_code = 'BP01.PACK.BAG1.BL' THEN 2
        ELSE 99
    END,
    ec.equipment_code = 'BP01.PACK.BAG1' -- Bagger 1 is primary
FROM factory_telemetry.equipment_config ec
WHERE ec.production_line_id IS NOT NULL
ON CONFLICT (equipment_code, production_line_id) DO NOTHING;

-- Create view for equipment with production context
CREATE OR REPLACE VIEW public.v_equipment_production_status AS
SELECT 
    ec.id,
    ec.equipment_code,
    ec.name as equipment_name,
    ec.equipment_type,
    ec.criticality_level,
    ec.target_speed,
    ec.enabled as equipment_enabled,
    pl.id as production_line_id,
    pl.line_code,
    pl.name as line_name,
    pl.target_speed as line_target_speed,
    c.current_operator,
    c.current_shift,
    c.current_job_id,
    c.production_schedule_id,
    c.target_quantity,
    c.actual_quantity,
    c.production_efficiency,
    c.quality_rate,
    c.changeover_status,
    c.planned_stop,
    c.planned_stop_reason,
    c.last_production_update,
    pt.product_code,
    pt.name as product_name,
    ps.scheduled_start,
    ps.scheduled_end,
    ps.status as schedule_status,
    ja.status as job_status,
    u.username as assigned_operator
FROM factory_telemetry.equipment_config ec
LEFT JOIN factory_telemetry.production_lines pl ON ec.production_line_id = pl.id
LEFT JOIN factory_telemetry.context c ON ec.equipment_code = c.equipment_code
LEFT JOIN factory_telemetry.product_types pt ON c.current_product_type_id = pt.id
LEFT JOIN factory_telemetry.production_schedules ps ON c.production_schedule_id = ps.id
LEFT JOIN factory_telemetry.job_assignments ja ON c.current_job_id = ja.id
LEFT JOIN factory_telemetry.users u ON ja.user_id = u.id
WHERE ec.enabled = true
ORDER BY pl.line_code, ec.equipment_code;

-- Create view for production line equipment summary
CREATE OR REPLACE VIEW public.v_production_line_equipment AS
SELECT 
    pl.id as line_id,
    pl.line_code,
    pl.name as line_name,
    pl.target_speed as line_target_speed,
    COUNT(ec.id) as total_equipment,
    COUNT(CASE WHEN ec.enabled = true THEN 1 END) as active_equipment,
    COUNT(CASE WHEN ec.equipment_type = 'production' THEN 1 END) as production_equipment,
    COUNT(CASE WHEN ec.criticality_level >= 4 THEN 1 END) as critical_equipment,
    AVG(ec.target_speed) as avg_equipment_speed,
    STRING_AGG(ec.equipment_code, ', ' ORDER BY elm.position_in_line) as equipment_codes
FROM factory_telemetry.production_lines pl
LEFT JOIN factory_telemetry.equipment_config ec ON pl.id = ec.production_line_id
LEFT JOIN factory_telemetry.equipment_line_mapping elm ON ec.equipment_code = elm.equipment_code AND pl.id = elm.production_line_id
GROUP BY pl.id, pl.line_code, pl.name, pl.target_speed
ORDER BY pl.line_code;

-- Create function to update equipment production context
CREATE OR REPLACE FUNCTION factory_telemetry.update_equipment_production_context(
    p_equipment_code TEXT,
    p_production_line_id UUID DEFAULT NULL,
    p_current_job_id UUID DEFAULT NULL,
    p_production_schedule_id UUID DEFAULT NULL,
    p_target_speed REAL DEFAULT NULL,
    p_current_product_type_id UUID DEFAULT NULL,
    p_shift_id UUID DEFAULT NULL,
    p_target_quantity INTEGER DEFAULT NULL,
    p_actual_quantity INTEGER DEFAULT NULL,
    p_production_efficiency REAL DEFAULT NULL,
    p_quality_rate REAL DEFAULT NULL,
    p_changeover_status TEXT DEFAULT NULL,
    p_current_operator TEXT DEFAULT NULL,
    p_current_shift TEXT DEFAULT NULL,
    p_planned_stop BOOLEAN DEFAULT NULL,
    p_planned_stop_reason TEXT DEFAULT NULL,
    p_change_reason TEXT DEFAULT 'system_update'
)
RETURNS VOID AS $$
DECLARE
    v_context_data JSONB;
    v_existing_context RECORD;
BEGIN
    -- Get existing context data
    SELECT * INTO v_existing_context 
    FROM factory_telemetry.context 
    WHERE equipment_code = p_equipment_code;
    
    -- Build context data JSONB
    v_context_data := jsonb_build_object(
        'equipment_code', p_equipment_code,
        'production_line_id', p_production_line_id,
        'current_job_id', p_current_job_id,
        'production_schedule_id', p_production_schedule_id,
        'target_speed', p_target_speed,
        'current_product_type_id', p_current_product_type_id,
        'shift_id', p_shift_id,
        'target_quantity', p_target_quantity,
        'actual_quantity', p_actual_quantity,
        'production_efficiency', p_production_efficiency,
        'quality_rate', p_quality_rate,
        'changeover_status', p_changeover_status,
        'current_operator', p_current_operator,
        'current_shift', p_current_shift,
        'planned_stop', p_planned_stop,
        'planned_stop_reason', p_planned_stop_reason,
        'updated_at', NOW()
    );
    
    -- Insert or update context
    INSERT INTO factory_telemetry.context (
        equipment_code, production_line_id, current_job_id, production_schedule_id,
        target_speed, current_product_type_id, shift_id, target_quantity, actual_quantity,
        production_efficiency, quality_rate, changeover_status, current_operator,
        current_shift, planned_stop, planned_stop_reason, last_production_update
    )
    VALUES (
        p_equipment_code, p_production_line_id, p_current_job_id, p_production_schedule_id,
        p_target_speed, p_current_product_type_id, p_shift_id, p_target_quantity, p_actual_quantity,
        p_production_efficiency, p_quality_rate, p_changeover_status, p_current_operator,
        p_current_shift, p_planned_stop, p_planned_stop_reason, NOW()
    )
    ON CONFLICT (equipment_code) DO UPDATE SET
        production_line_id = EXCLUDED.production_line_id,
        current_job_id = EXCLUDED.current_job_id,
        production_schedule_id = EXCLUDED.production_schedule_id,
        target_speed = EXCLUDED.target_speed,
        current_product_type_id = EXCLUDED.current_product_type_id,
        shift_id = EXCLUDED.shift_id,
        target_quantity = EXCLUDED.target_quantity,
        actual_quantity = EXCLUDED.actual_quantity,
        production_efficiency = EXCLUDED.production_efficiency,
        quality_rate = EXCLUDED.quality_rate,
        changeover_status = EXCLUDED.changeover_status,
        current_operator = EXCLUDED.current_operator,
        current_shift = EXCLUDED.current_shift,
        planned_stop = EXCLUDED.planned_stop,
        planned_stop_reason = EXCLUDED.planned_stop_reason,
        last_production_update = EXCLUDED.last_production_update,
        updated_at = NOW();
    
    -- Insert into history table
    INSERT INTO factory_telemetry.production_context_history (
        equipment_code, context_data, change_reason
    )
    VALUES (
        p_equipment_code, v_context_data, p_change_reason
    );
END;
$$ LANGUAGE plpgsql;

-- Create function to get equipment production context
CREATE OR REPLACE FUNCTION factory_telemetry.get_equipment_production_context(p_equipment_code TEXT)
RETURNS TABLE (
    equipment_code TEXT,
    production_line_id UUID,
    line_code TEXT,
    line_name TEXT,
    current_job_id UUID,
    production_schedule_id UUID,
    target_speed REAL,
    current_product_type_id UUID,
    product_code TEXT,
    product_name TEXT,
    shift_id UUID,
    shift_name TEXT,
    target_quantity INTEGER,
    actual_quantity INTEGER,
    production_efficiency REAL,
    quality_rate REAL,
    changeover_status TEXT,
    current_operator TEXT,
    current_shift TEXT,
    planned_stop BOOLEAN,
    planned_stop_reason TEXT,
    last_production_update TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.equipment_code,
        c.production_line_id,
        pl.line_code,
        pl.name as line_name,
        c.current_job_id,
        c.production_schedule_id,
        c.target_speed,
        c.current_product_type_id,
        pt.product_code,
        pt.name as product_name,
        c.shift_id,
        s.name as shift_name,
        c.target_quantity,
        c.actual_quantity,
        c.production_efficiency,
        c.quality_rate,
        c.changeover_status,
        c.current_operator,
        c.current_shift,
        c.planned_stop,
        c.planned_stop_reason,
        c.last_production_update
    FROM factory_telemetry.context c
    LEFT JOIN factory_telemetry.production_lines pl ON c.production_line_id = pl.id
    LEFT JOIN factory_telemetry.product_types pt ON c.current_product_type_id = pt.id
    LEFT JOIN factory_telemetry.production_shifts s ON c.shift_id = s.id
    WHERE c.equipment_code = p_equipment_code;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (comment out for local PostgreSQL, uncomment for Supabase)
-- GRANT USAGE ON SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON ALL TABLES IN SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON public.v_equipment_production_status, public.v_production_line_equipment TO anon, authenticated;
-- GRANT EXECUTE ON FUNCTION factory_telemetry.update_equipment_production_context TO anon, authenticated;
-- GRANT EXECUTE ON FUNCTION factory_telemetry.get_equipment_production_context TO anon, authenticated;
