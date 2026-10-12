# Attendance Marker (`am-oss`) — Enterprise Class Attendance System

A modular, production-oriented college class-attendance system built with **FastAPI**, **SQLAlchemy 2.0**, **SQLite/PostgreSQL**, **Bcrypt**, **JWT/Session Cookies**, **Admin Web UI**, and a **Cross-Platform Flutter Mobile Client**.

> [!IMPORTANT]
> **FINAL REPOSITORY HANDOFF**: This repository is the complete continuation source for the Attendance Marker project. The original developer may no longer actively maintain the project.
> - 📖 **Developer Handoff Guide**: [docs/DEVELOPER_SETUP_AND_HANDOFF.md](docs/DEVELOPER_SETUP_AND_HANDOFF.md)
> - 📊 **Project Status & Roadmap**: [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md)
> - 🛡️ **Development Data Policy**: [docs/DEVELOPMENT_DATA_POLICY.md](docs/DEVELOPMENT_DATA_POLICY.md)

---

## 🚀 Quick Start

### 1. Backend (FastAPI)
```powershell
# Create & activate environment
python -m venv .venv
.venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run development server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
- **API Documentation**: `http://127.0.0.1:8000/docs`
- **Admin Panel**: `http://127.0.0.1:8000/admin`

### 2. Mobile Client (Flutter)
```powershell
cd mobile
flutter pub get
flutter run
```

---

## 📊 Current Project Status (Milestone 10C.16)

- **Class 1**: `II Year CSE Cyber Security - Class 1` — **64 Students active**, **42 Timetable slots verified**.
- **Class 2**: `III Year CSE Cyber Security - Class 2` — **0 Students active** (55 source students prepared), **42 Timetable slots verified**.
- **Faculty Accounts**: 8 development faculty (`FAC01`–`FAC08`) with multi-faculty authorized access model.
- **Capacity Limits**: 130 max students (64 used, 66 remaining), 15 max faculty (8 used, 7 remaining).
- **Test Baseline**: **100+ Backend tests passing** (100%), **44 Flutter tests passing** (100%), **0 Flutter analyze issues**.

---

## 🏗️ Architecture Overview

The system follows a clean multi-tier modular architecture:

```text
┌──────────────────────────────────────────────────────────┐
│              Modern Web Client (HTML5/CSS/JS)            │
└────────────────────────────┬─────────────────────────────┘
                             │ REST API / Session Cookies
┌────────────────────────────▼─────────────────────────────┐
│                 FastAPI REST Backend (/api/v1)           │
├──────────────┬──────────────┬──────────────┬─────────────┤
│  Auth/RBAC   │  Timetable   │  Attendance  │ Recognition │
│   Service    │    Engine    │    Engine    │ Interface   │
└──────────────┴──────┬───────┴──────┬───────┴──────┬──────┘
                      │              │              │
┌─────────────────────▼──────────────▼──────────────▼──────┐
│           SQLAlchemy ORM 2.0 (SQLite / PostgreSQL)       │
└──────────────────────────────────────────────────────────┘
```

### Components
- **Frontend**: Single Page Application with role-based navigation, responsive sidebar, dynamic data tables, modal dialogs, and persistent session management.
- **Backend**: FastAPI RESTful API (`/api/v1`) with role-based access control (RBAC) enforced server-side.
- **Database**: SQLite (development) / PostgreSQL (production) with SQLAlchemy 2.0 ORM and Alembic migrations.
- **Auth**: Bcrypt password hashing, short-lived JWT access tokens, and HttpOnly session cookies for browser refresh & close/reopen persistence.
- **Recognition Engine Layer**: Pluggable `BaseRecognitionEngine` service interface separating computer vision logic from core attendance workflows.
- **Timetable Engine**: Database-driven active & upcoming class resolution based on server time and configurable period timings.

---

## 📁 Folder Structure

```text
Attendance_Marker/
├── app/
│   ├── api/                        # REST API Routers (/auth, /admin, /faculty)
│   │   ├── deps.py                 # DB and RBAC dependencies
│   │   ├── auth.py                 # Authentication endpoints
│   │   ├── admin.py                # Admin CRUD management APIs
│   │   └── faculty.py               # Faculty personalized schedule APIs
│   ├── core/
│   │   ├── config.py               # Settings & environment variables
│   │   ├── database.py             # SQLAlchemy engine & session setup
│   │   └── security.py             # Password hashing (bcrypt) & JWT management
│   ├── engines/
│   │   ├── timetable_engine.py     # Active/upcoming class schedule resolver
│   │   └── recognition/            # Pluggable Recognition Service Interface
│   │       ├── base.py             # Abstract Base Class (BaseRecognitionEngine)
│   │       └── local_dlib.py       # Dlib / face_recognition wrapper
│   ├── models/                     # SQLAlchemy ORM Entities
│   │   ├── user.py                 # User & Faculty models
│   │   ├── academic.py             # ClassSection, Subject, Period, Assignment, Timetable
│   │   ├── student.py              # Student model
│   │   ├── attendance.py           # ClassSession, AttendanceRecord, FaceEmbedding
│   │   └── audit.py                # AuditLog model
│   ├── schemas/                    # Pydantic validation schemas
│   ├── static/                     # CSS stylesheets & JS client application
│   └── templates/                  # HTML web client template (index.html)
├── alembic/                        # Alembic database migration scripts
├── dataset/                        # Preserved student face image dataset
├── attendance_marker.py            # Preserved prototype webcam script
├── attendance_manager.py            # Preserved prototype CSV logging script
├── encode_faces.py                 # Preserved prototype face encoding script
├── timetable.py                    # Preserved prototype timetable script
├── seed_db.py                      # Database initialization & seeding script
├── test_milestone1.py              # Automated test suite
└── main.py                         # Application main entry point
```

---

## 🔑 Demo Credentials

After running `seed_db.py`, the following demo accounts are available:

| Role | Username / Email | Password | Scope |
| :--- | :--- | :--- | :--- |
| **Administrator** | `admin` or `admin123` | `admin123` | Full system access & Admin Panel |
| **Faculty** | `faculty` or `faculty@college.edu` | `faculty123` | Personalized Timetable & Active Class |

---

## ⚡ Installation & Setup Instructions

### 1. Prerequisites
- Python 3.10+ (Tested on Python 3.13)
- `pip` or `venv`

### 2. Environment Setup
```bash
# Clone/navigate to project folder
cd /home/kali/Downloads/Attendance_Marker

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r dataset/requirements.txt
pip install fastapi uvicorn sqlalchemy alembic pydantic pyjwt passlib bcrypt python-multipart jinja2 httpx email-validator
```

### 3. Database Initialization & Seeding
```bash
# Seed default admin, faculty, classes, subjects, periods, timetable, and dataset students
python seed_db.py
```

### 4. Database Migrations
```bash
# Generate migration revision (if model changes occur)
alembic revision --autogenerate -m "Migration description"

# Apply migrations
alembic stamp head
```

### 5. Running the Application
```bash
# Start development server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Open your browser and navigate to **`http://localhost:8000`** to access the web application.
API Documentation is available at **`http://localhost:8000/docs`**.

---

## 🔐 Authentication & Session Design

1. **Password Security**: Passwords are standardly hashed using `bcrypt`. Plaintext passwords are never stored or logged.
2. **Persistent Login**:
   - Upon successful login, the server issues a JWT token and sets a secure HttpOnly session cookie (`attendance_session`).
   - Reopening the browser or refreshing the page triggers a lightweight call to `/api/v1/auth/me`, restoring the authenticated session seamlessly.
3. **Role-Based Authorization (RBAC)**:
   - Server-side dependencies (`require_admin`, `require_faculty`) intercept every API request.
   - Faculty users attempting to invoke `/api/v1/admin/*` endpoints receive an HTTP `403 Forbidden` error.

---

## ⚙️ Configuring College Timetables via Admin Panel

All faculty schedules, subject catalogues, class sections, and period timings are **database-driven** and fully configurable through the Admin Panel UI without code modification:

1. **Configure Period Timings**: Go to **Period Timings** tab -> Add slot (e.g. Period 1: 09:10 - 10:00).
2. **Add Subjects**: Go to **Subjects** tab -> Register subject code and name.
3. **Add Classes/Sections**: Go to **Classes / Sections** tab -> Create target class section (e.g. CSE-3A).
4. **Create Faculty Assignments**: Go to **Faculty Assignments** tab -> Assign Faculty + Subject + Class Section.
5. **Set Timetable**: Go to **Master Timetable** tab -> Assign Day + Period Slot + Faculty Assignment.

---

## 🧪 Running Automated Tests

```bash
python test_milestone1.py
```
Outputs `Ran 13 tests ... OK`.
