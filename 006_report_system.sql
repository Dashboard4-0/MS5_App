-- Migration 006: Add Report System tables
-- This migration adds comprehensive report generation and template management tables

-- Report Templates table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    template_type TEXT NOT NULL CHECK (template_type IN ('production', 'oee', 'downtime', 'quality', 'maintenance', 'custom')),
    parameters JSONB NOT NULL DEFAULT '[]'::jsonb, -- Template parameters configuration
    sections JSONB NOT NULL DEFAULT '[]'::jsonb,  -- Template sections configuration
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES factory_telemetry.users(id),
    updated_by UUID REFERENCES factory_telemetry.users(id)
);

-- Report Generation Jobs table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_generation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES factory_telemetry.report_templates(id),
    report_type TEXT NOT NULL,
    parameters JSONB NOT NULL DEFAULT '{}'::jsonb, -- Generation parameters
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    priority INTEGER DEFAULT 0, -- Higher number = higher priority
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_by UUID REFERENCES factory_telemetry.users(id),
    error_message TEXT,
    progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100)
);

-- Generated Reports table (extends existing production_reports table)
-- Add new columns to existing production_reports table
ALTER TABLE factory_telemetry.production_reports 
ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES factory_telemetry.report_templates(id),
ADD COLUMN IF NOT EXISTS generation_job_id UUID REFERENCES factory_telemetry.report_generation_jobs(id),
ADD COLUMN IF NOT EXISTS file_size BIGINT,
ADD COLUMN IF NOT EXISTS file_hash TEXT,
ADD COLUMN IF NOT EXISTS generation_parameters JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed' CHECK (status IN ('generating', 'completed', 'failed', 'deleted')),
ADD COLUMN IF NOT EXISTS download_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_downloaded_at TIMESTAMPTZ;

-- Report Access Log table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_access_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID REFERENCES factory_telemetry.production_reports(id) ON DELETE CASCADE,
    user_id UUID REFERENCES factory_telemetry.users(id),
    action TEXT NOT NULL CHECK (action IN ('viewed', 'downloaded', 'shared', 'deleted')),
    accessed_at TIMESTAMPTZ DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    additional_data JSONB DEFAULT '{}'::jsonb
);

-- Report Favorites table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES factory_telemetry.users(id) ON DELETE CASCADE,
    template_id UUID REFERENCES factory_telemetry.report_templates(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- User-defined name for the favorite
    parameters JSONB NOT NULL DEFAULT '{}'::jsonb, -- Saved parameters
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, template_id, name)
);

-- Report Schedules table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    template_id UUID REFERENCES factory_telemetry.report_templates(id),
    parameters JSONB NOT NULL DEFAULT '{}'::jsonb,
    schedule_cron TEXT NOT NULL, -- Cron expression for scheduling
    is_active BOOLEAN DEFAULT true,
    next_run_at TIMESTAMPTZ,
    last_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES factory_telemetry.users(id),
    updated_by UUID REFERENCES factory_telemetry.users(id)
);

-- Report Schedule Runs table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_schedule_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID REFERENCES factory_telemetry.report_schedules(id) ON DELETE CASCADE,
    generation_job_id UUID REFERENCES factory_telemetry.report_generation_jobs(id),
    report_id UUID REFERENCES factory_telemetry.production_reports(id),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed', 'skipped')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Report Categories table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    color TEXT, -- Hex color code for UI
    icon TEXT, -- Icon name for UI
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Report Template Categories junction table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_template_categories (
    template_id UUID REFERENCES factory_telemetry.report_templates(id) ON DELETE CASCADE,
    category_id UUID REFERENCES factory_telemetry.report_categories(id) ON DELETE CASCADE,
    PRIMARY KEY (template_id, category_id)
);

-- Report Permissions table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES factory_telemetry.report_templates(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    can_generate BOOLEAN DEFAULT false,
    can_view BOOLEAN DEFAULT false,
    can_edit BOOLEAN DEFAULT false,
    can_delete BOOLEAN DEFAULT false,
    can_schedule BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(template_id, role)
);

-- Report Notifications table
CREATE TABLE IF NOT EXISTS factory_telemetry.report_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID REFERENCES factory_telemetry.production_reports(id) ON DELETE CASCADE,
    user_id UUID REFERENCES factory_telemetry.users(id),
    notification_type TEXT NOT NULL CHECK (notification_type IN ('generated', 'failed', 'scheduled', 'shared')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_report_templates_type ON factory_telemetry.report_templates (template_type);
CREATE INDEX IF NOT EXISTS idx_report_templates_active ON factory_telemetry.report_templates (is_active);
CREATE INDEX IF NOT EXISTS idx_report_templates_created_by ON factory_telemetry.report_templates (created_by);

CREATE INDEX IF NOT EXISTS idx_report_generation_jobs_status ON factory_telemetry.report_generation_jobs (status);
CREATE INDEX IF NOT EXISTS idx_report_generation_jobs_priority ON factory_telemetry.report_generation_jobs (priority DESC);
CREATE INDEX IF NOT EXISTS idx_report_generation_jobs_created_at ON factory_telemetry.report_generation_jobs (created_at);
CREATE INDEX IF NOT EXISTS idx_report_generation_jobs_template_id ON factory_telemetry.report_generation_jobs (template_id);

CREATE INDEX IF NOT EXISTS idx_production_reports_template_id ON factory_telemetry.production_reports (template_id);
CREATE INDEX IF NOT EXISTS idx_production_reports_status ON factory_telemetry.production_reports (status);
CREATE INDEX IF NOT EXISTS idx_production_reports_generated_at ON factory_telemetry.production_reports (generated_at);
CREATE INDEX IF NOT EXISTS idx_production_reports_line_id ON factory_telemetry.production_reports (line_id);

CREATE INDEX IF NOT EXISTS idx_report_access_logs_report_id ON factory_telemetry.report_access_logs (report_id);
CREATE INDEX IF NOT EXISTS idx_report_access_logs_user_id ON factory_telemetry.report_access_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_report_access_logs_accessed_at ON factory_telemetry.report_access_logs (accessed_at);

CREATE INDEX IF NOT EXISTS idx_report_favorites_user_id ON factory_telemetry.report_favorites (user_id);
CREATE INDEX IF NOT EXISTS idx_report_favorites_template_id ON factory_telemetry.report_favorites (template_id);

CREATE INDEX IF NOT EXISTS idx_report_schedules_active ON factory_telemetry.report_schedules (is_active);
CREATE INDEX IF NOT EXISTS idx_report_schedules_next_run ON factory_telemetry.report_schedules (next_run_at);
CREATE INDEX IF NOT EXISTS idx_report_schedules_template_id ON factory_telemetry.report_schedules (template_id);

CREATE INDEX IF NOT EXISTS idx_report_schedule_runs_schedule_id ON factory_telemetry.report_schedule_runs (schedule_id);
CREATE INDEX IF NOT EXISTS idx_report_schedule_runs_status ON factory_telemetry.report_schedule_runs (status);
CREATE INDEX IF NOT EXISTS idx_report_schedule_runs_created_at ON factory_telemetry.report_schedule_runs (created_at);

CREATE INDEX IF NOT EXISTS idx_report_categories_active ON factory_telemetry.report_categories (is_active);
CREATE INDEX IF NOT EXISTS idx_report_categories_sort_order ON factory_telemetry.report_categories (sort_order);

CREATE INDEX IF NOT EXISTS idx_report_permissions_template_id ON factory_telemetry.report_permissions (template_id);
CREATE INDEX IF NOT EXISTS idx_report_permissions_role ON factory_telemetry.report_permissions (role);

CREATE INDEX IF NOT EXISTS idx_report_notifications_user_id ON factory_telemetry.report_notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_report_notifications_is_read ON factory_telemetry.report_notifications (is_read);
CREATE INDEX IF NOT EXISTS idx_report_notifications_sent_at ON factory_telemetry.report_notifications (sent_at);

-- Create views for common queries
CREATE OR REPLACE VIEW factory_telemetry.report_generation_status AS
SELECT 
    rgj.id as job_id,
    rgj.template_id,
    rt.name as template_name,
    rgj.report_type,
    rgj.status,
    rgj.priority,
    rgj.progress_percentage,
    rgj.created_at,
    rgj.started_at,
    rgj.completed_at,
    rgj.error_message,
    u.username as created_by_username,
    CASE 
        WHEN rgj.status = 'completed' THEN pr.id
        ELSE NULL
    END as report_id
FROM factory_telemetry.report_generation_jobs rgj
LEFT JOIN factory_telemetry.report_templates rt ON rgj.template_id = rt.id
LEFT JOIN factory_telemetry.users u ON rgj.created_by = u.id
LEFT JOIN factory_telemetry.production_reports pr ON rgj.id = pr.generation_job_id;

CREATE OR REPLACE VIEW factory_telemetry.report_statistics AS
SELECT 
    COUNT(*) as total_reports,
    COUNT(CASE WHEN pr.generated_at >= NOW() - INTERVAL '1 day' THEN 1 END) as reports_today,
    COUNT(CASE WHEN pr.generated_at >= NOW() - INTERVAL '7 days' THEN 1 END) as reports_this_week,
    COUNT(CASE WHEN pr.generated_at >= NOW() - INTERVAL '30 days' THEN 1 END) as reports_this_month,
    SUM(pr.file_size) as total_storage_used,
    AVG(pr.file_size) as average_file_size,
    COUNT(CASE WHEN pr.status = 'completed' THEN 1 END) as completed_reports,
    COUNT(CASE WHEN pr.status = 'failed' THEN 1 END) as failed_reports,
    COUNT(CASE WHEN pr.status = 'generating' THEN 1 END) as generating_reports
FROM factory_telemetry.production_reports pr;

-- Insert default report categories
INSERT INTO factory_telemetry.report_categories (name, description, color, icon, sort_order) VALUES
('Production', 'Production-related reports', '#2196F3', 'factory', 1),
('OEE', 'Overall Equipment Effectiveness reports', '#4CAF50', 'trending_up', 2),
('Downtime', 'Downtime analysis reports', '#F44336', 'warning', 3),
('Quality', 'Quality control reports', '#FF9800', 'check_circle', 4),
('Maintenance', 'Maintenance reports', '#9C27B0', 'build', 5),
('Custom', 'Custom user-defined reports', '#607D8B', 'tune', 6)
ON CONFLICT (name) DO NOTHING;

-- Insert default report templates
INSERT INTO factory_telemetry.report_templates (name, description, template_type, parameters, sections, created_by) VALUES
('Daily Production Report', 'Standard daily production report with OEE and downtime analysis', 'production', 
 '[{"name": "line_id", "type": "uuid", "required": true, "description": "Production line ID"}, {"name": "report_date", "type": "date", "required": true, "description": "Report date"}, {"name": "shift", "type": "string", "required": false, "description": "Shift (Day/Night)"}]',
 '[{"type": "header", "title": "Report Header"}, {"type": "summary", "title": "Executive Summary"}, {"type": "oee", "title": "OEE Analysis"}, {"type": "downtime", "title": "Downtime Analysis"}, {"type": "production", "title": "Production Details"}, {"type": "quality", "title": "Quality Analysis"}, {"type": "equipment", "title": "Equipment Status"}]',
 (SELECT id FROM factory_telemetry.users LIMIT 1)),
('OEE Analysis Report', 'Comprehensive OEE analysis report for a date range', 'oee',
 '[{"name": "line_id", "type": "uuid", "required": true, "description": "Production line ID"}, {"name": "start_date", "type": "date", "required": true, "description": "Start date"}, {"name": "end_date", "type": "date", "required": true, "description": "End date"}]',
 '[{"type": "header", "title": "Report Header"}, {"type": "oee_overview", "title": "OEE Overview"}, {"type": "oee_trends", "title": "OEE Trends"}, {"type": "performance_analysis", "title": "Performance Analysis"}, {"type": "recommendations", "title": "Recommendations"}]',
 (SELECT id FROM factory_telemetry.users LIMIT 1)),
('Downtime Analysis Report', 'Comprehensive downtime analysis report for a date range', 'downtime',
 '[{"name": "line_id", "type": "uuid", "required": true, "description": "Production line ID"}, {"name": "start_date", "type": "date", "required": true, "description": "Start date"}, {"name": "end_date", "type": "date", "required": true, "description": "End date"}]',
 '[{"type": "header", "title": "Report Header"}, {"type": "downtime_overview", "title": "Downtime Overview"}, {"type": "downtime_breakdown", "title": "Downtime Breakdown"}, {"type": "top_reasons", "title": "Top Downtime Reasons"}, {"type": "equipment_downtime", "title": "Equipment Downtime Analysis"}, {"type": "downtime_recommendations", "title": "Downtime Reduction Recommendations"}]',
 (SELECT id FROM factory_telemetry.users LIMIT 1))
ON CONFLICT DO NOTHING;

-- Insert default report permissions
INSERT INTO factory_telemetry.report_permissions (template_id, role, can_generate, can_view, can_edit, can_delete, can_schedule) 
SELECT 
    rt.id,
    'admin',
    true, true, true, true, true
FROM factory_telemetry.report_templates rt
ON CONFLICT (template_id, role) DO NOTHING;

INSERT INTO factory_telemetry.report_permissions (template_id, role, can_generate, can_view, can_edit, can_delete, can_schedule) 
SELECT 
    rt.id,
    'production_manager',
    true, true, true, false, true
FROM factory_telemetry.report_templates rt
ON CONFLICT (template_id, role) DO NOTHING;

INSERT INTO factory_telemetry.report_permissions (template_id, role, can_generate, can_view, can_edit, can_delete, can_schedule) 
SELECT 
    rt.id,
    'shift_manager',
    true, true, false, false, true
FROM factory_telemetry.report_templates rt
ON CONFLICT (template_id, role) DO NOTHING;

INSERT INTO factory_telemetry.report_permissions (template_id, role, can_generate, can_view, can_edit, can_delete, can_schedule) 
SELECT 
    rt.id,
    'engineer',
    true, true, false, false, false
FROM factory_telemetry.report_templates rt
ON CONFLICT (template_id, role) DO NOTHING;

INSERT INTO factory_telemetry.report_permissions (template_id, role, can_generate, can_view, can_edit, can_delete, can_schedule) 
SELECT 
    rt.id,
    'operator',
    false, true, false, false, false
FROM factory_telemetry.report_templates rt
ON CONFLICT (template_id, role) DO NOTHING;

-- Create function to update report download count
CREATE OR REPLACE FUNCTION factory_telemetry.update_report_download_count()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.action = 'downloaded' THEN
        UPDATE factory_telemetry.production_reports 
        SET 
            download_count = download_count + 1,
            last_downloaded_at = NEW.accessed_at
        WHERE id = NEW.report_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for download count
CREATE TRIGGER trigger_update_report_download_count
    AFTER INSERT ON factory_telemetry.report_access_logs
    FOR EACH ROW
    EXECUTE FUNCTION factory_telemetry.update_report_download_count();

-- Create function to clean up old reports
CREATE OR REPLACE FUNCTION factory_telemetry.cleanup_old_reports()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete reports older than 1 year that haven't been downloaded
    DELETE FROM factory_telemetry.production_reports 
    WHERE generated_at < NOW() - INTERVAL '1 year'
    AND download_count = 0
    AND status = 'completed';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Delete old access logs
    DELETE FROM factory_telemetry.report_access_logs 
    WHERE accessed_at < NOW() - INTERVAL '6 months';
    
    -- Delete old generation jobs
    DELETE FROM factory_telemetry.report_generation_jobs 
    WHERE created_at < NOW() - INTERVAL '3 months'
    AND status IN ('completed', 'failed', 'cancelled');
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get report generation queue status
CREATE OR REPLACE FUNCTION factory_telemetry.get_report_queue_status()
RETURNS TABLE (
    pending_jobs INTEGER,
    processing_jobs INTEGER,
    completed_today INTEGER,
    failed_today INTEGER,
    average_generation_time INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(CASE WHEN rgj.status = 'pending' THEN 1 END)::INTEGER as pending_jobs,
        COUNT(CASE WHEN rgj.status = 'processing' THEN 1 END)::INTEGER as processing_jobs,
        COUNT(CASE WHEN rgj.status = 'completed' AND rgj.completed_at >= CURRENT_DATE THEN 1 END)::INTEGER as completed_today,
        COUNT(CASE WHEN rgj.status = 'failed' AND rgj.created_at >= CURRENT_DATE THEN 1 END)::INTEGER as failed_today,
        AVG(rgj.completed_at - rgj.started_at) as average_generation_time
    FROM factory_telemetry.report_generation_jobs rgj
    WHERE rgj.created_at >= NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;
