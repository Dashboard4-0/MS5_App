# MS5.0 Floor Dashboard - Database Schema Documentation

## Overview

This document describes the complete database schema for the MS5.0 Floor Dashboard application. The schema extends the existing factory telemetry system with comprehensive production management capabilities.

## Schema Structure

The database uses PostgreSQL with TimescaleDB extension for time-series data. All tables are organized within the `factory_telemetry` schema.

## Core Production Management Tables

### 1. Production Lines (`production_lines`)

Defines production lines and their associated equipment.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `line_code` | TEXT | Unique line identifier (e.g., 'L-BAG1') |
| `name` | TEXT | Human-readable line name |
| `description` | TEXT | Optional description |
| `equipment_codes` | TEXT[] | Array of equipment codes on this line |
| `target_speed` | REAL | Target production speed |
| `enabled` | BOOLEAN | Whether line is active |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

### 2. Product Types (`product_types`)

Defines different products that can be manufactured.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `product_code` | TEXT | Unique product identifier |
| `name` | TEXT | Product name |
| `description` | TEXT | Product description |
| `target_speed` | REAL | Target production speed for this product |
| `cycle_time_seconds` | REAL | Expected cycle time per unit |
| `quality_specs` | JSONB | Quality specifications and tolerances |
| `enabled` | BOOLEAN | Whether product is active |
| `created_at` | TIMESTAMPTZ | Creation timestamp |

### 3. Production Schedules (`production_schedules`)

Schedules production runs for specific products on specific lines.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `line_id` | UUID | Reference to production line |
| `product_type_id` | UUID | Reference to product type |
| `scheduled_start` | TIMESTAMPTZ | Planned start time |
| `scheduled_end` | TIMESTAMPTZ | Planned end time |
| `target_quantity` | INTEGER | Target number of units to produce |
| `priority` | INTEGER | Schedule priority (1=highest) |
| `status` | TEXT | Current status (scheduled, in_progress, completed, cancelled, paused) |
| `created_by` | UUID | User who created the schedule |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

### 4. Job Assignments (`job_assignments`)

Assigns production schedules to specific operators.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `schedule_id` | UUID | Reference to production schedule |
| `user_id` | UUID | Reference to assigned user |
| `assigned_at` | TIMESTAMPTZ | When job was assigned |
| `accepted_at` | TIMESTAMPTZ | When operator accepted job |
| `started_at` | TIMESTAMPTZ | When job was started |
| `completed_at` | TIMESTAMPTZ | When job was completed |
| `status` | TEXT | Job status (assigned, accepted, in_progress, completed, cancelled) |
| `notes` | TEXT | Optional notes |

## Quality Management Tables

### 5. Quality Checks (`quality_checks`)

Records quality inspection results.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `line_id` | UUID | Reference to production line |
| `product_type_id` | UUID | Reference to product type |
| `check_time` | TIMESTAMPTZ | When check was performed |
| `check_type` | TEXT | Type of check (incoming, in_process, final, audit) |
| `check_result` | TEXT | Result (pass, fail, conditional) |
| `quantity_checked` | INTEGER | Number of units checked |
| `quantity_passed` | INTEGER | Number of units that passed |
| `quantity_failed` | INTEGER | Number of units that failed |
| `defect_codes` | TEXT[] | Array of defect codes found |
| `notes` | TEXT | Additional notes |
| `checked_by` | UUID | User who performed the check |

### 6. Defect Codes (`defect_codes`)

Standardized defect classification system.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `code` | TEXT | Unique defect code |
| `name` | TEXT | Defect name |
| `description` | TEXT | Detailed description |
| `category` | TEXT | Defect category (dimensional, visual, functional, packaging) |
| `severity` | TEXT | Severity level (minor, major, critical) |
| `enabled` | BOOLEAN | Whether code is active |

## Maintenance Management Tables

### 7. Maintenance Work Orders (`maintenance_work_orders`)

Tracks maintenance work orders.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `work_order_number` | TEXT | Unique work order number |
| `equipment_code` | TEXT | Equipment being maintained |
| `title` | TEXT | Work order title |
| `description` | TEXT | Detailed description |
| `priority` | TEXT | Priority level (low, medium, high, critical) |
| `status` | TEXT | Current status (open, assigned, in_progress, completed, cancelled) |
| `work_type` | TEXT | Type of work (preventive, corrective, predictive, emergency) |
| `scheduled_start` | TIMESTAMPTZ | Planned start time |
| `scheduled_end` | TIMESTAMPTZ | Planned end time |
| `actual_start` | TIMESTAMPTZ | Actual start time |
| `actual_end` | TIMESTAMPTZ | Actual end time |
| `estimated_duration_hours` | REAL | Estimated duration |
| `actual_duration_hours` | REAL | Actual duration |
| `assigned_to` | UUID | User assigned to work order |
| `created_by` | UUID | User who created work order |

### 8. Maintenance Tasks (`maintenance_tasks`)

Individual tasks within work orders.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `work_order_id` | UUID | Reference to work order |
| `task_name` | TEXT | Task name |
| `description` | TEXT | Task description |
| `task_order` | INTEGER | Order of task execution |
| `estimated_duration_minutes` | INTEGER | Estimated duration |
| `actual_duration_minutes` | INTEGER | Actual duration |
| `status` | TEXT | Task status (pending, in_progress, completed, skipped) |
| `completed_by` | UUID | User who completed task |
| `completed_at` | TIMESTAMPTZ | Completion time |
| `notes` | TEXT | Task notes |

## Time-Series Data Tables

### 9. OEE Calculations (`oee_calculations`)

Time-series OEE calculations (TimescaleDB hypertable).

| Column | Type | Description |
|--------|------|-------------|
| `id` | BIGSERIAL | Primary key |
| `line_id` | UUID | Reference to production line |
| `equipment_code` | TEXT | Equipment code |
| `calculation_time` | TIMESTAMPTZ | Time of calculation |
| `availability` | REAL | Availability percentage (0-1) |
| `performance` | REAL | Performance percentage (0-1) |
| `quality` | REAL | Quality percentage (0-1) |
| `oee` | REAL | Overall OEE (0-1) |
| `planned_production_time` | INTEGER | Planned time in seconds |
| `actual_production_time` | INTEGER | Actual time in seconds |
| `ideal_cycle_time` | REAL | Ideal cycle time in seconds |
| `actual_cycle_time` | REAL | Actual cycle time in seconds |
| `good_parts` | INTEGER | Number of good parts |
| `total_parts` | INTEGER | Total parts produced |

### 10. Energy Consumption (`energy_consumption`)

Time-series energy consumption data (TimescaleDB hypertable).

| Column | Type | Description |
|--------|------|-------------|
| `id` | BIGSERIAL | Primary key |
| `equipment_code` | TEXT | Equipment code |
| `consumption_time` | TIMESTAMPTZ | Time of measurement |
| `power_consumption_kw` | REAL | Power consumption in kW |
| `energy_consumption_kwh` | REAL | Energy consumption in kWh |
| `voltage_v` | REAL | Voltage in volts |
| `current_a` | REAL | Current in amperes |
| `power_factor` | REAL | Power factor |
| `temperature_c` | REAL | Temperature in Celsius |
| `humidity_percent` | REAL | Humidity percentage |

## Downtime and Event Management

### 11. Downtime Events (`downtime_events`)

Records machine downtime events.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `line_id` | UUID | Reference to production line |
| `equipment_code` | TEXT | Equipment code |
| `start_time` | TIMESTAMPTZ | Downtime start time |
| `end_time` | TIMESTAMPTZ | Downtime end time |
| `duration_seconds` | INTEGER | Duration in seconds |
| `reason_code` | TEXT | Reason code |
| `reason_description` | TEXT | Detailed reason description |
| `category` | TEXT | Category (planned, unplanned, changeover, maintenance) |
| `subcategory` | TEXT | Subcategory |
| `reported_by` | UUID | User who reported downtime |
| `confirmed_by` | UUID | User who confirmed downtime |
| `confirmed_at` | TIMESTAMPTZ | Confirmation time |
| `notes` | TEXT | Additional notes |

### 12. Andon Events (`andon_events`)

Andon system events and escalations.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `line_id` | UUID | Reference to production line |
| `equipment_code` | TEXT | Equipment code |
| `event_type` | TEXT | Event type (stop, quality, maintenance, material) |
| `priority` | TEXT | Priority level (low, medium, high, critical) |
| `description` | TEXT | Event description |
| `reported_by` | UUID | User who reported event |
| `reported_at` | TIMESTAMPTZ | Report time |
| `acknowledged_by` | UUID | User who acknowledged event |
| `acknowledged_at` | TIMESTAMPTZ | Acknowledgment time |
| `resolved_by` | UUID | User who resolved event |
| `resolved_at` | TIMESTAMPTZ | Resolution time |
| `resolution_notes` | TEXT | Resolution details |
| `status` | TEXT | Event status (open, acknowledged, resolved, escalated) |

## Reporting and Analytics

### 13. Production Reports (`production_reports`)

Generated production reports.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `line_id` | UUID | Reference to production line |
| `report_date` | DATE | Report date |
| `shift` | TEXT | Shift identifier |
| `total_production` | INTEGER | Total units produced |
| `good_parts` | INTEGER | Good parts count |
| `scrap_parts` | INTEGER | Scrap parts count |
| `rework_parts` | INTEGER | Rework parts count |
| `total_downtime_minutes` | INTEGER | Total downtime in minutes |
| `oee_average` | REAL | Average OEE |
| `report_data` | JSONB | Detailed report data |
| `generated_by` | UUID | User who generated report |
| `generated_at` | TIMESTAMPTZ | Generation time |
| `pdf_path` | TEXT | Path to generated PDF |

### 14. Production KPIs (`production_kpis`)

Daily production KPIs (TimescaleDB hypertable).

| Column | Type | Description |
|--------|------|-------------|
| `id` | BIGSERIAL | Primary key |
| `line_id` | UUID | Reference to production line |
| `kpi_date` | DATE | KPI date |
| `shift_id` | UUID | Reference to shift |
| `oee` | REAL | Overall Equipment Effectiveness |
| `availability` | REAL | Availability percentage |
| `performance` | REAL | Performance percentage |
| `quality` | REAL | Quality percentage |
| `total_production` | INTEGER | Total production count |
| `good_parts` | INTEGER | Good parts count |
| `scrap_parts` | INTEGER | Scrap parts count |
| `rework_parts` | INTEGER | Rework parts count |
| `total_downtime_minutes` | INTEGER | Total downtime |
| `planned_downtime_minutes` | INTEGER | Planned downtime |
| `unplanned_downtime_minutes` | INTEGER | Unplanned downtime |
| `changeover_time_minutes` | INTEGER | Changeover time |
| `maintenance_time_minutes` | INTEGER | Maintenance time |
| `energy_consumption_kwh` | REAL | Energy consumption |
| `material_waste_percent` | REAL | Material waste percentage |
| `first_pass_yield` | REAL | First pass yield |

## User Management Extensions

### 15. User Extensions

Extended user information:

| Column | Type | Description |
|--------|------|-------------|
| `first_name` | TEXT | User's first name |
| `last_name` | TEXT | User's last name |
| `employee_id` | TEXT | Employee ID |
| `department` | TEXT | Department |
| `shift` | TEXT | Assigned shift |
| `skills` | TEXT[] | Array of skills |
| `certifications` | TEXT[] | Array of certifications |
| `is_active` | BOOLEAN | Whether user is active |

### 16. Production Shifts (`production_shifts`)

Defines production shifts.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `name` | TEXT | Shift name |
| `start_time` | TIME | Shift start time |
| `end_time` | TIME | Shift end time |
| `description` | TEXT | Shift description |
| `enabled` | BOOLEAN | Whether shift is active |

## Key Views

### 1. Production Dashboard (`v_production_dashboard`)

Comprehensive view of production status including schedules, assignments, and user information.

### 2. Downtime Summary (`v_downtime_summary`)

Summary of downtime events with duration calculations and user information.

### 3. OEE Summary (`v_oee_summary`)

OEE calculations with performance ratings and trend analysis.

### 4. Production Performance (`v_production_performance`)

Daily production performance metrics by line and shift.

### 5. Maintenance Overview (`v_maintenance_overview`)

Maintenance work orders with task completion status.

### 6. Quality Summary (`v_quality_summary`)

Quality check results with pass rates and defect analysis.

## Indexes

The schema includes comprehensive indexing for optimal performance:

- Primary key indexes on all tables
- Foreign key indexes for joins
- Composite indexes for common query patterns
- Time-based indexes for time-series data
- Status and category indexes for filtering

## TimescaleDB Hypertables

The following tables are configured as TimescaleDB hypertables for efficient time-series data storage:

- `oee_calculations` - Partitioned by `calculation_time`
- `energy_consumption` - Partitioned by `consumption_time`
- `production_kpis` - Partitioned by `created_at`

## Data Relationships

### Core Relationships

1. **Production Lines** → **Equipment** (one-to-many via equipment_codes array)
2. **Production Schedules** → **Production Lines** (many-to-one)
3. **Production Schedules** → **Product Types** (many-to-one)
4. **Job Assignments** → **Production Schedules** (many-to-one)
5. **Job Assignments** → **Users** (many-to-one)

### Quality Relationships

1. **Quality Checks** → **Production Lines** (many-to-one)
2. **Quality Checks** → **Product Types** (many-to-one)
3. **Quality Checks** → **Defect Codes** (many-to-many via defect_codes array)

### Maintenance Relationships

1. **Maintenance Work Orders** → **Equipment** (many-to-one via equipment_code)
2. **Maintenance Tasks** → **Maintenance Work Orders** (many-to-one)

### Time-Series Relationships

1. **OEE Calculations** → **Production Lines** (many-to-one)
2. **Energy Consumption** → **Equipment** (many-to-one via equipment_code)
3. **Production KPIs** → **Production Lines** (many-to-one)
4. **Production KPIs** → **Production Shifts** (many-to-one)

## Security and Permissions

The schema is designed with row-level security (RLS) in mind:

- All tables include user references for audit trails
- Sensitive data is properly encrypted
- Access control is implemented at the application level
- Views provide controlled access to aggregated data

## Performance Considerations

1. **Partitioning**: Time-series tables are partitioned by time for efficient queries
2. **Indexing**: Comprehensive indexing strategy for common query patterns
3. **Archiving**: Old time-series data can be easily archived or compressed
4. **Caching**: Frequently accessed data is cached at the application level
5. **Materialized Views**: Complex aggregations can be materialized for performance

## Migration Strategy

The schema is designed for incremental migration:

1. **Migration 001**: Core telemetry tables (existing)
2. **Migration 002**: PLC and equipment management (existing)
3. **Migration 003**: Production management tables
4. **Migration 004**: Advanced production features

Each migration is backward compatible and can be rolled back if needed.
