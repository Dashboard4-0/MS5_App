-- Factory Telemetry Schema
-- Migration 005: Add Andon Escalation System

-- Andon Escalations Table
CREATE TABLE IF NOT EXISTS factory_telemetry.andon_escalations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES factory_telemetry.andon_events(id) ON DELETE CASCADE,
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    acknowledgment_timeout_minutes INTEGER NOT NULL DEFAULT 15,
    resolution_timeout_minutes INTEGER NOT NULL DEFAULT 60,
    escalation_recipients TEXT[] NOT NULL DEFAULT '{}',
    escalation_level INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'escalated', 'cancelled', 'resolved')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    escalated_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    escalation_notes TEXT,
    escalated_by UUID REFERENCES factory_telemetry.users(id),
    acknowledged_by UUID REFERENCES factory_telemetry.users(id)
);

-- Andon Escalation History Table
CREATE TABLE IF NOT EXISTS factory_telemetry.andon_escalation_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    escalation_id UUID NOT NULL REFERENCES factory_telemetry.andon_escalations(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('created', 'acknowledged', 'escalated', 'cancelled', 'resolved', 'timeout')),
    performed_by UUID REFERENCES factory_telemetry.users(id),
    performed_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    escalation_level INTEGER,
    recipients_notified TEXT[],
    notification_method TEXT CHECK (notification_method IN ('email', 'sms', 'phone', 'websocket', 'push'))
);

-- Andon Escalation Rules Table
CREATE TABLE IF NOT EXISTS factory_telemetry.andon_escalation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    escalation_level INTEGER NOT NULL,
    delay_minutes INTEGER NOT NULL DEFAULT 0,
    recipients TEXT[] NOT NULL DEFAULT '{}',
    notification_methods TEXT[] NOT NULL DEFAULT '{"email", "websocket"}',
    escalation_message_template TEXT,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Andon Escalation Recipients Table
CREATE TABLE IF NOT EXISTS factory_telemetry.andon_escalation_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    sms_enabled BOOLEAN DEFAULT FALSE,
    email_enabled BOOLEAN DEFAULT TRUE,
    websocket_enabled BOOLEAN DEFAULT TRUE,
    push_enabled BOOLEAN DEFAULT FALSE,
    escalation_levels INTEGER[] DEFAULT '{1,2,3,4}',
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add escalation status to andon_events table
ALTER TABLE factory_telemetry.andon_events 
ADD COLUMN IF NOT EXISTS escalation_level INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS escalation_status TEXT DEFAULT 'none' CHECK (escalation_status IN ('none', 'escalated', 'timeout', 'resolved'));

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_andon_escalations_event_id ON factory_telemetry.andon_escalations (event_id);
CREATE INDEX IF NOT EXISTS idx_andon_escalations_status ON factory_telemetry.andon_escalations (status);
CREATE INDEX IF NOT EXISTS idx_andon_escalations_priority ON factory_telemetry.andon_escalations (priority);
CREATE INDEX IF NOT EXISTS idx_andon_escalations_created_at ON factory_telemetry.andon_escalations (created_at);
CREATE INDEX IF NOT EXISTS idx_andon_escalation_history_escalation_id ON factory_telemetry.andon_escalation_history (escalation_id);
CREATE INDEX IF NOT EXISTS idx_andon_escalation_history_performed_at ON factory_telemetry.andon_escalation_history (performed_at);
CREATE INDEX IF NOT EXISTS idx_andon_escalation_rules_priority ON factory_telemetry.andon_escalation_rules (priority);
CREATE INDEX IF NOT EXISTS idx_andon_escalation_recipients_role ON factory_telemetry.andon_escalation_recipients (role);

-- Insert default escalation rules
INSERT INTO factory_telemetry.andon_escalation_rules (priority, escalation_level, delay_minutes, recipients, notification_methods, escalation_message_template)
VALUES 
    ('low', 1, 0, '{"shift_manager", "engineer"}', '{"email", "websocket"}', 'Low priority Andon event requires attention: {event_description}'),
    ('low', 2, 15, '{"production_manager"}', '{"email", "websocket", "sms"}', 'Escalated: Low priority Andon event still unresolved after 15 minutes: {event_description}'),
    ('medium', 1, 0, '{"shift_manager", "engineer", "production_manager"}', '{"email", "websocket", "sms"}', 'Medium priority Andon event requires immediate attention: {event_description}'),
    ('medium', 2, 10, '{"admin"}', '{"email", "websocket", "sms", "phone"}', 'Escalated: Medium priority Andon event still unresolved after 10 minutes: {event_description}'),
    ('high', 1, 0, '{"shift_manager", "engineer", "production_manager", "admin"}', '{"email", "websocket", "sms", "phone"}', 'HIGH PRIORITY: Andon event requires immediate attention: {event_description}'),
    ('high', 2, 5, '{"all_managers"}', '{"email", "websocket", "sms", "phone"}', 'URGENT ESCALATION: High priority Andon event still unresolved after 5 minutes: {event_description}'),
    ('critical', 1, 0, '{"all_managers", "admin"}', '{"email", "websocket", "sms", "phone"}', 'CRITICAL: Andon event requires IMMEDIATE attention: {event_description}'),
    ('critical', 2, 2, '{"all_managers", "admin"}', '{"email", "websocket", "sms", "phone"}', 'CRITICAL ESCALATION: Andon event still unresolved after 2 minutes: {event_description}')
ON CONFLICT DO NOTHING;

-- Insert default escalation recipients
INSERT INTO factory_telemetry.andon_escalation_recipients (role, name, email, phone, sms_enabled, email_enabled, websocket_enabled, push_enabled, escalation_levels)
VALUES 
    ('shift_manager', 'Shift Manager', 'shift.manager@company.com', '+1234567890', true, true, true, true, '{1,2,3,4}'),
    ('engineer', 'Maintenance Engineer', 'engineer@company.com', '+1234567891', true, true, true, true, '{1,2,3,4}'),
    ('production_manager', 'Production Manager', 'production.manager@company.com', '+1234567892', true, true, true, true, '{2,3,4}'),
    ('admin', 'System Administrator', 'admin@company.com', '+1234567893', true, true, true, true, '{2,3,4}'),
    ('all_managers', 'All Managers', 'managers@company.com', '+1234567894', true, true, true, true, '{3,4}')
ON CONFLICT (role) DO NOTHING;

-- Create view for active escalations
CREATE OR REPLACE VIEW public.v_active_andon_escalations AS
SELECT 
    ae.id as escalation_id,
    ae.event_id,
    ae.priority,
    ae.escalation_level,
    ae.status as escalation_status,
    ae.created_at as escalation_created_at,
    ae.acknowledged_at,
    ae.escalated_at,
    ae.acknowledgment_timeout_minutes,
    ae.resolution_timeout_minutes,
    ae.escalation_recipients,
    ae.escalation_notes,
    ae.acknowledged_by,
    ae.escalated_by,
    ae.event_id,
    ae.line_id,
    ae.equipment_code,
    ae.event_type,
    ae.description as event_description,
    ae.reported_at,
    ae.reported_by,
    u1.username as reported_by_username,
    u2.username as acknowledged_by_username,
    u3.username as escalated_by_username,
    pl.line_code,
    pl.name as line_name,
    -- Calculate time remaining for acknowledgment
    CASE 
        WHEN ae.status = 'active' AND ae.acknowledged_at IS NULL THEN
            GREATEST(0, ae.acknowledgment_timeout_minutes - EXTRACT(EPOCH FROM (NOW() - ae.created_at))/60)
        ELSE NULL
    END as acknowledgment_time_remaining_minutes,
    -- Calculate time remaining for resolution
    CASE 
        WHEN ae.status IN ('active', 'acknowledged') AND ae.resolved_at IS NULL THEN
            GREATEST(0, ae.resolution_timeout_minutes - EXTRACT(EPOCH FROM (NOW() - ae.created_at))/60)
        ELSE NULL
    END as resolution_time_remaining_minutes
FROM factory_telemetry.andon_escalations ae
JOIN factory_telemetry.andon_events ae_events ON ae.event_id = ae_events.id
JOIN factory_telemetry.production_lines pl ON ae_events.line_id = pl.id
LEFT JOIN factory_telemetry.users u1 ON ae_events.reported_by = u1.id
LEFT JOIN factory_telemetry.users u2 ON ae.acknowledged_by = u2.id
LEFT JOIN factory_telemetry.users u3 ON ae.escalated_by = u3.id
WHERE ae.status IN ('active', 'acknowledged', 'escalated')
ORDER BY ae.priority DESC, ae.created_at ASC;

-- Create view for escalation statistics
CREATE OR REPLACE VIEW public.v_andon_escalation_statistics AS
SELECT 
    DATE(ae.created_at) as date,
    ae.priority,
    COUNT(*) as total_escalations,
    COUNT(CASE WHEN ae.status = 'resolved' THEN 1 END) as resolved_escalations,
    COUNT(CASE WHEN ae.status = 'escalated' THEN 1 END) as escalated_escalations,
    COUNT(CASE WHEN ae.status = 'active' THEN 1 END) as active_escalations,
    AVG(CASE 
        WHEN ae.acknowledged_at IS NOT NULL THEN 
            EXTRACT(EPOCH FROM (ae.acknowledged_at - ae.created_at))/60 
        ELSE NULL 
    END) as avg_acknowledgment_time_minutes,
    AVG(CASE 
        WHEN ae.resolved_at IS NOT NULL THEN 
            EXTRACT(EPOCH FROM (ae.resolved_at - ae.created_at))/60 
        ELSE NULL 
    END) as avg_resolution_time_minutes,
    MAX(ae.escalation_level) as max_escalation_level_reached
FROM factory_telemetry.andon_escalations ae
WHERE ae.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(ae.created_at), ae.priority
ORDER BY date DESC, ae.priority;

-- Create function to automatically escalate Andon events
CREATE OR REPLACE FUNCTION factory_telemetry.auto_escalate_andon_events()
RETURNS void AS $$
DECLARE
    escalation_record RECORD;
    next_escalation_level INTEGER;
    escalation_rule RECORD;
    recipients TEXT[];
    notification_methods TEXT[];
BEGIN
    -- Find escalations that need to be escalated
    FOR escalation_record IN
        SELECT 
            ae.id,
            ae.event_id,
            ae.priority,
            ae.escalation_level,
            ae.acknowledgment_timeout_minutes,
            ae.resolution_timeout_minutes,
            ae.created_at,
            ae.acknowledged_at,
            ae.resolved_at,
            ae.status,
            ae_events.description as event_description,
            ae_events.line_id,
            ae_events.equipment_code
        FROM factory_telemetry.andon_escalations ae
        JOIN factory_telemetry.andon_events ae_events ON ae.event_id = ae_events.id
        WHERE ae.status IN ('active', 'acknowledged')
        AND (
            -- Escalate if acknowledgment timeout exceeded
            (ae.acknowledged_at IS NULL AND ae.created_at < NOW() - INTERVAL '1 minute' * ae.acknowledgment_timeout_minutes)
            OR
            -- Escalate if resolution timeout exceeded
            (ae.acknowledged_at IS NOT NULL AND ae.resolved_at IS NULL AND ae.created_at < NOW() - INTERVAL '1 minute' * ae.resolution_timeout_minutes)
        )
    LOOP
        -- Get next escalation level
        next_escalation_level := escalation_record.escalation_level + 1;
        
        -- Get escalation rule for next level
        SELECT * INTO escalation_rule
        FROM factory_telemetry.andon_escalation_rules
        WHERE priority = escalation_record.priority
        AND escalation_level = next_escalation_level
        AND enabled = true
        ORDER BY delay_minutes ASC
        LIMIT 1;
        
        -- If no more escalation rules, mark as escalated
        IF escalation_rule IS NULL THEN
            UPDATE factory_telemetry.andon_escalations
            SET status = 'escalated',
                escalated_at = NOW(),
                escalation_level = next_escalation_level
            WHERE id = escalation_record.id;
            
            -- Log escalation
            INSERT INTO factory_telemetry.andon_escalation_history
            (escalation_id, action, performed_at, notes, escalation_level)
            VALUES
            (escalation_record.id, 'escalated', NOW(), 'Maximum escalation level reached', next_escalation_level);
        ELSE
            -- Update escalation with new level and recipients
            UPDATE factory_telemetry.andon_escalations
            SET escalation_level = next_escalation_level,
                escalation_recipients = escalation_rule.recipients,
                escalated_at = NOW(),
                status = CASE 
                    WHEN escalation_record.status = 'active' THEN 'escalated'
                    ELSE escalation_record.status
                END
            WHERE id = escalation_record.id;
            
            -- Log escalation
            INSERT INTO factory_telemetry.andon_escalation_history
            (escalation_id, action, performed_at, notes, escalation_level, recipients_notified, notification_method)
            VALUES
            (escalation_record.id, 'escalated', NOW(), 
             'Escalated to level ' || next_escalation_level || ' after timeout',
             next_escalation_level, escalation_rule.recipients, 'auto');
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create function to get escalation recipients with contact info
CREATE OR REPLACE FUNCTION factory_telemetry.get_escalation_recipients(recipient_roles TEXT[])
RETURNS TABLE(
    role TEXT,
    name TEXT,
    email TEXT,
    phone TEXT,
    sms_enabled BOOLEAN,
    email_enabled BOOLEAN,
    websocket_enabled BOOLEAN,
    push_enabled BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        aer.role,
        aer.name,
        aer.email,
        aer.phone,
        aer.sms_enabled,
        aer.email_enabled,
        aer.websocket_enabled,
        aer.push_enabled
    FROM factory_telemetry.andon_escalation_recipients aer
    WHERE aer.role = ANY(recipient_roles)
    AND aer.enabled = true;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (comment out for local PostgreSQL, uncomment for Supabase)
-- GRANT USAGE ON SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON ALL TABLES IN SCHEMA factory_telemetry TO anon, authenticated;
-- GRANT SELECT ON public.v_active_andon_escalations, public.v_andon_escalation_statistics TO anon, authenticated;
