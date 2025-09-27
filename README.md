# MS5.0 Floor Dashboard

## Overview

The MS5.0 Floor Dashboard is a comprehensive factory management system designed for tablet-based operations with role-based access control. This system provides real-time production monitoring, OEE calculations, Andon management, and comprehensive reporting capabilities.

## System Architecture

- **Backend**: FastAPI-based REST API with WebSocket support
- **Frontend**: React Native tablet application
- **Database**: PostgreSQL with TimescaleDB extension
- **Cache**: Redis for session management and caching
- **Monitoring**: Prometheus, Grafana, and AlertManager
- **PLC Integration**: Real-time PLC data processing and integration

## Key Features

### Production Management
- Real-time production line monitoring
- Job assignment and tracking
- Production scheduling and planning
- Quality management and defect tracking

### OEE Analytics
- Real-time OEE calculations
- Performance analytics and trends
- Equipment effectiveness monitoring
- Historical data analysis

### Andon System
- Machine stoppage alerts
- Escalation management
- Real-time notifications
- Response time tracking

### Role-Based Access Control
- Multi-role user management
- Permission-based access control
- Secure authentication and authorization
- Audit logging

## Project Structure

```
MS5.0_App/
├── backend/                 # FastAPI backend application
├── frontend/                # React Native frontend application
├── data/                    # CSV files and reference documents
├── documentation/           # Project documentation
│   ├── reports/            # Phase completion reports
│   ├── plans/              # Implementation plans
│   ├── analysis/           # Code analysis and work summaries
│   └── guides/             # User and deployment guides
├── scripts/                 # Deployment and utility scripts
├── tests/                   # Test suites and validation scripts
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   ├── e2e/                # End-to-end tests
│   ├── performance/        # Performance tests
│   ├── security/           # Security tests
│   └── phase_tests/        # Phase-specific test results
├── *.sql                    # Database schema files
└── README.md               # This file
```

## Quick Start

### Prerequisites

- Python 3.11+
- Node.js 16+
- PostgreSQL 15+
- Redis
- Docker & Docker Compose (optional)

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cp env.example .env
# Edit .env with your configuration
```

### Frontend Setup

```bash
cd frontend
npm install
cp .env.example .env
# Edit .env with your configuration
```

### Database Setup

```bash
# Create database
createdb factory_telemetry

# Run schema migrations
psql -d factory_telemetry -f 001_init_telemetry.sql
psql -d factory_telemetry -f 002_plc_equipment_management.sql
psql -d factory_telemetry -f 003_production_management.sql
psql -d factory_telemetry -f 004_advanced_production_features.sql
psql -d factory_telemetry -f 005_andon_escalation_system.sql
psql -d factory_telemetry -f 006_report_system.sql
psql -d factory_telemetry -f 007_plc_integration_phase1.sql
psql -d factory_telemetry -f 008_fix_critical_schema_issues.sql
psql -d factory_telemetry -f 009_database_optimization.sql
```

### Running the Application

```bash
# Start backend
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Start frontend
cd frontend
npm start
```

## Deployment

For production deployment, see the comprehensive deployment guide:

- [Deployment Guide](documentation/guides/DEPLOYMENT_GUIDE.md)
- [Step-by-Step Deployment Plan](DEPLOYMENT_PLAN.md)

## Testing

The project includes comprehensive test suites:

```bash
# Run all tests
cd tests
python -m pytest

# Run specific test categories
python -m pytest unit/
python -m pytest integration/
python -m pytest e2e/
python -m pytest performance/
python -m pytest security/
```

## Documentation

- [API Documentation](documentation/guides/API_DOCUMENTATION.md)
- [User Guide](documentation/guides/USER_GUIDE.md)
- [Troubleshooting Guide](documentation/guides/TROUBLESHOOTING_GUIDE.md)
- [Maintenance Procedures](documentation/guides/MAINTENANCE_PROCEDURES.md)

## Phase Completion Status

- ✅ **Phase 1**: PLC Integration Services (100% Complete)
- ✅ **Phase 2**: Real-time Integration (100% Complete)
- ✅ **Phase 3**: Backend Service Completion (100% Complete)
- ✅ **Phase 4**: Testing & Performance Optimization (100% Complete)
- ✅ **Phase 5**: Production Deployment & Validation (100% Complete)

## System Status

**Production Ready**: The MS5.0 Floor Dashboard is fully implemented and ready for production deployment with comprehensive testing, monitoring, and deployment infrastructure.

## Support

For support and maintenance procedures, see:
- [Support Procedures](documentation/guides/SUPPORT_PROCEDURES.md)
- [Training Materials](documentation/guides/TRAINING_MATERIALS.md)

## License

This project is proprietary software developed for factory management operations.
