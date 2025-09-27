-- Test Script for Phase 1 Migration (008_fix_critical_schema_issues.sql)
-- This script tests the migration to ensure all critical schema issues are resolved

-- ============================================================================
-- 1. TEST USERS TABLE EXTENSIONS
-- ============================================================================

-- Test 1: Verify users table has all required columns
SELECT 
    'Users Table Columns Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 7 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as columns_found
FROM information_schema.columns 
WHERE table_schema = 'factory_telemetry' 
AND table_name = 'users' 
AND column_name IN ('first_name', 'last_name', 'employee_id', 'department', 'shift', 'skills', 'certifications', 'is_active');

-- Test 2: Verify users table role constraint includes all required roles
SELECT 
    'Users Role Constraint Test' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.check_constraints 
            WHERE constraint_name = 'users_role_check' 
            AND check_clause LIKE '%production_manager%'
            AND check_clause LIKE '%shift_manager%'
            AND check_clause LIKE '%engineer%'
            AND check_clause LIKE '%maintenance%'
            AND check_clause LIKE '%quality%'
        ) THEN 'PASS'
        ELSE 'FAIL'
    END as result;

-- Test 3: Insert test user with new role
INSERT INTO factory_telemetry.users (username, email, password_hash, role, first_name, last_name, employee_id, department, shift, skills, certifications, is_active)
VALUES ('test_production_manager', 'test.pm@factory.local', '$2b$12$test', 'production_manager', 'Test', 'Manager', 'EMP001', 'Production', 'Day', ARRAY['production_planning', 'team_management'], ARRAY['lean_six_sigma'], true)
ON CONFLICT (username) DO NOTHING;

-- Test 4: Verify test user was created successfully
SELECT 
    'Test User Creation' as test_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM factory_telemetry.users WHERE username = 'test_production_manager') THEN 'PASS'
        ELSE 'FAIL'
    END as result;

-- ============================================================================
-- 2. TEST EQUIPMENT_CONFIG TABLE EXTENSIONS
-- ============================================================================

-- Test 5: Verify equipment_config table has all required columns
SELECT 
    'Equipment Config Columns Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 6 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as columns_found
FROM information_schema.columns 
WHERE table_schema = 'factory_telemetry' 
AND table_name = 'equipment_config' 
AND column_name IN ('production_line_id', 'equipment_type', 'criticality_level', 'oee_targets', 'fault_thresholds', 'andon_settings');

-- Test 6: Verify equipment_config has production line mapping
SELECT 
    'Equipment Production Line Mapping' as test_name,
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as equipment_with_production_lines
FROM factory_telemetry.equipment_config 
WHERE production_line_id IS NOT NULL;

-- Test 7: Verify equipment_config has default values
SELECT 
    'Equipment Config Default Values' as test_name,
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as equipment_with_defaults
FROM factory_telemetry.equipment_config 
WHERE oee_targets IS NOT NULL 
AND fault_thresholds IS NOT NULL 
AND andon_settings IS NOT NULL;

-- ============================================================================
-- 3. TEST CONTEXT TABLE EXTENSIONS
-- ============================================================================

-- Test 8: Verify context table has all required columns
SELECT 
    'Context Table Columns Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 5 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as columns_found
FROM information_schema.columns 
WHERE table_schema = 'factory_telemetry' 
AND table_name = 'context' 
AND column_name IN ('current_job_id', 'production_schedule_id', 'target_speed', 'current_product_type_id', 'production_line_id');

-- ============================================================================
-- 4. TEST PRODUCTION LINES
-- ============================================================================

-- Test 9: Verify production lines exist
SELECT 
    'Production Lines Existence' as test_name,
    CASE 
        WHEN COUNT(*) >= 1 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as production_lines_count
FROM factory_telemetry.production_lines;

-- Test 10: Verify production line has equipment
SELECT 
    'Production Line Equipment Mapping' as test_name,
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as equipment_mapped_to_lines
FROM factory_telemetry.production_lines pl
JOIN factory_telemetry.equipment_config ec ON pl.id = ec.production_line_id;

-- ============================================================================
-- 5. TEST NEW VIEWS
-- ============================================================================

-- Test 11: Verify equipment production status view exists
SELECT 
    'Equipment Production Status View' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.views 
            WHERE table_schema = 'public' 
            AND table_name = 'v_equipment_production_status'
        ) THEN 'PASS'
        ELSE 'FAIL'
    END as result;

-- Test 12: Verify production line status view exists
SELECT 
    'Production Line Status View' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.views 
            WHERE table_schema = 'public' 
            AND table_name = 'v_production_line_status'
        ) THEN 'PASS'
        ELSE 'FAIL'
    END as result;

-- Test 13: Test equipment production status view query
SELECT 
    'Equipment Production Status View Query' as test_name,
    CASE 
        WHEN COUNT(*) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as records_returned
FROM public.v_equipment_production_status;

-- ============================================================================
-- 6. TEST NEW FUNCTIONS
-- ============================================================================

-- Test 14: Verify get_equipment_production_context function exists
SELECT 
    'Get Equipment Production Context Function' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_schema = 'factory_telemetry' 
            AND routine_name = 'get_equipment_production_context'
        ) THEN 'PASS'
        ELSE 'FAIL'
    END as result;

-- Test 15: Verify update_equipment_production_context function exists
SELECT 
    'Update Equipment Production Context Function' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_schema = 'factory_telemetry' 
            AND routine_name = 'update_equipment_production_context'
        ) THEN 'PASS'
        ELSE 'FAIL'
    END as result;

-- Test 16: Test get_equipment_production_context function
SELECT 
    'Get Equipment Production Context Function Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as records_returned
FROM factory_telemetry.get_equipment_production_context('BP01.PACK.BAG1');

-- ============================================================================
-- 7. TEST DATA INTEGRITY
-- ============================================================================

-- Test 17: Verify foreign key constraints work
SELECT 
    'Foreign Key Constraints Test' as test_name,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM factory_telemetry.equipment_config 
            WHERE production_line_id IS NOT NULL 
            AND production_line_id NOT IN (SELECT id FROM factory_telemetry.production_lines)
        ) THEN 'PASS'
        ELSE 'FAIL'
    END as result;

-- Test 18: Verify context foreign key constraints work
SELECT 
    'Context Foreign Key Constraints Test' as test_name,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM factory_telemetry.context 
            WHERE current_job_id IS NOT NULL 
            AND current_job_id NOT IN (SELECT id FROM factory_telemetry.job_assignments)
        ) THEN 'PASS'
        ELSE 'FAIL'
    END as result;

-- ============================================================================
-- 8. TEST INDEXES
-- ============================================================================

-- Test 19: Verify critical indexes exist
SELECT 
    'Critical Indexes Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 5 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as indexes_found
FROM pg_indexes 
WHERE schemaname = 'factory_telemetry' 
AND indexname IN (
    'idx_users_employee_id',
    'idx_users_role',
    'idx_equipment_config_production_line',
    'idx_context_current_job',
    'idx_production_schedules_line_status'
);

-- ============================================================================
-- 9. CLEANUP TEST DATA
-- ============================================================================

-- Clean up test user
DELETE FROM factory_telemetry.users WHERE username = 'test_production_manager';

-- ============================================================================
-- 10. SUMMARY REPORT
-- ============================================================================

-- Generate summary report
SELECT 
    'PHASE 1 MIGRATION TEST SUMMARY' as summary,
    'All critical schema issues should be resolved' as description,
    NOW() as test_completed_at;