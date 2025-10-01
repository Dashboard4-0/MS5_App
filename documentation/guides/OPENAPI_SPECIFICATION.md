# MS5.0 Floor Dashboard - OpenAPI 3.0 Specification

## Complete API Specification

This document provides the complete OpenAPI 3.0 specification for the MS5.0 Floor Dashboard API.

```yaml
openapi: 3.0.3
info:
  title: MS5.0 Floor Dashboard API
  description: |
    Comprehensive factory management system API providing real-time production monitoring,
    OEE calculations, Andon management, and role-based access control.
  version: 1.0.0
  contact:
    name: MS5.0 Development Team
    email: support@ms5.company.com
  license:
    name: Proprietary
servers:
  - url: https://api.ms5.company.com/api/v1
    description: Production server
  - url: https://staging-api.ms5.company.com/api/v1
    description: Staging server
  - url: http://localhost:8000/api/v1
    description: Local development server

security:
  - BearerAuth: []

paths:
  # Authentication Endpoints
  /auth/login:
    post:
      tags: [Authentication]
      summary: User login
      description: Authenticate user and receive access token
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [username, password]
              properties:
                username:
                  type: string
                  example: "john.doe"
                password:
                  type: string
                  format: password
                  example: "securePassword123"
      responses:
        '200':
          description: Login successful
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/LoginResponse'
        '401':
          description: Invalid credentials
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'

  /auth/refresh:
    post:
      tags: [Authentication]
      summary: Refresh access token
      description: Get new access token using refresh token
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [refresh_token]
              properties:
                refresh_token:
                  type: string
                  example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
      responses:
        '200':
          description: Token refreshed successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TokenResponse'

  /auth/logout:
    post:
      tags: [Authentication]
      summary: User logout
      description: Invalidate user session
      responses:
        '200':
          description: Logout successful
          content:
            application/json:
              schema:
                type: object
                properties:
                  message:
                    type: string
                    example: "Logged out successfully"

  /auth/profile:
    get:
      tags: [Authentication]
      summary: Get user profile
      description: Retrieve current user profile information
      responses:
        '200':
          description: Profile retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserProfile'
    put:
      tags: [Authentication]
      summary: Update user profile
      description: Update current user profile information
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UserProfileUpdate'
      responses:
        '200':
          description: Profile updated successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserProfile'

  # Production Management Endpoints
  /production/lines:
    get:
      tags: [Production]
      summary: List production lines
      description: Retrieve all production lines with optional filtering
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
        - name: offset
          in: query
          schema:
            type: integer
            minimum: 0
            default: 0
        - name: status
          in: query
          schema:
            type: string
            enum: [active, inactive, maintenance]
      responses:
        '200':
          description: Production lines retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductionLinesResponse'
    post:
      tags: [Production]
      summary: Create production line
      description: Create a new production line
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductionLineCreate'
      responses:
        '201':
          description: Production line created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductionLineResponse'

  /production/lines/{line_id}:
    get:
      tags: [Production]
      summary: Get production line
      description: Retrieve specific production line details
      parameters:
        - name: line_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Production line retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductionLineResponse'
        '404':
          description: Production line not found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
    put:
      tags: [Production]
      summary: Update production line
      description: Update production line information
      parameters:
        - name: line_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductionLineUpdate'
      responses:
        '200':
          description: Production line updated successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductionLineResponse'
    delete:
      tags: [Production]
      summary: Delete production line
      description: Delete production line
      parameters:
        - name: line_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '204':
          description: Production line deleted successfully
        '404':
          description: Production line not found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'

  # Dashboard Endpoints
  /dashboard/lines:
    get:
      tags: [Dashboard]
      summary: Get dashboard lines
      description: Retrieve production lines for dashboard display
      responses:
        '200':
          description: Dashboard lines retrieved successfully
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/LineStatusResponse'

  /dashboard/summary:
    get:
      tags: [Dashboard]
      summary: Get dashboard summary
      description: Retrieve overall dashboard summary statistics
      responses:
        '200':
          description: Dashboard summary retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/DashboardSummaryResponse'

  # OEE Endpoints
  /oee/calculate:
    post:
      tags: [OEE]
      summary: Calculate OEE
      description: Calculate Overall Equipment Effectiveness for equipment
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/OEECalculationRequest'
      responses:
        '200':
          description: OEE calculated successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/OEECalculationResponse'

  /oee/lines/{line_id}/current:
    get:
      tags: [OEE]
      summary: Get current OEE
      description: Retrieve current OEE for production line
      parameters:
        - name: line_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Current OEE retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/OEECalculationResponse'

  # Andon System Endpoints
  /andon/events:
    get:
      tags: [Andon]
      summary: List Andon events
      description: Retrieve Andon events with filtering
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [open, acknowledged, resolved]
        - name: priority
          in: query
          schema:
            type: string
            enum: [low, medium, high, critical]
        - name: line_id
          in: query
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Andon events retrieved successfully
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/AndonEventResponse'
    post:
      tags: [Andon]
      summary: Create Andon event
      description: Create new Andon event
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/AndonEventCreate'
      responses:
        '201':
          description: Andon event created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AndonEventResponse'

  /andon/events/{event_id}/acknowledge:
    put:
      tags: [Andon]
      summary: Acknowledge Andon event
      description: Acknowledge Andon event
      parameters:
        - name: event_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                notes:
                  type: string
                  example: "Event acknowledged, investigating issue"
      responses:
        '200':
          description: Event acknowledged successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AndonEventResponse'

  /andon/events/{event_id}/resolve:
    put:
      tags: [Andon]
      summary: Resolve Andon event
      description: Resolve Andon event
      parameters:
        - name: event_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [resolution_notes]
              properties:
                resolution_notes:
                  type: string
                  example: "Issue resolved by replacing faulty sensor"
                resolution_time:
                  type: string
                  format: date-time
      responses:
        '200':
          description: Event resolved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AndonEventResponse'

  # Equipment Endpoints
  /equipment/status:
    get:
      tags: [Equipment]
      summary: Get equipment status
      description: Retrieve status of all equipment
      parameters:
        - name: line_id
          in: query
          schema:
            type: string
            format: uuid
        - name: status
          in: query
          schema:
            type: string
            enum: [running, stopped, fault, maintenance]
      responses:
        '200':
          description: Equipment status retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/EquipmentStatusResponse'

  /equipment/{equipment_code}/status:
    get:
      tags: [Equipment]
      summary: Get equipment detail status
      description: Retrieve detailed status for specific equipment
      parameters:
        - name: equipment_code
          in: path
          required: true
          schema:
            type: string
            example: "EQ001"
      responses:
        '200':
          description: Equipment status retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/EquipmentDetailResponse'

  # Reports Endpoints
  /reports/production:
    post:
      tags: [Reports]
      summary: Generate production report
      description: Generate production report for specific line and date
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [line_id, report_date]
              properties:
                line_id:
                  type: string
                  format: uuid
                report_date:
                  type: string
                  format: date
                shift:
                  type: string
                  enum: [day, night, evening]
                report_type:
                  type: string
                  enum: [daily, weekly, monthly]
                  default: daily
      responses:
        '201':
          description: Report generated successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ReportResponse'

  /reports/oee:
    post:
      tags: [Reports]
      summary: Generate OEE report
      description: Generate OEE analysis report
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [line_id, start_date, end_date]
              properties:
                line_id:
                  type: string
                  format: uuid
                start_date:
                  type: string
                  format: date
                end_date:
                  type: string
                  format: date
                report_type:
                  type: string
                  enum: [oee_analysis, trend_analysis, comparison]
                  default: oee_analysis
      responses:
        '201':
          description: OEE report generated successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ReportResponse'

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    # Authentication Schemas
    LoginResponse:
      type: object
      properties:
        access_token:
          type: string
          example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        refresh_token:
          type: string
          example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        token_type:
          type: string
          example: "bearer"
        expires_in:
          type: integer
          example: 1800
        user:
          $ref: '#/components/schemas/UserProfile'

    TokenResponse:
      type: object
      properties:
        access_token:
          type: string
        token_type:
          type: string
          example: "bearer"
        expires_in:
          type: integer
          example: 1800

    UserProfile:
      type: object
      properties:
        id:
          type: string
          format: uuid
        username:
          type: string
        email:
          type: string
          format: email
        role:
          type: string
          enum: [admin, production_manager, shift_manager, engineer, operator, maintenance, quality, viewer]
        first_name:
          type: string
        last_name:
          type: string
        employee_id:
          type: string
        department:
          type: string
        shift:
          type: string
        is_active:
          type: boolean
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    UserProfileUpdate:
      type: object
      properties:
        first_name:
          type: string
        last_name:
          type: string
        email:
          type: string
          format: email
        department:
          type: string
        shift:
          type: string

    # Production Schemas
    ProductionLineCreate:
      type: object
      required: [name, line_code]
      properties:
        name:
          type: string
          example: "Production Line 1"
        line_code:
          type: string
          example: "PL001"
        description:
          type: string
        capacity:
          type: number
          format: float
        cycle_time:
          type: number
          format: float
        is_active:
          type: boolean
          default: true

    ProductionLineUpdate:
      type: object
      properties:
        name:
          type: string
        description:
          type: string
        capacity:
          type: number
          format: float
        cycle_time:
          type: number
          format: float
        is_active:
          type: boolean

    ProductionLineResponse:
      type: object
      properties:
        id:
          type: string
          format: uuid
        name:
          type: string
        line_code:
          type: string
        description:
          type: string
        capacity:
          type: number
          format: float
        cycle_time:
          type: number
          format: float
        is_active:
          type: boolean
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    ProductionLinesResponse:
      type: object
      properties:
        lines:
          type: array
          items:
            $ref: '#/components/schemas/ProductionLineResponse'
        total_count:
          type: integer
        limit:
          type: integer
        offset:
          type: integer

    # Dashboard Schemas
    LineStatusResponse:
      type: object
      properties:
        line_id:
          type: string
          format: uuid
        line_name:
          type: string
        line_code:
          type: string
        status:
          type: string
          enum: [running, stopped, fault, maintenance]
        current_job:
          type: string
        oee:
          type: number
          format: float
        availability:
          type: number
          format: float
        performance:
          type: number
          format: float
        quality:
          type: number
          format: float
        last_updated:
          type: string
          format: date-time

    DashboardSummaryResponse:
      type: object
      properties:
        total_lines:
          type: integer
        active_lines:
          type: integer
        overall_oee:
          type: number
          format: float
        total_production:
          type: number
          format: float
        active_jobs:
          type: integer
        open_andon_events:
          type: integer
        last_updated:
          type: string
          format: date-time

    # OEE Schemas
    OEECalculationRequest:
      type: object
      required: [line_id, equipment_code]
      properties:
        line_id:
          type: string
          format: uuid
        equipment_code:
          type: string
        calculation_time:
          type: string
          format: date-time
        time_period_hours:
          type: integer
          minimum: 1
          maximum: 168
          default: 24

    OEECalculationResponse:
      type: object
      properties:
        line_id:
          type: string
          format: uuid
        equipment_code:
          type: string
        calculation_time:
          type: string
          format: date-time
        time_period_hours:
          type: integer
        availability:
          type: number
          format: float
        performance:
          type: number
          format: float
        quality:
          type: number
          format: float
        oee:
          type: number
          format: float
        planned_production_time:
          type: number
          format: float
        actual_production_time:
          type: number
          format: float
        downtime:
          type: number
          format: float
        total_pieces:
          type: integer
        good_pieces:
          type: integer
        defective_pieces:
          type: integer

    # Andon Schemas
    AndonEventCreate:
      type: object
      required: [line_id, equipment_code, event_type, priority]
      properties:
        line_id:
          type: string
          format: uuid
        equipment_code:
          type: string
        event_type:
          type: string
          enum: [equipment_fault, quality_issue, material_shortage, maintenance_required, safety_concern]
        priority:
          type: string
          enum: [low, medium, high, critical]
        description:
          type: string
        reported_by:
          type: string
          format: uuid

    AndonEventResponse:
      type: object
      properties:
        id:
          type: string
          format: uuid
        line_id:
          type: string
          format: uuid
        equipment_code:
          type: string
        event_type:
          type: string
        priority:
          type: string
        status:
          type: string
          enum: [open, acknowledged, resolved]
        description:
          type: string
        reported_by:
          type: string
          format: uuid
        acknowledged_by:
          type: string
          format: uuid
        resolved_by:
          type: string
          format: uuid
        created_at:
          type: string
          format: date-time
        acknowledged_at:
          type: string
          format: date-time
        resolved_at:
          type: string
          format: date-time
        resolution_notes:
          type: string

    # Equipment Schemas
    EquipmentStatusResponse:
      type: object
      properties:
        equipment:
          type: array
          items:
            $ref: '#/components/schemas/EquipmentStatus'
        total_count:
          type: integer
        running_count:
          type: integer
        stopped_count:
          type: integer
        fault_count:
          type: integer
        maintenance_count:
          type: integer

    EquipmentStatus:
      type: object
      properties:
        equipment_code:
          type: string
        equipment_name:
          type: string
        line_id:
          type: string
          format: uuid
        status:
          type: string
          enum: [running, stopped, fault, maintenance]
        last_updated:
          type: string
          format: date-time

    EquipmentDetailResponse:
      type: object
      properties:
        equipment_code:
          type: string
        equipment_name:
          type: string
        line_id:
          type: string
          format: uuid
        status:
          type: string
        current_job:
          type: string
        cycle_time:
          type: number
          format: float
        target_speed:
          type: number
          format: float
        actual_speed:
          type: number
          format: float
        temperature:
          type: number
          format: float
        pressure:
          type: number
          format: float
        vibration:
          type: number
          format: float
        last_maintenance:
          type: string
          format: date-time
        next_maintenance:
          type: string
          format: date-time
        last_updated:
          type: string
          format: date-time

    # Report Schemas
    ReportResponse:
      type: object
      properties:
        report_id:
          type: string
          format: uuid
        report_type:
          type: string
        generated_at:
          type: string
          format: date-time
        generated_by:
          type: string
          format: uuid
        parameters:
          type: object
        download_url:
          type: string
          format: uri
        expires_at:
          type: string
          format: date-time

    # Error Schemas
    ErrorResponse:
      type: object
      properties:
        error:
          type: string
        message:
          type: string
        details:
          type: object
        timestamp:
          type: string
          format: date-time
        request_id:
          type: string

tags:
  - name: Authentication
    description: User authentication and authorization
  - name: Production
    description: Production line and job management
  - name: Dashboard
    description: Dashboard data and summaries
  - name: OEE
    description: Overall Equipment Effectiveness calculations
  - name: Andon
    description: Andon system event management
  - name: Equipment
    description: Equipment status and monitoring
  - name: Reports
    description: Report generation and management
```

## WebSocket API Documentation

### WebSocket Endpoint
```
WS /ws/?token=<access_token>&line_id=<line_id>&subscription_types=<types>
```

### Connection Parameters
- `token`: JWT access token for authentication
- `line_id`: Optional production line ID for filtering
- `subscription_types`: Comma-separated list of subscription types

### Subscription Types
- `line_status`: Production line status updates
- `equipment_status`: Equipment status changes
- `andon_events`: New Andon events
- `oee_updates`: OEE calculation updates
- `job_updates`: Job assignment updates
- `system_alerts`: System-wide alerts

### WebSocket Messages

#### Client to Server
```json
{
  "type": "subscribe",
  "subscription_types": ["line_status", "andon_events"],
  "line_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

```json
{
  "type": "unsubscribe",
  "subscription_types": ["line_status"]
}
```

```json
{
  "type": "ping"
}
```

#### Server to Client
```json
{
  "type": "line_status_update",
  "data": {
    "line_id": "123e4567-e89b-12d3-a456-426614174000",
    "status": "running",
    "oee": 85.5,
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

```json
{
  "type": "andon_event",
  "data": {
    "id": "456e7890-e89b-12d3-a456-426614174000",
    "line_id": "123e4567-e89b-12d3-a456-426614174000",
    "equipment_code": "EQ001",
    "event_type": "equipment_fault",
    "priority": "high",
    "description": "Sensor malfunction detected",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

## Error Codes Reference

### HTTP Status Codes
- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `204 No Content`: Request successful, no content returned
- `400 Bad Request`: Invalid request data
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `409 Conflict`: Resource conflict
- `422 Unprocessable Entity`: Validation error
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

### Application Error Codes
- `AUTH_001`: Invalid credentials
- `AUTH_002`: Token expired
- `AUTH_003`: Insufficient permissions
- `PROD_001`: Production line not found
- `PROD_002`: Invalid production parameters
- `OEE_001`: OEE calculation failed
- `ANDON_001`: Andon event not found
- `EQUIP_001`: Equipment not found
- `EQUIP_002`: Equipment offline
- `REPORT_001`: Report generation failed
- `REPORT_002`: Invalid report parameters

## Rate Limiting

### Limits by Endpoint Type
- **Authentication**: 5 requests per minute
- **Dashboard**: 60 requests per minute
- **Production**: 30 requests per minute
- **OEE**: 20 requests per minute
- **Andon**: 40 requests per minute
- **Equipment**: 50 requests per minute
- **Reports**: 10 requests per minute

### Rate Limit Headers
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 59
X-RateLimit-Reset: 1642248000
```

## SDK Examples

### JavaScript/TypeScript
```typescript
import { MS5Client } from '@ms5/sdk';

const client = new MS5Client({
  baseUrl: 'https://api.ms5.company.com/api/v1',
  token: 'your-access-token'
});

// Get production lines
const lines = await client.production.getLines();

// Create Andon event
const event = await client.andon.createEvent({
  line_id: '123e4567-e89b-12d3-a456-426614174000',
  equipment_code: 'EQ001',
  event_type: 'equipment_fault',
  priority: 'high',
  description: 'Sensor malfunction'
});

// Subscribe to WebSocket updates
const ws = client.websocket.connect({
  subscription_types: ['line_status', 'andon_events']
});
```

### Python
```python
from ms5_sdk import MS5Client

client = MS5Client(
    base_url='https://api.ms5.company.com/api/v1',
    token='your-access-token'
)

# Get production lines
lines = client.production.get_lines()

# Create Andon event
event = client.andon.create_event(
    line_id='123e4567-e89b-12d3-a456-426614174000',
    equipment_code='EQ001',
    event_type='equipment_fault',
    priority='high',
    description='Sensor malfunction'
)

# Subscribe to WebSocket updates
ws = client.websocket.connect(
    subscription_types=['line_status', 'andon_events']
)
```

## Testing the API

### Using curl
```bash
# Login
curl -X POST https://api.ms5.company.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "password": "password"}'

# Get production lines
curl -X GET https://api.ms5.company.com/api/v1/production/lines \
  -H "Authorization: Bearer <access_token>"

# Create Andon event
curl -X POST https://api.ms5.company.com/api/v1/andon/events \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "line_id": "123e4567-e89b-12d3-a456-426614174000",
    "equipment_code": "EQ001",
    "event_type": "equipment_fault",
    "priority": "high",
    "description": "Sensor malfunction"
  }'
```

### Using Postman
1. Import the OpenAPI specification into Postman
2. Set up authentication with Bearer token
3. Test all endpoints with sample data
4. Use the Postman collection for automated testing

## API Versioning

The API uses URL-based versioning:
- Current version: `/api/v1/`
- Future versions: `/api/v2/`, `/api/v3/`, etc.

### Backward Compatibility
- New fields are added without breaking existing clients
- Deprecated fields are marked and removed in major versions
- Breaking changes are communicated via deprecation notices

## Support and Resources

- **API Documentation**: This document
- **Interactive Docs**: https://api.ms5.company.com/docs
- **Support Email**: api-support@ms5.company.com
- **Status Page**: https://status.ms5.company.com
- **Changelog**: https://api.ms5.company.com/changelog
