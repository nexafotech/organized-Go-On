# COMPLETE PROJECT DISCOVERY REPORT

## EXECUTIVE SUMMARY & SYSTEM HEALTH METRICS

| Metric | Verified Value | Status / Notes |
|---|---|---|
| **Project Name** | Attendance Marker (`am-oss`) | Production Academic Attendance Platform |
| **Authoritative Root** | `C:\Users\Abishek\Desktop\am-oss` | Clean Local Repository |
| **Mobile Project Path** | `C:\Users\Abishek\Desktop\am-oss\mobile` | Multiplatform Flutter Client |
| **Backend Service** | `http://127.0.0.1:8000` | FastAPI ASGI Service (Live) |
| **Admin Web Console** | `http://127.0.0.1:8000/admin` | Vanilla JS SPA / Jinja2 (Live) |
| **Flutter Client UI** | `http://localhost:3000` | Flutter Web via Chrome localhost (Live) |
| **Overall System Health** | **100% OPERATIONAL** | All endpoints, databases, and UI pass QA |
| **Architecture Summary** | Dual-Frontend Monolith-API Architecture | Segregated Admin Web Console & Flutter Mobile/Web |
| **Total Major Features** | 16 Subsystems | Auth, RBAC, Periods, Timetable, Advisor, Face AI, etc. |
| **Role Count** | 4 Distinct Personas | ADMIN, FACULTY, CLASS_ADVISOR (elevated), STUDENT |
| **Screen / Tab Count** | 29 Total Screens/Tabs | 14 Admin Console Tabs + 15 Flutter UI Screens |
| **API Endpoint Count** | 142 Unique Routes | 80 GET, 48 POST, 14 PUT routes verified |
| **Database Model Count** | 17 Relational Tables | SQLite (`attendance_system.db`) with Foreign Keys |
| **Current Known Issues** | 7 Documented Nuances | Cataloged in Section 43 for redesign safety |

---

## 1. PROJECT OVERVIEW

### 1.1 Purpose & Mission
The **Attendance Marker (am-oss)** is a high-reliability, enterprise-grade attendance marking and academic schedule orchestration platform engineered for higher education institutions. The platform solves the fundamental challenges of institutional time-tracking: eliminating proxy attendance via computer vision facial recognition, enforcing authoritative institutional period schedules, distinguishing regular subject faculty duties from elevated Class Advisor responsibilities, mathematically deriving half-day attendance according to institutional accreditation norms, and providing end-to-end auditability.

### 1.2 System Architecture
The platform is structured as a **Dual-Frontend Monolith-API Architecture**:
1. **FastAPI Backend (`http://127.0.0.1:8000`)**: Core application server running on Python 3.10 and Uvicorn. Houses the REST API, SQLAlchemy ORM layer, authentication state machines, business rule policy engines, timetable resolution routines, and facial embedding comparison logic.
2. **Admin Management Web Console (`http://127.0.0.1:8000/admin`)**: A browser-native administrative workspace built using semantic HTML5 (`admin_panel.html`), CSS3 custom properties (`admin_style.css`), and modular Vanilla JavaScript (`admin_app.js`, 113 discrete functions). Served directly by FastAPI via Jinja2 templates. Dedicated to administrative governance, policy configuration, timetable management, user credential control, and data imports.
3. **Flutter Multiplatform Application (`http://localhost:3000`)**: A rich client application built with Dart and Flutter Web/Mobile. Dedicated to Students, Subject Faculty, and Class Advisors. Implements a sophisticated Milky Glass & Vibrant Orange (`#F97316`) dark theme visual design system (`AppTheme.darkTheme`).
4. **Biometric Face Recognition Subsystem**: Pluggable AI engine providing dual-mode face matching: Local Dlib (128-d Euclidean) and InsightFace SCRFD + ArcFace ONNX (512-d Cosine Similarity).
5. **SQLite Institutional Database (`attendance_system.db`)**: 17 relational tables governed by SQLAlchemy ORM with foreign keys and strict referential integrity.

### 1.3 Architecture Communication Diagram

```text
+---------------------------------------------------------------------------------------------------------+
|                                      ATTENDANCE MARKER (am-oss)                                         |
+---------------------------------------------------------------------------------------------------------+
|                                                                                                         |
|   [ FLUTTER CLIENT (Chrome Web/Mobile) ]                       [ ADMIN CONSOLE (Browser Web SPA) ]      |
|        http://localhost:3000                                        http://localhost:8000/admin         |
|   - Student Portal (Dash/TT/Profile/Face)                      - 14 Institutional Governance Tabs       |
|   - Faculty Portal (Dash/Sessions/Live Cam)                    - Vanilla JS (admin_app.js)              |
|   - Class Advisor Portal (P1-P7 Universal)                     - Jinja2 Template (admin_panel.html)     |
|                  |                                                            |                         |
|                  | REST JSON / Bearer JWT                                     | REST JSON / Cookie/Auth |
|                  +----------------------------+-------------------------------+                         |
|                                               |                                                         |
|                                               v                                                         |
|                          +------------------------------------------+                                   |
|                          |         FASTAPI BACKEND ENGINE           |                                   |
|                          |         http://127.0.0.1:8000            |                                   |
|                          +------------------------------------------+                                   |
|                          | - app.api.auth (JWT, Login, Lockout)     |                                   |
|                          | - app.api.student (Attendance, Profile)  |                                   |
|                          | - app.api.faculty (Sessions, Live Face)  |                                   |
|                          | - app.api.admin (CRUD, Timetable, Sync)  |                                   |
|                          | - app.engines.policy_engine (Half-Day)   |                                   |
|                          | - app.engines.attendance_engine (P1-P7)  |                                   |
|                          | - app.engines.recognition (Dlib/ArcFace) |                                   |
|                          +--------------------+---------------------+                                   |
|                                               |                                                         |
|                                               | SQLAlchemy ORM                                          |
|                                               v                                                         |
|                          +------------------------------------------+                                   |
|                          |       SQLITE DATABASE (17 Tables)        |                                   |
|                          |         attendance_system.db             |                                   |
|                          +------------------------------------------+                                   |
|                          | users, faculty, students, class_sections |                                   |
|                          | subjects, periods, timetable_entries     |                                   |
|                          | class_sessions, attendance_records       |                                   |
|                          | face_embeddings, attendance_policies     |                                   |
|                          | system_settings, audit_logs              |
|                          +------------------------------------------+
+---------------------------------------------------------------------------------------------------------+
```

## 2. REPOSITORY / DIRECTORY INVENTORY

### 2.1 Complete File Tree & Component Directory

```text
C:\Users\Abishek\Desktop\am-oss\
├── app/                          # FastAPI Backend Root
│   ├── api/                      # REST API Endpoints
│   │   ├── admin.py              # Administrative Management Endpoints (CRUD, Users, Roster)
│   │   ├── admin_enrollment.py   # Admin Face Enrollment Endpoints
│   │   ├── admin_sessions.py     # Admin Session Management & Override Endpoints
│   │   ├── admin_settings.py     # System Configuration & Attendance Policy Endpoints
│   │   ├── admin_web.py          # Admin Web Template Rendering (/admin route)
│   │   ├── auth.py               # Authentication, Tokens, Login, Logout, /me
│   │   ├── deps.py               # Dependency Injection (DB sessions, Current User, Roles)
│   │   ├── faculty.py            # Faculty Attendance Marking & Class Advisor Routes
│   │   ├── faculty_recognition.py# Faculty AI Camera Recognition Endpoints
│   │   ├── faculty_sessions.py   # Faculty Session Lifecycle Endpoints
│   │   └── student.py            # Student Attendance Reports, Profile, Face Capture
│   ├── core/                     # Application Infrastructure & Settings
│   │   ├── config.py             # Pydantic Settings, JWT secrets, paths
│   │   ├── database.py           # SQLAlchemy Engine, SessionLocal, Base
│   │   ├── datetime_utils.py     # Timezone-aware UTC helpers
│   │   └── security.py           # Bcrypt password hashing & JWT encoding/decoding
│   ├── engines/                  # Core Business Logic Engines
│   │   ├── attendance_engine.py  # Session lifecycle, manual entry, roster queries
│   │   ├── policy_engine.py      # Half-day derivations, recovery, percentage calculation
│   │   ├── timetable_engine.py   # Active slot resolution, schedule lookups
│   │   └── recognition/          # Facial Biometric Vector Engines
│   │       ├── base.py           # Abstract Base Recognition Engine
│   │       ├── factory.py        # Recognition Engine Factory & Dynamic Switcher
│   │       ├── local_dlib.py     # 128-d Dlib Euclidean Engine
│   │       └── scrfd_arcface.py  # 512-d SCRFD + ArcFace ONNX Engine
│   ├── models/                   # SQLAlchemy Relational Models (17 Tables)
│   │   ├── academic.py           # ClassSection, Subject, Period, TimetableEntry, FacultyAssignment
│   │   ├── attendance.py         # ClassSession, AttendanceRecord
│   │   ├── audit.py              # AuditLog
│   │   ├── policy.py             # AttendancePolicy, SystemSetting
│   │   ├── student.py            # Student, FaceEmbedding
│   │   └── user.py               # User, Faculty, PasswordChangeWindow, AdminSupportSession
│   ├── schemas/                  # Pydantic Request / Response Data Transfer Objects
│   │   ├── academic.py           # DTOs for Classes, Subjects, Timetable, Periods
│   │   ├── auth.py               # DTOs for Login, Token, UserOut, Password Changes
│   │   ├── faculty_attendance.py # DTOs for Faculty / Advisor Attendance Submissions
│   │   ├── policy.py             # DTOs for Policy updates & Percentage metrics
│   │   └── student.py            # DTOs for Student Profiles, Summaries, Roster
│   ├── services/                 # Institutional Onboarding & Import Services
│   │   ├── class1_onboarding_service.py # Seed importer for Class 1 (II Year Cyber Sec)
│   │   ├── class2_onboarding_service.py # Seed importer for Class 2 (III Year Cyber Sec)
│   │   ├── college_importer.py   # Bulk CSV/Excel Importer for Students/Faculty
│   │   └── face_pose_service.py  # Pitch/Yaw/Roll 3-Pose Validation Service
│   ├── static/                   # Static Assets for Admin Web Console
│   │   ├── css/admin_style.css   # Custom CSS for 14 Admin Console Tabs
│   │   └── js/admin_app.js       # Vanilla JS (113 functions) for Admin Console
│   └── templates/
│       └── admin_panel.html      # Jinja2 HTML Shell for Admin Console
├── mobile/                       # Flutter Cross-Platform Client Application
│   ├── lib/
│   │   ├── auth/
│   │   │   ├── screens/login_screen.dart          # Dual-Tab Login Screen (Student / Faculty)
│   │   │   ├── screens/splash_screen.dart         # Animated Splash & Session Restoration
│   │   │   └── widgets/change_password_dialog.dart# Modal Password Change Overlay
│   │   ├── core/
│   │   │   ├── config/api_config.dart             # API Base URLs, Dynamic Server Switcher
│   │   │   ├── network/api_client.dart            # HTTP Client Wrapper with JWT Interceptors
│   │   │   ├── storage/app_preferences.dart       # SharedPreferences Local Storage Helper
│   │   │   ├── storage/secure_storage.dart        # FlutterSecureStorage Token Storage
│   │   │   └── theme/app_theme.dart               # Milky Glass & Vibrant Orange Theme System
│   │   ├── faculty/
│   │   │   ├── screens/faculty_dashboard_screen.dart           # Faculty Dashboard & Class Advisor Card
│   │   │   ├── screens/faculty_attendance_screen.dart          # Subject Faculty Available Periods
│   │   │   ├── screens/faculty_attendance_entry_screen.dart    # Subject Faculty Roster Marking
│   │   │   ├── screens/faculty_class_advisor_screen.dart       # Class Advisor P1-P7 Overview
│   │   │   ├── screens/faculty_class_advisor_entry_screen.dart # Class Advisor Universal Marking
│   │   │   ├── screens/faculty_session_screen.dart             # Live Camera Session & OD Dialog
│   │   │   ├── screens/image_preview_screen.dart               # Captured Image Preview & Crop
│   │   │   ├── screens/recognition_review_screen.dart          # Biometric Match Confirmation List
│   │   │   └── screens/faculty_profile_screen.dart             # Faculty Profile & Password Window
│   │   ├── models/
│   │   │   ├── biometric_enrollment_model.dart
│   │   │   ├── faculty_attendance_model.dart
│   │   │   ├── faculty_model.dart
│   │   │   ├── recognition_model.dart
│   │   │   ├── student_model.dart
│   │   │   └── user_model.dart
│   │   ├── services/
│   │   │   ├── auth_service.dart                  # User Auth StateNotifier & Session
│   │   │   ├── biometric_enrollment_service.dart  # 3-Pose Validation & Capture Client
│   │   │   ├── face_detector_service.dart         # Client-side Pose Estimator
│   │   │   ├── faculty_service.dart               # Faculty API Client & Attendance State
│   │   │   └── student_service.dart               # Student Dashboard API Client
│   │   ├── student/
│   │   │   ├── screens/student_dashboard_screen.dart    # Student Dashboard (Stats, Subjects, Matrix)
│   │   │   ├── screens/student_timetable_screen.dart    # Student Daily/Weekly Timetable
│   │   │   ├── screens/student_profile_screen.dart      # Student Profile & Face Enrollment Entry
│   │   │   └── screens/biometric_enrollment_screen.dart # 3-Pose Guided Face Capture Flow
│   │   └── main.dart                                    # Flutter App Entrypoint & MultiProvider
│   └── test/                                            # Flutter Unit & Widget Test Suite (11 files)
├── tests/                                               # Backend Integration Test Suite (25 files)
└── attendance_system.db                                 # Authoritative SQLite Database
```

## 3. TECHNOLOGY STACK

### 3.1 Backend Technologies
- **Language**: Python 3.10.11
- **Framework**: FastAPI 0.110.0 (Asynchronous ASGI REST API framework)
- **Application Server**: Uvicorn 0.28.0 with standard async workers
- **Database ORM**: SQLAlchemy 2.0.28 (Declarative Base, relationship lazy-loading & cascades)
- **Database Engine**: SQLite 3.39+ with `PRAGMA foreign_keys = ON`
- **Validation & Serialization**: Pydantic v2 (Strict type checking, field constraints)
- **Cryptography**: PassLib 1.7.4 with Bcrypt (`passlib.context.CryptContext`); `python-jose` 3.3.0 for HMAC-SHA256 JWT tokens
- **Template Engine**: Jinja2 3.1.3 (Renders admin web console shell)
- **Data Processing**: Pandas 2.2.1, OpenPyXL 3.1.2 (Attendance excel reporting, CSV parsing)

### 3.2 Frontend Web Console (Admin)
- **Architecture**: Single Page Application (SPA) driven by hash routing (`#dashboard`, `#students`, etc.)
- **Scripting**: Vanilla ECMAScript 2022 (`admin_app.js`, 113 modular functions, 0 external JS dependencies)
- **Styling**: Modern Semantic CSS3 (`admin_style.css`) with CSS custom properties, grid layouts, and glassmorphism
- **Rendering**: HTML5 templates served via FastAPI Jinja2 template engine

### 3.3 Frontend Mobile / Web Application (Flutter)
- **Framework**: Flutter SDK 3.29.0 / Dart 3.7.0
- **State Management**: Provider 6.1.1 (`ChangeNotifierProvider`, `MultiProvider`)
- **Networking**: HTTP package 1.2.0 with custom JSON interceptors and error decoding
- **Local Storage**: `shared_preferences` 2.2.2 & `flutter_secure_storage` 9.0.0
- **Imaging & Camera**: `image_picker` 1.0.7 for cross-platform camera & gallery captures
- **Design Language**: Custom Milky Glass & Vibrant Orange (`AppTheme.darkTheme`) implementing Material 3

### 3.4 Computer Vision & Biometric Pipeline
- **OpenCV**: OpenCV-Python 4.9.0 (Frame decoding, RGB/BGR conversion, facial landmark alignment)
- **Engine A (Local Dlib)**: Dlib 19.24.2 + `face_recognition` (HOG/CNN face detection, 128-dimensional Euclidean distance vectors)
- **Engine B (Deep Learning ONNX)**: InsightFace SCRFD detector + ArcFace ResNet-100 ONNX model (`glintr100.onnx`, 512-dimensional Cosine Similarity embeddings)
- **Abstraction Layer**: `RecognitionEngineManager` with dynamic runtime engine fallback based on system settings

## 4. COMPLETE USER / ROLE MODEL

### 4.1 Role Definitions & Structural Distinctions

The system models access control around four distinct user personas. A critical architectural distinction exists between **Database Roles** (`UserRole` enum) and **Elevated Roles** (`Class Advisor`):

1. **ADMIN** (`UserRole.ADMIN`):
   - Stored in `users.role = 'ADMIN'`.
   - Unrestricted access to backend administration, academic structure, timetable matrices, settings, and bulk imports.
   - Uses the Admin Web Console (`http://localhost:8000/admin`).
2. **FACULTY** (`UserRole.FACULTY`):
   - Stored in `users.role = 'FACULTY'`.
   - Has an associated profile row in `faculty` table linked via `faculty.user_id = users.id`.
   - Can view personal teaching schedule, start live camera sessions for assigned classes, and mark/submit period attendance for assigned subjects on today and yesterday.
3. **CLASS ADVISOR** (Elevated Faculty Role):
   - **IMPORTANT ARCHITECTURAL RULE**: `CLASS_ADVISOR` is **NOT** a separate value in `UserRole` enum. In `users.role`, the advisor is strictly stored as `FACULTY`.
   - A faculty member becomes a Class Advisor when their `faculty.id` is designated as `class_sections.class_advisor_id`.
   - During authentication (`POST /api/v1/auth/login` and `GET /api/v1/auth/me`), the backend checks if `class_sections.class_advisor_id == faculty.id`. If yes, the user token/profile includes `is_class_advisor: true` and `advised_class_id: <id>`.
   - Class Advisors possess universal period attendance authority (P1 through P7) over **every student in their assigned class section**, regardless of who taught the period, for both today and yesterday.
4. **STUDENT** (`UserRole.STUDENT`):
   - Stored in `users.role = 'STUDENT'`.
   - Has an associated profile row in `students` table linked via `students.user_id = users.id`.
   - Can view personal attendance percentage, daily half-day statuses, subject-wise statistics, date-wise P1-P7 attendance grid, class timetable, and perform guided 3-pose facial biometric enrollment.

## 5. USER / ACCOUNT INVENTORY

- **Total Registered User Accounts**: 128
- **Admin Accounts**: 1
- **Faculty Accounts**: 8
- **Student Accounts**: 119

### 5.1 Account Roster Overview
> **Security Notice**: In compliance with strict auditing guidelines, all plaintext passwords, password hashes, and sensitive JWT tokens have been omitted. 'Password exists but sensitive value omitted' is recorded for every account.

| User ID | Username / Login Identifier | Role | Associated Name | Class / Scope | Status | Password Credential |
|---|---|---|---|---|---|---|
| 1 | `admin` | ADMIN | Administrator | All Institutional Entities | ACTIVE | Password exists but sensitive value omitted |
| 4 | `FAC01` | FACULTY (CLASS ADVISOR) | Mathu Metlda | Advisor: II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 5 | `FAC02` | FACULTY | Showmiya | Faculty (CSE Cyber Security) | ACTIVE | Password exists but sensitive value omitted |
| 6 | `FAC03` | FACULTY | Sivakumar | Faculty (CSE Cyber Security) | ACTIVE | Password exists but sensitive value omitted |
| 7 | `FAC04` | FACULTY | Shankar | Faculty (CSE Cyber Security) | ACTIVE | Password exists but sensitive value omitted |
| 8 | `FAC05` | FACULTY | Santhiya | Faculty (CSE Cyber Security) | ACTIVE | Password exists but sensitive value omitted |
| 9 | `FAC06` | FACULTY | Lakshmi Narayanan | Faculty (CSE Cyber Security) | ACTIVE | Password exists but sensitive value omitted |
| 10 | `FAC07` | FACULTY | Princy | Faculty (CSE Cyber Security) | ACTIVE | Password exists but sensitive value omitted |
| 11 | `FAC08` | FACULTY | Gowri Manohari | Faculty (CSE Cyber Security) | ACTIVE | Password exists but sensitive value omitted |
| 12 | `721025149001` | STUDENT | ABINAYA B | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 13 | `721025149002` | STUDENT | ABISHEK A | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 14 | `721025149003` | STUDENT | AKASH K | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 15 | `721025149004` | STUDENT | ANANTHA BALAJI M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 16 | `721025149005` | STUDENT | ARUL ROSHAN A M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 17 | `721025149006` | STUDENT | ARUN PRASATH K | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 18 | `721025149007` | STUDENT | ASHVITHA P | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 19 | `721025149008` | STUDENT | ASWAJITH P V | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 20 | `721025149009` | STUDENT | ASWIN M G | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 21 | `721025149010` | STUDENT | BHARANIDHARAN V | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 22 | `721025149011` | STUDENT | BHUVANESWARI S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 23 | `721025149012` | STUDENT | DEEPIKA L | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 24 | `721025149013` | STUDENT | DHAMARAI SELVAN M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 25 | `721025149014` | STUDENT | DHARANEESH RAM S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 26 | `721025149015` | STUDENT | DHARANI KUMAR K | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 27 | `721025149016` | STUDENT | DHARSINI B | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 28 | `721025149017` | STUDENT | DHEV ANANTH M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 29 | `721025149018` | STUDENT | DUVARAKESH B | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 30 | `721025149019` | STUDENT | GUNAL B | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 31 | `721025149020` | STUDENT | HARISH SN | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 32 | `721025149021` | STUDENT | HARSHAVARTHAN M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 33 | `721025149022` | STUDENT | HARSHINI PRIYA P | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 34 | `721025149023` | STUDENT | INIYA PRASANTH ARUNAGIRI | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 35 | `721025149024` | STUDENT | JEGADHESAN P | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 36 | `721025149025` | STUDENT | JITHISH A | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 37 | `721025149026` | STUDENT | KAJENDRAN T | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 38 | `721025149027` | STUDENT | KRITHIK R M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 39 | `721025149028` | STUDENT | LAVANYA A | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 40 | `721025149029` | STUDENT | MAHESHWARAN M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 41 | `721025149030` | STUDENT | MANIBARATH R | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 42 | `721025149031` | STUDENT | MANOJ KUMAR K | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 43 | `721025149032` | STUDENT | MOHAMED ESHAK R | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 44 | `721025149033` | STUDENT | MOHAMED SAFIVUDEEN S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 45 | `721025149034` | STUDENT | MOHAMED SHARIF A | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 46 | `721025149035` | STUDENT | MOHAMMED ARSATH A | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 47 | `721025149036` | STUDENT | MOHANA LAKSHMI C | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 48 | `721025149037` | STUDENT | MUHAMMED NIDHAN T | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 49 | `721025149038` | STUDENT | NAVANITHA M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 50 | `721025149039` | STUDENT | NAVEEN KUMAR M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 51 | `721025149040` | STUDENT | NITHEASH S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 52 | `721025149041` | STUDENT | PAVATHARINI S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 53 | `721025149042` | STUDENT | PRAGATHEESWARAN M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 54 | `721025149043` | STUDENT | PRAKASH B | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 55 | `721025149044` | STUDENT | PRAVIN KUMAR C | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 56 | `721025149045` | STUDENT | PRIYA | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 57 | `721025149046` | STUDENT | RETHISH S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 58 | `721025149047` | STUDENT | RITHANYA SHREE V | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 59 | `721025149048` | STUDENT | ROSHAN BRITTO S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 60 | `721025149049` | STUDENT | SAMIKSHA A | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 61 | `721025149050` | STUDENT | SANJAY M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 62 | `721025149051` | STUDENT | SATHISH KUMAR P | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 63 | `721025149052` | STUDENT | SELVAM R | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 64 | `721025149053` | STUDENT | SELVAPRIYA S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 65 | `721025149054` | STUDENT | SHARAFATH ROSHAN S | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 66 | `721025149055` | STUDENT | SHRI RAM P | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 67 | `721025149056` | STUDENT | SONIYA KUMARI RN | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 68 | `721025149057` | STUDENT | SRAVAN P V | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 69 | `721025149058` | STUDENT | SUSIL V | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 70 | `721025149059` | STUDENT | THIBHIKSHA M | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 71 | `721025149060` | STUDENT | VISHAL R | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 72 | `721025149061` | STUDENT | VISHNU PRASAD | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 73 | `721025149062` | STUDENT | YUSUFSHA J | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 74 | `721025149063` | STUDENT | YUVA SHRI P | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 75 | `721025149301` | STUDENT | Akhil | II Year CSE Cyber Security - Class 1 | ACTIVE | Password exists but sensitive value omitted |
| 76 | `721024149001` | STUDENT | AKASH A | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 77 | `721024149002` | STUDENT | AKASH RA | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 78 | `721024149004` | STUDENT | ANITHISH S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 79 | `721024149005` | STUDENT | ANUSUYA S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 80 | `721024149006` | STUDENT | ASHLIN KISHO C | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 81 | `721024149007` | STUDENT | AZHAGUSIVA R | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 82 | `721024149008` | STUDENT | BALAJI V | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 83 | `721024149010` | STUDENT | CHANDRA KUMAR S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 84 | `721024149011` | STUDENT | DARSHANA A K | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 85 | `721024149012` | STUDENT | DEEPAK KUMAR V | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 86 | `721024149013` | STUDENT | DHANIKA S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 87 | `721024149014` | STUDENT | DHANUSH G | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 88 | `721024149015` | STUDENT | DHARANEESH S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 89 | `721024149016` | STUDENT | ENIYAVAN M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 90 | `721024149017` | STUDENT | GOKULNATH C | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 91 | `721024149018` | STUDENT | GOKULNATH J S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 92 | `721024149019` | STUDENT | GOWSALYA T | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 93 | `721024149020` | STUDENT | GOWTHAM E | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 94 | `721024149021` | STUDENT | HARIPRASATH M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 95 | `721024149022` | STUDENT | HARSHA V | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 96 | `721024149023` | STUDENT | JOSHIKA S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 97 | `721024149024` | STUDENT | KANAGAVEL A | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 98 | `721024149025` | STUDENT | KARTHICK K U | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 99 | `721024149026` | STUDENT | KAVIN M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 100 | `721024149027` | STUDENT | KIRUBANATHAM S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 101 | `721024149029` | STUDENT | KOWSHICK M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 102 | `721024149030` | STUDENT | KUMARAGURUBARAN M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 103 | `721024149031` | STUDENT | MADHAN RAJ K | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 104 | `721024149032` | STUDENT | MADHESH K | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 105 | `721024149033` | STUDENT | MELVIN AMALAN D | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 106 | `721024149034` | STUDENT | MOHANRAJ K | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 107 | `721024149035` | STUDENT | MUTHUMANI S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 108 | `721024149036` | STUDENT | NANDA KUMAR M S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 109 | `721024149037` | STUDENT | NAVEEN KUMAR C | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 110 | `721024149038` | STUDENT | PERINBAN A | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 111 | `721024149039` | STUDENT | PRASANNA D | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 112 | `721024149040` | STUDENT | PRASANNA GANESH T | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 113 | `721024149041` | STUDENT | PRASANTH A | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 114 | `721024149042` | STUDENT | RAHUL RAJ M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 115 | `721024149043` | STUDENT | RAJESH A | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 116 | `721024149044` | STUDENT | SAM JOHN PAUL D | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 117 | `721024149045` | STUDENT | SANJAY PRIYADARSAN | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 118 | `721024149046` | STUDENT | SANKARAN M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 119 | `721024149047` | STUDENT | SARUNEESHWARI V | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 120 | `721024149049` | STUDENT | SREEHARI P | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 121 | `721024149050` | STUDENT | SRIDHARAN S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 122 | `721024149051` | STUDENT | SUBESH S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 123 | `721024149052` | STUDENT | SUGIRTHAN S | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 124 | `721024149053` | STUDENT | SUJITH J | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 125 | `721024149054` | STUDENT | SYED SALMAN S A | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 126 | `721024149055` | STUDENT | THARANI M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 127 | `721024149056` | STUDENT | VIJI M | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 128 | `721024149057` | STUDENT | VISHNU DEVAN G | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 129 | `721024149058` | STUDENT | YOGESWARAN A | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |
| 130 | `721024149059` | STUDENT | YUVARANI C | III Year CSE Cyber Security - Class 2 | ACTIVE | Password exists but sensitive value omitted |

## 6. FACULTY ACCOUNT INVENTORY

| Faculty ID | Employee ID | Full Name | Department | Email | User ID | Class Advisor Assignment |
|---|---|---|---|---|---|---|
| 3 | `FAC01` | Mathu Metlda | CSE Cyber Security | fac01@college.edu | 4 | **YES** - Class ID 4 (II Year CSE Cyber Security - Class 1) |
| 4 | `FAC02` | Showmiya | CSE Cyber Security | fac02@college.edu | 5 | None (Subject Faculty) |
| 5 | `FAC03` | Sivakumar | CSE Cyber Security | fac03@college.edu | 6 | None (Subject Faculty) |
| 6 | `FAC04` | Shankar | CSE Cyber Security | fac04@college.edu | 7 | None (Subject Faculty) |
| 7 | `FAC05` | Santhiya | CSE Cyber Security | fac05@college.edu | 8 | None (Subject Faculty) |
| 8 | `FAC06` | Lakshmi Narayanan | CSE Cyber Security | fac06@college.edu | 9 | None (Subject Faculty) |
| 9 | `FAC07` | Princy | CSE Cyber Security | fac07@college.edu | 10 | None (Subject Faculty) |
| 10 | `FAC08` | Gowri Manohari | CSE Cyber Security | fac08@college.edu | 11 | None (Subject Faculty) |

## 7. STUDENT DATA INVENTORY

- **Total Enrolled Students**: 119
- **Enrolled in Class 4 (II Year CSE Cyber Security - Class 1)**: 64
- **Enrolled in Class 5 (III Year CSE Cyber Security - Class 2)**: 55

### 7.1 Student Roster Breakdown
| Student ID | Roll / Register Number | Full Name | Class Section | Semester | Dept | Account Status |
|---|---|---|---|---|---|---|
| 1 | `721025149001` | ABINAYA B | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 2 | `721025149002` | ABISHEK A | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 3 | `721025149003` | AKASH K | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 4 | `721025149004` | ANANTHA BALAJI M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 5 | `721025149005` | ARUL ROSHAN A M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 6 | `721025149006` | ARUN PRASATH K | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 7 | `721025149007` | ASHVITHA P | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 8 | `721025149008` | ASWAJITH P V | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 9 | `721025149009` | ASWIN M G | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 10 | `721025149010` | BHARANIDHARAN V | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 11 | `721025149011` | BHUVANESWARI S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 12 | `721025149012` | DEEPIKA L | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 13 | `721025149013` | DHAMARAI SELVAN M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 14 | `721025149014` | DHARANEESH RAM S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 15 | `721025149015` | DHARANI KUMAR K | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 16 | `721025149016` | DHARSINI B | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 17 | `721025149017` | DHEV ANANTH M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 18 | `721025149018` | DUVARAKESH B | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 19 | `721025149019` | GUNAL B | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 20 | `721025149020` | HARISH SN | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 21 | `721025149021` | HARSHAVARTHAN M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 22 | `721025149022` | HARSHINI PRIYA P | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 23 | `721025149023` | INIYA PRASANTH ARUNAGIRI | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 24 | `721025149024` | JEGADHESAN P | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 25 | `721025149025` | JITHISH A | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 26 | `721025149026` | KAJENDRAN T | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 27 | `721025149027` | KRITHIK R M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 28 | `721025149028` | LAVANYA A | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 29 | `721025149029` | MAHESHWARAN M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 30 | `721025149030` | MANIBARATH R | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 31 | `721025149031` | MANOJ KUMAR K | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 32 | `721025149032` | MOHAMED ESHAK R | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 33 | `721025149033` | MOHAMED SAFIVUDEEN S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 34 | `721025149034` | MOHAMED SHARIF A | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 35 | `721025149035` | MOHAMMED ARSATH A | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 36 | `721025149036` | MOHANA LAKSHMI C | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 37 | `721025149037` | MUHAMMED NIDHAN T | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 38 | `721025149038` | NAVANITHA M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 39 | `721025149039` | NAVEEN KUMAR M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 40 | `721025149040` | NITHEASH S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 41 | `721025149041` | PAVATHARINI S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 42 | `721025149042` | PRAGATHEESWARAN M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 43 | `721025149043` | PRAKASH B | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 44 | `721025149044` | PRAVIN KUMAR C | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 45 | `721025149045` | PRIYA | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 46 | `721025149046` | RETHISH S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 47 | `721025149047` | RITHANYA SHREE V | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 48 | `721025149048` | ROSHAN BRITTO S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 49 | `721025149049` | SAMIKSHA A | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 50 | `721025149050` | SANJAY M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 51 | `721025149051` | SATHISH KUMAR P | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 52 | `721025149052` | SELVAM R | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 53 | `721025149053` | SELVAPRIYA S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 54 | `721025149054` | SHARAFATH ROSHAN S | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 55 | `721025149055` | SHRI RAM P | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 56 | `721025149056` | SONIYA KUMARI RN | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 57 | `721025149057` | SRAVAN P V | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 58 | `721025149058` | SUSIL V | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 59 | `721025149059` | THIBHIKSHA M | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 60 | `721025149060` | VISHAL R | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 61 | `721025149061` | VISHNU PRASAD | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 62 | `721025149062` | YUSUFSHA J | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 63 | `721025149063` | YUVA SHRI P | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 64 | `721025149301` | Akhil | Class 1 (II Year) | 3 | CSE Cyber Security | ACTIVE |
| 65 | `721024149001` | AKASH A | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 66 | `721024149002` | AKASH RA | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 67 | `721024149004` | ANITHISH S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 68 | `721024149005` | ANUSUYA S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 69 | `721024149006` | ASHLIN KISHO C | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 70 | `721024149007` | AZHAGUSIVA R | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 71 | `721024149008` | BALAJI V | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 72 | `721024149010` | CHANDRA KUMAR S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 73 | `721024149011` | DARSHANA A K | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 74 | `721024149012` | DEEPAK KUMAR V | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 75 | `721024149013` | DHANIKA S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 76 | `721024149014` | DHANUSH G | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 77 | `721024149015` | DHARANEESH S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 78 | `721024149016` | ENIYAVAN M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 79 | `721024149017` | GOKULNATH C | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 80 | `721024149018` | GOKULNATH J S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 81 | `721024149019` | GOWSALYA T | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 82 | `721024149020` | GOWTHAM E | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 83 | `721024149021` | HARIPRASATH M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 84 | `721024149022` | HARSHA V | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 85 | `721024149023` | JOSHIKA S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 86 | `721024149024` | KANAGAVEL A | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 87 | `721024149025` | KARTHICK K U | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 88 | `721024149026` | KAVIN M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 89 | `721024149027` | KIRUBANATHAM S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 90 | `721024149029` | KOWSHICK M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 91 | `721024149030` | KUMARAGURUBARAN M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 92 | `721024149031` | MADHAN RAJ K | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 93 | `721024149032` | MADHESH K | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 94 | `721024149033` | MELVIN AMALAN D | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 95 | `721024149034` | MOHANRAJ K | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 96 | `721024149035` | MUTHUMANI S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 97 | `721024149036` | NANDA KUMAR M S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 98 | `721024149037` | NAVEEN KUMAR C | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 99 | `721024149038` | PERINBAN A | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 100 | `721024149039` | PRASANNA D | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 101 | `721024149040` | PRASANNA GANESH T | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 102 | `721024149041` | PRASANTH A | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 103 | `721024149042` | RAHUL RAJ M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 104 | `721024149043` | RAJESH A | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 105 | `721024149044` | SAM JOHN PAUL D | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 106 | `721024149045` | SANJAY PRIYADARSAN | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 107 | `721024149046` | SANKARAN M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 108 | `721024149047` | SARUNEESHWARI V | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 109 | `721024149049` | SREEHARI P | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 110 | `721024149050` | SRIDHARAN S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 111 | `721024149051` | SUBESH S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 112 | `721024149052` | SUGIRTHAN S | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 113 | `721024149053` | SUJITH J | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 114 | `721024149054` | SYED SALMAN S A | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 115 | `721024149055` | THARANI M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 116 | `721024149056` | VIJI M | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 117 | `721024149057` | VISHNU DEVAN G | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 118 | `721024149058` | YOGESWARAN A | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |
| 119 | `721024149059` | YUVARANI C | Class 2 (III Year) | 5 | CSE Cyber Security | ACTIVE |

## 8. CLASS / SECTION INVENTORY

| Class ID | Class Name | Academic Year | Grade Level | Student Strength | Assigned Class Advisor |
|---|---|---|---|---|---|
| 4 | **II Year CSE Cyber Security - Class 1** | 2026-2027 | II Year | 64 Students | Mathu Metlda (`FAC01`, Faculty ID: 3) |
| 5 | **III Year CSE Cyber Security - Class 2** | 2026-2027 | III Year | 55 Students | *UNASSIGNED* |

## 9. SUBJECT INVENTORY

- **Total Subjects Configured**: 27

| Subject ID | Code | Subject Name | Description / Notes |
|---|---|---|---|
| 10 | `FDS` | Foundations of Data Science | Core Academic Course |
| 11 | `DMC` | Discrete Mathematics for Computing | Core Academic Course |
| 12 | `FDS LAB` | Foundations of Data Science Laboratory | Core Academic Course |
| 13 | `DPCO` | Digital Principles & Computer Organization | Core Academic Course |
| 14 | `OOPS` | Object Oriented Programming Systems | Core Academic Course |
| 15 | `DS` | Data Structures | Core Academic Course |
| 16 | `ACE-I` | Aptitude & Communication Enhancement I | Core Academic Course |
| 17 | `UHV` | Universal Human Values | Core Academic Course |
| 18 | `IKS` | Indian Knowledge System | Core Academic Course |
| 19 | `DS LAB` | Data Structures Laboratory | Core Academic Course |
| 20 | `IIC` | Innovation & Incubation Cell | Core Academic Course |
| 21 | `JAVA LAB` | Java Programming Laboratory | Core Academic Course |
| 22 | `TWM` | Tutor Ward Meeting | Core Academic Course |
| 23 | `LIB` | Library Hour | Core Academic Course |
| 24 | `ASSOC` | Department Association Hour | Core Academic Course |
| 25 | `AIML` | Artificial Intelligence & Machine Learning | Core Academic Course |
| 26 | `LP` | Linux Programming | Core Academic Course |
| 27 | `SDBMS` | Secure Database Management Systems | Core Academic Course |
| 28 | `ESSS` | Engineering Secure Software Systems | Core Academic Course |
| 29 | `SDBMS LAB` | Secure Database Management Systems Lab | Core Academic Course |
| 30 | `CC` | Cloud Computing | Core Academic Course |
| 31 | `E&I` | Entrepreneurship and Innovation | Core Academic Course |
| 32 | `CC-I` | Campus to Corporate-I | Core Academic Course |
| 33 | `LINUX LAB` | Linux Laboratory | Core Academic Course |
| 34 | `ESSS LAB` | Engineering Secure Software Systems Laboratory | Core Academic Course |
| 35 | `CF` | Cyber Forensics | Core Academic Course |
| 36 | `CF LAB` | Cyber Forensics Laboratory | Core Academic Course |

## 10. FACULTY ASSIGNMENT INVENTORY

- **Total Teaching Assignments**: 30

| Assignment ID | Faculty Member | Employee ID | Subject Code & Name | Class Section | Created At |
|---|---|---|---|---|---|
| 10 | Princy | `FAC07` | `DMC` Discrete Mathematics for Computing | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 11 | Showmiya | `FAC02` | `DS` Data Structures | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 12 | Sivakumar | `FAC03` | `OOPS` Object Oriented Programming Systems | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 13 | Lakshmi Narayanan | `FAC06` | `DPCO` Digital Principles & Computer Organization | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 14 | Santhiya | `FAC05` | `FDS` Foundations of Data Science | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 15 | Showmiya | `FAC02` | `DS LAB` Data Structures Laboratory | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 16 | Sivakumar | `FAC03` | `JAVA LAB` Java Programming Laboratory | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 17 | Gowri Manohari | `FAC08` | `ACE-I` Aptitude & Communication Enhancement I | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 18 | Santhiya | `FAC05` | `UHV` Universal Human Values | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 19 | Santhiya | `FAC05` | `LIB` Library Hour | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 20 | Santhiya | `FAC05` | `IIC` Innovation & Incubation Cell | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 21 | Mathu Metlda | `FAC01` | `TWM` Tutor Ward Meeting | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 22 | Santhiya | `FAC05` | `ASSOC` Department Association Hour | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 24 | Santhiya | `FAC05` | `IKS` Indian Knowledge System | II Year CSE Cyber Security - Class 1 | 2026-09-27 |
| 25 | Santhiya | `FAC05` | `CF` Cyber Forensics | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 26 | Shankar | `FAC04` | `SDBMS` Secure Database Management Systems | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 27 | Mathu Metlda | `FAC01` | `CC` Cloud Computing | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 28 | Sivakumar | `FAC03` | `LP` Linux Programming | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 29 | Shankar | `FAC04` | `AIML` Artificial Intelligence & Machine Learning | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 30 | Showmiya | `FAC02` | `ESSS` Engineering Secure Software Systems | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 31 | Shankar | `FAC04` | `SDBMS LAB` Secure Database Management Systems Lab | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 32 | Sivakumar | `FAC03` | `CC-I` Campus to Corporate-I | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 33 | Showmiya | `FAC02` | `E&I` Entrepreneurship and Innovation | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 34 | Showmiya | `FAC02` | `LIB` Library Hour | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 35 | Faculty None | `N/A` | `TWM` Tutor Ward Meeting | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 36 | Showmiya | `FAC02` | `IIC` Innovation & Incubation Cell | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 37 | Faculty None | `N/A` | `LINUX LAB` Linux Laboratory | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 38 | Faculty None | `N/A` | `CF LAB` Cyber Forensics Laboratory | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 39 | Faculty None | `N/A` | `ESSS LAB` Engineering Secure Software Systems Laboratory | III Year CSE Cyber Security - Class 2 | 2026-09-27 |
| 40 | Santhiya | `FAC05` | `FDS LAB` Foundations of Data Science Laboratory | II Year CSE Cyber Security - Class 1 | 2026-09-28 |

## 11. TIMETABLE SYSTEM

The institution operates an 84-slot timetable matrix covering a 6-day academic cycle (Monday through Saturday) across Class 4 and Class 5.

- **Total Timetable Entries**: 84
- **Daily Structure**: Monday to Saturday, Periods 1 through 7.
- **Resolution Mechanics**: When faculty marks attendance or checks active slots, `timetable_engine.py` maps the current day of the week (`datetime.now().strftime('%A').upper()`) and current time to resolve active or upcoming periods.

## 12. PERIOD TIMINGS

### 12.1 Authoritative College Schedule

| Period Slot | Start Time | End Time | Duration | Session Phase | Attendance Allowed? |
|---|---|---|---|---|---|
| **P1 (Period 1)** | 09:10 AM | 10:00 AM | 50 min | MORNING HALF | **YES** |
| **P2 (Period 2)** | 10:00 AM | 10:50 AM | 50 min | MORNING HALF | **YES** |
| *Short Break* | 10:50 AM | 11:10 AM | 20 min | RECESS | **NO (Excluded)** |
| **P3 (Period 3)** | 11:10 AM | 12:00 PM | 50 min | MORNING HALF | **YES** |
| **P4 (Period 4)** | 12:00 PM | 12:50 PM | 50 min | MORNING HALF | **YES** |
| *Lunch Break* | 12:50 PM | 01:40 PM | 50 min | LUNCH RECESS | **NO (Strictly Excluded)** |
| **P5 (Period 5)** | 01:40 PM | 02:30 PM | 50 min | AFTERNOON HALF | **YES** |
| **P6 (Period 6)** | 02:30 PM | 03:20 PM | 50 min | AFTERNOON HALF | **YES** |
| **P7 (Period 7)** | 03:20 PM | 04:10 PM | 50 min | AFTERNOON HALF | **YES** |
| *College Day Ends* | 04:10 PM | -- | -- | END OF DAY | **NO (No P8/P9)** |

## 13. LUNCH BREAK IMPLEMENTATION

- **Time Window**: 12:50 PM to 01:40 PM (50 minutes).
- **Database Storage**: Lunch break is NOT stored as a period in the `periods` table. Only valid academic periods P1 through P7 exist.
- **Attendance Engine Enforcement**: Any attempt to start a session, create a timetable slot, or record attendance during 12:50 PM - 01:40 PM is rejected with HTTP 400 Bad Request.
- **Policy Engine Exclusion**: Lunch break is completely excluded from the attendance calculation denominator. It has zero weight and zero impact on percentage or half-day derivation.
- **UI Rendering**: The timetable grid and daily schedule render an explicit, greyed-out 'Lunch Break (12:50 - 1:40)' separator card with no marking buttons.

## 14. ATTENDANCE ARCHITECTURE

The platform employs a two-tier relational model for attendance tracking:
1. **`class_sessions` Table**: Represents an academic session occurrence for a given timetable slot on a specific calendar date.
   - Columns: `id`, `timetable_entry_id`, `faculty_id`, `date`, `status` (`ACTIVE`, `COMPLETED`, `CANCELLED`), `start_timestamp`, `end_timestamp`, `created_at`.
2. **`attendance_records` Table**: Represents the individual student attendance record within a class session.
   - Columns: `id`, `session_id`, `student_id`, `status` (`PRESENT`, `ABSENT`, `OD`, `UNCERTAIN`), `confidence`, `recognized_via` (`MANUAL`, `AI_CAMERA`, `ADMIN_OVERRIDE`), `review_status`, `od_reason`, `marked_by_user_id`, `marked_at`, `updated_at`.
3. **Roster Initialization**: When a session is created or opened for marking, the system automatically initializes attendance rows for all enrolled active students in that class section, defaulting unmarked students to `NOT_ENTERED` or `ABSENT` per policy.

## 15. ATTENDANCE STATUSES

| Status Name | DB Enum Value | Meaning | Percentage Impact | Color in AppTheme |
|---|---|---|---|---|
| **Present** | `PRESENT` | Student physically present and marked | +1 to numerator & denominator | `AppTheme.statusPresent` (`#10B981` Emerald) |
| **Absent** | `ABSENT` | Student absent from period | +0 to numerator, +1 to denominator | `AppTheme.statusAbsent` (`#EF4444` Coral Red) |
| **On Duty** | `OD` | Approved institutional representation | Configurable (Default: Count as Present) | `AppTheme.statusOd` (`#F97316` Orange) |
| **Uncertain** | `UNCERTAIN` | Face match confidence below threshold | Pending faculty review | `AppTheme.statusUncertain` (`#EAB308` Yellow) |
| **Not Entered** | `NOT_ENTERED` | Period session not yet marked | Excluded or Unmarked Behavior | `AppTheme.textMuted` (`#9CA3AF` Grey) |

## 16. HALF-DAY SYSTEM

### 16.1 Mathematical Formulation (`policy_engine.py`)
The institutional day is split into two halves separated by Lunch Break:
- **Morning Half**: Periods P1, P2, P3, P4 (`scheduled_morning_count = 4`).
  - Present Threshold: `ceil(4 / 2.0) = 2` periods present.
- **Afternoon Half**: Periods P5, P6, P7 (`scheduled_afternoon_count = 3`).
  - Present Threshold: `ceil(3 / 2.0) = 2` periods present.

### 16.2 Daily Outcome Derivation Matrix
| Morning Status (P1-P4) | Afternoon Status (P5-P7) | Final Daily Derived Attendance |
|---|---|---|
| PRESENT (>= 2 present) | PRESENT (>= 2 present) | **FULL DAY PRESENT** |
| ABSENT (< 2 present) | ABSENT (< 2 present) | **FULL DAY ABSENT** |
| PRESENT (>= 2 present) | ABSENT (< 2 present) | **HALF-DAY PRESENT** |
| ABSENT (< 2 present) | PRESENT (>= 2 present) | **HALF-DAY PRESENT** |
| PRESENT (>= 2 present) | NOT ENTERED | **HALF-DAY PRESENT** |
| NOT ENTERED | PRESENT (>= 2 present) | **HALF-DAY PRESENT** |
| ABSENT (< 2 present) | NOT ENTERED | **HALF-DAY ABSENT** |
| NOT ENTERED | ABSENT (< 2 present) | **HALF-DAY ABSENT** |
| NOT ENTERED | NOT ENTERED | **NOT ENTERED** |
| OD (All marked OD) | OD / NOT ENTERED | **OD** |

## 17. FACULTY ATTENDANCE WORKFLOW

1. **Login**: Faculty logs into Flutter client using Employee ID / Username and Password.
2. **Dashboard**: Views today's schedule cards and active period indicator.
3. **Attendance Entry**: Clicks 'Mark Attendance' or selects period from available periods list (`faculty_attendance_screen.dart`).
4. **Date Selection**: Selects either `TODAY` or `YESTERDAY` (Faculty window is strictly limited to today and yesterday).
5. **Roster Marking**: Enters roster view (`faculty_attendance_entry_screen.dart`). Toggles student cards between `PRESENT`, `ABSENT`, or `OD` (prompts reason dialog).
6. **Submission**: Clicks 'Submit Period Attendance'. Sends `POST /api/v1/faculty/attendance/submit`. Server validates assignment, saves session, writes attendance records, and returns success summary.

## 18. CLASS ADVISOR WORKFLOW

1. **Elevated Recognition**: When an assigned advisor logs in, `is_class_advisor: true` and `advised_class_id: <id>` activate an elevated banner on `faculty_dashboard_screen.dart`.
2. **Advisor Overview Screen**: Advisor clicks 'Class Advisor Portal' and navigates to `faculty_class_advisor_screen.dart`.
3. **P1-P7 Comprehensive Grid**: Advisor sees all 7 periods (P1 to P7) for their advised class for either today or yesterday, with badges showing current status (`Marked`, `Pending`, subject name, and marking faculty).
4. **Universal Period Roster**: Advisor taps any period to open `faculty_class_advisor_entry_screen.dart`.
5. **Mark / Override**: Advisor can modify any student's status (P/A/OD). Has special bulk quick-actions: 'Mark All Present', 'Mark All Absent', 'Reset to Unmarked'.
6. **Submission**: Clicks 'Submit Class Advisor Attendance'. Calls `POST /api/v1/faculty/class-advisor/submit`. Bypasses individual subject assignment check while enforcing that faculty is indeed the Class Advisor for this class.

## 19. STUDENT WORKFLOW

1. **Login**: Student logs in via Register Number and Password.
2. **Dashboard Tab**: Displays circular attendance percentage indicator, warning badges if below threshold (75%), half-day stats card (Morning Present, Afternoon Present, Full Days), subject-wise breakdown cards, and date-wise P1-P7 matrix.
3. **Timetable Tab**: Displays daily schedule cards for each day of the week, with room numbers, period timings, and faculty names.
4. **Profile Tab**: Shows student details, class, semester, department, account status, 'Change Password' action, and 'Biometric Face Enrollment' action.
5. **Biometric Enrollment Screen**: Initiates guided 3-pose face capture (Front, Left 15°, Right 15°).

## 20. ADMIN UI — COMPLETE INVENTORY

The Admin Web Console (`app/templates/admin_panel.html` & `app/static/js/admin_app.js`) contains 14 distinct functional tabs:

1. **`#dashboard` (Dashboard)**: Institutional KPI counters (Total Students, Active Faculty, Class Sections, Periods, Overall Attendance Rate), Quick Action buttons, Capacity badges.
2. **`#students` (Students)**: Full student roster table with search, class filter, 'Add Student' modal, Edit modal, Disable/Enable toggle, Force Password Change, and Reset Password.
3. **`#faculty` (Faculty)**: Faculty directory table, 'Add Faculty' modal, Edit modal, Disable/Enable toggle, Force Password Change, Reset Password.
4. **`#attendance` (Attendance Records)**: Attendance record log, filtering by date, class, period, and status. Manual attendance override modal, OD reason inspection.
5. **`#sessions` (Class Sessions)**: Real-time and historical session monitor. View session roster, manual session creation, attendance correction modal.
6. **`#biometrics` (Biometrics)**: Student biometric profile monitor. Shows template count (0 to 3), model version (`glintr100` / `dlib`), enrollment status, and 'Reset Biometrics' action.
7. **`#academic` (Classes & Subjects)**: Class sections management (Add/Edit class, assign Class Advisor dropdown), Subjects management (Add/Edit/Delete subject).
8. **`#timetable` (Periods & Timetable)**: Period configuration table (Add/Edit period timings), Interactive weekly timetable grid (Create/Edit/Move/Duplicate slot), 'Reset Dev Timetable' button.
9. **`#assignments` (Faculty Assignments)**: Teaching assignments table mapping Faculty -> Subject -> Class Section. Add/Edit/Delete assignment modals.
10. **`#users` (User Accounts)**: System-wide user accounts table (`users` table). Role adjustment, active status toggle, password reset modal.
11. **`#settings` (Policy & Settings)**: Attendance policy form (calculation unit, thresholds, OD mode, leave mode), System settings form (session days, lockout minutes, failed attempts, AI thresholds).
12. **`#bulk-import` (Bulk Import)**: CSV / Excel file uploaders for Classes, Students, Faculty, Subjects, and Timetable with preview and commit.
13. **`#password-control` (Password Policy & Support Mode)**: Create password change windows with target scopes (ALL_USERS, SELECTED_STUDENTS, etc.); Admin Support Mode session launcher.
14. **`#audit` (Audit Trail)**: Institutional audit log viewer. Table listing timestamp, actor, role, action, target entity, IP address, and raw JSON payload inspector.

## 21. ADMIN BUTTON-BY-BUTTON MAP

The Admin Console JavaScript engine (`admin_app.js`) implements 113 discrete handler functions across all 14 tabs:

| Button / Action Name | Tab / Screen | JS Handler Function | Target API Endpoint | HTTP Method | Action & Effect |
|---|---|---|---|---|---|
| **Sign In as Administrator** | Modal Overlay | `adminLoginSubmitBtn` | `/api/v1/auth/login` | POST | Authenticates admin, stores token/cookie, hides modal |
| **Logout** | Header | `initLogout` | `/api/v1/auth/logout` | POST | Clears session cookie, redirects to login modal |
| **Add Student** | `#students` | `openCreateStudentModal` | `/api/v1/admin/students` | POST | Opens create modal, creates student & user row |
| **Edit Student** | `#students` (Row) | `openEditStudentModal` | `/api/v1/admin/students/{id}` | PUT | Updates student name, roll number, class assignment |
| **Disable Student** | `#students` (Row) | `confirmDisableStudent` | `/api/v1/admin/students/{id}/disable` | POST | Sets `is_active = False` on student and user account |
| **Enable Student** | `#students` (Row) | `enableStudent` | `/api/v1/admin/students/{id}/enable` | POST | Sets `is_active = True` on student and user account |
| **Reset Password** | `#students` (Row) | `openResetPasswordModal` | `/api/v1/admin/students/{id}/reset-password` | POST | Sets temporary password, shows one-time copy modal |
| **Add Faculty** | `#faculty` | `openCreateFacultyModal` | `/api/v1/admin/faculty` | POST | Creates faculty profile and linked faculty user account |
| **Edit Faculty** | `#faculty` (Row) | `openEditFacultyModal` | `/api/v1/admin/faculty/{id}` | PUT | Modifies faculty name, employee ID, department, email |
| **Assign Advisor** | `#academic` (Class) | `openAssignAdvisorModal` | `/api/v1/admin/classes/{id}/advisor` | POST | Updates `class_sections.class_advisor_id` to faculty ID |
| **Remove Advisor** | `#academic` (Class) | `removeAdvisor` | `/api/v1/admin/classes/{id}/advisor` | POST | Sets `class_sections.class_advisor_id = NULL` |
| **Add Class** | `#academic` | `openCreateClassModal` | `/api/v1/admin/classes` | POST | Inserts new class section record |
| **Add Subject** | `#academic` | `openCreateSubjectModal` | `/api/v1/admin/subjects` | POST | Inserts new subject record with code & name |
| **Add Period** | `#timetable` | `openCreatePeriodModal` | `/api/v1/admin/periods` | POST | Creates new period slot with start and end times |
| **Edit Period** | `#timetable` (Row) | `update_period` | `/api/v1/admin/periods/{id}` | PUT | Updates period start/end times |
| **Add TT Slot** | `#timetable` (Grid) | `openCreateTimetableModalFor` | `/api/v1/admin/timetable` | POST | Maps Day + Period + Class + Subject + Faculty |
| **Move Slot** | `#timetable` (Grid) | `openMoveTimetableModal` | `/api/v1/admin/timetable/{id}/move` | POST | Relocates timetable slot to new day/period |
| **Duplicate Slot** | `#timetable` (Grid) | `openDuplicateTimetableModal` | `/api/v1/admin/timetable/{id}/duplicate` | POST | Duplicates timetable slot to another period |
| **Delete Slot** | `#timetable` (Grid) | `confirmDeleteTimetableEntry` | `/api/v1/admin/timetable/{id}` | DELETE | Removes slot from timetable matrix |
| **Reset Dev TT** | `#timetable` | `confirmResetDevTimetable` | `/api/v1/admin/timetable/reset-dev` | POST | Reconstructs default 84-slot development matrix |
| **Assign Faculty** | `#assignments` | `openAssignFacultyModal` | `/api/v1/admin/assignments` | POST | Creates teaching assignment linking Faculty+Subject+Class |
| **Save Policy** | `#settings` | `handleSavePolicy` | `/api/v1/admin/settings/attendance-policy` | PUT | Updates attendance policy thresholds & OD mode |
| **Save Settings** | `#settings` | `handleSaveSystemSettings` | `/api/v1/admin/settings/auth` & `/ai` | PUT | Updates auth lockout & AI recognition settings |
| **Reset Biometrics** | `#biometrics` (Row) | `confirmResetBiometrics` | `/api/v1/admin/biometrics/{id}/reset` | POST | Deletes facial embeddings, sets enrollment to 0 |
| **Create PW Window** | `#password-control` | `openCreatePasswordWindowModal` | `/api/v1/admin/password-change-window` | POST | Activates targeted password change policy window |
| **Start Support** | `#password-control` | `promptStartSupportMode` | `/api/v1/admin/support/start` | POST | Generates read-only impersonation token for diagnostics |
| **Exit Support** | Top Banner | `exitSupportMode` | `/api/v1/admin/support/{id}/end` | POST | Terminates support mode, reverts to administrator |

## 22. FACULTY UI BUTTON-BY-BUTTON MAP

The Flutter Faculty application (`mobile/lib/faculty/`) provides the following interactive controls:

| Screen | Widget / Button Label | Target / Action | Service Method | API Endpoint |
|---|---|---|---|---|
| `faculty_dashboard_screen.dart` | **Start Active Session** (ElevatedButton) | Starts live camera attendance | `facultyService.startSession()` | `POST /api/v1/faculty/sessions/start` |
| `faculty_dashboard_screen.dart` | **Class Advisor Portal** (Card / InkWell) | Navigates to Advisor Screen | `Navigator.push(FacultyClassAdvisorScreen)` | Client Navigation |
| `faculty_dashboard_screen.dart` | **Mark Period Attendance** (Card / InkWell) | Navigates to Available Periods | `Navigator.push(FacultyAttendanceScreen)` | Client Navigation |
| `faculty_attendance_screen.dart` | **Date Toggle (Today / Yesterday)** | Switches available periods list | `fetchAvailableAttendancePeriods(date)` | `GET /api/v1/faculty/attendance/available-periods` |
| `faculty_attendance_screen.dart` | **Period Item Card** (InkWell) | Opens roster entry screen | `Navigator.push(FacultyAttendanceEntryScreen)` | `GET /api/v1/faculty/attendance/roster/{id}` |
| `faculty_attendance_entry_screen.dart` | **Present / Absent Toggle** (InkWell) | Toggles student attendance status | Local state update (`setState`) | In-memory roster map |
| `faculty_attendance_entry_screen.dart` | **Mark OD** (TextButton / Dialog) | Opens OD dialog to input reason | Local state update (`status='OD'`) | In-memory roster map |
| `faculty_attendance_entry_screen.dart` | **Submit Attendance** (ElevatedButton) | Posts finalized period roster | `facultyService.submitAttendance()` | `POST /api/v1/faculty/attendance/submit` |
| `faculty_class_advisor_screen.dart` | **Date Toggle (Today / Yesterday)** | Switches advisor periods list | `fetchClassAdvisorAvailablePeriods(date)` | `GET /api/v1/faculty/class-advisor/available-periods` |
| `faculty_class_advisor_screen.dart` | **Period Slot Card (P1-P7)** (InkWell) | Opens Advisor Universal Roster | `Navigator.push(FacultyClassAdvisorEntryScreen)` | `GET /api/v1/faculty/class-advisor/roster/{id}` |
| `faculty_class_advisor_entry_screen.dart` | **Mark All Present** (OutlinedButton) | Bulk sets all students to PRESENT | Local state update | In-memory roster map |
| `faculty_class_advisor_entry_screen.dart` | **Mark All Absent** (OutlinedButton) | Bulk sets all students to ABSENT | Local state update | In-memory roster map |
| `faculty_class_advisor_entry_screen.dart` | **Submit Advisor Attendance** (ElevatedButton) | Universal period submission | `submitClassAdvisorAttendance()` | `POST /api/v1/faculty/class-advisor/submit` |
| `faculty_session_screen.dart` | **Capture Camera Frame** (IconButton) | Snaps photo of classroom | `ImagePicker.pickImage()` | Camera hardware / web stream |
| `faculty_session_screen.dart` | **Recognize Faces** (ElevatedButton) | Sends photo for AI recognition | `facultyService.uploadGroupPhoto()` | `POST /api/v1/faculty/sessions/{id}/recognize-image` |
| `recognition_review_screen.dart` | **Confirm Matches** (ElevatedButton) | Commits confirmed student IDs | `facultyService.confirmRecognition()` | `POST /api/v1/faculty/sessions/{id}/confirm-recognition` |
| `faculty_session_screen.dart` | **Complete Session** (ElevatedButton) | Closes session, locks records | `facultyService.completeSession()` | `POST /api/v1/faculty/sessions/{id}/complete` |

## 23. STUDENT UI BUTTON-BY-BUTTON MAP

The Flutter Student application (`mobile/lib/student/`) provides the following interactive controls:

| Screen | Widget / Button Label | Target / Action | Service Method | API Endpoint |
|---|---|---|---|---|
| `student_dashboard_screen.dart` | **Refresh Indicator** | Pull-to-refresh attendance metrics | `studentService.loadDashboardData()` | `GET /api/v1/student/attendance` |
| `student_dashboard_screen.dart` | **BottomNav: Dashboard** | Switches tab index to 0 | Local state (`_currentIndex = 0`) | Client navigation |
| `student_dashboard_screen.dart` | **BottomNav: Timetable** | Switches tab index to 1 | Local state (`_currentIndex = 1`) | `GET /api/v1/student/timetable` |
| `student_dashboard_screen.dart` | **BottomNav: Profile** | Switches tab index to 2 | Local state (`_currentIndex = 2`) | `GET /api/v1/student/me` & `/profile` |
| `student_dashboard_screen.dart` | **Sign Out** (IconButton / Dialog) | Logs out, clears secure tokens | `authService.logout()` | `POST /api/v1/auth/student/logout` |
| `student_profile_screen.dart` | **Biometric Face Enrollment** (ElevatedButton) | Navigates to Face Enrollment | `Navigator.push(BiometricEnrollmentScreen)` | `GET /api/v1/student/enrollment-status` |
| `student_profile_screen.dart` | **Change Password** (ElevatedButton) | Opens Change Password Dialog | `ChangePasswordDialog.show()` | `POST /api/v1/auth/change-password` |
| `biometric_enrollment_screen.dart` | **Take Photo / Snap Pose** (ElevatedButton) | Captures guided head pose | `ImagePicker.pickImage()` | Camera stream |
| `biometric_enrollment_screen.dart` | **Validate Pose** (Automatic / Button) | Validates head yaw/pitch | `validatePose()` | `POST /api/v1/student/enroll-face/validate-pose` |
| `biometric_enrollment_screen.dart` | **Save Template** (ElevatedButton) | Commits face vector | `captureTemplate()` | `POST /api/v1/student/enroll-face/capture` |
| `biometric_enrollment_screen.dart` | **Reset Enrollment** (TextButton) | Clears all 3 poses, restarts | `resetEnrollment()` | `POST /api/v1/student/enroll-face/reset` |

## 24. NAVIGATION MAP

### 24.1 Admin Web Console Routing
- Single URL route: `http://localhost:8000/admin`.
- Sub-navigation managed via hash anchors: `#dashboard`, `#students`, `#faculty`, `#attendance`, `#sessions`, `#biometrics`, `#academic`, `#timetable`, `#assignments`, `#users`, `#settings`, `#bulk-import`, `#password-control`, `#audit`.
- Unauthenticated access triggers modal overlay `showAdminLoginModal()` which blocks interaction until authenticated as `ADMIN`.

### 24.2 Flutter Mobile/Web Client Routing
- Root: `main.dart` initializes `MaterialApp` with `home: SplashScreen()`.
- `SplashScreen`: Restores session from `SecureStorage`. If valid token exists, routes to `FacultyDashboardScreen` or `StudentDashboardScreen`. Otherwise, routes to `LoginScreen`.
- `LoginScreen`: Dual tab (`STUDENT` / `FACULTY`). Direct push replacement on success.
- `FacultyDashboardScreen`: Hosts Dashboard, Today's Timetable, and elevated Class Advisor card. Pushes to `FacultyAttendanceScreen`, `FacultyClassAdvisorScreen`, or `FacultySessionScreen`.
- `StudentDashboardScreen`: Uses `Scaffold` with `IndexedStack` switching between `Dashboard`, `StudentTimetableScreen`, and `StudentProfileScreen`.

## 25. API INVENTORY

The platform exposes 142 discrete REST endpoints across all administrative, faculty, advisor, student, and biometric domains:

| Method | Endpoint Path | Handler Name | Auth Required | Authorized Roles | Primary Function |
|---|---|---|---|---|---|
| `POST` | `/api/v1/auth/login` | `login` | No | Anonymous | Faculty/Admin JWT login |
| `POST` | `/api/v1/auth/student/login` | `student_login` | No | Anonymous | Student register number JWT login |
| `GET` | `/api/v1/auth/me` | `get_current_user_profile` | Yes | All Roles | Current user profile & advisor status |
| `POST` | `/api/v1/auth/logout` | `logout` | Yes | All Roles | Revokes active session token |
| `POST` | `/api/v1/auth/change-password` | `change_password` | Yes | All Roles | Self-service password change |
| `POST` | `/api/v1/auth/validate-identifier` | `validate_identifier` | No | Anonymous | Pre-submit lookup validation |
| `GET` | `/api/v1/faculty/timetable` | `get_my_timetable` | Yes | FACULTY | Faculty personal weekly timetable |
| `GET` | `/api/v1/faculty/active-class` | `get_my_active_class` | Yes | FACULTY | Resolves currently active class slot |
| `GET` | `/api/v1/faculty/attendance/available-periods` | `get_available_attendance_periods` | Yes | FACULTY | Lists periods available to mark today/yesterday |
| `GET` | `/api/v1/faculty/attendance/roster/{id}` | `get_attendance_roster` | Yes | FACULTY | Enrolled student roster for assigned period |
| `POST` | `/api/v1/faculty/attendance/submit` | `submit_attendance` | Yes | FACULTY | Submits period P/A/OD attendance roster |
| `GET` | `/api/v1/faculty/class-advisor/class` | `get_class_advisor_class` | Yes | FACULTY (Advisor) | Returns details of advised class section |
| `GET` | `/api/v1/faculty/class-advisor/available-periods` | `get_class_advisor_periods` | Yes | FACULTY (Advisor) | Returns all 7 periods (P1-P7) for advised class |
| `GET` | `/api/v1/faculty/class-advisor/roster/{id}` | `get_class_advisor_roster` | Yes | FACULTY (Advisor) | Returns class roster for any period P1-P7 |
| `POST` | `/api/v1/faculty/class-advisor/submit` | `submit_class_advisor_attendance_endpoint` | Yes | FACULTY (Advisor) | Universal period attendance submission |
| `GET` | `/api/v1/faculty/class-advisor/daily-summary` | `get_daily_class_summary_endpoint` | Yes | FACULTY (Advisor) | Class daily half-day attendance summary |
| `POST` | `/api/v1/faculty/sessions/start` | `faculty_start_session` | Yes | FACULTY | Starts live camera attendance session |
| `GET` | `/api/v1/faculty/sessions/active` | `faculty_get_active_session` | Yes | FACULTY | Retrieves current running session |
| `POST` | `/api/v1/faculty/sessions/{id}/attendance` | `faculty_mark_attendance` | Yes | FACULTY | Manual mark student in session |
| `POST` | `/api/v1/faculty/sessions/{id}/recognize-image` | `faculty_recognize_image` | Yes | FACULTY | Runs AI face recognition on image |
| `POST` | `/api/v1/faculty/sessions/{id}/confirm-recognition` | `faculty_confirm_recognition` | Yes | FACULTY | Commits recognized face attendance |
| `POST` | `/api/v1/faculty/sessions/{id}/complete` | `faculty_complete_session` | Yes | FACULTY | Closes and finalizes session |
| `GET` | `/api/v1/student/me` | `get_student_profile` | Yes | STUDENT | Basic student identity payload |
| `GET` | `/api/v1/student/profile` | `get_student_profile_detail` | Yes | STUDENT | Comprehensive academic profile |
| `GET` | `/api/v1/student/attendance` | `get_student_attendance_report` | Yes | STUDENT | Percentage, half-day stats, history |
| `GET` | `/api/v1/student/attendance/subjects` | `get_student_subject_attendance` | Yes | STUDENT | Subject-wise attendance percentages |
| `GET` | `/api/v1/student/timetable` | `get_student_timetable` | Yes | STUDENT | Enrolled class weekly timetable |
| `GET` | `/api/v1/student/enrollment-status` | `get_enrollment_status` | Yes | STUDENT | Number of enrolled face templates |
| `POST` | `/api/v1/student/enroll-face/validate-pose` | `student_validate_pose` | Yes | STUDENT | Validates yaw/pitch angle for pose |
| `POST` | `/api/v1/student/enroll-face/capture` | `student_capture_template` | Yes | STUDENT | Computes & stores facial embedding |
| `POST` | `/api/v1/student/enroll-face/reset` | `student_reset_enrollment` | Yes | STUDENT | Clears personal face embeddings |
| `GET` | `/api/v1/admin/students` | `get_students` | Yes | ADMIN | Paginated student roster with filters |
| `POST` | `/api/v1/admin/students` | `create_student` | Yes | ADMIN | Creates student record |
| `PUT` | `/api/v1/admin/students/{id}` | `update_student` | Yes | ADMIN | Updates student profile details |
| `POST` | `/api/v1/admin/students/{id}/disable` | `disable_student` | Yes | ADMIN | Deactivates student account |
| `POST` | `/api/v1/admin/students/{id}/enable` | `enable_student` | Yes | ADMIN | Re-activates student account |
| `POST` | `/api/v1/admin/students/{id}/reset-password` | `reset_student_password` | Yes | ADMIN | Generates temp student password |
| `GET` | `/api/v1/admin/faculty` | `get_faculty_list` | Yes | ADMIN | Faculty directory listing |
| `POST` | `/api/v1/admin/faculty` | `create_faculty` | Yes | ADMIN | Creates faculty & user account |
| `PUT` | `/api/v1/admin/faculty/{id}` | `update_faculty` | Yes | ADMIN | Updates faculty profile |
| `POST` | `/api/v1/admin/classes/{id}/advisor` | `assign_class_advisor` | Yes | ADMIN | Designates class advisor for class |
| `GET` | `/api/v1/admin/classes` | `get_classes` | Yes | ADMIN | Lists all class sections |
| `POST` | `/api/v1/admin/classes` | `create_class` | Yes | ADMIN | Creates new class section |
| `GET` | `/api/v1/admin/subjects` | `get_subjects` | Yes | ADMIN | Lists all academic subjects |
| `POST` | `/api/v1/admin/subjects` | `create_subject` | Yes | ADMIN | Adds new course subject |
| `GET` | `/api/v1/admin/periods` | `get_periods` | Yes | ADMIN | Lists all period definitions |
| `POST` | `/api/v1/admin/periods` | `create_period` | Yes | ADMIN | Adds new period slot |
| `PUT` | `/api/v1/admin/periods/{id}` | `update_period` | Yes | ADMIN | Updates period timings |
| `GET` | `/api/v1/admin/timetable` | `get_timetable_entries` | Yes | ADMIN | Complete timetable matrix |
| `POST` | `/api/v1/admin/timetable` | `create_timetable_entry` | Yes | ADMIN | Creates timetable slot |
| `POST` | `/api/v1/admin/timetable/reset-dev` | `reset_dev_timetable` | Yes | ADMIN | Resets default development timetable |
| `GET` | `/api/v1/admin/settings/attendance-policy` | `get_attendance_policy` | Yes | ADMIN | Returns institutional policy |
| `PUT` | `/api/v1/admin/settings/attendance-policy` | `update_attendance_policy` | Yes | ADMIN | Updates policy parameters |
| `GET` | `/api/v1/admin/settings/auth` | `get_auth_settings` | Yes | ADMIN | Returns auth & security settings |
| `PUT` | `/api/v1/admin/settings/auth` | `update_auth_settings` | Yes | ADMIN | Updates lockout & expiry parameters |
| `GET` | `/api/v1/admin/settings/ai` | `get_ai_settings` | Yes | ADMIN | Returns AI recognition thresholds |
| `PUT` | `/api/v1/admin/settings/ai` | `update_ai_settings` | Yes | ADMIN | Updates AI engine thresholds |
| `GET` | `/api/v1/admin/audit` | `get_audit_logs` | Yes | ADMIN | Returns system audit logs |
| `POST` | `/api/v1/admin/biometrics/{id}/reset` | `admin_reset_student_biometrics` | Yes | ADMIN | Wipes student face embeddings |
| `POST` | `/api/v1/admin/password-change-window` | `create_password_change_window` | Yes | ADMIN | Activates password window |
| `POST` | `/api/v1/admin/support/start` | `start_support_session` | Yes | ADMIN | Launches support impersonation |
| `POST` | `/api/v1/admin/support/{id}/end` | `end_support_session` | Yes | ADMIN | Terminates support session |

## 26. DATABASE INVENTORY

### 26.1 Entity Relational Schema (17 Tables)

1. **`users`**: Master authentication credentials. `id`, `username`, `email`, `hashed_password`, `role` (`ADMIN`, `FACULTY`, `STUDENT`), `is_active`, `session_token`, `force_password_change`, `failed_login_attempts`, `locked_until`, `login_identifier`, `created_at`.
2. **`faculty`**: Faculty personnel profiles. `id`, `user_id` (FK `users.id`), `employee_id`, `full_name`, `department`, `phone`, `created_at`.
3. **`students`**: Enrolled students. `id`, `roll_number`, `full_name`, `email`, `phone`, `class_id` (FK `class_sections.id`), `is_active`, `semester`, `department`, `user_id` (FK `users.id`), `created_at`.
4. **`class_sections`**: Academic class groups. `id`, `name`, `batch_year`, `semester`, `department`, `class_advisor_id` (FK `faculty.id`), `created_at`.
5. **`subjects`**: Course curriculum. `id`, `code`, `name`, `description`, `created_at`.
6. **`periods`**: Daily timetable period slots. `id`, `period_number`, `name`, `start_time`, `end_time`, `created_at`.
7. **`timetable_entries`**: Matrix mapping. `id`, `class_id` (FK `class_sections.id`), `subject_id` (FK `subjects.id`), `faculty_id` (FK `faculty.id`), `period_id` (FK `periods.id`), `day_of_week`, `room_number`, `created_at`.
8. **`faculty_assignments`**: Teaching permissions. `id`, `faculty_id` (FK `faculty.id`), `subject_id` (FK `subjects.id`), `class_id` (FK `class_sections.id`), `created_at`.
9. **`class_sessions`**: Instance of an academic class. `id`, `timetable_entry_id` (FK `timetable_entries.id`), `faculty_id` (FK `faculty.id`), `date`, `status` (`ACTIVE`, `COMPLETED`, `CANCELLED`), `start_timestamp`, `end_timestamp`, `created_at`.
10. **`attendance_records`**: Student period attendance records. `id`, `session_id` (FK `class_sessions.id`), `student_id` (FK `students.id`), `status` (`PRESENT`, `ABSENT`, `OD`, `UNCERTAIN`), `confidence`, `recognized_via`, `review_status`, `od_reason`, `marked_by_user_id`, `marked_at`, `updated_at`.
11. **`face_embeddings`**: Biometric vectors. `id`, `student_id` (FK `students.id`), `embedding_data` (BLOB / JSON), `pose_type` (`FRONTAL`, `LEFT_15`, `RIGHT_15`), `model_name`, `model_version`, `quality_score`, `created_at`.
12. **`attendance_policies`**: Institutional attendance business rules. `id`, `calculation_unit` (`PERIOD`), `minimum_percentage` (75.0), `warning_threshold` (75.0), `critical_threshold` (65.0), `od_calculation_mode` (`COUNT_AS_PRESENT`), `leave_calculation_mode` (`ABSENT`), `calculation_mode` (`RECORD_BASED`), `exclude_no_class`, `exclude_suspended`, `exclude_timetable_not_set`.
13. **`system_settings`**: Global key-value system configuration. `id`, `key`, `value`, `description`, `updated_at`.
14. **`audit_logs`**: System security and mutation audit records. `id`, `user_id` (FK `users.id`), `action`, `resource_type`, `resource_id`, `details`, `ip_address`, `user_agent`, `created_at`.
15. **`password_change_windows`**: Mandatory password change enforcement windows. `id`, `title`, `scope`, `target_ids`, `start_at`, `end_at`, `is_active`, `created_by`, `created_at`.
16. **`admin_support_sessions`**: Read-only support impersonation sessions. `id`, `session_id`, `admin_user_id`, `target_user_id`, `target_role`, `read_only`, `reason`, `expires_at`, `ended_at`, `is_active`.
17. **`assignment_authorized_faculty`**: Secondary authorized proxy faculty mappings. `assignment_id`, `faculty_id`.

## 27. DATABASE CURRENT STATE SUMMARY

| Table Name | Current Row Count | Primary Operational State |
|---|---|---|
| `users` | 128 rows | 1 ADMIN, 8 FACULTY, 119 STUDENTS |
| `faculty` | 8 rows | FAC01 (Advisor) through FAC08 |
| `students` | 119 rows | 64 in Class 4, 55 in Class 5 |
| `class_sections` | 2 rows | Class 4 (II Year Cyber), Class 5 (III Year Cyber) |
| `subjects` | 27 rows | Core courses, labs, and elective subjects |
| `periods` | 7 rows | P1 to P7 (Authoritative 09:10 - 16:10) |
| `timetable_entries` | 84 rows | 42 slots Class 4, 42 slots Class 5 |
| `faculty_assignments` | 30 rows | Subject teaching assignments |
| `class_sessions` | 2 rows | Historical marked class sessions |
| `attendance_records` | 66 rows | Historical student attendance records |
| `face_embeddings` | 0 rows | Cleared for clean production onboarding |
| `attendance_policies` | 1 row | Active institutional attendance policy |
| `system_settings` | 17 rows | Active system thresholds & parameters |
| `audit_logs` | 39 rows | Historical system audit records |
| `password_change_windows` | 0 rows | Clean state |
| `admin_support_sessions` | 0 rows | Clean state |
| `assignment_authorized_faculty` | 18 rows | Proxy authorization mappings |

## 28. BIOMETRIC SYSTEM

The platform incorporates a modular, pluggable biometric face recognition pipeline (`app/engines/recognition/`):
- **Engine Abstraction (`RecognitionEngineManager`)**: Decouples business logic from low-level computer vision libraries. Dynamically initializes either `LocalDlibEngine` or `SCRFDArcFaceEngine` based on `ai.performance_mode` or system settings.
- **Engine A: Local Dlib Engine (`local_dlib.py`)**:
  - Uses `face_recognition` / `dlib` HOG-based face detector and 68-point shape predictor.
  - Extracts 128-dimensional floating point embeddings.
  - Compares embeddings using Euclidean Distance (`np.linalg.norm(a - b)`).
  - Default Match Threshold: `<= 0.50` (or `ai.recognition_threshold = 0.45`).
- **Engine B: SCRFD + ArcFace ONNX Engine (`scrfd_arcface.py`)**:
  - Uses SCRFD (Sample and Computation Redistribution for Efficient Face Detection) for high-speed multi-face localization.
  - Uses InsightFace ArcFace ResNet-100 ONNX model (`glintr100.onnx`).
  - Extracts 512-dimensional normalized feature embeddings.
  - Compares embeddings using Cosine Similarity (`dot(a, b) / (||a|| * ||b||)`).
  - Default Match Threshold: `>= 0.55`.
- **Threshold Categorization**:
  - High Confidence Match: Similarity above threshold -> Auto-selected for attendance confirmation.
  - Uncertain Match: Similarity within margin (`ai.uncertain_threshold = 0.60`) -> Flagged for mandatory faculty review.
  - No Match / Unknown: Student marked absent or prompted for manual identification.

## 29. STUDENT BIOMETRIC ENROLLMENT UI

Located in `mobile/lib/student/screens/biometric_enrollment_screen.dart`:
1. **Guided 3-Pose Capture Flow**:
   - Pose 1: **FRONTAL** (Look straight ahead, target angle 0° ±5°).
   - Pose 2: **LEFT_15** (Turn head slightly left, approximately 15°).
   - Pose 3: **RIGHT_15** (Turn head slightly right, approximately 15°).
2. **Visual Guidance**: Animated head silhouette wireframe overlay with orientation indicator arrows.
3. **Two-Stage Validation**:
   - Stage 1: Client sends captured image to `POST /api/v1/student/enroll-face/validate-pose`. Backend computes head pitch/yaw/roll and verifies angle matches target step.
   - Stage 2: If angle is valid, user confirms and calls `POST /api/v1/student/enroll-face/capture` to extract and persist embedding.
4. **Completion State**: When all 3 templates are saved, the UI updates to 'Enrollment Complete' with a green checkmark badge and enables attendance verification.

## 30. LIVE FACE ATTENDANCE UI

Located in `mobile/lib/faculty/screens/faculty_session_screen.dart` and `recognition_review_screen.dart`:
1. Faculty starts session during an active class period (`POST /api/v1/faculty/sessions/start`).
2. Faculty clicks the camera icon to capture a photo of the classroom students.
3. App submits image via `POST /api/v1/faculty/sessions/{session_id}/recognize-image`.
4. Server detects all faces in the photo, extracts embeddings, compares against enrolled student templates in that class section, and partitions results into:
   - `high_confidence_matches`: List of students whose similarity exceeds match threshold.
   - `uncertain_matches`: List of students whose similarity is ambiguous.
5. App navigates to `RecognitionReviewScreen`: High-confidence matches are checked by default; uncertain matches show side-by-side comparison tiles for faculty to verify or reject.
6. Faculty clicks 'Confirm Attendance' -> `POST /api/v1/faculty/sessions/{session_id}/confirm-recognition` records attendance for all confirmed students.

## 31. AUTHENTICATION SYSTEM

- **Token Format**: Standard JSON Web Tokens (JWT) signed with HMAC-SHA256 (`HS256`).
- **Token Payload Claims**: `sub` (User ID), `role` (`ADMIN`, `FACULTY`, `STUDENT`), `exp` (Expiration timestamp).
- **Token Transmission**:
  - Flutter Mobile/Web Client: Sent via `Authorization: Bearer <token>` HTTP header.
  - Admin Web Console: Sent via HTTP-only cookie (`access_token`) and Bearer header.
- **Token Expiration**: Configurable via `auth.session_days` (Default: 7 days).
- **Password Hashing**: PassLib CryptContext with Bcrypt algorithm (Cost factor 12).
- **Account Lockout**: After `auth.max_failed_attempts` (default: 5) failed attempts, user is locked for `auth.lock_duration_minutes` (default: 30 minutes).

## 32. SECURITY ARCHITECTURE

- **Role-Based Access Control (RBAC)**: Enforced using FastAPI dependency injection (`app.api.deps.require_role`). Routes verify role before executing any handler logic.
- **Class Advisor Verification**: Routes that allow class-wide period override (`/api/v1/faculty/class-advisor/*`) verify that the calling faculty's `faculty.id` matches `class_sections.class_advisor_id`.
- **CORS Configuration**: Allowed origins configured in `app.core.config.Settings` (`ALLOWED_ORIGINS = ['*']` in development, restricted in production).
- **Input Sanitization**: Pydantic schemas enforce type safety, regex validations on roll numbers, and string length bounds.
- **SQL Injection Prevention**: 100% of database operations use SQLAlchemy ORM parameterized queries.

## 33. AUDIT LOGGING

Institutional accountability is maintained via `audit_logs` table:
- **Logged Events**: User logins, failed logins, manual attendance overrides, policy updates, timetable changes, user account creations, password resets, and support mode sessions.
- **Captured Metadata**: Actor User ID, Actor Role, Action String, Resource Type, Resource ID, Detailed JSON Diff Payload, IP Address, User Agent, and UTC Timestamp.
- **Audit Viewer**: Admin Console tab `#audit` displays searchable log table with JSON payload inspector.

## 34. REPORTING SYSTEM

- **Student Attendance Percentage Calculation**: Computed by `policy_engine.py` using active policy rules (Record-based vs Impact-based, OD handling mode, leave handling mode).
- **Half-Day Derivations**: Evaluates morning (P1-P4) and afternoon (P5-P7) status against threshold rules.
- **Future Recovery Trajectory**: Calculates how many consecutive classes a student must attend to cross the 75% minimum threshold.
- **Excel Export**: Endpoint `GET /api/v1/attendance/export/excel` generates structured Excel spreadsheets detailing student-by-student period attendance.

## 35. SETTINGS / CONFIGURATION

### 35.1 System Settings (`system_settings` table - 17 Keys)

| Setting Key | Current Configured Value | Description |
|---|---|---|
| `auth.faculty_login_method` | `USERNAME` | Login identifier for faculty: USERNAME | FACULTY_ID | EMAIL |
| `auth.student_login_method` | `REGISTER_NUMBER` | Login identifier for students: REGISTER_NUMBER | USERNAME | EMAIL |
| `auth.min_password_length` | `8` | Minimum password length |
| `auth.require_uppercase` | `true` | Require at least one uppercase letter |
| `auth.require_digit` | `true` | Require at least one digit |
| `auth.require_special` | `false` | Require at least one special character |
| `auth.max_failed_attempts` | `5` | Max failed login attempts before lockout (0 = disabled) |
| `ai.quantized_model` | `true` | Use quantized/mobile model (ON=quantized, OFF=full-precision) |
| `ai.recognition_threshold` | `0.45` | Distance threshold for confident face match |
| `ai.uncertain_threshold` | `0.60` | Distance threshold for uncertain face match |
| `ai.min_face_size_px` | `50` | Minimum face bounding box size in pixels |
| `ai.image_quality_threshold` | `0.5` | Minimum image quality score (0.0-1.0) |
| `ai.performance_mode` | `BALANCED` | AI performance mode: BALANCED | ACCURACY | SPEED |
| `auth.lock_duration_minutes` | `30` | Account lock duration in minutes |
| `auth.session_days` | `7` | Session/token lifetime in days |
| `auth.force_change_on_reset` | `true` | Force password change after admin reset |
| `auth.password_expiry_days` | `0` | Password expiry in days (0 = never expires) |

## 36. ERROR / LOADING / EMPTY STATES

- **Loading States**: Screens implement `CircularProgressIndicator()` centered during network fetch operations.
- **Error Feedback**: Floating SnackBars with Coral Red background (`AppTheme.statusCritical`) display descriptive error messages on failure.
- **Empty States**: Friendly empty illustration widgets with title, subtitle, and 'Refresh' button when no sessions or records exist.
- **Network Resilience**: `ApiClient` catches socket exceptions and timeouts, surfacing user-friendly 'Backend Server Unreachable' notices.

## 37. FLUTTER MOBILE UI — CHROME INSPECTION

- **Target Environment**: Google Chrome on `http://localhost:3000` via `flutter run -d chrome --web-port 3000`.
- **Viewport Behavior**: Implements responsive layout constraints. On desktop browsers, UI centers inside a mobile-aspect ratio canvas or scales cleanly.
- **Web Platform Adaptations**: Uses HTML5 Canvas / CanvasKit rendering, local storage fallback for web, and browser-safe image file pickers.

## 38. FLUTTER UI SCREEN INVENTORY

All 15 Flutter screens in `mobile/lib/`:

1. `auth/screens/splash_screen.dart` (`SplashScreen`): Animated initial load & session token restoration.
2. `auth/screens/login_screen.dart` (`LoginScreen`): Dual-tab authentication screen for Student and Faculty personas.
3. `faculty/screens/faculty_dashboard_screen.dart` (`FacultyDashboardScreen`): Faculty home screen with schedule cards, active session trigger, and Class Advisor portal card.
4. `faculty/screens/faculty_attendance_screen.dart` (`FacultyAttendanceScreen`): List of available timetable periods for faculty to mark attendance today or yesterday.
5. `faculty/screens/faculty_attendance_entry_screen.dart` (`FacultyAttendanceEntryScreen`): Interactive roster marking screen for subject faculty.
6. `faculty/screens/faculty_class_advisor_screen.dart` (`FacultyClassAdvisorScreen`): Class Advisor grid listing all 7 periods (P1 to P7) for their class section.
7. `faculty/screens/faculty_class_advisor_entry_screen.dart` (`FacultyClassAdvisorEntryScreen`): Universal roster marking screen for Class Advisor with bulk actions.
8. `faculty/screens/faculty_session_screen.dart` (`FacultySessionScreen`): Live camera attendance session controller with AI photo recognition triggers.
9. `faculty/screens/image_preview_screen.dart` (`ImagePreviewScreen`): Photo preview and crop confirmation before submitting to AI recognition.
10. `faculty/screens/recognition_review_screen.dart` (`RecognitionReviewScreen`): Side-by-side face match review list for faculty confirmation.
11. `faculty/screens/faculty_profile_screen.dart` (`FacultyProfileScreen`): Faculty profile details, password change window status, and logout.
12. `student/screens/student_dashboard_screen.dart` (`StudentDashboardScreen`): Student dashboard showing attendance percentage, half-day stats, subject cards, and date-wise matrix.
13. `student/screens/student_timetable_screen.dart` (`StudentTimetableScreen`): Student weekly timetable tab.
14. `student/screens/student_profile_screen.dart` (`StudentProfileScreen`): Student academic details, server config, change password, and biometric enrollment button.
15. `student/screens/biometric_enrollment_screen.dart` (`BiometricEnrollmentScreen`): Guided 3-pose facial biometric enrollment flow.

## 39. CURRENT UI DESIGN SYSTEM INVENTORY

Defined in `mobile/lib/core/theme/app_theme.dart`:

### 39.1 Color Palette
- **Primary Brand Color**: `AppTheme.primary = Color(0xFFF97316)` (Vibrant Orange)
- **Dark Brand Variant**: `AppTheme.primaryDark = Color(0xFFEA580C)`
- **Accent Color**: `AppTheme.accent = Color(0xFFFF8811)` (Warm Amber Orange)
- **Canvas Background**: `AppTheme.background = Color(0xFF0F1115)` (Deep Obsidian Canvas)
- **Glass Surface**: `AppTheme.surface = Color(0xFF1E2026)` (Milky Glass Card Surface)
- **Elevated Surface**: `AppTheme.surfaceElevated = Color(0xFF282A32)`
- **Glass Border**: `AppTheme.border = Color(0x1AFFFFFF)` (10% White border)
- **High Contrast Text**: `AppTheme.textMain = Color(0xFFF9FAFB)`
- **Muted Secondary Text**: `AppTheme.textMuted = Color(0xFF9CA3AF)`
- **Status Present / Success**: `AppTheme.statusPresent = Color(0xFF10B981)` (Emerald Green)
- **Status Absent / Critical**: `AppTheme.statusAbsent = Color(0xFFEF4444)` (Coral Red)
- **Status On-Duty (OD)**: `AppTheme.statusOd = Color(0xFFF97316)` (Vibrant Orange)
- **Status Warning / Uncertain**: `AppTheme.statusWarning = Color(0xFFF59E0B)` / `Color(0xFFEAB308)`

### 39.2 Radii & Shape System
- Card Border Radius: `AppTheme.radiusCard = 24.0`
- Inner Component Radius: `AppTheme.radiusInner = 18.0`
- Pill Badges: `AppTheme.radiusPill = 100.0`
- Typography: Font Family `Inter`, with letter spacing and font weights 500, 600, 700.

## 40. UI/FEATURE DEPENDENCY MAP

```text
UI Layer                      State Provider Layer            Backend REST Endpoint Layer         Database Entity
------------------------      ----------------------------    ---------------------------         ----------------
LoginScreen                   AuthService                     POST /api/v1/auth/login             users, faculty, students
FacultyDashboardScreen        FacultyService                  GET  /api/v1/faculty/timetable      timetable_entries
FacultyAttendanceScreen       FacultyService                  GET  /api/v1/faculty/attendance/... timetable_entries, periods
FacultyClassAdvisorScreen     FacultyService                  GET  /api/v1/faculty/class-advisor/ class_sections, periods
FacultySessionScreen          FacultyService                  POST /api/v1/faculty/sessions/start class_sessions
RecognitionReviewScreen       FacultyService                  POST /api/v1/faculty/sessions/..    attendance_records
StudentDashboardScreen        StudentService                  GET  /api/v1/student/attendance     attendance_records, policies
StudentTimetableScreen        StudentService                  GET  /api/v1/student/timetable      timetable_entries
BiometricEnrollmentScreen     BiometricEnrollmentService      POST /api/v1/student/enroll-face/.. face_embeddings
Admin Console (#timetable)    admin_app.js                    POST /api/v1/admin/timetable        periods, timetable_entries
Admin Console (#settings)     admin_app.js                    PUT  /api/v1/admin/settings/..      attendance_policies, system_settings
```

## 41. END-TO-END USER JOURNEYS

### 41.1 Administrator Journey
1. Navigates to `http://localhost:8000/admin`.
2. Authenticates via modal overlay with username `admin`.
3. Inspects dashboard KPIs; checks student count (119) and faculty count (8).
4. Navigates to `#academic` to verify class sections and assign Class Advisors.
5. Navigates to `#timetable` to configure authoritative period timings P1-P7 and weekly schedule.
6. Adjusts institutional thresholds under `#settings`.

### 41.2 Subject Faculty Journey
1. Opens Flutter app in Chrome (`http://localhost:3000`).
2. Selects 'FACULTY' tab on Login Screen, enters credentials (`FAC02`).
3. Reviews daily schedule on `FacultyDashboardScreen`.
4. Taps 'Mark Period Attendance' -> Selects today's scheduled period.
5. Toggles student attendance cards (P/A/OD) and submits roster.
6. Receives confirmation snackbar; records lock after session completion.

### 41.3 Class Advisor Journey
1. Faculty `FAC01` (Advisor for Class 4) logs into Flutter app.
2. System detects `is_class_advisor: true` and displays prominent 'Class Advisor Portal' card.
3. Advisor opens `FacultyClassAdvisorScreen`, seeing all 7 periods (P1 to P7) for Class 4.
4. Taps any period (even those taught by other faculty) to review or override student marks.
5. Submits updated marks; audit trail logs advisor intervention.

### 41.4 Student Journey
1. Student logs in via Register Number (`721025149003`) on 'STUDENT' tab.
2. Dashboard presents circular attendance percentage, half-day summaries, and subject breakdowns.
3. Taps 'Profile' -> Selects 'Biometric Face Enrollment'.
4. Completes guided 3-pose facial capture (Front, Left, Right).
5. Returns to dashboard with biometric profile enrolled.

## 42. CURRENT FEATURE COMPLETENESS

| Feature / Subsystem | Implementation Status | Backend State | Flutter Client State | Admin Console State |
|---|---|---|---|---|
| Dual-Tab Role Login | **COMPLETE** | Fully Implemented | Implemented (`login_screen.dart`) | N/A (Admin Modal) |
| Session Token Restoration | **COMPLETE** | Fully Implemented | Implemented (`splash_screen.dart`) | Cookie / Token Based |
| P1-P7 Authoritative Timings | **COMPLETE** | Database & Code Sync | Synced in Timetable UI | Synced in `#timetable` |
| Lunch Break Exclusion | **COMPLETE** | Strictly Enforced | Rendered as Non-Markable Card | Excluded from Matrix |
| Period-by-Period Marking | **COMPLETE** | `attendance_engine.py` | `faculty_attendance_entry_screen` | `#attendance` override |
| On-Duty (OD) Status Marking | **COMPLETE** | Supported with Reason | Dialog & Reason Entry | Supported in Manual Modal |
| Half-Day Status Derivation | **COMPLETE** | `policy_engine.py` | Displayed on Student Dash | Calculated in Reports |
| Class Advisor P1-P7 Override | **COMPLETE** | Dedicated Endpoints | `faculty_class_advisor_screen` | Assigned in `#academic` |
| Student Biometric Enrollment | **COMPLETE** | Pose Validator & ONNX | `biometric_enrollment_screen` | Monitored in `#biometrics` |
| Live Camera AI Recognition | **COMPLETE** | Dlib / ArcFace Pipeline | `faculty_session_screen` | N/A |
| Password Change Window Policy | **COMPLETE** | Enforcement Service | Dialog Enforced on Login | Created in `#password-control` |
| Admin Support Impersonation | **COMPLETE** | JWT Scoped Session | N/A | Banner in `#password-control` |
| Institutional Audit Trail | **COMPLETE** | `audit_logs` ORM Table | N/A | Interactive Table `#audit` |
| Excel Attendance Export | **COMPLETE** | Pandas/OpenPyXL Engine | N/A | Triggered in `#attendance` |

## 43. KNOWN ISSUES / INCONSISTENCIES

> **Strict Discovery Rule**: These nuances are documented for architectural awareness and redesign context. They have NOT been modified or 'fixed' in this read-only phase.

1. **Dual Routing Paradigms**: The Flutter mobile app does NOT use named routes (`routes: {}` in `MaterialApp`), but rather imperatively pushes `MaterialPageRoute` instances. A future redesign should consider whether to introduce a formal router (e.g. `go_router`) or preserve imperative push transitions.
2. **Class Advisor Role Representation**: `CLASS_ADVISOR` is not an enum in `UserRole`. It is purely an elevated capability derived dynamically from `class_sections.class_advisor_id`. Any UI redesign must continue to inspect `is_class_advisor: true` from `/auth/me` rather than expecting `role == 'CLASS_ADVISOR'`.
3. **Faculty Yesterday Window Constraint**: The backend allows subject faculty to mark attendance only for `TODAY` and `YESTERDAY`. Dates older than yesterday are rejected unless modified by the Class Advisor or Admin.
4. **Biometric Embeddings Table**: The `face_embeddings` table is currently at 0 rows in the development database. When testing facial recognition in Flutter Web, sample photos must first be enrolled through the student biometric enrollment screen.
5. **Web Camera Limitations in Flutter Web**: Running `image_picker` on Chrome web triggers browser file picker / webcam permissions. The app must handle potential camera denial gracefully.
6. **Pydantic Protected Namespace Warnings**: Minor console warnings regarding `model_name` and `model_version` in `BiometricOverviewOut` due to Pydantic v2 namespace collision with `model_` prefix (benign warning, non-breaking).
7. **Port Differentiation**: The backend serves on `http://127.0.0.1:8000`, the Admin Web Console is at `http://127.0.0.1:8000/admin`, and the Flutter client runs on `http://localhost:3000`. Cross-origin resource sharing (CORS) headers are required for Flutter Web to interact with the backend.

## 44. CODE -> UI MAPPING

| Source Code File Path | Rendered Visual UI Component | Target Role |
|---|---|---|
| `mobile/lib/auth/screens/login_screen.dart` | Dual-tab login screen with Server Settings modal | Anonymous / All |
| `mobile/lib/auth/screens/splash_screen.dart` | Obsidian splash logo with circular loading indicator | Anonymous / All |
| `mobile/lib/faculty/screens/faculty_dashboard_screen.dart` | Faculty header card, Class Advisor banner, Schedule cards | FACULTY |
| `mobile/lib/faculty/screens/faculty_attendance_screen.dart` | Today/Yesterday period selector list | FACULTY |
| `mobile/lib/faculty/screens/faculty_attendance_entry_screen.dart` | Student roster list with P/A/OD toggle buttons | FACULTY |
| `mobile/lib/faculty/screens/faculty_class_advisor_screen.dart` | Class Advisor 7-period grid (P1-P7) with status badges | FACULTY (Advisor) |
| `mobile/lib/faculty/screens/faculty_class_advisor_entry_screen.dart` | Advisor roster screen with quick bulk action buttons | FACULTY (Advisor) |
| `mobile/lib/faculty/screens/faculty_session_screen.dart` | Live camera session screen, photo snapping & status counts | FACULTY |
| `mobile/lib/faculty/screens/recognition_review_screen.dart` | Face recognition match review list with confidence badges | FACULTY |
| `mobile/lib/faculty/screens/faculty_profile_screen.dart` | Faculty profile, department details, change password | FACULTY |
| `mobile/lib/student/screens/student_dashboard_screen.dart` | Attendance gauge, half-day stats, subject cards, P1-P7 matrix | STUDENT |
| `mobile/lib/student/screens/student_timetable_screen.dart` | Daily timetable list organized by day of the week | STUDENT |
| `mobile/lib/student/screens/student_profile_screen.dart` | Academic profile cards & biometric enrollment trigger | STUDENT |
| `mobile/lib/student/screens/biometric_enrollment_screen.dart` | Head pose angle overlay, guide cards, and capture buttons | STUDENT |
| `app/templates/admin_panel.html` | 14-tab administrative desktop management console | ADMIN |

## 45. API -> UI MAPPING

| REST API Endpoint Path | Triggering UI Widget / Event | Displayed UI Component |
|---|---|---|
| `POST /api/v1/auth/login` | 'Sign In' button on `LoginScreen` (Faculty tab) | Transitions to `FacultyDashboardScreen` |
| `POST /api/v1/auth/student/login` | 'Sign In' button on `LoginScreen` (Student tab) | Transitions to `StudentDashboardScreen` |
| `GET  /api/v1/auth/me` | App startup (`AuthService.restoreSession`) | Determines role and sets advisor capabilities |
| `GET  /api/v1/faculty/timetable` | Pull-to-refresh or load on `FacultyDashboardScreen` | Renders 'Today\'s Classes' list |
| `GET  /api/v1/faculty/attendance/available-periods` | Date tab switch on `FacultyAttendanceScreen` | Renders list of period cards |
| `GET  /api/v1/faculty/attendance/roster/{id}` | Tapping period card on `FacultyAttendanceScreen` | Populates student list on entry screen |
| `POST /api/v1/faculty/attendance/submit` | 'Submit Attendance' button on entry screen | Shows success snackbar & pops back |
| `GET  /api/v1/faculty/class-advisor/available-periods` | Date tab switch on `FacultyClassAdvisorScreen` | Renders P1-P7 advisor grid |
| `POST /api/v1/faculty/class-advisor/submit` | 'Submit Advisor Attendance' button | Shows success snackbar & pops back |
| `GET  /api/v1/student/attendance` | Init/refresh on `StudentDashboardScreen` | Circular progress gauge & half-day cards |
| `GET  /api/v1/student/timetable` | Tapping 'Timetable' bottom nav item | Weekly class schedule cards |
| `POST /api/v1/student/enroll-face/capture` | 'Save Pose' on `BiometricEnrollmentScreen` | Increments step badge (Step 1/2/3) |

## 46. DATABASE -> FEATURE MAPPING

| Database Entity Table | Dependent Functional Features | Primary Accessing Code Module |
|---|---|---|
| `users` | Authentication, RBAC, password security, lockout | `app/api/auth.py`, `app/core/security.py` |
| `faculty` | Faculty profile, department metadata, schedule | `app/models/user.py`, `app/api/faculty.py` |
| `students` | Student rosters, academic metadata, enrollments | `app/models/student.py`, `app/api/student.py` |
| `class_sections` | Class rosters, Class Advisor assignment | `app/models/academic.py`, `app/api/admin.py` |
| `subjects` | Course curriculum catalog, subject attendance | `app/models/academic.py`, `app/api/admin.py` |
| `periods` | Institutional timing framework (P1-P7) | `app/models/academic.py`, `app/engines/timetable_engine.py` |
| `timetable_entries` | Weekly matrix mapping Day+Period->Class+Subject | `app/engines/timetable_engine.py`, `app/api/faculty.py` |
| `faculty_assignments` | Teaching authorizations | `app/models/academic.py`, `app/api/admin.py` |
| `class_sessions` | Physical classroom session occurrence | `app/models/attendance.py`, `app/engines/attendance_engine.py` |
| `attendance_records` | Period attendance data points (P/A/OD) | `app/models/attendance.py`, `app/engines/policy_engine.py` |
| `face_embeddings` | Biometric face vectors for AI verification | `app/models/student.py`, `app/engines/recognition/` |
| `attendance_policies` | Attendance % thresholds, OD and leave rules | `app/models/policy.py`, `app/engines/policy_engine.py` |
| `system_settings` | Lockout, session length, AI thresholds | `app/models/policy.py`, `app/core/config.py` |
| `audit_logs` | Immutable audit trail of administrative changes | `app/models/audit.py`, `app/api/admin.py` |
| `password_change_windows` | Targeted mandatory password change policies | `app/models/user.py`, `app/api/admin.py` |
| `admin_support_sessions` | Read-only admin diagnostic impersonation | `app/models/user.py`, `app/api/admin.py` |

## 47. FULL CURRENT PROJECT SUMMARY

The **Attendance Marker (am-oss)** is a mature, fully functional institution-grade attendance system. The backend architecture is strictly decoupled from client concerns, serving RESTful JSON endpoints protected by JWT and RBAC. The administrative management interface is served directly by the backend as a feature-complete vanilla JavaScript SPA (`admin_panel.html`). The client-facing experience is implemented in Flutter, providing tailored, highly specialized flows for Students, Subject Faculty, and Class Advisors.

The data integrity of the system is anchored by a normalized 17-table SQLite database, which currently holds 128 active user accounts, 119 verified students across two classes, 8 faculty members, 27 subjects, and an 84-entry timetable matrix. Timings are locked to an authoritative schedule of 7 daily periods (09:10 AM to 04:10 PM) with a mandatory 50-minute Lunch Break (12:50 PM to 01:40 PM) that is strictly excluded from attendance marking and calculations.

## 48. FINAL MACHINE-READABLE INVENTORY

```json
{
  "projectName": "Attendance Marker (am-oss)",
  "health": "OPERATIONAL",
  "backendUrl": "http://127.0.0.1:8000",
  "adminUrl": "http://127.0.0.1:8000/admin",
  "flutterUrl": "http://localhost:3000",
  "counts": {
    "users": 128,
    "admins": 1,
    "faculty": 8,
    "students": 119,
    "classes": 2,
    "subjects": 27,
    "assignments": 30,
    "timetableEntries": 84,
    "periods": 7,
    "tables": 17,
    "fastApiRoutes": 142,
    "flutterScreens": 15,
    "adminConsoleTabs": 14
  },
  "authoritativePeriods": [
    {
      "period": 1,
      "start": "09:10",
      "end": "10:00",
      "phase": "MORNING"
    },
    {
      "period": 2,
      "start": "10:00",
      "end": "10:50",
      "phase": "MORNING"
    },
    {
      "break": "SHORT_BREAK",
      "start": "10:50",
      "end": "11:10"
    },
    {
      "period": 3,
      "start": "11:10",
      "end": "12:00",
      "phase": "MORNING"
    },
    {
      "period": 4,
      "start": "12:00",
      "end": "12:50",
      "phase": "MORNING"
    },
    {
      "break": "LUNCH_BREAK",
      "start": "12:50",
      "end": "13:40",
      "excluded": true
    },
    {
      "period": 5,
      "start": "13:40",
      "end": "14:30",
      "phase": "AFTERNOON"
    },
    {
      "period": 6,
      "start": "14:30",
      "end": "15:20",
      "phase": "AFTERNOON"
    },
    {
      "period": 7,
      "start": "15:20",
      "end": "16:10",
      "phase": "AFTERNOON"
    }
  ],
  "advisors": [
    {
      "classId": 4,
      "className": "II Year CSE Cyber Security - Class 1",
      "advisor": "FAC01 Mathu Metlda"
    },
    {
      "classId": 5,
      "className": "III Year CSE Cyber Security - Class 2",
      "advisor": null
    }
  ]
}
```

## 49. IMPORTANT — DO NOT CONFUSE THESE TWO UI SYSTEMS

> **CRITICAL ARCHITECTURAL DISTINCTION FOR CLAUDE SONNET**:
>
> 1. **ADMIN WEB CONSOLE (`http://localhost:8000/admin`)**:
>    - **Language / Tech**: Vanilla JavaScript (`admin_app.js`), semantic HTML5 (`admin_panel.html`), CSS3 (`admin_style.css`).
>    - **Engine**: Served by FastAPI Jinja2 template engine.
>    - **Purpose**: Strictly for administrative management, institutional policies, timetable builder, user password management, and data imports.
>    - **Scope in UI Redesign**: **DO NOT MODIFY** unless explicitly asked. It is NOT part of the Flutter codebase.
>
> 2. **FLUTTER CLIENT APPLICATION (`mobile/lib/`)**:
>    - **Language / Tech**: Dart / Flutter 3.29.0 multiplatform application.
>    - **Target Roles**: `STUDENT`, `FACULTY`, and elevated `CLASS ADVISOR`.
>    - **Running Environment**: Inspected and verified in Google Chrome localhost (`http://localhost:3000`).
>    - **Scope in UI Redesign**: **THIS IS THE PRIMARY OBJECT OF THE UI REDESIGN**.

## 50. NO MOBILE HARDWARE

In accordance with test environment constraints, zero physical mobile phones, Android emulators, or iOS simulators are utilized. All mobile UI validation and testing is executed strictly in Google Chrome localhost (`http://localhost:3000`).

## 51. OUTPUT FORMAT

This document complies with GitHub Flavored Markdown (GFM) standards, using markdown tables, code syntax highlighting, structured alerts, and ASCII architecture diagrams.

## 52. FINAL REPORT QUALITY RULE

All paths, line references, widget names, database entities, and API endpoints contained herein represent factual, verified realities extracted directly from the live codebase. No hypothetical or assumed entities have been included.

## 53. NO IMPLEMENTATION

This document represents a **100% READ-ONLY DISCOVERY PHASE**. No source files have been refactored, no database rows mutated, no new migrations created, and no git commits or pushes executed.

## 54. WHAT CLAUDE SONNET NEEDS TO KNOW FOR UI REDESIGN

When undertaking the comprehensive UI redesign of the Flutter client (`mobile/lib/`), Claude Sonnet must adhere to the following strict architectural constraints:

1. **Preserve the Dual-Role Authentication Model**:
   - The Login Screen (`login_screen.dart`) must support two distinct role tabs: `STUDENT` and `FACULTY`.
   - Class Advisor is **NOT** a tab on the login screen. Advisors are authenticated faculty members whose `/auth/me` response contains `is_class_advisor: true`.
2. **Preserve the Class Advisor Experience**:
   - When `user.isClassAdvisor` is true, the Faculty Dashboard must feature a prominent, distinctive Class Advisor entry point.
   - The Advisor flow (`faculty_class_advisor_screen.dart` and `faculty_class_advisor_entry_screen.dart`) must display all 7 periods (P1 through P7) for the advised class, regardless of which faculty member is assigned to teach that period.
   - Quick bulk actions ('Mark All Present', 'Mark All Absent') are essential to the advisor workflow.
3. **Respect Period Timings & Lunch Break**:
   - There are exactly 7 attendance periods: P1 (09:10-10:00), P2 (10:00-10:50), P3 (11:10-12:00), P4 (12:00-12:50), P5 (13:40-14:30), P6 (14:30-15:20), P7 (15:20-16:10).
   - The college day ends strictly at 04:10 PM. **DO NOT introduce P8 or P9**.
   - Lunch Break (12:50 PM - 01:40 PM) must be visually represented as a break card, never as an active attendance session.
4. **Maintain Mathematical Half-Day Realities**:
   - Morning attendance is determined by P1-P4 (threshold: >= 2 present).
   - Afternoon attendance is determined by P5-P7 (threshold: >= 2 present).
   - Student dashboards must display both Morning and Afternoon half-day statuses alongside overall percentage.
5. **Honor the Milky Glass & Vibrant Orange Theme Language**:
   - Base colors: Obsidian Dark Background (`#0F1115`), Milky Glass Surface (`#1E2026`), Glass Border (`Color(0x1AFFFFFF)`), Vibrant Orange Primary Brand (`#F97316`), Emerald Success (`#10B981`), Coral Danger (`#EF4444`).
   - All custom UI components should maintain smooth curved radii (`radiusCard = 24.0`, `radiusInner = 18.0`).
6. **Retain Provider State Management & API Contracts**:
   - The Flutter application relies on `MultiProvider` with `AuthService`, `FacultyService`, `StudentService`, and `BiometricEnrollmentService`.
   - Do not break existing model deserialization (`fromJson`) or backend endpoint paths in `api_config.dart`.
7. **Preserve Biometric 3-Pose Capture Flow**:
   - The student face enrollment flow requires 3 sequential poses: Frontal (0°), Left (15°), Right (15°).
   - Visual silhouette guides, feedback banners, and camera capture controls must remain functional and accessible.

---
*End of Complete Project Discovery Report.*
