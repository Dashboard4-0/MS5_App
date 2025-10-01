# MS5.0 Floor Dashboard - API Documentation

## Table of Contents
1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Base URL and Endpoints](#base-url-and-endpoints)
4. [API Endpoints](#api-endpoints)
5. [Data Models](#data-models)
6. [Error Handling](#error-handling)
7. [Rate Limiting](#rate-limiting)
8. [WebSocket API](#websocket-api)
9. [Examples](#examples)
10. [SDK and Libraries](#sdk-and-libraries)

## Overview

The MS5.0 Floor Dashboard API provides programmatic access to all system functionality. The API follows RESTful principles and uses JSON for data exchange. All endpoints require authentication and support real-time updates via WebSocket connections.

### Key Features
- **RESTful API**: Standard HTTP methods and status codes
- **JSON Format**: All data exchanged in JSON format
- **Authentication**: JWT-based authentication
- **Real-time Updates**: WebSocket support for live data
- **Rate Limiting**: Built-in rate limiting protection
- **Comprehensive Error Handling**: Detailed error responses
- **Versioning**: API versioning for backward compatibility

### API Version
Current API Version: **v1**

Base URL: `https://api.ms5.company.com/api/v1`

## Authentication

The MS5.0 API uses JWT (JSON Web Token) authentication. All API requests must include a valid JWT token in the Authorization header.

### Getting an Access Token

#### Login Endpoint
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "username": "your_username",
  "password": "your_password"
}
```

#### Response
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1800,
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "username": "john.doe",
    "email": "john.doe@company.com",
    "role": "production_manager",
    "first_name": "John",
    "last_name": "Doe"
  }
}
```

### Using the Access Token

Include the access token in the Authorization header:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Token Refresh

When the access token expires, use the refresh token to get a new one:

```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Logout

```http
POST /api/v1/auth/logout
Authorization: Bearer <access_token>
```

## Base URL and Endpoints

### Base URL
- **Production**: `https://api.ms5.company.com/api/v1`
- **Staging**: `https://staging-api.ms5.company.com/api/v1`
- **Development**: `http://localhost:8000/api/v1`

### Endpoint Categories
- **Authentication**: `/auth/*`
- **Production**: `/production/*`
- **Jobs**: `/jobs/*`
- **Quality**: `/quality/*`
- **Andon**: `/andon/*`
- **Maintenance**: `/maintenance/*`
- **Equipment**: `/equipment/*`
- **Reports**: `/reports/*`
- **Users**: `/users/*`
- **System**: `/system/*`

## API Endpoints

### Authentication Endpoints

#### Login
```http
POST /auth/login
```
**Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

#### Refresh Token
```http
POST /auth/refresh
```
**Body:**
```json
{
  "refresh_token": "string"
}
```

#### Logout
```http
POST /auth/logout
```

#### Get User Profile
```http
GET /auth/profile
```

### Production Endpoints

#### Get Production Lines
```http
GET /production/lines
```

**Query Parameters:**
- `active` (boolean): Filter by active status
- `limit` (integer): Number of results per page
- `offset` (integer): Number of results to skip

**Response:**
```json
{
  "lines": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "line_code": "L-BAG1",
      "name": "Bagging Line 1",
      "description": "Primary bagging production line",
      "equipment_codes": ["EQ-BAG1", "EQ-SEAL1"],
      "target_speed": 120.0,
      "enabled": true,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ],
  "total": 1,
  "limit": 10,
  "offset": 0
}
```

#### Get Production Line by ID
```http
GET /production/lines/{line_id}
```

#### Create Production Line
```http
POST /production/lines
```

**Body:**
```json
{
  "line_code": "string",
  "name": "string",
  "description": "string",
  "equipment_codes": ["string"],
  "target_speed": 120.0,
  "enabled": true
}
```

#### Update Production Line
```http
PUT /production/lines/{line_id}
```

#### Delete Production Line
```http
DELETE /production/lines/{line_id}
```

#### Get Production Schedules
```http
GET /production/schedules
```

**Query Parameters:**
- `line_id` (UUID): Filter by production line
- `status` (string): Filter by status
- `start_date` (date): Filter by start date
- `end_date` (date): Filter by end date

#### Create Production Schedule
```http
POST /production/schedules
```

**Body:**
```json
{
  "line_id": "123e4567-e89b-12d3-a456-426614174000",
  "product_type_id": "123e4567-e89b-12d3-a456-426614174000",
  "scheduled_start": "2024-01-01T08:00:00Z",
  "scheduled_end": "2024-01-01T16:00:00Z",
  "target_quantity": 1000,
  "priority": 1
}
```

### Job Management Endpoints

#### Get Job Assignments
```http
GET /jobs/assignments
```

**Query Parameters:**
- `user_id` (UUID): Filter by user
- `status` (string): Filter by status
- `schedule_id` (UUID): Filter by schedule

#### Get My Jobs
```http
GET /jobs/my-jobs
```

#### Create Job Assignment
```http
POST /jobs/assignments
```

**Body:**
```json
{
  "schedule_id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "notes": "string"
}
```

#### Accept Job
```http
POST /jobs/assignments/{job_id}/accept
```

#### Start Job
```http
POST /jobs/assignments/{job_id}/start
```

#### Complete Job
```http
POST /jobs/assignments/{job_id}/complete
```

**Body:**
```json
{
  "completed_quantity": 950,
  "notes": "Completed with minor quality issues"
}
```

### Quality Control Endpoints

#### Get Quality Checks
```http
GET /quality/checks
```

#### Create Quality Check
```http
POST /quality/checks
```

**Body:**
```json
{
  "line_id": "123e4567-e89b-12d3-a456-426614174000",
  "product_type_id": "123e4567-e89b-12d3-a456-426614174000",
  "check_type": "in_process",
  "quantity_checked": 100,
  "quantity_passed": 98,
  "quantity_failed": 2,
  "defect_codes": ["D001", "D002"],
  "notes": "Minor defects found",
  "checked_by": "123e4567-e89b-12d3-a456-426614174000"
}
```

#### Get Defect Codes
```http
GET /quality/defect-codes
```

### Andon System Endpoints

#### Get Andon Events
```http
GET /andon/events
```

**Query Parameters:**
- `line_id` (UUID): Filter by production line
- `status` (string): Filter by status
- `priority` (string): Filter by priority

#### Create Andon Event
```http
POST /andon/events
```

**Body:**
```json
{
  "line_id": "123e4567-e89b-12d3-a456-426614174000",
  "equipment_code": "EQ-BAG1",
  "event_type": "quality",
  "priority": "high",
  "description": "Quality issue detected",
  "reported_by": "123e4567-e89b-12d3-a456-426614174000"
}
```

#### Acknowledge Andon Event
```http
POST /andon/events/{event_id}/acknowledge
```

**Body:**
```json
{
  "acknowledged_by": "123e4567-e89b-12d3-a456-426614174000",
  "notes": "Issue acknowledged, investigating"
}
```

#### Resolve Andon Event
```http
POST /andon/events/{event_id}/resolve
```

**Body:**
```json
{
  "resolved_by": "123e4567-e89b-12d3-a456-426614174000",
  "resolution_notes": "Issue resolved by adjusting settings"
}
```

### Maintenance Endpoints

#### Get Work Orders
```http
GET /maintenance/work-orders
```

#### Create Work Order
```http
POST /maintenance/work-orders
```

**Body:**
```json
{
  "equipment_code": "EQ-BAG1",
  "title": "Preventive Maintenance - Bagging Machine",
  "description": "Monthly preventive maintenance",
  "priority": "medium",
  "work_type": "preventive",
  "scheduled_start": "2024-01-01T02:00:00Z",
  "scheduled_end": "2024-01-01T04:00:00Z",
  "assigned_to": "123e4567-e89b-12d3-a456-426614174000"
}
```

#### Update Work Order Status
```http
PUT /maintenance/work-orders/{work_order_id}
```

### Equipment Endpoints

#### Get Equipment Status
```http
GET /equipment/status
```

#### Get Equipment Configuration
```http
GET /equipment/config
```

#### Update Equipment Configuration
```http
PUT /equipment/config/{equipment_code}
```

### Reports Endpoints

#### Get Production Reports
```http
GET /reports/production
```

**Query Parameters:**
- `line_id` (UUID): Filter by production line
- `start_date` (date): Report start date
- `end_date` (date): Report end date
- `format` (string): Report format (json, pdf, csv)

#### Generate Custom Report
```http
POST /reports/custom
```

**Body:**
```json
{
  "report_type": "oee_analysis",
  "parameters": {
    "line_id": "123e4567-e89b-12d3-a456-426614174000",
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
  },
  "format": "pdf"
}
```

### OEE Endpoints

#### Get OEE Data
```http
GET /oee/lines/{line_id}
```

**Query Parameters:**
- `start_date` (datetime): Start time for data
- `end_date` (datetime): End time for data
- `granularity` (string): Data granularity (hour, day, week)

#### Get Real-time OEE
```http
GET /oee/realtime/{line_id}
```

## Data Models

### Production Line
```json
{
  "id": "UUID",
  "line_code": "string",
  "name": "string",
  "description": "string",
  "equipment_codes": ["string"],
  "target_speed": "number",
  "enabled": "boolean",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### Production Schedule
```json
{
  "id": "UUID",
  "line_id": "UUID",
  "product_type_id": "UUID",
  "scheduled_start": "datetime",
  "scheduled_end": "datetime",
  "target_quantity": "integer",
  "priority": "integer",
  "status": "string",
  "created_by": "UUID",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### Job Assignment
```json
{
  "id": "UUID",
  "schedule_id": "UUID",
  "user_id": "UUID",
  "assigned_at": "datetime",
  "accepted_at": "datetime",
  "started_at": "datetime",
  "completed_at": "datetime",
  "status": "string",
  "notes": "string"
}
```

### Quality Check
```json
{
  "id": "UUID",
  "line_id": "UUID",
  "product_type_id": "UUID",
  "check_time": "datetime",
  "check_type": "string",
  "check_result": "string",
  "quantity_checked": "integer",
  "quantity_passed": "integer",
  "quantity_failed": "integer",
  "defect_codes": ["string"],
  "notes": "string",
  "checked_by": "UUID"
}
```

### Andon Event
```json
{
  "id": "UUID",
  "line_id": "UUID",
  "equipment_code": "string",
  "event_type": "string",
  "priority": "string",
  "description": "string",
  "reported_by": "UUID",
  "reported_at": "datetime",
  "acknowledged_by": "UUID",
  "acknowledged_at": "datetime",
  "resolved_by": "UUID",
  "resolved_at": "datetime",
  "resolution_notes": "string",
  "status": "string"
}
```

### OEE Calculation
```json
{
  "id": "integer",
  "line_id": "UUID",
  "equipment_code": "string",
  "calculation_time": "datetime",
  "availability": "number",
  "performance": "number",
  "quality": "number",
  "oee": "number",
  "planned_production_time": "integer",
  "actual_production_time": "integer",
  "ideal_cycle_time": "number",
  "actual_cycle_time": "number",
  "good_parts": "integer",
  "total_parts": "integer"
}
```

## Error Handling

The API uses standard HTTP status codes and returns detailed error information in JSON format.

### Error Response Format
```json
{
  "error": {
    "code": "string",
    "message": "string",
    "details": "object",
    "timestamp": "datetime",
    "request_id": "string"
  }
}
```

### HTTP Status Codes
- **200 OK**: Request successful
- **201 Created**: Resource created successfully
- **400 Bad Request**: Invalid request data
- **401 Unauthorized**: Authentication required
- **403 Forbidden**: Insufficient permissions
- **404 Not Found**: Resource not found
- **409 Conflict**: Resource conflict
- **422 Unprocessable Entity**: Validation error
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server error

### Common Error Codes
- **INVALID_CREDENTIALS**: Invalid username or password
- **TOKEN_EXPIRED**: Access token has expired
- **INSUFFICIENT_PERMISSIONS**: User lacks required permissions
- **VALIDATION_ERROR**: Request data validation failed
- **RESOURCE_NOT_FOUND**: Requested resource does not exist
- **DUPLICATE_RESOURCE**: Resource already exists
- **RATE_LIMIT_EXCEEDED**: Too many requests

### Example Error Response
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": {
      "field": "target_quantity",
      "message": "Target quantity must be greater than 0"
    },
    "timestamp": "2024-01-01T12:00:00Z",
    "request_id": "req_123456789"
  }
}
```

## Rate Limiting

The API implements rate limiting to ensure fair usage and system stability.

### Rate Limits
- **General API**: 1000 requests per hour per user
- **Authentication**: 10 requests per minute per IP
- **File Upload**: 100 requests per hour per user
- **Reports**: 50 requests per hour per user

### Rate Limit Headers
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

### Rate Limit Exceeded Response
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Please try again later.",
    "details": {
      "limit": 1000,
      "remaining": 0,
      "reset_time": "2024-01-01T13:00:00Z"
    }
  }
}
```

## WebSocket API

The MS5.0 API supports real-time updates via WebSocket connections.

### Connection
```javascript
const ws = new WebSocket('wss://api.ms5.company.com/ws?token=<access_token>');
```

### Authentication
Include the access token as a query parameter:
```
wss://api.ms5.company.com/ws?token=<access_token>
```

### Message Types

#### Subscribe to Updates
```json
{
  "type": "subscribe",
  "channel": "production_line",
  "line_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

#### Unsubscribe from Updates
```json
{
  "type": "unsubscribe",
  "channel": "production_line",
  "line_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### Real-time Updates

#### Production Line Update
```json
{
  "type": "line_status_update",
  "line_id": "123e4567-e89b-12d3-a456-426614174000",
  "data": {
    "status": "running",
    "current_speed": 115.5,
    "target_speed": 120.0,
    "efficiency": 96.25,
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

#### Andon Event
```json
{
  "type": "andon_event",
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "line_id": "123e4567-e89b-12d3-a456-426614174000",
    "event_type": "quality",
    "priority": "high",
    "description": "Quality issue detected",
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

#### OEE Update
```json
{
  "type": "oee_update",
  "line_id": "123e4567-e89b-12d3-a456-426614174000",
  "data": {
    "oee": 0.85,
    "availability": 0.92,
    "performance": 0.88,
    "quality": 0.96,
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

## Examples

### Complete Production Workflow

#### 1. Login
```bash
curl -X POST https://api.ms5.company.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "operator1",
    "password": "password123"
  }'
```

#### 2. Get My Jobs
```bash
curl -X GET https://api.ms5.company.com/api/v1/jobs/my-jobs \
  -H "Authorization: Bearer <access_token>"
```

#### 3. Accept Job
```bash
curl -X POST https://api.ms5.company.com/api/v1/jobs/assignments/123/accept \
  -H "Authorization: Bearer <access_token>"
```

#### 4. Start Job
```bash
curl -X POST https://api.ms5.company.com/api/v1/jobs/assignments/123/start \
  -H "Authorization: Bearer <access_token>"
```

#### 5. Complete Job
```bash
curl -X POST https://api.ms5.company.com/api/v1/jobs/assignments/123/complete \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "completed_quantity": 950,
    "notes": "Completed successfully"
  }'
```

### Real-time Monitoring with WebSocket

```javascript
// Connect to WebSocket
const ws = new WebSocket('wss://api.ms5.company.com/ws?token=<access_token>');

// Subscribe to production line updates
ws.onopen = function() {
  ws.send(JSON.stringify({
    type: 'subscribe',
    channel: 'production_line',
    line_id: '123e4567-e89b-12d3-a456-426614174000'
  }));
};

// Handle incoming updates
ws.onmessage = function(event) {
  const message = JSON.parse(event.data);
  
  switch(message.type) {
    case 'line_status_update':
      updateProductionLineDisplay(message.data);
      break;
    case 'andon_event':
      showAndonAlert(message.data);
      break;
    case 'oee_update':
      updateOEEDisplay(message.data);
      break;
  }
};
```

## SDK and Libraries

### JavaScript/TypeScript
```bash
npm install @ms5/api-client
```

```javascript
import { MS5Client } from '@ms5/api-client';

const client = new MS5Client({
  baseURL: 'https://api.ms5.company.com/api/v1',
  apiKey: 'your_api_key'
});

// Get production lines
const lines = await client.production.getLines();

// Create andon event
const event = await client.andon.createEvent({
  line_id: '123e4567-e89b-12d3-a456-426614174000',
  event_type: 'quality',
  priority: 'high',
  description: 'Quality issue detected'
});
```

### Python
```bash
pip install ms5-api-client
```

```python
from ms5_api_client import MS5Client

client = MS5Client(
    base_url='https://api.ms5.company.com/api/v1',
    api_key='your_api_key'
)

# Get production lines
lines = client.production.get_lines()

# Create andon event
event = client.andon.create_event({
    'line_id': '123e4567-e89b-12d3-a456-426614174000',
    'event_type': 'quality',
    'priority': 'high',
    'description': 'Quality issue detected'
})
```

### Postman Collection
Download the complete Postman collection for API testing:
[MS5.0 API Collection](https://api.ms5.company.com/docs/postman-collection.json)

## Comprehensive Examples

### Complete Authentication Flow with Error Handling

```javascript
class MS5APIClient {
  constructor(baseUrl, token = null) {
    this.baseUrl = baseUrl;
    this.token = token;
    this.refreshToken = null;
  }

  async login(username, password) {
    try {
      const response = await fetch(`${this.baseUrl}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username, password })
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(`Login failed: ${error.message}`);
      }

      const data = await response.json();
      this.token = data.access_token;
      this.refreshToken = data.refresh_token;
      
      console.log(`Welcome ${data.user.first_name} ${data.user.last_name}!`);
      return data;
    } catch (error) {
      console.error('Login error:', error.message);
      throw error;
    }
  }

  async refreshAccessToken() {
    if (!this.refreshToken) {
      throw new Error('No refresh token available');
    }

    try {
      const response = await fetch(`${this.baseUrl}/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ refresh_token: this.refreshToken })
      });

      if (!response.ok) {
        throw new Error('Token refresh failed');
      }

      const data = await response.json();
      this.token = data.access_token;
      return data;
    } catch (error) {
      console.error('Token refresh error:', error.message);
      throw error;
    }
  }

  async apiCall(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.token}`,
        ...options.headers
      },
      ...options
    };

    try {
      const response = await fetch(url, config);

      if (response.status === 401) {
        // Token expired, try to refresh
        await this.refreshAccessToken();
        config.headers['Authorization'] = `Bearer ${this.token}`;
        const retryResponse = await fetch(url, config);
        
        if (!retryResponse.ok) {
          throw new Error('Authentication failed after token refresh');
        }
        return await retryResponse.json();
      }

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.message || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error(`API call failed for ${endpoint}:`, error.message);
      throw error;
    }
  }
}

// Usage example
const client = new MS5APIClient('https://api.ms5.company.com/api/v1');

async function initializeClient() {
  try {
    await client.login('john.doe', 'securePassword123');
    console.log('Client initialized successfully');
  } catch (error) {
    console.error('Client initialization failed:', error.message);
  }
}
```

### Production Line Management with Full CRUD Operations

```javascript
class ProductionLineManager {
  constructor(apiClient) {
    this.client = apiClient;
  }

  async getAllLines(filters = {}) {
    try {
      const params = new URLSearchParams();
      if (filters.status) params.append('status', filters.status);
      if (filters.limit) params.append('limit', filters.limit);
      if (filters.offset) params.append('offset', filters.offset);

      const endpoint = `/production/lines${params.toString() ? `?${params}` : ''}`;
      const response = await this.client.apiCall(endpoint);
      
      console.log(`Retrieved ${response.total_count} production lines`);
      return response;
    } catch (error) {
      console.error('Failed to get production lines:', error.message);
      throw error;
    }
  }

  async createLine(lineData) {
    try {
      const response = await this.client.apiCall('/production/lines', {
        method: 'POST',
        body: JSON.stringify({
          name: lineData.name,
          line_code: lineData.line_code,
          description: lineData.description || '',
          capacity: lineData.capacity || 1000,
          cycle_time: lineData.cycle_time || 2.5,
          is_active: lineData.is_active !== false
        })
      });

      console.log(`Created production line: ${response.name} (${response.line_code})`);
      return response;
    } catch (error) {
      console.error('Failed to create production line:', error.message);
      throw error;
    }
  }

  async updateLine(lineId, updateData) {
    try {
      const response = await this.client.apiCall(`/production/lines/${lineId}`, {
        method: 'PUT',
        body: JSON.stringify(updateData)
      });

      console.log(`Updated production line: ${response.name}`);
      return response;
    } catch (error) {
      console.error('Failed to update production line:', error.message);
      throw error;
    }
  }

  async deleteLine(lineId) {
    try {
      await this.client.apiCall(`/production/lines/${lineId}`, {
        method: 'DELETE'
      });

      console.log(`Deleted production line: ${lineId}`);
      return true;
    } catch (error) {
      console.error('Failed to delete production line:', error.message);
      throw error;
    }
  }

  async getLineStatus(lineId) {
    try {
      const response = await this.client.apiCall(`/production/lines/${lineId}`);
      console.log(`Line ${response.name} status: ${response.is_active ? 'Active' : 'Inactive'}`);
      return response;
    } catch (error) {
      console.error('Failed to get line status:', error.message);
      throw error;
    }
  }
}

// Usage example
const lineManager = new ProductionLineManager(client);

async function manageProductionLines() {
  try {
    // Get all lines
    const lines = await lineManager.getAllLines({ status: 'active' });
    
    // Create a new line
    const newLine = await lineManager.createLine({
      name: 'Production Line 2',
      line_code: 'PL002',
      description: 'Secondary production line for high-volume orders',
      capacity: 1500,
      cycle_time: 2.0
    });

    // Update the line
    const updatedLine = await lineManager.updateLine(newLine.id, {
      capacity: 1800,
      description: 'Updated secondary production line with increased capacity'
    });

    // Get line status
    const status = await lineManager.getLineStatus(updatedLine.id);
    
    console.log('Production line management completed successfully');
  } catch (error) {
    console.error('Production line management failed:', error.message);
  }
}
```

### Advanced OEE Analysis and Monitoring

```javascript
class OEEManager {
  constructor(apiClient) {
    this.client = apiClient;
  }

  async calculateOEE(lineId, equipmentCode, timePeriodHours = 24) {
    try {
      const response = await this.client.apiCall('/oee/calculate', {
        method: 'POST',
        body: JSON.stringify({
          line_id: lineId,
          equipment_code: equipmentCode,
          time_period_hours: timePeriodHours
        })
      });

      console.log(`OEE Analysis for ${equipmentCode}:`);
      console.log(`  Overall OEE: ${response.oee.toFixed(2)}%`);
      console.log(`  Availability: ${response.availability.toFixed(2)}%`);
      console.log(`  Performance: ${response.performance.toFixed(2)}%`);
      console.log(`  Quality: ${response.quality.toFixed(2)}%`);
      console.log(`  Total Pieces: ${response.total_pieces}`);
      console.log(`  Good Pieces: ${response.good_pieces}`);
      console.log(`  Defective Pieces: ${response.defective_pieces}`);
      console.log(`  Downtime: ${response.downtime.toFixed(2)} minutes`);

      return response;
    } catch (error) {
      console.error('OEE calculation failed:', error.message);
      throw error;
    }
  }

  async getCurrentOEE(lineId) {
    try {
      const response = await this.client.apiCall(`/oee/lines/${lineId}/current`);
      console.log(`Current OEE for line ${lineId}: ${response.oee.toFixed(2)}%`);
      return response;
    } catch (error) {
      console.error('Failed to get current OEE:', error.message);
      throw error;
    }
  }

  async getOEEHistory(lineId, startDate, endDate, granularity = 'hour') {
    try {
      const params = new URLSearchParams({
        start_date: startDate,
        end_date: endDate,
        granularity: granularity
      });

      const response = await this.client.apiCall(`/oee/lines/${lineId}?${params}`);
      console.log(`Retrieved ${response.data.length} OEE data points`);
      return response;
    } catch (error) {
      console.error('Failed to get OEE history:', error.message);
      throw error;
    }
  }

  async analyzeOEETrends(lineId, days = 7) {
    try {
      const endDate = new Date();
      const startDate = new Date(endDate.getTime() - (days * 24 * 60 * 60 * 1000));
      
      const history = await this.getOEEHistory(
        lineId,
        startDate.toISOString().split('T')[0],
        endDate.toISOString().split('T')[0],
        'day'
      );

      // Calculate trends
      const oeeValues = history.data.map(point => point.oee);
      const avgOEE = oeeValues.reduce((sum, val) => sum + val, 0) / oeeValues.length;
      const trend = oeeValues[oeeValues.length - 1] - oeeValues[0];
      
      console.log(`OEE Trend Analysis (${days} days):`);
      console.log(`  Average OEE: ${avgOEE.toFixed(2)}%`);
      console.log(`  Trend: ${trend > 0 ? '+' : ''}${trend.toFixed(2)}%`);
      console.log(`  Best Day: ${Math.max(...oeeValues).toFixed(2)}%`);
      console.log(`  Worst Day: ${Math.min(...oeeValues).toFixed(2)}%`);

      return {
        average: avgOEE,
        trend: trend,
        best: Math.max(...oeeValues),
        worst: Math.min(...oeeValues),
        data: history.data
      };
    } catch (error) {
      console.error('OEE trend analysis failed:', error.message);
      throw error;
    }
  }
}

// Usage example
const oeeManager = new OEEManager(client);

async function performOEEAnalysis() {
  try {
    const lineId = '123e4567-e89b-12d3-a456-426614174000';
    const equipmentCode = 'EQ001';

    // Calculate current OEE
    const currentOEE = await oeeManager.calculateOEE(lineId, equipmentCode, 24);
    
    // Get current OEE
    const realtimeOEE = await oeeManager.getCurrentOEE(lineId);
    
    // Analyze trends
    const trends = await oeeManager.analyzeOEETrends(lineId, 7);
    
    console.log('OEE analysis completed successfully');
  } catch (error) {
    console.error('OEE analysis failed:', error.message);
  }
}
```

### Comprehensive Andon Event Management

```javascript
class AndonManager {
  constructor(apiClient) {
    this.client = apiClient;
  }

  async createEvent(eventData) {
    try {
      const response = await this.client.apiCall('/andon/events', {
        method: 'POST',
        body: JSON.stringify({
          line_id: eventData.line_id,
          equipment_code: eventData.equipment_code,
          event_type: eventData.event_type,
          priority: eventData.priority,
          description: eventData.description,
          reported_by: eventData.reported_by
        })
      });

      console.log(`Created Andon event: ${response.id}`);
      console.log(`Priority: ${response.priority}, Status: ${response.status}`);
      return response;
    } catch (error) {
      console.error('Failed to create Andon event:', error.message);
      throw error;
    }
  }

  async getEvents(filters = {}) {
    try {
      const params = new URLSearchParams();
      if (filters.status) params.append('status', filters.status);
      if (filters.priority) params.append('priority', filters.priority);
      if (filters.line_id) params.append('line_id', filters.line_id);

      const endpoint = `/andon/events${params.toString() ? `?${params}` : ''}`;
      const response = await this.client.apiCall(endpoint);
      
      console.log(`Retrieved ${response.length} Andon events`);
      return response;
    } catch (error) {
      console.error('Failed to get Andon events:', error.message);
      throw error;
    }
  }

  async acknowledgeEvent(eventId, notes = '') {
    try {
      const response = await this.client.apiCall(`/andon/events/${eventId}/acknowledge`, {
        method: 'PUT',
        body: JSON.stringify({ notes })
      });

      console.log(`Event ${eventId} acknowledged at: ${response.acknowledged_at}`);
      return response;
    } catch (error) {
      console.error('Failed to acknowledge event:', error.message);
      throw error;
    }
  }

  async resolveEvent(eventId, resolutionNotes, resolutionTime = null) {
    try {
      const response = await this.client.apiCall(`/andon/events/${eventId}/resolve`, {
        method: 'PUT',
        body: JSON.stringify({
          resolution_notes: resolutionNotes,
          resolution_time: resolutionTime || new Date().toISOString()
        })
      });

      console.log(`Event ${eventId} resolved at: ${response.resolved_at}`);
      console.log(`Resolution: ${response.resolution_notes}`);
      return response;
    } catch (error) {
      console.error('Failed to resolve event:', error.message);
      throw error;
    }
  }

  async getEventMetrics(timeframe = '24h') {
    try {
      const events = await this.getEvents();
      const now = new Date();
      const cutoffTime = new Date(now.getTime() - this.getTimeframeMs(timeframe));
      
      const recentEvents = events.filter(event => 
        new Date(event.created_at) >= cutoffTime
      );

      const metrics = {
        total: recentEvents.length,
        byPriority: {},
        byStatus: {},
        byType: {},
        avgResolutionTime: 0
      };

      recentEvents.forEach(event => {
        // Count by priority
        metrics.byPriority[event.priority] = (metrics.byPriority[event.priority] || 0) + 1;
        
        // Count by status
        metrics.byStatus[event.status] = (metrics.byStatus[event.status] || 0) + 1;
        
        // Count by type
        metrics.byType[event.event_type] = (metrics.byType[event.event_type] || 0) + 1;
        
        // Calculate resolution time for resolved events
        if (event.status === 'resolved' && event.resolved_at) {
          const created = new Date(event.created_at);
          const resolved = new Date(event.resolved_at);
          const resolutionTime = (resolved - created) / (1000 * 60); // minutes
          metrics.avgResolutionTime += resolutionTime;
        }
      });

      if (metrics.byStatus.resolved > 0) {
        metrics.avgResolutionTime = metrics.avgResolutionTime / metrics.byStatus.resolved;
      }

      console.log(`Andon Event Metrics (${timeframe}):`);
      console.log(`  Total Events: ${metrics.total}`);
      console.log(`  By Priority:`, metrics.byPriority);
      console.log(`  By Status:`, metrics.byStatus);
      console.log(`  By Type:`, metrics.byType);
      console.log(`  Avg Resolution Time: ${metrics.avgResolutionTime.toFixed(2)} minutes`);

      return metrics;
    } catch (error) {
      console.error('Failed to get event metrics:', error.message);
      throw error;
    }
  }

  getTimeframeMs(timeframe) {
    const timeframes = {
      '1h': 60 * 60 * 1000,
      '24h': 24 * 60 * 60 * 1000,
      '7d': 7 * 24 * 60 * 60 * 1000,
      '30d': 30 * 24 * 60 * 60 * 1000
    };
    return timeframes[timeframe] || timeframes['24h'];
  }
}

// Usage example
const andonManager = new AndonManager(client);

async function manageAndonEvents() {
  try {
    // Create a high-priority event
    const event = await andonManager.createEvent({
      line_id: '123e4567-e89b-12d3-a456-426614174000',
      equipment_code: 'EQ001',
      event_type: 'equipment_fault',
      priority: 'high',
      description: 'Critical sensor failure - immediate attention required',
      reported_by: '456e7890-e89b-12d3-a456-426614174000'
    });

    // Get all open events
    const openEvents = await andonManager.getEvents({ status: 'open' });
    
    // Acknowledge the event
    const acknowledgedEvent = await andonManager.acknowledgeEvent(
      event.id,
      'Event acknowledged, maintenance team dispatched'
    );

    // Resolve the event
    const resolvedEvent = await andonManager.resolveEvent(
      event.id,
      'Issue resolved by replacing faulty sensor. Equipment back online and functioning normally.'
    );

    // Get metrics
    const metrics = await andonManager.getEventMetrics('24h');
    
    console.log('Andon event management completed successfully');
  } catch (error) {
    console.error('Andon event management failed:', error.message);
  }
}
```

## Support

For API support and questions:
- **Email**: api-support@ms5.company.com
- **Documentation**: https://docs.ms5.company.com
- **Status Page**: https://status.ms5.company.com

---

*This API documentation is updated regularly. For the latest version, please check the API documentation endpoint.*
