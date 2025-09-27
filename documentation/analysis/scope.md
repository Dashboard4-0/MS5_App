I'll analyze the MS5.0 system requirements and create a comprehensive plan for the Floor dashboard app. Let me first examine the existing codebase and system architecture to understand the full scope.


[3 tools called]

Now let me examine the fault catalog and transforms to understand the data processing:


[2 tools called]

Now let me create a comprehensive plan for the MS5.0 Floor dashboard app. Based on my analysis of the system architecture, existing codebase, and requirements, here's the detailed plan:


[1 tool called]

# MS5.0 Floor Dashboard App - Comprehensive Development Plan

## Executive Summary

This plan outlines the development of a world-class factory management dashboard app for MS5.0 Floor, optimized for tablet use (Android/iOS) with role-based access control. The app will integrate with the existing PLC telemetry system and provide comprehensive production management capabilities aligned with IWS (Integrated Work Systems) principles.

## 1. System Architecture Overview

### 1.1 Technology Stack
- **Frontend**: React Native (cross-platform tablet optimization)
- **Backend**: FastAPI (Python) with PostgreSQL database
- **Real-time Communication**: WebSocket for live updates
- **Authentication**: JWT with role-based access control
- **File Generation**: ReportLab for PDF generation
- **Database**: PostgreSQL with TimescaleDB for time-series data

### 1.2 System Components
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React Native  │    │   FastAPI       │    │   PostgreSQL    │
│   Frontend      │◄──►│   Backend       │◄──►│   Database      │
│   (Tablet App)  │    │   (Edge Device) │    │   (Edge Device) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   WebSocket     │    │   PLC Tag       │    │   TimescaleDB   │
│   Real-time     │    │   Scanner       │    │   Time-series   │
│   Updates       │    │   (Existing)    │    │   Data          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 2. Database Schema Extensions

### 2.1 Production Management Tables

```sql
-- Production Lines
CREATE TABLE factory_telemetry.production_lines (
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
CREATE TABLE factory_telemetry.product_types (
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
CREATE TABLE factory_telemetry.production_schedules (
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
CREATE TABLE factory_telemetry.job_assignments (
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
CREATE TABLE factory_telemetry.checklist_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    equipment_codes TEXT[] NOT NULL,
    checklist_items JSONB NOT NULL, -- Array of {item, required, type}
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Checklist Completions
CREATE TABLE factory_telemetry.checklist_completions (
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
CREATE TABLE factory_telemetry.downtime_events (
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
CREATE TABLE factory_telemetry.oee_calculations (
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
CREATE TABLE factory_telemetry.production_reports (
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
CREATE TABLE factory_telemetry.andon_events (
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
```

### 2.2 User Role Extensions

```sql
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

-- User Roles (extend existing role field)
-- 'admin', 'production_manager', 'shift_manager', 'engineer', 'operator', 'maintenance', 'quality', 'viewer'
```

## 3. Backend API Architecture

### 3.1 Core Services Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── auth/
│   │   ├── __init__.py
│   │   ├── jwt_handler.py
│   │   ├── role_manager.py
│   │   └── permissions.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── production.py
│   │   ├── user.py
│   │   └── oee.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── production_service.py
│   │   ├── oee_calculator.py
│   │   ├── downtime_tracker.py
│   │   ├── andon_service.py
│   │   └── report_generator.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py
│   │   │   ├── production.py
│   │   │   ├── jobs.py
│   │   │   ├── oee.py
│   │   │   ├── andon.py
│   │   │   └── reports.py
│   │   └── websocket.py
│   └── utils/
│       ├── __init__.py
│       ├── calculations.py
│       ├── validators.py
│       └── pdf_generator.py
├── requirements.txt
└── Dockerfile
```

### 3.2 Key API Endpoints

#### Authentication & User Management
```python
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/users/profile
PUT  /api/v1/users/profile
GET  /api/v1/users/roles
```

#### Production Management
```python
# Production Lines
GET    /api/v1/production/lines
POST   /api/v1/production/lines
GET    /api/v1/production/lines/{line_id}
PUT    /api/v1/production/lines/{line_id}
DELETE /api/v1/production/lines/{line_id}

# Production Schedules
GET    /api/v1/production/schedules
POST   /api/v1/production/schedules
GET    /api/v1/production/schedules/{schedule_id}
PUT    /api/v1/production/schedules/{schedule_id}
DELETE /api/v1/production/schedules/{schedule_id}

# Job Assignments
GET    /api/v1/jobs/my-jobs
GET    /api/v1/jobs/{job_id}
POST   /api/v1/jobs/{job_id}/accept
POST   /api/v1/jobs/{job_id}/start
POST   /api/v1/jobs/{job_id}/complete
POST   /api/v1/jobs/{job_id}/cancel

# Checklists
GET    /api/v1/checklists/templates
POST   /api/v1/checklists/complete
GET    /api/v1/checklists/{completion_id}
```

#### Real-time Dashboard
```python
# Line Dashboard
GET /api/v1/dashboard/lines
GET /api/v1/dashboard/lines/{line_id}
GET /api/v1/dashboard/lines/{line_id}/status
GET /api/v1/dashboard/lines/{line_id}/oee
GET /api/v1/dashboard/lines/{line_id}/downtime

# Equipment Status
GET /api/v1/equipment/status
GET /api/v1/equipment/{equipment_code}/status
GET /api/v1/equipment/{equipment_code}/faults
```

#### OEE & Analytics
```python
# OEE Calculations
GET /api/v1/oee/lines/{line_id}
GET /api/v1/oee/equipment/{equipment_code}
POST /api/v1/oee/calculate

# Downtime Management
GET  /api/v1/downtime/events
POST /api/v1/downtime/events
PUT  /api/v1/downtime/events/{event_id}
GET  /api/v1/downtime/reasons
POST /api/v1/downtime/reasons
```

#### Andon System
```python
# Andon Events
GET  /api/v1/andon/events
POST /api/v1/andon/events
PUT  /api/v1/andon/events/{event_id}/acknowledge
PUT  /api/v1/andon/events/{event_id}/resolve
GET  /api/v1/andon/escalation-tree
```

#### Reports
```python
# Production Reports
GET  /api/v1/reports/production
POST /api/v1/reports/production/generate
GET  /api/v1/reports/production/{report_id}
GET  /api/v1/reports/production/{report_id}/pdf

# Custom Reports
POST /api/v1/reports/custom
GET  /api/v1/reports/templates
```

### 3.3 WebSocket Events

```python
# Real-time Events
{
    "type": "line_status_update",
    "data": {
        "line_id": "uuid",
        "status": "running|stopped|fault",
        "oee": 0.85,
        "availability": 0.92,
        "performance": 0.95,
        "quality": 0.95
    }
}

{
    "type": "downtime_event",
    "data": {
        "line_id": "uuid",
        "equipment_code": "BP01.PACK.BAG1",
        "reason": "Mechanical Fault",
        "start_time": "2025-01-20T10:30:00Z",
        "duration_minutes": 15
    }
}

{
    "type": "andon_alert",
    "data": {
        "line_id": "uuid",
        "priority": "high",
        "message": "Machine stopped - requires immediate attention",
        "escalation_level": 2
    }
}
```

## 4. Frontend Architecture (React Native)

### 4.1 Project Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── common/
│   │   │   ├── Button.js
│   │   │   ├── Card.js
│   │   │   ├── Input.js
│   │   │   ├── Modal.js
│   │   │   ├── LoadingSpinner.js
│   │   │   └── StatusIndicator.js
│   │   ├── dashboard/
│   │   │   ├── LineDashboard.js
│   │   │   ├── OEEGauge.js
│   │   │   ├── DowntimeChart.js
│   │   │   └── EquipmentStatus.js
│   │   ├── jobs/
│   │   │   ├── JobCard.js
│   │   │   ├── JobList.js
│   │   │   ├── JobDetails.js
│   │   │   └── JobStatusFilter.js
│   │   ├── checklist/
│   │   │   ├── ChecklistItem.js
│   │   │   ├── ChecklistForm.js
│   │   │   └── SignaturePad.js
│   │   └── andon/
│   │       ├── AndonButton.js
│   │       ├── AndonModal.js
│   │       └── EscalationTree.js
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── LoginScreen.js
│   │   │   └── ProfileScreen.js
│   │   ├── operator/
│   │   │   ├── MyJobsScreen.js
│   │   │   ├── LineDashboardScreen.js
│   │   │   ├── ChecklistScreen.js
│   │   │   └── JobCountdownScreen.js
│   │   ├── manager/
│   │   │   ├── ProductionOverviewScreen.js
│   │   │   ├── ScheduleManagementScreen.js
│   │   │   ├── TeamManagementScreen.js
│   │   │   └── ReportsScreen.js
│   │   ├── engineer/
│   │   │   ├── EquipmentStatusScreen.js
│   │   │   ├── FaultAnalysisScreen.js
│   │   │   ├── MaintenanceScreen.js
│   │   │   └── DiagnosticsScreen.js
│   │   └── shared/
│   │       ├── DashboardScreen.js
│   │       ├── AndonScreen.js
│   │       └── ReportsScreen.js
│   ├── navigation/
│   │   ├── AppNavigator.js
│   │   ├── AuthNavigator.js
│   │   ├── OperatorNavigator.js
│   │   ├── ManagerNavigator.js
│   │   └── EngineerNavigator.js
│   ├── services/
│   │   ├── api.js
│   │   ├── auth.js
│   │   ├── websocket.js
│   │   ├── storage.js
│   │   └── notifications.js
│   ├── store/
│   │   ├── index.js
│   │   ├── authSlice.js
│   │   ├── productionSlice.js
│   │   ├── jobsSlice.js
│   │   └── dashboardSlice.js
│   ├── utils/
│   │   ├── constants.js
│   │   ├── helpers.js
│   │   ├── validators.js
│   │   └── formatters.js
│   └── styles/
│       ├── colors.js
│       ├── typography.js
│       ├── spacing.js
│       └── components.js
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
├── android/
├── ios/
├── package.json
└── metro.config.js
```

### 4.2 Key Screen Designs

#### Operator Flow
1. **Login Screen** - Username/password with role detection
2. **My Jobs Screen** - Tabbed list view (Running, Pending, Completed)
3. **Job Details Screen** - Job information with accept/start buttons
4. **Checklist Screen** - Pre-start checklist with signature
5. **Line Dashboard Screen** - Real-time OEE, status, downtime
6. **Job Countdown Screen** - Timer for scheduled jobs

#### Manager Flow
1. **Production Overview** - Multi-line dashboard
2. **Schedule Management** - Create/edit production schedules
3. **Team Management** - Assign jobs to operators
4. **Reports Screen** - Generate and view reports

#### Engineer Flow
1. **Equipment Status** - All equipment status overview
2. **Fault Analysis** - Detailed fault investigation
3. **Maintenance** - Maintenance scheduling and tracking
4. **Diagnostics** - Real-time diagnostic tools

## 5. Core Business Logic Implementation

### 5.1 OEE Calculation Engine

```python
class OEECalculator:
    def calculate_oee(self, line_id: str, time_period: timedelta) -> Dict:
        """
        Calculate OEE for a production line over specified time period.
        OEE = Availability × Performance × Quality
        """
        # Get production data
        production_data = self.get_production_data(line_id, time_period)
        
        # Calculate Availability
        availability = self.calculate_availability(production_data)
        
        # Calculate Performance
        performance = self.calculate_performance(production_data)
        
        # Calculate Quality
        quality = self.calculate_quality(production_data)
        
        # Calculate OEE
        oee = availability * performance * quality
        
        return {
            "availability": availability,
            "performance": performance,
            "quality": quality,
            "oee": oee,
            "period": time_period,
            "calculated_at": datetime.utcnow()
        }
    
    def calculate_availability(self, data: Dict) -> float:
        """Availability = (Operating Time / Planned Production Time) × 100"""
        planned_time = data["planned_production_time"]
        operating_time = data["actual_production_time"]
        
        if planned_time == 0:
            return 0.0
        
        return min(1.0, operating_time / planned_time)
    
    def calculate_performance(self, data: Dict) -> float:
        """Performance = (Actual Output / Target Output) × 100"""
        target_output = data["target_output"]
        actual_output = data["actual_output"]
        
        if target_output == 0:
            return 0.0
        
        return min(1.0, actual_output / target_output)
    
    def calculate_quality(self, data: Dict) -> float:
        """Quality = (Good Parts / Total Parts) × 100"""
        total_parts = data["total_parts"]
        good_parts = data["good_parts"]
        
        if total_parts == 0:
            return 0.0
        
        return good_parts / total_parts
```

### 5.2 Downtime Tracking System

```python
class DowntimeTracker:
    def __init__(self):
        self.active_events = {}
        self.fault_catalog = self.load_fault_catalog()
    
    def detect_downtime_event(self, equipment_code: str, current_status: Dict) -> Optional[Dict]:
        """Detect and categorize downtime events based on PLC data"""
        if current_status["running"]:
            # Machine is running, check if we need to close an event
            if equipment_code in self.active_events:
                return self.close_downtime_event(equipment_code)
            return None
        
        # Machine is stopped, determine reason
        reason = self.determine_downtime_reason(equipment_code, current_status)
        
        if equipment_code not in self.active_events:
            # Start new downtime event
            return self.start_downtime_event(equipment_code, reason)
        
        return None
    
    def determine_downtime_reason(self, equipment_code: str, status: Dict) -> str:
        """Determine downtime reason from PLC fault data"""
        fault_bits = status.get("fault_bits", [])
        
        # Check for active faults
        for i, bit_active in enumerate(fault_bits):
            if bit_active:
                fault_info = self.fault_catalog.get(equipment_code, {}).get(i, {})
                if fault_info:
                    return fault_info["name"]
        
        # Check for planned stops
        if status.get("planned_stop", False):
            return "Planned Stop"
        
        # Check for speed-based stops
        if status.get("speed", 0) == 0:
            return "Speed Loss"
        
        return "Unknown Reason"
```

### 5.3 Andon Escalation System

```python
class AndonService:
    def __init__(self):
        self.escalation_tree = self.load_escalation_tree()
        self.active_alerts = {}
    
    def create_andon_event(self, line_id: str, equipment_code: str, 
                          event_type: str, priority: str, description: str) -> Dict:
        """Create new Andon event with automatic escalation"""
        event = {
            "id": str(uuid.uuid4()),
            "line_id": line_id,
            "equipment_code": equipment_code,
            "event_type": event_type,
            "priority": priority,
            "description": description,
            "status": "open",
            "created_at": datetime.utcnow(),
            "escalation_level": 0
        }
        
        # Store event
        self.store_andon_event(event)
        
        # Start escalation process
        self.start_escalation(event)
        
        # Send real-time notification
        self.send_websocket_notification(event)
        
        return event
    
    def start_escalation(self, event: Dict):
        """Start escalation process based on priority and time"""
        escalation_rules = self.escalation_tree.get(event["priority"], {})
        
        # Schedule escalation timers
        for level, rule in escalation_rules.items():
            delay = rule["delay_minutes"]
            recipients = rule["recipients"]
            
            # Schedule escalation
            self.schedule_escalation(event, level, delay, recipients)
```

## 6. User Role-Based Navigation

### 6.1 Role Definitions

```javascript
const USER_ROLES = {
  OPERATOR: {
    name: 'operator',
    permissions: [
      'view_my_jobs',
      'accept_jobs',
      'start_jobs',
      'complete_jobs',
      'view_line_dashboard',
      'complete_checklists',
      'report_downtime',
      'create_andon_events'
    ],
    navigation: [
      'MyJobs',
      'LineDashboard',
      'Checklist',
      'Andon'
    ]
  },
  SHIFT_MANAGER: {
    name: 'shift_manager',
    permissions: [
      'view_all_jobs',
      'assign_jobs',
      'view_production_overview',
      'manage_schedules',
      'view_reports',
      'acknowledge_andon_events',
      'manage_team'
    ],
    navigation: [
      'ProductionOverview',
      'ScheduleManagement',
      'TeamManagement',
      'Reports',
      'AndonManagement'
    ]
  },
  ENGINEER: {
    name: 'engineer',
    permissions: [
      'view_equipment_status',
      'analyze_faults',
      'manage_maintenance',
      'view_diagnostics',
      'resolve_andon_events',
      'configure_equipment'
    ],
    navigation: [
      'EquipmentStatus',
      'FaultAnalysis',
      'Maintenance',
      'Diagnostics',
      'AndonResolution'
    ]
  },
  PRODUCTION_MANAGER: {
    name: 'production_manager',
    permissions: [
      'view_all_data',
      'manage_production',
      'view_analytics',
      'generate_reports',
      'configure_system',
      'manage_users'
    ],
    navigation: [
      'ProductionOverview',
      'Analytics',
      'Reports',
      'SystemConfiguration',
      'UserManagement'
    ]
  }
};
```

### 6.2 Navigation Flow

```javascript
const AppNavigator = () => {
  const { user, isAuthenticated } = useSelector(state => state.auth);
  
  if (!isAuthenticated) {
    return <AuthNavigator />;
  }
  
  // Route based on user role
  switch (user.role) {
    case 'operator':
      return <OperatorNavigator />;
    case 'shift_manager':
      return <ManagerNavigator />;
    case 'engineer':
      return <EngineerNavigator />;
    case 'production_manager':
      return <ProductionManagerNavigator />;
    default:
      return <AuthNavigator />;
  }
};
```

## 7. Production Workflow Implementation

### 7.1 Job Assignment Flow

```python
class JobAssignmentService:
    def assign_job_to_operator(self, schedule_id: str, user_id: str) -> Dict:
        """Assign a production job to an operator"""
        # Get schedule details
        schedule = self.get_production_schedule(schedule_id)
        
        # Create job assignment
        assignment = {
            "id": str(uuid.uuid4()),
            "schedule_id": schedule_id,
            "user_id": user_id,
            "status": "assigned",
            "assigned_at": datetime.utcnow(),
            "line_id": schedule["line_id"],
            "product_type_id": schedule["product_type_id"],
            "target_quantity": schedule["target_quantity"],
            "scheduled_start": schedule["scheduled_start"]
        }
        
        # Store assignment
        self.store_job_assignment(assignment)
        
        # Send notification to operator
        self.send_job_notification(user_id, assignment)
        
        return assignment
    
    def accept_job(self, assignment_id: str, user_id: str) -> Dict:
        """Operator accepts a job assignment"""
        assignment = self.get_job_assignment(assignment_id)
        
        if assignment["user_id"] != user_id:
            raise PermissionError("User not authorized for this job")
        
        if assignment["status"] != "assigned":
            raise ValueError("Job cannot be accepted in current status")
        
        # Update assignment status
        assignment["status"] = "accepted"
        assignment["accepted_at"] = datetime.utcnow()
        
        self.update_job_assignment(assignment)
        
        return assignment
```

### 7.2 Pre-start Checklist System

```python
class ChecklistService:
    def get_checklist_template(self, equipment_codes: List[str]) -> Dict:
        """Get appropriate checklist template for equipment"""
        # Find template that matches equipment
        template = self.find_matching_template(equipment_codes)
        
        if not template:
            # Generate default template
            template = self.generate_default_template(equipment_codes)
        
        return template
    
    def complete_checklist(self, assignment_id: str, responses: Dict, 
                          signature_data: Dict) -> Dict:
        """Complete pre-start checklist"""
        assignment = self.get_job_assignment(assignment_id)
        
        # Validate all required items are completed
        template = self.get_checklist_template(assignment["equipment_codes"])
        self.validate_checklist_responses(template, responses)
        
        # Create completion record
        completion = {
            "id": str(uuid.uuid4()),
            "job_assignment_id": assignment_id,
            "template_id": template["id"],
            "completed_by": assignment["user_id"],
            "completed_at": datetime.utcnow(),
            "responses": responses,
            "signature_data": signature_data,
            "status": "completed"
        }
        
        self.store_checklist_completion(completion)
        
        # Update job status
        assignment["status"] = "ready_to_start"
        self.update_job_assignment(assignment)
        
        return completion
```

## 8. Real-time Dashboard Features

### 8.1 Line Dashboard Components

```javascript
const LineDashboard = ({ lineId }) => {
  const [dashboardData, setDashboardData] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  
  useEffect(() => {
    // Connect to WebSocket for real-time updates
    const ws = new WebSocket(`ws://${API_BASE_URL}/ws?line_id=${lineId}`);
    
    ws.onopen = () => setIsConnected(true);
    ws.onclose = () => setIsConnected(false);
    
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'line_status_update') {
        setDashboardData(data.data);
      }
    };
    
    return () => ws.close();
  }, [lineId]);
  
  if (!dashboardData) {
    return <LoadingSpinner />;
  }
  
  return (
    <ScrollView style={styles.container}>
      <StatusIndicator 
        status={dashboardData.status}
        isConnected={isConnected}
      />
      
      <OEEGauge 
        oee={dashboardData.oee}
        availability={dashboardData.availability}
        performance={dashboardData.performance}
        quality={dashboardData.quality}
      />
      
      <DowntimeChart 
        data={dashboardData.downtime_history}
        topReasons={dashboardData.top_downtime_reasons}
      />
      
      <EquipmentStatus 
        equipment={dashboardData.equipment}
      />
      
      <AndonButton 
        lineId={lineId}
        onPress={handleAndonPress}
      />
    </ScrollView>
  );
};
```

### 8.2 OEE Visualization

```javascript
const OEEGauge = ({ oee, availability, performance, quality }) => {
  const getOEEColor = (value) => {
    if (value >= 0.85) return '#4CAF50'; // Green
    if (value >= 0.70) return '#FF9800'; // Orange
    return '#F44336'; // Red
  };
  
  return (
    <View style={styles.oeeContainer}>
      <Text style={styles.oeeTitle}>Overall Equipment Effectiveness</Text>
      
      <View style={styles.gaugeContainer}>
        <CircularProgress
          value={oee}
          size={200}
          width={20}
          color={getOEEColor(oee)}
          backgroundColor="#E0E0E0"
        />
        <Text style={styles.oeeValue}>{Math.round(oee * 100)}%</Text>
      </View>
      
      <View style={styles.metricsRow}>
        <MetricCard 
          label="Availability"
          value={Math.round(availability * 100)}
          color="#2196F3"
        />
        <MetricCard 
          label="Performance"
          value={Math.round(performance * 100)}
          color="#9C27B0"
        />
        <MetricCard 
          label="Quality"
          value={Math.round(quality * 100)}
          color="#FF5722"
        />
      </View>
    </View>
  );
};
```

## 9. Andon System Implementation

### 9.1 Andon Button Component

```javascript
const AndonButton = ({ lineId, onPress }) => {
  const [isPressed, setIsPressed] = useState(false);
  
  const handlePress = () => {
    setIsPressed(true);
    
    // Show Andon modal
    onPress();
    
    // Reset button after delay
    setTimeout(() => setIsPressed(false), 2000);
  };
  
  return (
    <TouchableOpacity
      style={[
        styles.andonButton,
        isPressed && styles.andonButtonPressed
      ]}
      onPress={handlePress}
    >
      <Text style={styles.andonButtonText}>START ANDON</Text>
    </TouchableOpacity>
  );
};
```

### 9.2 Andon Modal

```javascript
const AndonModal = ({ visible, onClose, onSubmit }) => {
  const [eventType, setEventType] = useState('');
  const [priority, setPriority] = useState('');
  const [description, setDescription] = useState('');
  
  const handleSubmit = () => {
    if (!eventType || !priority || !description) {
      Alert.alert('Error', 'Please fill in all fields');
      return;
    }
    
    onSubmit({
      eventType,
      priority,
      description
    });
    
    onClose();
  };
  
  return (
    <Modal visible={visible} animationType="slide">
      <View style={styles.modalContainer}>
        <Text style={styles.modalTitle}>Create Andon Event</Text>
        
        <Picker
          selectedValue={eventType}
          onValueChange={setEventType}
          style={styles.picker}
        >
          <Picker.Item label="Select Event Type" value="" />
          <Picker.Item label="Stop" value="stop" />
          <Picker.Item label="Quality" value="quality" />
          <Picker.Item label="Maintenance" value="maintenance" />
          <Picker.Item label="Material" value="material" />
        </Picker>
        
        <Picker
          selectedValue={priority}
          onValueChange={setPriority}
          style={styles.picker}
        >
          <Picker.Item label="Select Priority" value="" />
          <Picker.Item label="Low" value="low" />
          <Picker.Item label="Medium" value="medium" />
          <Picker.Item label="High" value="high" />
          <Picker.Item label="Critical" value="critical" />
        </Picker>
        
        <TextInput
          style={styles.textInput}
          placeholder="Description"
          value={description}
          onChangeText={setDescription}
          multiline
        />
        
        <View style={styles.buttonRow}>
          <Button title="Cancel" onPress={onClose} />
          <Button title="Submit" onPress={handleSubmit} />
        </View>
      </View>
    </Modal>
  );
};
```

## 10. Report Generation System

### 10.1 PDF Report Generator

```python
class ReportGenerator:
    def __init__(self):
        self.template_engine = self.setup_template_engine()
    
    def generate_production_report(self, line_id: str, report_date: date, 
                                 shift: str = None) -> str:
        """Generate production report PDF"""
        # Get production data
        data = self.get_production_data(line_id, report_date, shift)
        
        # Create PDF document
        doc = SimpleDocTemplate(f"reports/production_{line_id}_{report_date}.pdf")
        story = []
        
        # Add header
        story.append(self.create_report_header(line_id, report_date, shift))
        
        # Add summary section
        story.append(self.create_summary_section(data))
        
        # Add OEE section
        story.append(self.create_oee_section(data))
        
        # Add downtime section
        story.append(self.create_downtime_section(data))
        
        # Add production details
        story.append(self.create_production_details(data))
        
        # Build PDF
        doc.build(story)
        
        return f"reports/production_{line_id}_{report_date}.pdf"
    
    def create_oee_section(self, data: Dict) -> List:
        """Create OEE section for report"""
        elements = []
        
        # OEE title
        elements.append(Paragraph("Overall Equipment Effectiveness", 
                                 styles['Heading2']))
        
        # OEE table
        oee_data = [
            ['Metric', 'Value', 'Target', 'Status'],
            ['Availability', f"{data['oee']['availability']:.1%}", 
             f"{data['oee']['target_availability']:.1%}", 
             self.get_status_indicator(data['oee']['availability'], 
                                     data['oee']['target_availability'])],
            ['Performance', f"{data['oee']['performance']:.1%}", 
             f"{data['oee']['target_performance']:.1%}", 
             self.get_status_indicator(data['oee']['performance'], 
                                     data['oee']['target_performance'])],
            ['Quality', f"{data['oee']['quality']:.1%}", 
             f"{data['oee']['target_quality']:.1%}", 
             self.get_status_indicator(data['oee']['quality'], 
                                     data['oee']['target_quality'])],
            ['OEE', f"{data['oee']['oee']:.1%}", 
             f"{data['oee']['target_oee']:.1%}", 
             self.get_status_indicator(data['oee']['oee'], 
                                     data['oee']['target_oee'])]
        ]
        
        table = Table(oee_data, colWidths=[2*inch, 1*inch, 1*inch, 1*inch])
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 14),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ]))
        
        elements.append(table)
        elements.append(Spacer(1, 12))
        
        return elements
```

## 11. Integration with Existing PLC System

### 11.1 PLC Data Integration

```python
class PLCDataIntegrator:
    def __init__(self):
        self.tag_scanner = self.initialize_tag_scanner()
        self.metric_transformer = MetricTransformer()
    
    def process_plc_data(self, equipment_code: str, raw_data: Dict) -> Dict:
        """Process raw PLC data and update production metrics"""
        # Transform raw data to canonical metrics
        metrics = self.metric_transformer.transform_metrics(equipment_code, raw_data)
        
        # Update database
        self.update_metric_latest(equipment_code, metrics)
        
        # Store historical data
        self.store_metric_history(equipment_code, metrics)
        
        # Update production status
        self.update_production_status(equipment_code, metrics)
        
        # Check for downtime events
        self.check_downtime_events(equipment_code, metrics)
        
        return metrics
    
    def update_production_status(self, equipment_code: str, metrics: Dict):
        """Update production line status based on equipment metrics"""
        line_id = self.get_line_for_equipment(equipment_code)
        
        if not line_id:
            return
        
        # Calculate line-level metrics
        line_metrics = self.calculate_line_metrics(line_id, equipment_code, metrics)
        
        # Update line status
        self.update_line_status(line_id, line_metrics)
        
        # Send WebSocket update
        self.send_line_update(line_id, line_metrics)
```

### 11.2 Fault Detection and Categorization

```python
class FaultDetectionService:
    def __init__(self):
        self.fault_catalog = self.load_fault_catalog()
        self.fault_history = {}
    
    def detect_faults(self, equipment_code: str, fault_bits: List[bool]) -> List[Dict]:
        """Detect and categorize faults from PLC fault bits"""
        active_faults = []
        
        for i, bit_active in enumerate(fault_bits):
            if bit_active:
                fault_info = self.fault_catalog.get(equipment_code, {}).get(i, {})
                
                fault = {
                    "equipment_code": equipment_code,
                    "bit_index": i,
                    "name": fault_info.get("name", f"Fault {i}"),
                    "description": fault_info.get("description", "Unknown fault"),
                    "marker": fault_info.get("marker", "INTERNAL"),
                    "timestamp": datetime.utcnow(),
                    "is_active": True
                }
                
                active_faults.append(fault)
                
                # Log fault event
                self.log_fault_event(fault)
        
        return active_faults
    
    def determine_downtime_reason(self, equipment_code: str, 
                                 active_faults: List[Dict]) -> str:
        """Determine primary downtime reason from active faults"""
        if not active_faults:
            return "Unknown Reason"
        
        # Prioritize faults by marker
        internal_faults = [f for f in active_faults if f["marker"] == "INTERNAL"]
        upstream_faults = [f for f in active_faults if f["marker"] == "UPSTREAM"]
        downstream_faults = [f for f in active_faults if f["marker"] == "DOWNSTREAM"]
        
        # Return highest priority fault
        if internal_faults:
            return internal_faults[0]["name"]
        elif upstream_faults:
            return f"Upstream: {upstream_faults[0]['name']}"
        elif downstream_faults:
            return f"Downstream: {downstream_faults[0]['name']}"
        
        return active_faults[0]["name"]
```

## 12. Additional World-Class Features

### 12.1 Predictive Maintenance Integration

```python
class PredictiveMaintenanceService:
    def __init__(self):
        self.ml_models = self.load_ml_models()
        self.anomaly_detector = AnomalyDetector()
    
    def analyze_equipment_health(self, equipment_code: str, 
                                metrics: Dict) -> Dict:
        """Analyze equipment health using ML models"""
        # Extract features from metrics
        features = self.extract_features(metrics)
        
        # Run anomaly detection
        anomaly_score = self.anomaly_detector.predict(features)
        
        # Predict remaining useful life
        rul_prediction = self.ml_models["rul"].predict(features)
        
        # Generate maintenance recommendations
        recommendations = self.generate_recommendations(
            equipment_code, anom