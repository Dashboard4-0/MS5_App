# MS5.0 Floor Dashboard - Comprehensive Implementation Plan

## Executive Summary

This document provides a detailed 10-phase implementation plan to resolve all critical issues identified in the code analysis and deliver a fully functional MS5.0 Floor Dashboard system. The plan addresses database schema issues, API implementation gaps, frontend missing components, PLC integration problems, and system-wide functionality.

## Critical Issues Summary

Based on Analysis1.md, the following critical issues must be resolved:

1. **Database Schema Issues**: Missing users table, equipment_config table, inconsistent column references
2. **API Implementation Issues**: Missing permission constants, incomplete service methods
3. **Frontend Implementation Issues**: Missing Redux store, API service layer, components
4. **PLC Integration Issues**: Import path problems, async/await mismatches
5. **OEE Calculation Issues**: Missing database dependencies, incomplete methods
6. **Andon System Issues**: Missing service dependencies, incomplete notifications
7. **WebSocket Implementation Issues**: Missing event types, incomplete real-time functionality

## Implementation Phases

---

## Phase 1: Database Schema Foundation (Weeks 1-2)
**Priority: CRITICAL - Blocks everything**

### 1.1 Create Missing Core Tables

#### Add Users Table
```sql
-- Add to 001_init_telemetry.sql
CREATE TABLE factory_telemetry.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'production_manager', 'shift_manager', 'engineer', 'operator', 'maintenance', 'quality', 'viewer')),
    first_name TEXT,
    last_name TEXT,
    employee_id TEXT UNIQUE,
    department TEXT,
    shift TEXT,
    skills TEXT[],
    certifications TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_users_username ON factory_telemetry.users(username);
CREATE INDEX idx_users_email ON factory_telemetry.users(email);
CREATE INDEX idx_users_role ON factory_telemetry.users(role);
CREATE INDEX idx_users_employee_id ON factory_telemetry.users(employee_id);
```

#### Add Equipment Configuration Table
```sql
-- Add to 001_init_telemetry.sql
CREATE TABLE factory_telemetry.equipment_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_code TEXT UNIQUE NOT NULL,
    equipment_name TEXT NOT NULL,
    equipment_type TEXT NOT NULL,
    production_line_id UUID REFERENCES factory_telemetry.production_lines(id),
    ideal_cycle_time REAL DEFAULT 1.0,
    target_speed REAL DEFAULT 100.0,
    oee_targets JSONB,
    fault_thresholds JSONB,
    andon_settings JSONB,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_equipment_config_code ON factory_telemetry.equipment_config(equipment_code);
CREATE INDEX idx_equipment_config_line ON factory_telemetry.equipment_config(production_line_id);
```

### 1.2 Fix Column References

#### Update Context Table Schema
```sql
-- Add missing columns to context table
ALTER TABLE factory_telemetry.context
ADD COLUMN IF NOT EXISTS current_job_id UUID REFERENCES factory_telemetry.job_assignments(id),
ADD COLUMN IF NOT EXISTS production_schedule_id UUID REFERENCES factory_telemetry.production_schedules(id),
ADD COLUMN IF NOT EXISTS target_speed REAL,
ADD COLUMN IF NOT EXISTS current_product_type_id UUID REFERENCES factory_telemetry.product_types(id),
ADD COLUMN IF NOT EXISTS production_line_id UUID REFERENCES factory_telemetry.production_lines(id);
```

### 1.3 Create Migration Script
```sql
-- Create migration script: 008_fix_critical_schema_issues.sql
-- This script will be run to fix all database schema issues
```

### 1.4 Testing
- [ ] Run migration scripts
- [ ] Verify all foreign key constraints work
- [ ] Test data insertion and retrieval
- [ ] Validate schema integrity

---

## Phase 2: API Implementation and Permissions (Weeks 3-4)
**Priority: CRITICAL - Blocks API functionality**

### 2.1 Fix Permission Constants

#### Update Constants File
```typescript
// Update frontend/src/config/constants.ts
export const PERMISSIONS = {
  // Existing permissions
  DASHBOARD_READ: 'dashboard:read',
  DASHBOARD_WRITE: 'dashboard:write',
  EQUIPMENT_READ: 'equipment:read',
  EQUIPMENT_WRITE: 'equipment:write',
  EQUIPMENT_DELETE: 'equipment:delete',
  JOBS_READ: 'jobs:read',
  JOBS_WRITE: 'jobs:write',
  JOBS_DELETE: 'jobs:delete',
  OEE_READ: 'oee:read',
  OEE_WRITE: 'oee:write',
  ANDON_READ: 'andon:read',
  ANDON_WRITE: 'andon:write',
  ANDON_DELETE: 'andon:delete',
  REPORTS_READ: 'reports:read',
  REPORTS_WRITE: 'reports:write',
  REPORTS_DELETE: 'reports:delete',
  
  // Missing permissions from analysis
  SCHEDULE_READ: 'schedule:read',
  SCHEDULE_WRITE: 'schedule:write',
  SCHEDULE_DELETE: 'schedule:delete',
  PRODUCTION_READ: 'production:read',
  PRODUCTION_WRITE: 'production:write',
  PRODUCTION_DELETE: 'production:delete',
  DOWNTIME_READ: 'downtime:read',
  DOWNTIME_WRITE: 'downtime:write',
  DOWNTIME_DELETE: 'downtime:delete',
  CHECKLIST_READ: 'checklist:read',
  CHECKLIST_WRITE: 'checklist:write',
  CHECKLIST_DELETE: 'checklist:delete',
  USER_READ: 'user:read',
  USER_WRITE: 'user:write',
  USER_DELETE: 'user:delete',
  SYSTEM_READ: 'system:read',
  SYSTEM_WRITE: 'system:write',
  SYSTEM_DELETE: 'system:delete'
};
```

### 2.2 Implement Missing Service Methods

#### Complete Production Service
```python
# Update backend/app/services/production_service.py
class ProductionService:
    def __init__(self):
        self.db = get_database()
    
    async def get_production_schedules(self, line_id: str = None) -> List[Dict]:
        """Get production schedules with optional line filter."""
        # Implementation here
        pass
    
    async def create_production_schedule(self, schedule_data: Dict) -> Dict:
        """Create new production schedule."""
        # Implementation here
        pass
    
    async def update_production_schedule(self, schedule_id: str, update_data: Dict) -> Dict:
        """Update existing production schedule."""
        # Implementation here
        pass
    
    async def delete_production_schedule(self, schedule_id: str) -> bool:
        """Delete production schedule."""
        # Implementation here
        pass
    
    async def get_job_assignments(self, user_id: str = None) -> List[Dict]:
        """Get job assignments with optional user filter."""
        # Implementation here
        pass
    
    async def assign_job(self, job_data: Dict) -> Dict:
        """Assign job to operator."""
        # Implementation here
        pass
    
    async def update_job_status(self, job_id: str, status: str) -> Dict:
        """Update job status."""
        # Implementation here
        pass
```

### 2.3 Complete API Endpoints

#### Update Production API
```python
# Update backend/app/api/v1/production.py
# Add missing endpoint implementations
# Fix permission references
# Complete service method calls
```

### 2.4 Testing
- [ ] Test all API endpoints
- [ ] Verify permission system works
- [ ] Test service method implementations
- [ ] Validate error handling

---

## Phase 3: Frontend Implementation (Weeks 5-6)
**Priority: CRITICAL - Blocks frontend functionality**

### 3.1 Implement Redux Store

#### Create Store Structure
```typescript
// Create frontend/src/store/index.ts
import { configureStore } from '@reduxjs/toolkit';
import authSlice from './slices/authSlice';
import jobsSlice from './slices/jobsSlice';
import productionSlice from './slices/productionSlice';
import dashboardSlice from './slices/dashboardSlice';

export const store = configureStore({
  reducer: {
    auth: authSlice,
    jobs: jobsSlice,
    production: productionSlice,
    dashboard: dashboardSlice,
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

#### Create Job Slice
```typescript
// Create frontend/src/store/slices/jobsSlice.ts
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { apiService } from '../../services/api';

export const fetchMyJobs = createAsyncThunk(
  'jobs/fetchMyJobs',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.getMyJobs();
      return response.data;
    } catch (error) {
      return rejectWithValue(error.message);
    }
  }
);

export const acceptJob = createAsyncThunk(
  'jobs/acceptJob',
  async (jobId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.acceptJob(jobId);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.message);
    }
  }
);

const jobsSlice = createSlice({
  name: 'jobs',
  initialState: {
    jobs: [],
    isLoading: false,
    error: null,
  },
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchMyJobs.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(fetchMyJobs.fulfilled, (state, action) => {
        state.isLoading = false;
        state.jobs = action.payload;
      })
      .addCase(fetchMyJobs.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload as string;
      });
  },
});

export const { clearError } = jobsSlice.actions;
export default jobsSlice.reducer;
```

### 3.2 Implement API Service Layer

#### Create API Service
```typescript
// Create frontend/src/services/api.ts
import axios from 'axios';
import { API_CONFIG } from '../config/constants';

class ApiService {
  private baseURL = API_CONFIG.BASE_URL;
  private token: string | null = null;

  constructor() {
    this.setupInterceptors();
  }

  setToken(token: string) {
    this.token = token;
  }

  private setupInterceptors() {
    // Request interceptor
    axios.interceptors.request.use(
      (config) => {
        if (this.token) {
          config.headers.Authorization = `Bearer ${this.token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor
    axios.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401) {
          // Handle token expiry
          this.handleTokenExpiry();
        }
        return Promise.reject(error);
      }
    );
  }

  // Job methods
  async getMyJobs() {
    return axios.get(`${this.baseURL}/api/v1/jobs/my-jobs`);
  }

  async acceptJob(jobId: string) {
    return axios.post(`${this.baseURL}/api/v1/jobs/${jobId}/accept`);
  }

  async startJob(jobId: string) {
    return axios.post(`${this.baseURL}/api/v1/jobs/${jobId}/start`);
  }

  async completeJob(jobId: string) {
    return axios.post(`${this.baseURL}/api/v1/jobs/${jobId}/complete`);
  }

  // Production methods
  async getProductionLines() {
    return axios.get(`${this.baseURL}/api/v1/production/lines`);
  }

  async getProductionSchedules() {
    return axios.get(`${this.baseURL}/api/v1/production/schedules`);
  }

  // OEE methods
  async getOEEData(lineId: string) {
    return axios.get(`${this.baseURL}/api/v1/oee/lines/${lineId}`);
  }

  // Andon methods
  async getAndonEvents() {
    return axios.get(`${this.baseURL}/api/v1/andon/events`);
  }

  async createAndonEvent(eventData: any) {
    return axios.post(`${this.baseURL}/api/v1/andon/events`, eventData);
  }

  private handleTokenExpiry() {
    // Implement token refresh logic
  }
}

export const apiService = new ApiService();
```

### 3.3 Implement Missing Components

#### Create Common Components
```typescript
// Create frontend/src/components/common/LoadingSpinner.tsx
import React from 'react';
import { View, ActivityIndicator, Text, StyleSheet } from 'react-native';

interface LoadingSpinnerProps {
  message?: string;
}

export const LoadingSpinner: React.FC<LoadingSpinnerProps> = ({ 
  message = 'Loading...' 
}) => {
  return (
    <View style={styles.container}>
      <ActivityIndicator size="large" color="#007AFF" />
      <Text style={styles.message}>{message}</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  message: {
    marginTop: 10,
    fontSize: 16,
    color: '#666',
  },
});
```

### 3.4 Testing
- [ ] Test Redux store functionality
- [ ] Test API service methods
- [ ] Test component rendering
- [ ] Test user interactions

---

## Phase 4: PLC Integration Fixes (Weeks 7-8)
**Priority: HIGH - Enables PLC data integration**

### 4.1 Fix Import Path Issues

#### Update Enhanced Metric Transformer
```python
# Fix backend/app/services/enhanced_metric_transformer.py
# Update import paths
from app.services.transforms import MetricTransformer
from app.services.production_service import ProductionService
from app.services.oee_calculator import OEECalculator
from app.services.downtime_tracker import DowntimeTracker
from app.services.notification_service import NotificationService
```

### 4.2 Fix Async/Await Issues

#### Update Method Signatures
```python
# Update backend/app/services/enhanced_metric_transformer.py
class EnhancedMetricTransformer(MetricTransformer):
    def __init__(self, fault_catalog: Dict[int, Dict] = None, production_service=None):
        super().__init__(fault_catalog)
        self.production_service = production_service
        self.oee_calculator = OEECalculator()
        self.downtime_tracker = DowntimeTracker()
        self.notification_service = NotificationService()
    
    async def transform_metrics(self, equipment_code: str, raw_data: Dict, context_data: Dict) -> Dict:
        """Enhanced transformation with async support."""
        # Call parent transformation
        metrics = await super().transform_metrics(equipment_code, raw_data, context_data)
        
        # Add production-specific metrics
        production_metrics = await self._add_production_metrics(raw_data, context_data)
        metrics.update(production_metrics)
        
        # Add OEE calculations
        oee_metrics = await self._calculate_enhanced_oee(metrics, context_data)
        metrics.update(oee_metrics)
        
        # Add downtime tracking
        downtime_metrics = await self._track_downtime_events(metrics, context_data)
        metrics.update(downtime_metrics)
        
        return metrics
    
    async def _add_production_metrics(self, raw_data: Dict, context_data: Dict) -> Dict[str, Any]:
        """Add production management specific metrics."""
        # Implementation here
        pass
    
    async def _calculate_enhanced_oee(self, metrics: Dict, context_data: Dict) -> Dict[str, Any]:
        """Calculate enhanced OEE with production context."""
        # Implementation here
        pass
    
    async def _track_downtime_events(self, metrics: Dict, context_data: Dict) -> Dict[str, Any]:
        """Track downtime events with production context."""
        # Implementation here
        pass
```

### 4.3 Complete PLC Integration

#### Update Telemetry Poller
```python
# Update backend/app/services/enhanced_telemetry_poller.py
class EnhancedTelemetryPoller(TelemetryPoller):
    def __init__(self):
        super().__init__()
        self.production_service = None
        self.andon_service = None
        self.notification_service = None
    
    async def initialize(self) -> None:
        """Initialize with production services."""
        await super().initialize()
        
        # Initialize production services
        self.production_service = ProductionService()
        self.andon_service = AndonService()
        self.notification_service = NotificationService()
        
        # Initialize enhanced transformer
        self.transformer = EnhancedMetricTransformer(
            fault_catalog=self.fault_catalog,
            production_service=self.production_service
        )
    
    async def _poll_cycle(self) -> None:
        """Enhanced polling cycle with production management."""
        await super()._poll_cycle()
        
        # Process production events
        await self._process_production_events()
        
        # Process Andon events
        await self._process_andon_events()
        
        # Send notifications
        await self._send_notifications()
    
    async def _process_production_events(self) -> None:
        """Process production-related events."""
        # Implementation here
        pass
    
    async def _process_andon_events(self) -> None:
        """Process Andon events and escalations."""
        # Implementation here
        pass
    
    async def _send_notifications(self) -> None:
        """Send notifications for events."""
        # Implementation here
        pass
```

### 4.4 Testing
- [ ] Test import path fixes
- [ ] Test async/await functionality
- [ ] Test PLC data integration
- [ ] Test production service integration

---

## Phase 5: OEE Calculation System (Weeks 9-10)
**Priority: HIGH - Enables OEE functionality**

### 5.1 Fix Database Dependencies

#### Update OEE Calculator
```python
# Update backend/app/services/oee_calculator.py
class OEECalculator:
    def __init__(self):
        self.db = get_database()
    
    async def calculate_real_time_oee(self, line_id: str, equipment_code: str, current_metrics: Dict) -> Dict:
        """Calculate real-time OEE using current metrics."""
        # Get equipment configuration
        equipment_config = await self._get_equipment_config(equipment_code)
        
        # Calculate availability
        availability = await self._calculate_availability(equipment_code, current_metrics, equipment_config)
        
        # Calculate performance
        performance = await self._calculate_performance(equipment_code, current_metrics, equipment_config)
        
        # Calculate quality
        quality = await self._calculate_quality(equipment_code, current_metrics, equipment_config)
        
        # Calculate OEE
        oee = availability * performance * quality
        
        return {
            "oee": oee,
            "availability": availability,
            "performance": performance,
            "quality": quality,
            "timestamp": datetime.utcnow(),
            "equipment_code": equipment_code,
            "line_id": line_id
        }
    
    async def _get_equipment_config(self, equipment_code: str) -> Dict:
        """Get equipment configuration from database."""
        query = """
        SELECT * FROM factory_telemetry.equipment_config 
        WHERE equipment_code = %s
        """
        result = await self.db.fetch_one(query, (equipment_code,))
        return result or {}
    
    async def _calculate_availability(self, equipment_code: str, metrics: Dict, config: Dict) -> float:
        """Calculate availability from PLC data."""
        # Implementation here
        pass
    
    async def _calculate_performance(self, equipment_code: str, metrics: Dict, config: Dict) -> float:
        """Calculate performance from PLC data."""
        # Implementation here
        pass
    
    async def _calculate_quality(self, equipment_code: str, metrics: Dict, config: Dict) -> float:
        """Calculate quality from production data."""
        # Implementation here
        pass
```

### 5.2 Implement Missing Methods

#### Complete Downtime Tracker Integration
```python
# Update backend/app/services/oee_calculator.py
class OEECalculator:
    async def get_downtime_data(self, equipment_code: str, time_period: timedelta) -> Dict:
        """Get downtime data for OEE calculation."""
        # Implementation here
        pass
    
    async def get_production_data(self, equipment_code: str, time_period: timedelta) -> Dict:
        """Get production data for OEE calculation."""
        # Implementation here
        pass
    
    async def store_oee_calculation(self, oee_data: Dict) -> None:
        """Store OEE calculation in database."""
        # Implementation here
        pass
```

### 5.3 Testing
- [ ] Test OEE calculation accuracy
- [ ] Test database dependencies
- [ ] Test real-time calculations
- [ ] Test historical data retrieval

---

## Phase 6: Andon System Completion (Weeks 11-12)
**Priority: MEDIUM - Enables Andon functionality**

### 6.1 Implement Missing Service Dependencies

#### Complete Notification Service
```python
# Create backend/app/services/notification_service.py
class NotificationService:
    def __init__(self):
        self.db = get_database()
        self.websocket_manager = None
    
    async def send_notification(self, user_id: str, title: str, message: str, notification_type: str = "info") -> bool:
        """Send notification to user."""
        # Implementation here
        pass
    
    async def send_push_notification(self, user_id: str, title: str, body: str) -> bool:
        """Send push notification."""
        # Implementation here
        pass
    
    async def send_email_notification(self, email: str, subject: str, body: str) -> bool:
        """Send email notification."""
        # Implementation here
        pass
    
    async def send_sms_notification(self, phone: str, message: str) -> bool:
        """Send SMS notification."""
        # Implementation here
        pass
```

### 6.2 Complete Andon Service

#### Update Andon Service
```python
# Update backend/app/services/andon_service.py
class AndonService:
    def __init__(self):
        self.db = get_database()
        self.notification_service = NotificationService()
        self.escalation_service = AndonEscalationService()
    
    async def create_andon_event(self, event_data: Dict) -> Dict:
        """Create new Andon event."""
        # Implementation here
        pass
    
    async def acknowledge_andon_event(self, event_id: str, user_id: str) -> Dict:
        """Acknowledge Andon event."""
        # Implementation here
        pass
    
    async def resolve_andon_event(self, event_id: str, user_id: str, resolution_notes: str) -> Dict:
        """Resolve Andon event."""
        # Implementation here
        pass
    
    async def escalate_andon_event(self, event_id: str, escalation_level: int) -> Dict:
        """Escalate Andon event."""
        # Implementation here
        pass
```

### 6.3 Testing
- [ ] Test notification system
- [ ] Test Andon event creation
- [ ] Test escalation system
- [ ] Test user notifications

---

## Phase 7: WebSocket Implementation (Weeks 13-14)
**Priority: MEDIUM - Enables real-time functionality**

### 7.1 Complete WebSocket Event Types

#### Update WebSocket Manager
```python
# Update backend/app/services/websocket_manager.py
class WebSocketManager:
    def __init__(self):
        self.connections = {}
        self.subscriptions = {}
    
    async def broadcast_line_status_update(self, line_id: str, data: Dict):
        """Broadcast line status update."""
        message = {
            "type": "line_status_update",
            "line_id": line_id,
            "data": data,
            "timestamp": datetime.utcnow().isoformat()
        }
        await self._broadcast_to_subscribers("line", line_id, message)
    
    async def broadcast_production_update(self, line_id: str, data: Dict):
        """Broadcast production update."""
        message = {
            "type": "production_update",
            "line_id": line_id,
            "data": data,
            "timestamp": datetime.utcnow().isoformat()
        }
        await self._broadcast_to_subscribers("production", line_id, message)
    
    async def broadcast_andon_event(self, event: Dict):
        """Broadcast Andon event."""
        message = {
            "type": "andon_event",
            "data": event,
            "timestamp": datetime.utcnow().isoformat()
        }
        await self._broadcast_to_subscribers("andon", event["line_id"], message)
    
    async def broadcast_oee_update(self, line_id: str, oee_data: Dict):
        """Broadcast OEE update."""
        message = {
            "type": "oee_update",
            "line_id": line_id,
            "data": oee_data,
            "timestamp": datetime.utcnow().isoformat()
        }
        await self._broadcast_to_subscribers("oee", line_id, message)
    
    async def broadcast_downtime_event(self, event: Dict):
        """Broadcast downtime event."""
        message = {
            "type": "downtime_event",
            "data": event,
            "timestamp": datetime.utcnow().isoformat()
        }
        await self._broadcast_to_subscribers("downtime", event["line_id"], message)
```

### 7.2 Implement WebSocket Authentication

#### Update WebSocket Endpoint
```python
# Update backend/app/api/websocket.py
async def websocket_endpoint(websocket: WebSocket, token: str = None):
    """WebSocket endpoint with authentication."""
    await websocket.accept()
    
    if token:
        try:
            # Verify JWT token
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            user_id = payload.get("sub")
            
            # Add user to connection
            websocket_manager.add_connection(websocket, user_id)
            
        except JWTError:
            await websocket.close(code=1008, reason="Invalid token")
            return
    
    try:
        while True:
            # Handle incoming messages
            data = await websocket.receive_text()
            message = json.loads(data)
            
            # Process message
            await process_websocket_message(websocket, message)
            
    except WebSocketDisconnect:
        websocket_manager.remove_connection(websocket)
```

### 7.3 Testing
- [ ] Test WebSocket connections
- [ ] Test real-time updates
- [ ] Test authentication
- [ ] Test message handling

---

## Phase 8: Testing and Validation (Weeks 15-16)
**Priority: HIGH - Ensures system reliability**

### 8.1 Unit Testing

#### Backend Tests
```python
# Create test files for all services
# test_services/test_production_service.py
# test_services/test_oee_calculator.py
# test_services/test_andon_service.py
# test_services/test_websocket_manager.py
```

#### Frontend Tests
```typescript
// Create test files for all components
// __tests__/components/MyJobsScreen.test.tsx
// __tests__/services/api.test.ts
// __tests__/store/slices/jobsSlice.test.ts
```

### 8.2 Integration Testing

#### API Integration Tests
```python
# Create integration tests
# test_integration/test_api_endpoints.py
# test_integration/test_database_integration.py
# test_integration/test_websocket_integration.py
```

#### Frontend Integration Tests
```typescript
// Create integration tests
// __tests__/integration/api.test.ts
// __tests__/integration/websocket.test.ts
```

### 8.3 End-to-End Testing

#### Complete Workflow Tests
```python
# Create E2E tests
# test_e2e/test_production_workflow.py
# test_e2e/test_andon_escalation.py
# test_e2e/test_oee_calculation.py
```

### 8.4 Performance Testing

#### Load Testing
```python
# Create load tests
# test_performance/test_api_load.py
# test_performance/test_websocket_load.py
# test_performance/test_database_load.py
```

### 8.5 Testing Checklist
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All E2E tests pass
- [ ] Performance tests meet requirements
- [ ] Security tests pass
- [ ] Error handling tests pass

---

## Phase 9: Production Deployment (Weeks 17-18)
**Priority: HIGH - System goes live**

### 9.1 Staging Environment Setup

#### Deploy to Staging
```bash
# Deploy backend to staging
docker-compose -f docker-compose.staging.yml up -d

# Deploy frontend to staging
npm run build:staging
```

### 9.2 Production Environment Setup

#### Deploy to Production
```bash
# Deploy backend to production
docker-compose -f docker-compose.production.yml up -d

# Deploy frontend to production
npm run build:production
```

### 9.3 Database Migration

#### Run Production Migrations
```sql
-- Run all migration scripts in production
-- 001_init_telemetry.sql
-- 002_plc_equipment_management.sql
-- 003_production_management.sql
-- 004_advanced_production_features.sql
-- 005_andon_escalation_system.sql
-- 006_report_system.sql
-- 007_plc_integration_phase1.sql
-- 008_fix_critical_schema_issues.sql
```

### 9.4 Monitoring Setup

#### Configure Monitoring
```yaml
# Configure Prometheus monitoring
# Configure Grafana dashboards
# Configure alerting rules
# Configure log aggregation
```

### 9.5 Deployment Checklist
- [ ] Staging deployment successful
- [ ] Production deployment successful
- [ ] Database migrations completed
- [ ] Monitoring configured
- [ ] Alerts configured
- [ ] Backup procedures tested

---

## Phase 10: Optimization and Maintenance (Weeks 19-20)
**Priority: LOW - System optimization**

### 10.1 Performance Optimization

#### Database Optimization
```sql
-- Add additional indexes
-- Optimize queries
-- Configure connection pooling
-- Set up read replicas
```

#### API Optimization
```python
# Implement caching
# Optimize database queries
# Add request batching
# Implement rate limiting
```

### 10.2 Monitoring and Alerting

#### Set Up Monitoring
```yaml
# Configure application metrics
# Set up business metrics
# Configure alerting thresholds
# Set up dashboard automation
```

### 10.3 Documentation

#### Create Documentation
```markdown
# Create user documentation
# Create API documentation
# Create deployment documentation
# Create troubleshooting guides
```

### 10.4 Training and Support

#### User Training
```markdown
# Create training materials
# Conduct user training sessions
# Create video tutorials
# Set up support procedures
```

### 10.5 Maintenance Procedures

#### Ongoing Maintenance
```markdown
# Create maintenance schedules
# Set up automated backups
# Create update procedures
# Set up security monitoring
```

## Success Criteria

### Technical Success Criteria
- [ ] All critical issues resolved
- [ ] System uptime > 99.9%
- [ ] API response time < 250ms
- [ ] WebSocket connection stability > 99%
- [ ] Database query performance < 100ms
- [ ] All tests passing
- [ ] Security vulnerabilities addressed

### Business Success Criteria
- [ ] Production visibility improved
- [ ] Downtime reduced by 20%
- [ ] OEE improved by 15%
- [ ] User adoption rate > 90%
- [ ] User satisfaction > 4.5/5
- [ ] System reliability > 99.9%

## Risk Mitigation

### Technical Risks
- **PLC Communication Failures**: Implement fault-tolerant communication with retry logic
- **Database Performance Issues**: Optimize queries and implement caching
- **WebSocket Connection Problems**: Implement reconnection logic and connection pooling
- **API Scalability Concerns**: Implement load balancing and horizontal scaling

### Business Risks
- **User Adoption Challenges**: Provide comprehensive training and support
- **Data Accuracy Concerns**: Implement data validation and quality checks
- **System Reliability Issues**: Implement comprehensive monitoring and alerting
- **Integration Complexity**: Use phased rollout approach with rollback procedures

## Resource Requirements

### Development Team
- **Backend Developer**: 1 FTE for 20 weeks
- **Frontend Developer**: 1 FTE for 20 weeks
- **Database Administrator**: 0.5 FTE for 20 weeks
- **DevOps Engineer**: 0.5 FTE for 20 weeks
- **QA Engineer**: 0.5 FTE for 20 weeks

### Infrastructure
- **Development Environment**: Cloud instances for development and testing
- **Staging Environment**: Production-like environment for testing
- **Production Environment**: High-availability production environment
- **Monitoring Tools**: Prometheus, Grafana, ELK stack
- **CI/CD Pipeline**: Automated deployment and testing

## Conclusion

This comprehensive 10-phase implementation plan addresses all critical issues identified in the code analysis and provides a clear path to deliver a fully functional MS5.0 Floor Dashboard system. The plan is designed to be executed incrementally, with each phase building upon the previous one, ensuring that the system remains stable and functional throughout the implementation process.

The key success factors are:
1. **Phased Approach**: Each phase addresses specific issues without disrupting existing functionality
2. **Comprehensive Testing**: Extensive testing at each phase ensures quality and reliability
3. **Risk Mitigation**: Proactive risk management and mitigation strategies
4. **User Focus**: Continuous focus on user experience and business value
5. **Quality Assurance**: Rigorous quality control and validation processes

By following this plan, the MS5.0 Floor Dashboard will be transformed from a partially functional system with critical issues into a world-class production management platform that delivers real business value.
