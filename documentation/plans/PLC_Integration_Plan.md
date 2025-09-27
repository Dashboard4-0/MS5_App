# MS5.0 Floor Dashboard - PLC Telemetry Integration Plan

## Executive Summary

This document outlines the comprehensive integration plan for the MS5.0 Floor Dashboard application with the existing PLC telemetry system. The integration leverages the existing tag scanner infrastructure while extending it to support the new production management, OEE calculation, downtime tracking, and Andon escalation systems.

## 1. Existing PLC System Analysis

### 1.1 Current Architecture
The existing PLC telemetry system consists of:

**Core Components:**
- **PLC Clients**: LogixDriver (CompactLogix/ControlLogix) and SLCDriver (SLC 5/05) support
- **Tag Scanner**: Real-time polling service with 1Hz frequency
- **Data Transformation**: Raw PLC data to canonical metrics conversion
- **Fault Detection**: Edge detection and fault catalog integration
- **Database Storage**: PostgreSQL with TimescaleDB for time-series data
- **API Layer**: FastAPI with WebSocket support for real-time updates

**Current Equipment:**
- **Bagger 1**: CompactLogix PLC with 64-bit fault array
- **Basket Loader 1**: SLC 5/05 PLC with simplified fault detection

**Data Flow:**
```
PLC (Logix/SLC) → Tag Scanner → Metric Transformer → Database → API → WebSocket
```

### 1.2 Existing Data Models
- **Equipment Configuration**: `equipment_config` table with PLC associations
- **Metric Definitions**: `metric_def` table with value types and thresholds
- **Latest Metrics**: `metric_latest` table for current values
- **Historical Metrics**: `metric_hist` table for time-series data
- **Fault Management**: `fault_catalog`, `fault_active`, and `fault_events` tables
- **Context Data**: `context` table for operator and shift information

## 2. Integration Strategy

### 2.1 Seamless Integration Approach
The integration will extend the existing system without disrupting current operations:

1. **Preserve Existing Functionality**: All current PLC polling and data collection continues unchanged
2. **Extend Data Models**: Add new production management tables alongside existing schema
3. **Enhance Transformations**: Extend metric transformer to support new production metrics
4. **Integrate Services**: Connect new services with existing PLC data streams
5. **Unified API**: Provide single API layer for both existing and new functionality

### 2.2 Data Flow Integration
```
Existing PLC Data → Enhanced Transformer → Production Services → Dashboard
                    ↓
                Database (Extended Schema)
                    ↓
                Real-time Updates (WebSocket)
```

## 3. Technical Integration Points

### 3.1 Database Schema Integration

#### 3.1.1 Extend Existing Tables
```sql
-- Extend equipment_config to support production lines
ALTER TABLE factory_telemetry.equipment_config 
ADD COLUMN production_line_id UUID REFERENCES factory_telemetry.production_lines(id),
ADD COLUMN equipment_type TEXT DEFAULT 'production',
ADD COLUMN criticality_level INTEGER DEFAULT 3;

-- Extend context table for production management
ALTER TABLE factory_telemetry.context
ADD COLUMN current_job_id UUID REFERENCES factory_telemetry.job_assignments(id),
ADD COLUMN production_schedule_id UUID REFERENCES factory_telemetry.production_schedules(id),
ADD COLUMN target_speed REAL,
ADD COLUMN current_product_type_id UUID REFERENCES factory_telemetry.product_types(id);
```

#### 3.1.2 New Production Tables
The existing production management schema (003_production_management.sql, 004_advanced_production_features.sql) integrates seamlessly with the existing PLC system through equipment associations.

### 3.2 Enhanced Metric Transformer

#### 3.2.1 Extend MetricTransformer Class
```python
class EnhancedMetricTransformer(MetricTransformer):
    """Extended transformer with production management integration."""
    
    def __init__(self, fault_catalog: Dict[int, Dict] = None, production_service=None):
        super().__init__(fault_catalog)
        self.production_service = production_service
        self.oee_calculator = OEECalculator()
        self.downtime_tracker = DowntimeTracker()
    
    def transform_bagger_metrics(self, raw_data: Dict[str, Any], context_data: Dict[str, Any]) -> Dict[str, Any]:
        """Enhanced transformation with production management integration."""
        # Call parent transformation
        metrics = super().transform_bagger_metrics(raw_data, context_data)
        
        # Add production-specific metrics
        metrics.update(self._add_production_metrics(raw_data, context_data))
        
        # Add OEE calculations
        metrics.update(self._calculate_enhanced_oee(metrics, context_data))
        
        # Add downtime tracking
        metrics.update(self._track_downtime_events(metrics, context_data))
        
        return metrics
    
    def _add_production_metrics(self, raw_data: Dict, context_data: Dict) -> Dict[str, Any]:
        """Add production management specific metrics."""
        processed = raw_data.get("processed", {})
        
        return {
            "production_line_id": context_data.get("production_line_id"),
            "current_job_id": context_data.get("current_job_id"),
            "target_quantity": context_data.get("target_quantity", 0),
            "actual_quantity": processed.get("product_count", 0),
            "production_efficiency": self._calculate_production_efficiency(processed, context_data),
            "quality_rate": self._calculate_quality_rate(processed, context_data),
            "changeover_status": self._detect_changeover_status(processed, context_data)
        }
    
    def _calculate_enhanced_oee(self, metrics: Dict, context_data: Dict) -> Dict[str, Any]:
        """Calculate enhanced OEE with production context."""
        if not self.oee_calculator:
            return {}
        
        return self.oee_calculator.calculate_real_time_oee(
            line_id=context_data.get("production_line_id"),
            equipment_code=context_data.get("equipment_code"),
            current_metrics=metrics
        )
    
    def _track_downtime_events(self, metrics: Dict, context_data: Dict) -> Dict[str, Any]:
        """Track downtime events with production context."""
        if not self.downtime_tracker:
            return {}
        
        return self.downtime_tracker.detect_downtime_event(
            equipment_code=context_data.get("equipment_code"),
            current_status=metrics,
            production_context=context_data
        )
```

### 3.3 Enhanced Polling Service

#### 3.3.1 Extend TelemetryPoller
```python
class EnhancedTelemetryPoller(TelemetryPoller):
    """Enhanced poller with production management integration."""
    
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
        # Check for job completion
        # Update production schedules
        # Calculate production KPIs
        pass
    
    async def _process_andon_events(self) -> None:
        """Process Andon events and escalations."""
        # Check for new Andon events
        # Process escalations
        # Send alerts
        pass
```

### 3.4 Real-time Integration

#### 3.4.1 Enhanced WebSocket System
```python
class EnhancedWebSocketManager:
    """Enhanced WebSocket manager with production management support."""
    
    def __init__(self):
        self.connections = {}
        self.subscriptions = {}
    
    async def broadcast_production_update(self, line_id: str, data: Dict):
        """Broadcast production-specific updates."""
        message = {
            "type": "production_update",
            "line_id": line_id,
            "data": data,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await self._broadcast_to_subscribers("production", line_id, message)
    
    async def broadcast_andon_event(self, event: Dict):
        """Broadcast Andon events."""
        message = {
            "type": "andon_event",
            "data": event,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await self._broadcast_to_subscribers("andon", event["line_id"], message)
    
    async def broadcast_oee_update(self, line_id: str, oee_data: Dict):
        """Broadcast OEE updates."""
        message = {
            "type": "oee_update",
            "line_id": line_id,
            "data": oee_data,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await self._broadcast_to_subscribers("oee", line_id, message)
```

## 4. Production Management Integration

### 4.1 Job Assignment Integration

#### 4.1.1 Equipment-to-Job Mapping
```python
class EquipmentJobMapper:
    """Map equipment to production jobs and schedules."""
    
    def __init__(self, production_service: ProductionService):
        self.production_service = production_service
    
    async def get_current_job(self, equipment_code: str) -> Optional[Dict]:
        """Get current job assignment for equipment."""
        # Query production schedules for equipment
        # Check for active job assignments
        # Return job details with production context
        pass
    
    async def update_job_progress(self, equipment_code: str, metrics: Dict):
        """Update job progress based on equipment metrics."""
        # Calculate production progress
        # Update job assignment status
        # Trigger completion events
        pass
```

### 4.2 OEE Calculation Integration

#### 4.2.1 Real-time OEE with PLC Data
```python
class PLCIntegratedOEECalculator(OEECalculator):
    """OEE calculator integrated with PLC data streams."""
    
    def calculate_real_time_oee(self, line_id: str, equipment_code: str, current_metrics: Dict) -> Dict:
        """Calculate real-time OEE using current PLC metrics."""
        # Get current production context
        production_context = self.get_production_context(line_id, equipment_code)
        
        # Calculate availability from PLC running status
        availability = self.calculate_availability_from_plc(current_metrics)
        
        # Calculate performance from speed metrics
        performance = self.calculate_performance_from_plc(current_metrics, production_context)
        
        # Calculate quality from production data
        quality = self.calculate_quality_from_production(current_metrics, production_context)
        
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
```

### 4.3 Downtime Tracking Integration

#### 4.3.1 PLC-Based Downtime Detection
```python
class PLCIntegratedDowntimeTracker(DowntimeTracker):
    """Downtime tracker integrated with PLC fault detection."""
    
    def detect_downtime_event(self, equipment_code: str, current_status: Dict, production_context: Dict) -> Dict:
        """Detect downtime events from PLC status and production context."""
        # Check PLC running status
        is_running = current_status.get("running_status", False)
        has_faults = current_status.get("has_faults", False)
        
        # Determine downtime reason
        if not is_running:
            if has_faults:
                reason = self._determine_fault_reason(current_status)
                category = "unplanned"
            elif production_context.get("planned_stop", False):
                reason = production_context.get("planned_stop_reason", "Planned Stop")
                category = "planned"
            else:
                reason = "Unknown"
                category = "unplanned"
            
            # Create downtime event
            return self._create_downtime_event(
                equipment_code=equipment_code,
                reason=reason,
                category=category,
                production_context=production_context
            )
        
        return {}
```

### 4.4 Andon System Integration

#### 4.4.1 PLC-Triggered Andon Events
```python
class PLCIntegratedAndonService(AndonService):
    """Andon service integrated with PLC fault detection."""
    
    def __init__(self):
        super().__init__()
        self.fault_thresholds = self._load_fault_thresholds()
    
    async def process_plc_faults(self, equipment_code: str, fault_data: Dict):
        """Process PLC faults and create Andon events."""
        active_faults = fault_data.get("active_alarms", [])
        
        for fault in active_faults:
            # Determine Andon event type and priority
            event_type, priority = self._classify_fault(fault, equipment_code)
            
            if event_type and priority:
                # Create Andon event
                andon_event = await self.create_andon_event(
                    line_id=self._get_line_for_equipment(equipment_code),
                    equipment_code=equipment_code,
                    event_type=event_type,
                    priority=priority,
                    description=f"PLC Fault: {fault}",
                    auto_generated=True
                )
                
                # Start escalation process
                await self._start_escalation(andon_event)
    
    def _classify_fault(self, fault_name: str, equipment_code: str) -> Tuple[str, str]:
        """Classify fault for Andon event creation."""
        # Map fault names to Andon event types and priorities
        fault_mapping = self.fault_thresholds.get(equipment_code, {})
        
        for fault_pattern, (event_type, priority) in fault_mapping.items():
            if fault_pattern.lower() in fault_name.lower():
                return event_type, priority
        
        # Default classification
        return "maintenance", "medium"
```

## 5. Data Synchronization Strategy

### 5.1 Real-time Data Flow
```
PLC Data → Enhanced Transformer → Production Services → Database → WebSocket → Dashboard
    ↓
Fault Detection → Andon Events → Escalation System → Notifications
    ↓
OEE Calculation → Performance Analytics → Reporting System
```

### 5.2 Context Data Management
```python
class ProductionContextManager:
    """Manage production context data for PLC integration."""
    
    def __init__(self, production_service: ProductionService):
        self.production_service = production_service
    
    async def update_equipment_context(self, equipment_code: str, context_data: Dict):
        """Update equipment context with production information."""
        # Get current job assignment
        current_job = await self.production_service.get_current_job(equipment_code)
        
        # Update context table
        context_update = {
            "equipment_code": equipment_code,
            "current_job_id": current_job["id"] if current_job else None,
            "production_line_id": current_job["line_id"] if current_job else None,
            "target_quantity": current_job["target_quantity"] if current_job else 0,
            "current_operator": context_data.get("current_operator"),
            "current_shift": context_data.get("current_shift"),
            "planned_stop": context_data.get("planned_stop", False),
            "planned_stop_reason": context_data.get("planned_stop_reason", "")
        }
        
        await self._update_context_table(context_update)
    
    async def get_production_context(self, equipment_code: str) -> Dict:
        """Get production context for equipment."""
        # Query context table
        # Get current job details
        # Get production line information
        # Return comprehensive context
        pass
```

## 6. API Integration

### 6.1 Enhanced API Endpoints
```python
# Extend existing API with production management endpoints
@app.get("/api/v1/equipment/{equipment_code}/production-status")
async def get_equipment_production_status(equipment_code: str):
    """Get production status for equipment."""
    # Get current PLC metrics
    # Get production context
    # Get current job assignment
    # Return comprehensive status
    pass

@app.get("/api/v1/lines/{line_id}/real-time-oee")
async def get_real_time_oee(line_id: str):
    """Get real-time OEE for production line."""
    # Get all equipment on line
    # Calculate line-level OEE
    # Return OEE metrics
    pass

@app.websocket("/api/v1/ws/production")
async def production_websocket(websocket: WebSocket, line_id: str = None):
    """WebSocket for production-specific updates."""
    # Subscribe to production updates
    # Send real-time production data
    # Handle production events
    pass
```

### 6.2 WebSocket Event Types
```python
# New WebSocket event types for production management
PRODUCTION_EVENTS = {
    "job_assigned": "Job assigned to operator",
    "job_started": "Job execution started",
    "job_completed": "Job completed",
    "job_cancelled": "Job cancelled",
    "production_update": "Production metrics updated",
    "oee_update": "OEE calculation updated",
    "downtime_event": "Downtime event detected",
    "andon_event": "Andon event created",
    "escalation_update": "Andon escalation updated",
    "quality_alert": "Quality threshold exceeded",
    "changeover_started": "Changeover process started",
    "changeover_completed": "Changeover process completed"
}
```

## 7. Configuration Management

### 7.1 Equipment Configuration
```python
# Extend equipment configuration for production management
EQUIPMENT_CONFIG_EXTENSIONS = {
    "production_line_id": "UUID of associated production line",
    "equipment_type": "Type of equipment (production, utility, etc.)",
    "criticality_level": "Criticality level (1-5)",
    "target_speed": "Target production speed",
    "oee_targets": "OEE target values",
    "fault_thresholds": "Fault classification thresholds",
    "andon_settings": "Andon event configuration"
}
```

### 7.2 Production Line Mapping
```python
# Map equipment to production lines
PRODUCTION_LINE_MAPPING = {
    "BP01.PACK.BAG1": "Line-001",  # Bagger 1
    "BP01.LOAD.BASKET1": "Line-001",  # Basket Loader 1
    # Add more equipment mappings
}
```

## 8. Implementation Phases

### 8.1 Phase 1: Database Integration (Week 1-2)
- Extend existing database schema
- Create production management tables
- Update equipment configuration
- Test database migrations

### 8.2 Phase 2: Service Integration (Week 3-4)
- Extend metric transformer
- Integrate production services
- Update polling service
- Test service integration

### 8.3 Phase 3: Real-time Integration (Week 5-6)
- Enhance WebSocket system
- Implement real-time updates
- Add production event broadcasting
- Test real-time functionality

### 8.4 Phase 4: API Integration (Week 7-8)
- Extend API endpoints
- Add production-specific endpoints
- Implement WebSocket subscriptions
- Test API integration

### 8.5 Phase 5: Testing and Optimization (Week 9-10)
- End-to-end testing
- Performance optimization
- Load testing
- Production deployment

## 9. Testing Strategy

### 9.1 Unit Testing
- Test enhanced metric transformer
- Test production service integration
- Test OEE calculation accuracy
- Test downtime detection logic

### 9.2 Integration Testing
- Test PLC data flow integration
- Test database schema extensions
- Test WebSocket real-time updates
- Test API endpoint functionality

### 9.3 End-to-End Testing
- Test complete production workflow
- Test Andon escalation system
- Test reporting integration
- Test dashboard real-time updates

## 10. Monitoring and Maintenance

### 10.1 Performance Monitoring
- Monitor PLC polling performance
- Monitor database query performance
- Monitor WebSocket connection health
- Monitor API response times

### 10.2 Error Handling
- Implement fault-tolerant PLC communication
- Add retry logic for failed operations
- Implement graceful degradation
- Add comprehensive logging

### 10.3 Maintenance Procedures
- Regular database maintenance
- PLC connection health checks
- Performance optimization
- System updates and patches

## 11. Security Considerations

### 11.1 Data Security
- Encrypt sensitive production data
- Implement access controls
- Secure PLC communication
- Audit data access

### 11.2 Network Security
- Secure PLC network access
- Implement VPN for remote access
- Monitor network traffic
- Regular security updates

## 12. Deployment Strategy

### 12.1 Staging Environment
- Deploy to staging environment
- Test with production data
- Validate integration points
- Performance testing

### 12.2 Production Deployment
- Phased rollout approach
- Monitor system performance
- Rollback procedures
- User training

## 13. Success Metrics

### 13.1 Technical Metrics
- PLC polling success rate > 99.9%
- API response time < 250ms
- WebSocket connection stability > 99%
- Database query performance < 100ms

### 13.2 Business Metrics
- Production visibility improvement
- Downtime reduction
- OEE improvement
- User adoption rate

## 14. Risk Mitigation

### 14.1 Technical Risks
- PLC communication failures
- Database performance issues
- WebSocket connection problems
- API scalability concerns

### 14.2 Business Risks
- User adoption challenges
- Data accuracy concerns
- System reliability issues
- Integration complexity

## 15. Conclusion

The PLC telemetry integration plan provides a comprehensive approach to seamlessly integrate the MS5.0 Floor Dashboard with the existing PLC system. The integration preserves all existing functionality while adding powerful production management capabilities.

**Key Benefits:**
- **Seamless Integration**: No disruption to existing PLC operations
- **Real-time Data**: Live production data from PLC systems
- **Enhanced Analytics**: Advanced OEE and performance calculations
- **Automated Workflows**: Andon events and escalations
- **Unified Interface**: Single dashboard for all production data

**Implementation Timeline**: 10 weeks with phased rollout
**Resource Requirements**: 2-3 developers, 1 PLC specialist, 1 database administrator
**Success Criteria**: 99.9% uptime, <250ms response times, 100% user adoption

The integration will transform the existing PLC telemetry system into a comprehensive production management platform, providing real-time visibility, automated workflows, and advanced analytics for factory floor operations.
