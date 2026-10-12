# Developer Setup & Handoff Guide — Attendance Marker (`am-oss`)

> [!IMPORTANT]
> **FINAL HANDOFF NOTICE**:
> This repository is the continuation source for the Attendance Marker project. The original developer may no longer actively maintain the project.
> This document provides all technical context, architecture specifications, database invariants, and next steps required for any developer to clone the repository and continue engineering operations immediately.

---

## 1. Project Overview

- **Project Name**: Attendance Marker (`am-oss`)
- **System Architecture**:
  - **Backend**: FastAPI (Python 3.10+) REST API with SQLAlchemy ORM and Pydantic v2 schemas.
  - **Database (Development)**: SQLite (`attendance_system.db`, local-only, auto-initialized on startup).
  - **Admin Web UI**: Server-rendered HTML5/Vanilla JavaScript dashboard hosted directly at `/admin` (no heavy frontend build step required).
  - **Mobile Client**: Cross-platform Flutter (Dart 3.x) application with offline-resilient architecture, live server URL configuration, camera-based face detection, and role-based UX.
- **Role Model (RBAC)**:
  - `ADMIN`: Full management of students, faculty, timetable, class assignments, system settings, password change windows, and auditable support sessions.
  - `FACULTY`: Timetable schedules, active class slot detection, attendance session management (start, roster view, manual/biometric marking, session completion).
  - `STUDENT`: Personal timetable viewing, attendance history, monthly attendance summary statistics, and mandatory password reset workflows.

---

## 2. Repository Structure

```text
am-oss/
├── app/                              # FastAPI Backend Source Tree
│   ├── api/                          # REST API route endpoints
│   │   ├── admin.py                  # Admin operations, account management, timetable, capacity
│   │   ├── auth.py                   # Authentication, login, /auth/me, password change
│   │   ├── faculty_sessions.py       # Faculty attendance session lifecycle & roster marking
│   │   ├── student.py                # Student timetable and attendance endpoints
│   │   └── deps.py                   # Dependency injection (DB session, RBAC guards)
│   ├── core/                         # Core infrastructure & configuration
│   │   ├── config.py                 # Pydantic Settings & environment variables
│   │   ├── database.py               # SQLAlchemy Engine, SessionLocal & Base
│   │   ├── security.py               # Bcrypt password hashing & JWT token handling
│   │   └── datetime_utils.py         # Timezone-aware UTC normalization utilities
│   ├── engines/                      # Business logic domain engines
│   │   ├── attendance_engine.py      # Attendance session lifecycle & authorization rules
│   │   ├── timetable_engine.py       # Schedule aggregation & slot lookup
│   │   └── face_engine.py            # Biometric vector comparisons & thresholds
│   ├── models/                       # SQLAlchemy Database Models
│   │   ├── user.py                   # User, Faculty, PasswordControl, SupportSession
│   │   ├── student.py                # Student profile model
│   │   ├── academic.py               # ClassSection, Subject, Period, FacultyAssignment, TimetableEntry
│   │   ├── attendance.py             # ClassSession, AttendanceRecord, FaceEmbedding
│   │   └── audit.py                  # AuditLog model
│   ├── schemas/                      # Pydantic request & response serializers
│   ├── services/                     # Importers, seed loaders, validation services
│   ├── static/                       # Admin Web UI static assets (CSS, JS, Icons)
│   ├── templates/                    # Jinja2 HTML templates for Admin UI
│   └── main.py                       # FastAPI application entry point & CORS configuration
├── college_seed/                     # Official college seed data (JSON format)
│   ├── class_sections.json           # Class definitions (Class 1, Class 2)
│   ├── periods.json                  # Standard 7 period time definitions (8:45 AM - 4:10 PM)
│   ├── subjects.json                 # Academic subjects & course codes
│   ├── timetable_class1.json         # 42 official timetable slots for Class 1
│   ├── timetable_class2.json         # 42 official timetable slots for Class 2
│   ├── students_class1_production.json # 64 official student profiles for Class 1
│   └── students_class2_development.json # Prepared 55 Class 2 student roster (Pending import)
├── docs/                             # Architecture specs, validation reports & guides
├── mobile/                           # Flutter Mobile Application
│   ├── lib/                          # Flutter Dart application code
│   │   ├── auth/                     # Login screen, change password dialogs
│   │   ├── core/                     # Network client, API configuration, theme
│   │   ├── faculty/                  # Faculty dashboard, timetable, attendance session screen
│   │   ├── student/                  # Student dashboard, timetable, attendance statistics
│   │   ├── models/                   # Dart data models & JSON serializers
│   │   └── services/                 # AuthService, FacultyService, StudentService
│   ├── test/                         # Comprehensive Flutter widget & integration tests
│   └── pubspec.yaml                  # Flutter package dependencies
├── scripts/                          # Administrative, migration & validation utilities
│   ├── update_class1_faculty_assignments.py # Safe Class 1 faculty update script
│   ├── validate_class1_student_roster.py    # Class 1 64-student data integrity validator
│   └── validate_class2_student_roster.py    # Class 2 55-student source data validator
├── tests/                            # Pytest Backend Automated Test Suite (100+ tests)
├── requirements.txt                  # Python runtime dependencies
└── README.md                         # Project overview and quick start
```

---

## 3. Windows Development Setup

### Prerequisites
- **Python**: Version 3.10.x or 3.11.x (Installed and on system `PATH`).
- **Flutter SDK**: Version 3.24.x or higher (Dart 3.5+).
- **Git**: Installed and configured.
- **Android SDK / Android Studio / Chrome**: For running mobile/web test targets.

### Installation Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/abishekaruchamy-oss/am-oss.git
   cd am-oss
   ```

2. **Create and activate a Python virtual environment**:
   ```powershell
   python -m venv .venv
   .venv\Scripts\activate
   ```

3. **Install Python dependencies**:
   ```powershell
   pip install -r requirements.txt
   ```

4. **Initialize Flutter mobile packages**:
   ```powershell
   cd mobile
   flutter pub get
   cd ..
   ```

---

## 4. Running the Backend

1. **Activate the virtual environment and start Uvicorn**:
   ```powershell
   cd C:\Users\Abhishek\Desktop\am-oss
   .venv\Scripts\activate
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

2. **Access Interactive Documentation (Swagger UI)**:
   - Local: `http://127.0.0.1:8000/docs`
   - Admin Panel: `http://127.0.0.1:8000/admin`

3. **LAN / Device Access**:
   - To access the API from a physical mobile device or emulator on the local WiFi network:
     `http://<YOUR_WINDOWS_LAN_IP>:8000`
   - Example: `http://192.168.1.15:8000`
   - *Note*: Ensure Windows Defender Firewall allows inbound TCP traffic on port `8000` on private networks.

---

## 5. Running the Mobile App

1. **Launch the Flutter Application**:
   ```powershell
   cd mobile
   flutter pub get
   flutter run
   ```

2. **Configuring the Server URL**:
   - On the Mobile Login screen, tap the **Settings icon** (top-right gear).
   - Enter your active backend server address (e.g., `http://192.168.1.15:8000` or `http://10.0.2.2:8000` for Android Emulator).
   - Tap **Save & Test Connection** to verify backend connectivity.

---

## 6. Database & Current Data State

### Database Design
- **Development Database**: SQLite (`attendance_system.db`).
- **Auto-Initialization**: SQLAlchemy runs `Base.metadata.create_all()` at startup to ensure all schema tables exist.
- **Local Isolation**: Database `.db` files are strictly excluded via `.gitignore` and must **never** be committed to Git.

### Current Verified Development State

| Entity / Dimension | Current Verified State | System Capacity Limits | Status |
| :--- | :--- | :--- | :--- |
| **Class 1 Students** | **64 students** (`II Year CSE Cyber Security - Class 1`) | 130 max system students | **Active & Verified** |
| **Class 2 Students** | **0 students** (`III Year CSE Cyber Security - Class 2`) | 130 max system students | **Pending Onboarding (55 source records prepared)** |
| **Class 1 Timetable** | **42 slots** (6 days × 7 periods) | 42 slots per class section | **Active & Verified** |
| **Class 2 Timetable** | **42 slots** (6 days × 7 periods) | 42 slots per class section | **Active & Verified** |
| **Total Timetable** | **84 slots** | 84 total timetable entries | **Active & Verified** |
| **Development Faculty** | **8 accounts** (`FAC01`–`FAC08`) | 15 max system faculty | **Active & Verified** |
| **Attendance Records** | 1 verification record | — | Preserved development check |

### Current Development Faculty Accounts
1. `FAC01` — **Mathu Metlda** (`fac01` / `FAC01`)
2. `FAC02` — **Showmiya** (`fac02` / `FAC02`)
3. `FAC03` — **Sivakumar** (`fac03` / `FAC03`)
4. `FAC04` — **Shankar** (`fac04` / `FAC04`)
5. `FAC05` — **Santhiya** (`fac05` / `FAC05`)
6. `FAC06` — **Lakshmi Narayanan** (`fac06` / `FAC06`)
7. `FAC07` — **Princy** (`fac07` / `FAC07`)
8. `FAC08` — **Gowri Manohari** (`fac08` / `FAC08`)

---

## 7. Class 1 Faculty Mappings & Multi-Faculty Authorized Access

Class 1 (`II Year CSE Cyber Security - Class 1`) uses the official subject assignments and multi-faculty authorization model:

| Subject Code | Full Subject Name | Primary Faculty | Authorized Faculty List |
| :--- | :--- | :--- | :--- |
| **DPCO** | Digital Principles & Computer Organization | `FAC06` (Lakshmi Narayanan) | Lakshmi Narayanan |
| **DMC** | **Discrete Mathematics for Computing** | `FAC07` (Princy) | Princy |
| **ACE-I** | Aptitude & Communication Enhancement I | `FAC08` (Gowri Manohari) | **Gowri Manohari**, **Shankar** (`FAC04`) |
| **TWM** | **Tutor Ward Meeting** | `FAC01` (Mathu Metlda) | **Mathu**, **Showmiya**, **Shankar**, **Sivakumar**, **Santhiya** |
| **ASSOC** | Department Association Hour | `FAC05` (Santhiya) | **Santhiya** |
| **FDS** | Foundations of Data Science | `FAC05` (Santhiya) | Santhiya |
| **DS** | Data Structures | `FAC02` (Showmiya) / `FAC01` (Mathu) | Showmiya / Mathu |
| **OOPS** | Object Oriented Programming Systems | `FAC03` (Sivakumar) | Sivakumar |
| **UHV / LIB / IIC** | Human Values / Library / Innovation | `FAC05` (Santhiya) | Santhiya |

### Multi-Faculty Architecture vs. Timetable Ownership
- **Primary Timetable Slot Assignment**: Each timetable slot is assigned to a single primary `FacultyAssignment` record. This guarantees conflict detection algorithms can detect and prevent double-booking conflicts during scheduling.
- **Secondary Multi-Faculty Authorization**: The `assignment_authorized_faculty` table allows multiple faculty members to be authorized for a single assignment. Authorized faculty can view the slot on their personal timetable, start attendance sessions, record attendance, and complete sessions.
- **Security Check**: Unauthorized faculty attempting attendance actions receive `HTTP 403 Forbidden` (`"You are not authorized to manage attendance for this timetable slot."`).

---

## 8. Password & Security Policy

1. **Password Standards**:
   - **Temporary Password**: Exactly **5 characters**, cryptographically generated (`secrets`), containing uppercase, lowercase, digits, and safe symbols.
   - **Permanent Password**: Minimum **8 characters**, must differ from current password.
2. **Password Storage**:
   - **Bcrypt Hashes Only**: Passwords are never stored in plaintext anywhere in the database.
   - **One-Time Reveal**: Admin password reset returns the temporary password once in the response payload for display in the admin modal; it cannot be retrieved via GET endpoints.
3. **Account Lockout & State Reset**:
   - Account lockout occurs after repeated failed login attempts.
   - Admin password reset explicitly sets `failed_login_attempts = 0`, `locked_until = None`, `session_token = None`, and `force_password_change = True`.
4. **Admin Support Mode**:
   - Allows administrators to temporarily assist a user with read-only view access.
   - Requires admin password re-authentication, enforces a 15-minute time window, cannot target `ADMIN` accounts, and logs all actions to `AuditLog`.

---

## 9. Automated Testing & Verification Baseline

### Running All Backend Tests
```powershell
.venv\Scripts\activate
python -m pytest tests/ test_seed_import.py -v
```
*Current Baseline*: **100+ passing tests**.

### Running Specific Test Suites
```powershell
# Admin account management & capacity
python -m pytest tests/test_admin_account_management.py -v

# Password policy, reset & support mode
python -m pytest tests/test_password_policy_and_support_mode.py -v

# Class 1 multi-faculty access
python -m pytest tests/test_class1_multi_faculty_assignments.py -v

# Faculty attendance session E2E
python -m pytest tests/test_faculty_attendance_e2e.py -v

# College seed importer idempotency
python -m pytest test_seed_import.py -v
```

### Running Flutter Tests & Analysis
```powershell
cd mobile
flutter analyze
flutter test
```
*Current Baseline*: **0 analyzer issues**, **44/44 passing tests**.

---

## 10. College Source Material & Data Archive

The repository includes a dedicated `college_data/` archive of all original authentic source scans, official master timetable photos, and student enrollment roll sheets.

| Material Type | Original Source Path (OneDrive) | Repository Archive Location | Purpose & Conversion Status |
| :--- | :--- | :--- | :--- |
| **Official Timetables** | `C:\Users\Abishek\OneDrive\Desktop\am-ttnl` | `college_data/official_timetable/` | **Master Schedule Reference**: Transcribed into `college_seed/timetable_class1.json` & `timetable_class2.json` (42 slots each). |
| **Official Name Lists** | `C:\Users\Abishek\OneDrive\Desktop\am-ttnl` | `college_data/official_name_lists/` | **Student Roster Reference**: Transcribed into `college_seed/students_class1_production.json` & `students_class2_development.json`. |
| **Official Photos** | `C:\Users\Abishek\OneDrive\Desktop\am-pic` | `college_data/official_photos/` | **Biometric Face Recognition Source**: 6 high-resolution campus/student reference images. Stored in private repository only. |
| **Resource Catalog** | — | `college_data/INDEX.md` | Catalog of all source materials and current lifecycle status. |
| **Integrity Checksums** | — | `college_data/source_manifest.txt` | SHA-256 integrity checksums for all source files. |
| **Data Policy** | — | `docs/DEVELOPMENT_DATA_POLICY.md` | Development data handling, anti-fabrication rules, and privacy policy. |

---

## 11. Known Pending Work & Next Development Phases

### Phase 1: Class 2 Student Onboarding (Milestone 10C.12.2)
- **Source Data Prepared**: 55 Class 2 student records have been transcribed and validated into [`college_seed/students_class2_development.json`](../college_seed/students_class2_development.json).
- **Execution Steps**:
  1. Validate register numbers and department naming (`python scripts/validate_class2_student_roster.py`).
  2. Import Class 2 student accounts into the database via `college_importer.py`.
  3. Generate private credential register `CLASS2_STUDENT_CREDENTIALS.docx` stored **outside** Git.
  4. Verify Class 2 student login and personal timetable access on mobile.

### Phase 2: Biometric Face Recognition Enrollment (Milestone 10C.13)
- Real student photos from `college_data/official_photos/` must be mapped to confirmed student roll numbers.
- Generate 128-dimensional biometric embedding vectors into the `face_embeddings` table.
- **Anti-Fabrication Rule**: Do not fabricate dummy photos or embeddings for missing students.

### Phase 3: Real-Device Faculty Authorization Verification
- Verify faculty session start, roster marking, and session completion across physical mobile devices for:
  - `FAC06` (Lakshmi Narayanan) → DPCO
  - `FAC07` (Princy) → DMC
  - `FAC08` (Gowri Manohari) & `FAC04` (Shankar) → ACE-I
  - `FAC01` / `FAC02` / `FAC03` / `FAC04` / `FAC05` → TWM
  - `FAC05` (Santhiya) → ASSOC

### Phase 4: Production Faculty Transition
- Transition from development accounts (`FAC01`–`FAC08`) to permanent official faculty employee IDs and institutional credentials prior to production deployment.

---

## 12. Troubleshooting Guide

- **Backend Connection Failed on Mobile**:
  - Verify Uvicorn is running with `--host 0.0.0.0`.
  - Check your computer's local IP address via `ipconfig` (e.g. `192.168.x.x`).
  - Open `http://<IP>:8000/docs` in the mobile device's browser to test connectivity.
  - Verify Windows Defender Firewall allows TCP port 8000.
- **HTTP 401 Unauthorized**:
  - Invalid username/register number or password. Check if temporary password requires reset.
- **HTTP 403 Forbidden**:
  - Account is locked or disabled, or faculty member is not in the authorized list for the requested timetable slot.
- **HTTP 500 Server Error**:
  - Check the active Uvicorn terminal console for Python traceback logs.

---

## 12. Security Checklist for Developers

> [!CAUTION]
> **CRITICAL SECURITY RULES**:
> 1. **NEVER** commit `.db`, `.sqlite`, or `attendance_system*.db` files.
> 2. **NEVER** commit `CLASS1_STUDENT_CREDENTIALS.docx` or `CLASS2_STUDENT_CREDENTIALS.docx`.
> 3. **NEVER** log plaintext passwords, authorization tokens, or private keys.
> 4. **NEVER** hardcode private IP addresses or production secrets in source code.
