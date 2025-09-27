-- Factory Telemetry Schema
-- Migration 008: Fix Critical Schema Issues (Phase 1)
-- This migration addresses the critical database schema issues identified in the implementation plan

-- ============================================================================
-- 1. UPDATE USERS TABLE WITH ADDITIONAL ROLE OPTIONS
-- ============================================================================

-- Update the users table role constraint to include all required roles
ALTER TABLE factory_telemetry.users 
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE factory_telemetry.users 
ADD CONSTRAINT users_role_check 
CHECK (role IN ('admin', 'production_manager', 'shift_manager', 'engineer', 'operator', 'maintenance', 'quality', 'viewer'));

-- Add additional user fields if they don't exist
ALTER TABLE factory_telemetry.users 
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT,
ADD COLUMN IF NOT EXISTS employee_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS department TEXT,
ADD COLUMN IF NOT EXISTS shift TEXT,
ADD COLUMN IF NOT EXISTS skills TEXT[],
ADD COLUMN IF NOT EXISTS certifications TEXT[],
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create indexes for new user fields
CREATE INDEX IF NOT EXISTS idx_users_employee_id ON factory_telemetry.users(employee_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON factory_telemetry.users(role);
CREATE INDEX IF NOT EXISTS idx_users_department ON factory_telemetry.users(department);
CREATE INDEX IF NOT EXISTS idx_users_shift ON factory_telemetry.users(shift);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON factory_telemetry.users(is_active);

-- ============================================================================
-- 2. EXTEND EQUIPMENT_CONFIG TABLE FOR PRODUCTION MANAGEMENT
-- ============================================================================

-- Add production management fields to equipment_config table
ALTER TABLE factory_telemetry.equipment_config 
ADD COLUMN IF NOT EXISTS production_line_id UUID REFERENCES factory_telemetry.production_lines(id),
ADD COLUMN IF NOT EXISTS equipment_type TEXT DEFAULT 'production' CHECK (equipment_type IN ('production', 'utility', 'support', 'safety')),
ADD COLUMN IF NOT EXISTS criticality_level INTEGER DEFAULT 3 CHECK (criticality_level BETWEEN 1 AND 5),
ADD COLUMN IF NOT EXISTS ideal_cycle_time REAL DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS target_speed REAL DEFAULT 100.0,
ADD COLUMN IF NOT EXISTS oee_targets JSONB,
ADD COLUMN IF NOT EXISTS fault_thresholds JSONB,
ADD COLUMN IF NOT EXISTS andon_settings JSONB;

-- Create indexes for new equipment_config fields
CREATE INDEX IF NOT EXISTS idx_equipment_config_production_line ON factory_telemetry.equipment_config(production_line_id);
CREATE INDEX IF NOT EXISTS idx_equipment_config_equipment_type ON factory_telemetry.equipment_config(equipment_type);
CREATE INDEX IF NOT EXISTS idx_equipment_config_criticality ON factory_telemetry.equipment_config(criticality_level);

-- ============================================================================
-- 3. EXTEND CONTEXT TABLE FOR PRODUCTION MANAGEMENT
-- ============================================================================

-- Add production management fields to context table
ALTER TABLE factory_telemetry.context
ADD COLUMN IF NOT EXISTS current_job_id UUID REFERENCES factory_telemetry.job_assignments(id),
ADD COLUMN IF NOT EXISTS production_schedule_id UUID REFERENCES factory_telemetry.production_schedules(id),
ADD COLUMN IF NOT EXISTS target_speed REAL,
ADD COLUMN IF NOT EXISTS current_product_type_id UUID REFERENCES factory_telemetry.product_types(id),
ADD COLUMN IF NOT EXISTS production_line_id UUID REFERENCES factory_telemetry.production_lines(id);

-- Create indexes for new context fields
CREATE INDEX IF NOT EXISTS idx_context_current_job ON factory_telemetry.context(current_job_id);
CREATE INDEX IF NOT EXISTS idx_context_production_schedule ON factory_telemetry.context(production_schedule_id);
CREATE INDEX IF NOT EXISTS idx_context_production_line ON factory_telemetry.context(production_line_id);
CREATE INDEX IF NOT EXISTS idx_context_product_type ON factory_telemetry.context(current_product_type_id);

-- ============================================================================
-- 4. CREATE MISSING PRODUCTION LINES IF NOT EXISTS
-- ============================================================================

-- Ensure we have at least one production line for the existing equipment
INSERT INTO factory_telemetry.production_lines (line_code, name, description, equipment_codes, target_speed)
VALUES 
    ('L-BAG1', 'Bagger Line 1', 'Primary bagging production line', 
     ARRAY['BP01.PACK.BAG1', 'BP01.PACK.BAG1.BL'], 100.0)
ON CONFLICT (line_code) DO NOTHING;

-- ============================================================================
-- 5. UPDATE EQUIPMENT CONFIGURATION WITH PRODUCTION LINE MAPPING
-- ============================================================================

-- Update existing equipment to map to production line
UPDATE factory_telemetry.equipment_config 
SET production_line_id = (
    SELECT id FROM factory_telemetry.production_lines 
    WHERE line_code = 'L-BAG1'
)
WHERE equipment_code IN ('BP01.PACK.BAG1', 'BP01.PACK.BAG1.BL')
AND production_line_id IS NULL;

-- ============================================================================
-- 6. CREATE DEFAULT PRODUCTION TARGETS AND OEE TARGETS
-- ============================================================================

-- Update equipment_config with default OEE targets
UPDATE factory_telemetry.equipment_config 
SET oee_targets = '{
    "availability": 0.90,
    "performance": 0.95,
    "quality": 0.98,
    "oee": 0.85
}'::jsonb
WHERE oee_targets IS NULL;

-- Update equipment_config with default fault thresholds
UPDATE factory_telemetry.equipment_config 
SET fault_thresholds = '{
    "critical_faults": ["STARVATION_CAP_FEED", "MECHANICAL_FAULT"],
    "high_priority_faults": ["SENSOR_FAULT", "MOTOR_FAULT"],
    "medium_priority_faults": ["WARNING_ALARM", "MAINTENANCE_DUE"],
    "low_priority_faults": ["INFO_MESSAGE", "STATUS_UPDATE"]
}'::jsonb
WHERE fault_thresholds IS NULL;

-- Update equipment_config with default Andon settings
UPDATE factory_telemetry.equipment_config 
SET andon_settings = '{
    "auto_andon_enabled": true,
    "fault_andon_enabled": true,
    "quality_andon_enabled": true,
    "maintenance_andon_enabled": true,
    "escalation_enabled": true,
    "notification_methods": ["websocket", "email"]
}'::jsonb
WHERE andon_settings IS NULL;

-- ============================================================================
-- 7. CREATE ADDITIONAL INDEXES FOR PERFORMANCE
-- ============================================================================

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_production_schedules_line_status ON factory_telemetry.production_schedules (line_id, status);
CREATE INDEX IF NOT EXISTS idx_job_assignments_user_status ON factory_telemetry.job_assignments (user_id, status);
CREATE INDEX IF NOT EXISTS idx_downtime_events_equipment_time ON factory_telemetry.downtime_events (equipment_code, start_time);
CREATE INDEX IF NOT EXISTS idx_andon_events_line_status ON factory_telemetry.andon_events (line_id, status);
CREATE INDEX IF NOT EXISTS idx_oee_calculations_equipment_time ON factory_telemetry.oee_calculations (equipment_code, calculation_time);

-- ============================================================================
-- 8. UPDATE EXISTING DATA WITH DEFAULT VALUES
-- ============================================================================

-- Update existing users with default values where NULL
UPDATE factory_telemetry.users 
SET is_active = TRUE 
WHERE is_active IS NULL;

UPDATE factory_telemetry.users 
SET updated_at = NOW() 
WHERE updated_at IS NULL;

-- Update existing equipment with default values where NULL
UPDATE factory_telemetry.equipment_config 
SET equipment_type = 'production' 
WHERE equipment_type IS NULL;

UPDATE factory_telemetry.equipment_config 
SET criticality_level = 3 
WHERE criticality_level IS NULL;

UPDATE factory_telemetry.equipment_config 
SET ideal_cycle_time = 1.0 
WHERE ideal_cycle_time IS NULL;

UPDATE factory_telemetry.equipment_config 
SET target_speed = 100.0 
WHERE target_speed IS NULL;

-- ============================================================================
-- 9. CREATE HELPFUL VIEWS FOR PRODUCTION MANAGEMENT
-- ============================================================================

-- Create view for equipment with production context
CREATE OR REPLACE VIEW public.v_equipment_production_status AS
SELECT 
    ec.equipment_code,
    ec.name as equipment_name,
    ec.equipment_type,
    ec.criticality_level,
    ec.ideal_cycle_time,
    ec.target_speed,
    ec.oee_targets,
    ec.fault_thresholds,
    ec.andon_settings,
    pl.line_code,
    pl.name as line_name,
    c.current_operator,
    c.current_shift,
    c.planned_stop,
    c.planned_stop_reason,
    c.current_job_id,
    c.production_schedule_id,
    c.target_speed as context_target_speed,
    pt.product_code,
    pt.name as product_name,
    ja.status as job_status,
    ja.assigned_at,
    ja.accepted_at,
    ja.started_at,
    ja.completed_at
FROM factory_telemetry.equipment_config ec
LEFT JOIN factory_telemetry.production_lines pl ON ec.production_line_id = pl.id
LEFT JOIN factory_telemetry.context c ON ec.equipment_code = c.equipment_code
LEFT JOIN factory_telemetry.job_assignments ja ON c.current_job_id = ja.id
LEFT JOIN factory_telemetry.production_schedules ps ON ja.schedule_id = ps.id
LEFT JOIN factory_telemetry.product_types pt ON ps.product_type_id = pt.id
WHERE ec.enabled = true
ORDER BY pl.line_code, ec.equipment_code;

-- Create view for production line status
CREATE OR REPLACE VIEW public.v_production_line_status AS
SELECT 
    pl.id as line_id,
    pl.line_code,
    pl.name as line_name,
    pl.target_speed,
    pl.enabled,
    COUNT(ec.equipment_code) as total_equipment,
    COUNT(CASE WHEN ec.enabled = true THEN 1 END) as active_equipment,
    COUNT(CASE WHEN c.planned_stop = false THEN 1 END) as running_equipment,
    COUNT(CASE WHEN c.planned_stop = true THEN 1 END) as stopped_equipment,
    COUNT(ps.id) as active_schedules,
    COUNT(ja.id) as active_jobs,
    COUNT(CASE WHEN ja.status = 'in_progress' THEN 1 END) as running_jobs
FROM factory_telemetry.production_lines pl
LEFT JOIN factory_telemetry.equipment_config ec ON pl.id = ec.production_line_id
LEFT JOIN factory_telemetry.context c ON ec.equipment_code = c.equipment_code
LEFT JOIN factory_telemetry.production_schedules ps ON pl.id = ps.line_id AND ps.status = 'in_progress'
LEFT JOIN factory_telemetry.job_assignments ja ON ps.id = ja.schedule_id AND ja.status IN ('assigned', 'accepted', 'in_progress')
WHERE pl.enabled = true
GROUP BY pl.id, pl.line_code, pl.name, pl.target_speed, pl.enabled
ORDER BY pl.line_code;

-- ============================================================================
-- 10. CREATE FUNCTIONS FOR PRODUCTION MANAGEMENT
-- ============================================================================

-- Function to get equipment production context
CREATE OR REPLACE FUNCTION factory_telemetry.get_equipment_production_context(equipment_code_param TEXT)
RETURNS TABLE(
    equipment_code TEXT,
    line_id UUID,
    line_code TEXT,
    current_job_id UUID,
    production_schedule_id UUID,
    target_speed REAL,
    current_operator TEXT,
    current_shift TEXT,
    planned_stop BOOLEAN,
    planned_stop_reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.equipment_code,
        c.production_line_id as line_id,
        pl.line_code,
        c.current_job_id,
        c.production_schedule_id,
        c.target_speed,
        c.current_operator,
        c.current_shift,
        c.planned_stop,
        c.planned_stop_reason
    FROM factory_telemetry.context c
    LEFT JOIN factory_telemetry.production_lines pl ON c.production_line_id = pl.id
    WHERE c.equipment_code = equipment_code_param;
END;
$$ LANGUAGE plpgsql;

-- Function to update equipment production context
CREATE OR REPLACE FUNCTION factory_telemetry.update_equipment_production_context(
    equipment_code_param TEXT,
    line_id_param UUID DEFAULT NULL,
    current_job_id_param UUID DEFAULT NULL,
    production_schedule_id_param UUID DEFAULT NULL,
    target_speed_param REAL DEFAULT NULL,
    current_operator_param TEXT DEFAULT NULL,
    current_shift_param TEXT DEFAULT NULL,
    planned_stop_param BOOLEAN DEFAULT NULL,
    planned_stop_reason_param TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE factory_telemetry.context
    SET 
        production_line_id = COALESCE(line_id_param, production_line_id),
        current_job_id = COALESCE(current_job_id_param, current_job_id),
        production_schedule_id = COALESCE(production_schedule_id_param, production_schedule_id),
        target_speed = COALESCE(target_speed_param, target_speed),
        current_operator = COALESCE(current_operator_param, current_operator),
        current_shift = COALESCE(current_shift_param, current_shift),
        planned_stop = COALESCE(planned_stop_param, planned_stop),
        planned_stop_reason = COALESCE(planned_stop_reason_param, planned_stop_reason),
        updated_at = NOW()
    WHERE equipment_code = equipment_code_param;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 11. GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions for new views and functions
-- GRANT USAGE ON SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON ALL TABLES IN SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON public.v_equipment_production_status, public.v_production_line_status TO anon, authenticated;
-- GRANT EXECUTE ON FUNCTION factory_telemetry.get_equipment_production_context(TEXT) TO anon, authenticated;
-- GRANT EXECUTE ON FUNCTION factory_telemetry.update_equipment_production_context(TEXT, UUID, UUID, UUID, REAL, TEXT, TEXT, BOOLEAN, TEXT) TO anon, authenticated;

-- ============================================================================
-- 12. VERIFICATION QUERIES
-- ============================================================================

-- Verify the migration was successful
DO $$
DECLARE
    user_count INTEGER;
    equipment_count INTEGER;
    production_line_count INTEGER;
    context_columns_count INTEGER;
BEGIN
    -- Check users table has required columns
    SELECT COUNT(*) INTO user_count
    FROM information_schema.columns 
    WHERE table_schema = 'factory_telemetry' 
    AND table_name = 'users' 
    AND column_name IN ('first_name', 'last_name', 'employee_id', 'department', 'shift', 'skills', 'certifications', 'is_active');
    
    -- Check equipment_config table has required columns
    SELECT COUNT(*) INTO equipment_count
    FROM information_schema.columns 
    WHERE table_schema = 'factory_telemetry' 
    AND table_name = 'equipment_config' 
    AND column_name IN ('production_line_id', 'equipment_type', 'criticality_level', 'oee_targets', 'fault_thresholds', 'andon_settings');
    
    -- Check production lines exist
    SELECT COUNT(*) INTO production_line_count
    FROM factory_telemetry.production_lines;
    
    -- Check context table has required columns
    SELECT COUNT(*) INTO context_columns_count
    FROM information_schema.columns 
    WHERE table_schema = 'factory_telemetry' 
    AND table_name = 'context' 
    AND column_name IN ('current_job_id', 'production_schedule_id', 'target_speed', 'current_product_type_id', 'production_line_id');
    
    -- Log verification results
    RAISE NOTICE 'Migration 008 verification:';
    RAISE NOTICE 'Users table extended columns: %', user_count;
    RAISE NOTICE 'Equipment config extended columns: %', equipment_count;
    RAISE NOTICE 'Production lines count: %', production_line_count;
    RAISE NOTICE 'Context table extended columns: %', context_columns_count;
    
    -- Verify critical requirements
    IF user_count >= 7 AND equipment_count >= 6 AND production_line_count >= 1 AND context_columns_count >= 5 THEN
        RAISE NOTICE 'Migration 008 completed successfully!';
    ELSE
        RAISE EXCEPTION 'Migration 008 verification failed!';
    END IF;
END $$;
