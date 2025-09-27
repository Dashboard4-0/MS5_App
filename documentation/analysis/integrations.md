# MS5.0 Floor Dashboard - Integration Points

This document outlines the integration points between the React Native frontend and the existing MS5.0 backend system, including any modifications needed for seamless integration.

## Backend Integration Points

### 1. API Endpoints Integration
The frontend is designed to integrate with the existing FastAPI backend endpoints. All API calls are configured to work with the current backend structure:

- **Base URL**: Configurable via `API_CONFIG.BASE_URL` in `src/config/constants.ts`
- **Authentication**: JWT token-based authentication using existing auth endpoints
- **WebSocket**: Real-time updates via existing WebSocket implementation

### 2. Data Model Compatibility
The frontend Pydantic models are designed to match the backend data structures:

- **User Models**: Compatible with existing user management system
- **Production Models**: Aligned with production management tables
- **Job Models**: Matches job assignment workflow
- **OEE Models**: Compatible with OEE calculation system

### 3. Authentication System
The frontend integrates with the existing JWT authentication system:

- **Login/Logout**: Uses existing `/api/v1/auth/login` and `/api/v1/auth/logout` endpoints
- **Token Refresh**: Implements automatic token refresh using `/api/v1/auth/refresh`
- **User Profile**: Fetches user data from `/api/v1/auth/profile`

## Required Backend Modifications

### 1. CORS Configuration
The backend needs to allow CORS requests from the React Native app:

```python
# In app/main.py, update CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # Development
        "http://localhost:8080",  # Development
        "https://your-app-domain.com",  # Production
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 2. WebSocket Authentication
The WebSocket endpoint needs to support JWT authentication:

```python
# In app/api/websocket.py, add JWT verification
async def websocket_endpoint(websocket: WebSocket, token: str = None):
    if token:
        # Verify JWT token
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            user_id = payload.get("sub")
            # Set user context
        except JWTError:
            await websocket.close(code=1008, reason="Invalid token")
```

### 3. File Upload Support
The backend needs to support file uploads for images and documents:

```python
# Add file upload endpoint
@app.post("/api/v1/upload")
async def upload_file(file: UploadFile = File(...)):
    # Handle file upload
    pass
```

### 4. Push Notifications
The backend needs to support push notifications:

```python
# Add notification service
class NotificationService:
    async def send_push_notification(self, user_id: str, title: str, body: str):
        # Send push notification
        pass
```

### 5. Andon Escalation System
The backend needs to support the new Andon escalation system:

```python
# New API endpoints for escalation management
- POST /api/v1/andon/escalations/ - Create escalation
- PUT /api/v1/andon/escalations/{escalation_id}/acknowledge - Acknowledge escalation
- PUT /api/v1/andon/escalations/{escalation_id}/resolve - Resolve escalation
- POST /api/v1/andon/escalations/{escalation_id}/escalate - Manual escalation
- GET /api/v1/andon/escalations/active - Get active escalations
- GET /api/v1/andon/escalations/{escalation_id}/history - Get escalation history
- GET /api/v1/andon/escalations/statistics - Get escalation statistics
- POST /api/v1/andon/escalations/process-automatic - Process automatic escalations
- GET /api/v1/andon/escalations/escalation-tree - Get escalation tree configuration
- GET /api/v1/andon/escalations/monitoring/dashboard - Get monitoring dashboard
```

### 6. Database Schema Extensions
The backend needs the following new database tables:

```sql
-- Andon escalation system tables
CREATE TABLE factory_telemetry.andon_escalations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES factory_telemetry.andon_events(id) ON DELETE CASCADE,
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    acknowledgment_timeout_minutes INTEGER NOT NULL,
    resolution_timeout_minutes INTEGER NOT NULL,
    escalation_recipients TEXT[] NOT NULL,
    escalation_level INTEGER DEFAULT 1,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'escalated', 'resolved')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    escalated_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    acknowledged_by UUID,
    escalated_by UUID,
    escalation_notes TEXT,
    last_reminder_sent_at TIMESTAMPTZ
);

CREATE TABLE factory_telemetry.andon_escalation_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    escalation_id UUID REFERENCES factory_telemetry.andon_escalations(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    performed_by UUID,
    performed_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    escalation_level INTEGER,
    recipients_notified TEXT[],
    notification_method TEXT
);

CREATE TABLE factory_telemetry.andon_escalation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    escalation_level INTEGER NOT NULL,
    delay_minutes INTEGER NOT NULL,
    recipients TEXT[] NOT NULL,
    notification_methods TEXT[] NOT NULL,
    escalation_message_template TEXT,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE factory_telemetry.andon_escalation_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    sms_enabled BOOLEAN DEFAULT false,
    email_enabled BOOLEAN DEFAULT true,
    websocket_enabled BOOLEAN DEFAULT true,
    push_enabled BOOLEAN DEFAULT false,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 7. WebSocket Escalation Support
The WebSocket system needs to support escalation-specific subscriptions:

```python
# New WebSocket subscription types
- "escalation" - Subscribe to all escalation events
- "escalation:escalation_id" - Subscribe to specific escalation
- "priority:priority_level" - Subscribe to specific priority escalations

# New WebSocket message types
- "escalation_event" - New escalation created
- "escalation_status_update" - Escalation status changed
- "escalation_reminder" - Escalation reminder notification
```

## Frontend Configuration

### 1. Environment Variables
The frontend needs the following environment variables:

```bash
# API Configuration
API_BASE_URL=http://localhost:8000
WS_BASE_URL=ws://localhost:8000

# Authentication
JWT_SECRET_KEY=your-secret-key

# Push Notifications
FCM_SERVER_KEY=your-fcm-server-key

# File Upload
MAX_FILE_SIZE=10485760  # 10MB
```

### 2. Platform-Specific Configuration

#### Android
- **Minimum SDK**: 21 (Android 5.0)
- **Target SDK**: 33 (Android 13)
- **Permissions**: Camera, Storage, Internet, Network State

#### iOS
- **Minimum Version**: 11.0
- **Target Version**: 16.0
- **Permissions**: Camera, Photo Library, Internet

## Data Synchronization

### 1. Offline Support
The frontend implements offline support with the following features:

- **Local Storage**: AsyncStorage for caching data
- **Queue System**: Offline actions are queued and synced when online
- **Conflict Resolution**: Handles data conflicts when syncing

### 2. Real-time Updates
WebSocket integration provides real-time updates for:

- **Line Status**: Production line status changes
- **Equipment Status**: Equipment status updates
- **Job Updates**: Job assignment and status changes
- **Andon Events**: Real-time Andon alerts
- **Andon Escalations**: Real-time escalation notifications and status updates
- **OEE Updates**: Live OEE calculations

## Security Considerations

### 1. Token Management
- **Access Tokens**: Short-lived (30 minutes)
- **Refresh Tokens**: Long-lived (7 days)
- **Automatic Refresh**: Tokens are refreshed automatically
- **Secure Storage**: Tokens are stored securely using Keychain (iOS) and Keystore (Android)

### 2. Data Encryption
- **In Transit**: All API calls use HTTPS/TLS
- **At Rest**: Sensitive data is encrypted in local storage
- **File Uploads**: Files are encrypted before upload

### 3. Input Validation
- **Client-side**: All inputs are validated before sending
- **Server-side**: Backend validates all incoming data
- **Sanitization**: User inputs are sanitized to prevent XSS

## Performance Optimizations

### 1. Caching Strategy
- **API Responses**: Cached for 5 minutes by default
- **Images**: Cached locally with LRU eviction
- **User Data**: Cached until logout or refresh

### 2. Network Optimization
- **Request Batching**: Multiple requests are batched when possible
- **Compression**: Gzip compression for API responses
- **Retry Logic**: Automatic retry for failed requests

### 3. Memory Management
- **Image Optimization**: Images are compressed and resized
- **List Virtualization**: Large lists use virtual scrolling
- **Memory Monitoring**: Memory usage is monitored and optimized

## Testing Integration

### 1. Unit Tests
- **Components**: All React components have unit tests
- **Services**: API and WebSocket services are tested
- **Utils**: Utility functions are thoroughly tested

### 2. Integration Tests
- **API Integration**: Tests for all API endpoints
- **WebSocket Integration**: Tests for real-time updates
- **Offline Integration**: Tests for offline functionality

### 3. E2E Tests
- **User Flows**: Complete user workflows are tested
- **Cross-platform**: Tests run on both iOS and Android
- **Performance**: Performance tests for critical paths

## Deployment Considerations

### 1. Build Configuration
- **Development**: Debug builds with logging enabled
- **Staging**: Release builds with limited logging
- **Production**: Optimized builds with minimal logging

### 2. App Store Deployment
- **iOS**: App Store Connect configuration
- **Android**: Google Play Console configuration
- **Updates**: Over-the-air updates for non-native changes

### 3. Monitoring
- **Crash Reporting**: Integrated crash reporting
- **Analytics**: User behavior analytics
- **Performance**: App performance monitoring

## Migration Strategy

### 1. Phase 1: Core Integration
- Deploy backend API modifications
- Deploy frontend with basic functionality
- Test authentication and basic data flow

### 2. Phase 2: Feature Rollout
- Enable real-time updates
- Add offline support
- Implement push notifications

### 3. Phase 3: Full Deployment
- Complete feature set
- Performance optimization
- User training and adoption

## Troubleshooting

### 1. Common Issues
- **Authentication Failures**: Check token expiry and refresh logic
- **WebSocket Disconnections**: Implement reconnection logic
- **Offline Sync Issues**: Check queue management and conflict resolution

### 2. Debug Tools
- **Redux DevTools**: For state debugging
- **Network Inspector**: For API call debugging
- **WebSocket Inspector**: For real-time debugging

### 3. Logging
- **Structured Logging**: All events are logged with context
- **Error Tracking**: Errors are tracked and reported
- **Performance Metrics**: Performance data is collected

## Conclusion

The React Native frontend is designed to integrate seamlessly with the existing MS5.0 backend system. The integration points are well-defined and the required modifications are minimal. The frontend provides a modern, tablet-optimized interface while maintaining compatibility with the existing backend architecture.
