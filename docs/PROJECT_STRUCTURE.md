# Project Structure & Architecture Guide — go-On

## 1. Executive Summary

**go-On** (formerly known as Attendance Marker / `am-oss`) is an enterprise-grade AI-powered facial recognition attendance and college management system. The project is engineered as a decoupled, multi-tier platform comprising:
- **FastAPI Asynchronous Backend** (`app/`): High-throughput REST API, SQLAlchemy 2.0 ORM, background class reminder scheduler, SCRFD-10G face detection, and ArcFace ResNet-50 embedding extraction.
- **Flutter Cross-Platform Mobile Application** (`mobile/`): Production Android and iOS client featuring adaptive themes, biometric login, offline-resilient sync, and push notifications via Firebase Cloud Messaging.
- **Responsive Web Portal** (`web/`): Vanilla HTML5/CSS3/JavaScript administrative dashboard and faculty control center with zero build-step overhead.
- **Zoho Catalyst AppSail Cloud Manifests** (`catalyst.json`, `app-config.json`, `scripts/run_catalyst.py`): Containerized serverless PaaS architecture.

---

## 2. Directory Map

```text
E:\originalam/
├── app-config.json                      # Zoho Catalyst AppSail execution manifest
├── catalyst.json                        # Zoho Catalyst project component manifest
├── requirements.txt                     # Python production & testing dependencies
├── pytest.ini                          # Pytest test discovery & execution configuration
├── alembic.ini                          # Database schema migration configuration
├── attendance_system.db                 # Primary production SQLite database (28.2 MB)
│
├── app/                                 # FastAPI Backend Service
│   ├── main.py                          # ASGI application factory, middleware, lifespans
│   ├── api/                             # API route controllers
│   │   ├── deps.py                      # Dependency injection (DB session, RBAC validation)
│   │   ├── auth.py                      # Authentication, session tokens, JWT issuing
│   │   ├── admin.py                     # Institutional administration & CRUD endpoints
│   │   ├── faculty.py                   # Faculty attendance & schedule endpoints
│   │   ├── student.py                   # Student profile, attendance history & leaves
│   │   ├── timetable.py                 # Academic schedule queries & slot resolvers
│   │   ├── attendance.py                # Attendance marking, verification & audit APIs
│   │   ├── notifications.py             # In-app notification center & FCM dispatch
│   │   └── recognition.py               # AI facial enrollment & recognition pipeline
│   ├── core/                            # System foundations
│   │   ├── config.py                    # Pydantic v2 settings & environment variables
│   │   ├── database.py                  # SQLAlchemy engine & sessionmaker factory
│   │   ├── security.py                  # Bcrypt password hashing, JWT signing & verification
│   │   ├── logging.py                   # Structured logger configuration
│   │   └── scheduler.py                 # Async Asia/Kolkata timetable notification loop
│   ├── models/                          # SQLAlchemy 2.0 ORM database entities
│   │   ├── user.py                      # User, Role, Department, Class models
│   │   ├── student.py                   # Student metadata & profile records
│   │   ├── faculty.py                   # Faculty profiles & subject assignments
│   │   ├── timetable.py                 # Period definitions, day orders, timetable slots
│   │   ├── attendance.py                # Attendance logs, sessions, and verification records
│   │   ├── notification.py              # Notification audit trails & user read states
│   │   └── embedding.py                 # 512-dimensional ArcFace vector storage
│   ├── schemas/                         # Pydantic validation & response schemas
│   │   ├── auth.py                      # Credentials, tokens, session payloads
│   │   ├── user.py                      # User creation & update schemas
│   │   ├── attendance.py                # Attendance submission & query schemas
│   │   ├── notification.py              # Push notification payloads
│   │   └── recognition.py               # Vector similarity & face verification schemas
│   └── engines/                         # Core domain logic & AI inference engines
│       ├── attendance_engine.py         # Business rules for period marking & presence validation
│       ├── timetable_engine.py          # Active period and day-order resolver
│       └── recognition/                 # Pluggable computer vision subsystem
│           ├── base.py                  # Abstract Base Class (BaseRecognitionEngine)
│           ├── scrfd_arcface.py         # ONNX Runtime detector (SCRFD) & extractor (ArcFace)
│           └── local_dlib.py            # Legacy dlib / face_recognition wrapper
│
├── mobile/                              # Flutter Cross-Platform Client
│   ├── pubspec.yaml                     # Dependencies (Provider, Dio, SharedPreferences, etc.)
│   ├── analysis_options.yaml            # Static linting rules
│   ├── android/                         # Android native project files
│   │   ├── app/src/main/AndroidManifest.xml # Permissions, activities, launch themes
│   │   ├── app/src/main/res/            # Native drawables, launch drawables, app icons
│   │   └── build.gradle                 # Gradle build scripts & SDK level configurations
│   ├── assets/                          # Static branding & visual assets
│   │   ├── splash/                      # High-res adaptive splash assets (gold logo, NEXAFO)
│   │   └── icons/                       # Vector & raster UI icons
│   ├── lib/                             # Application source code
│   │   ├── main.dart                    # Startup entrypoint, theme bootstrap, error boundary
│   │   ├── app.dart                     # MaterialApp routing & global theme configuration
│   │   ├── core/                        # Global helpers, network client, storage, theme tokens
│   │   ├── models/                      # Dart domain data classes
│   │   ├── providers/                   # State management (Auth, Theme, Attendance, Notification)
│   │   ├── screens/                     # UI Views (Login, Splash, Admin, Faculty, Student)
│   │   └── widgets/                     # Reusable UI components & custom progress indicators
│   └── test/                            # Flutter test suite (203 passing tests)
│
├── web/                                 # Zero-Build Browser Frontend
│   ├── index.html                       # Administrative single-page application
│   ├── login.html                       # Standalone browser authentication interface
│   ├── css/                             # Responsive modern stylesheet architecture
│   └── js/                              # Modular ES6 controllers for REST API consumption
│
├── scripts/                             # Operational & Deployment Automation
│   ├── run_catalyst.py                  # ASGI production launcher for Zoho Catalyst AppSail
│   ├── serve_web.py                     # Local lightweight static web server
│   ├── serve_apk.py                     # Local artifact & APK download portal
│   └── backup_database.py              # Automated SQLite / PostgreSQL snapshot utility
│
├── tests/                               # Backend Pytest Suite (38 passing tests)
│   ├── conftest.py                      # Test database fixtures & mocked authentication
│   ├── test_capacity_scale_5000.py      # Institutional 5,000-student stress benchmarks
│   ├── test_scrfd_arcface_engine.py     # ONNX model accuracy and vector distance tests
│   ├── test_security_audit_remediations.py # RBAC and authorization regression tests
│   └── test_push_delivery_and_system_tray.py # Notification dispatch tests
│
└── docs/                                # Institutional Documentation Hub
    ├── PROJECT_DISCOVERY.md             # Baseline discovery, versions, and deployment feasibility
    ├── STEP_BY_STEP_SETUP_AND_DEPLOYMENT.md # Beginner-to-production deployment guide
    ├── TEST_RESULTS.md                  # Comprehensive 278-test verification matrix
    ├── DEPLOYMENT_RUNBOOK.md            # Staging, production, and emergency response procedures
    ├── PROJECT_STRUCTURE.md             # This document
    ├── SECURITY_AND_DATA_HANDLING.md    # Cryptographic standards, PII, and biometric privacy
    ├── OPERATIONS_AND_MAINTENANCE.md    # Backup routines, scaling, and operational troubleshooting
    ├── CHANGELOG.md                     # Detailed release history and milestone transitions
    └── FINAL_PROJECT_REPORT.md          # Comprehensive executive engineering sign-off
```

---

## 3. Component Responsibilities & Invariants

### 3.1 Backend Service Layer (`app/`)
1. **Stateless Request Processing**: All business endpoints authenticate via cryptographically signed JWT bearer tokens or secure HttpOnly cookies.
2. **Database Abstraction**: Fully compatible with SQLite (development/staging) and PostgreSQL (high-concurrency production) using pure SQLAlchemy 2.0 syntax.
3. **Protected Engine Invariants**:
   - `app/engines/recognition/local_dlib.py`: Maintained as a baseline reference; not modified without backward compatibility tests.
   - `app/engines/attendance_engine.py`: Single source of truth for marking rules (grace periods, late cutoffs, attendance states).

### 3.2 Mobile Client Layer (`mobile/`)
1. **Theme Safety**: Theme state is initialized before UI rendering using `SharedPreferences`, completely eliminating theme flashing during cold starts.
2. **Adaptive Splash Flow**: Splash displays native brand branding while securely verifying authentication tokens in the background, transitioning immediately to the appropriate role dashboard.
3. **Resilient HTTP Communication**: Centralized Dio interceptor handles automated token refreshing, network timeouts, and offline error propagation.

### 3.3 Zoho Catalyst Deployment Layer
1. **AppSail Specification**: Configured via `app-config.json` running Python 3.11 with 2048 MB RAM to accommodate ONNX Runtime computer vision inference.
2. **Dynamic Port Discovery**: Handled transparently by `scripts/run_catalyst.py`, inspecting `$X_ZOHO_CATALYST_LISTEN_PORT` and `$PORT` without requiring environment modifications.
