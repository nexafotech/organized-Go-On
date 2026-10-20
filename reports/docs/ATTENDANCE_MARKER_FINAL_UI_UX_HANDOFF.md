# ATTENDANCE MARKER (`am-oss`) — FINAL MASTER UI/UX HANDOFF REPORT

> **Document Type**: Authoritative Technical & UI/UX Specification for Claude Sonnet (Lead Mobile UI/UX Designer & Senior Flutter Architect)  
> **Source Repository Root**: `C:\Users\Abishek\Desktop\am-oss`  
> **Mobile Project Root**: `C:\Users\Abishek\Desktop\am-oss\mobile`  
> **Backend Base URL**: `http://127.0.0.1:8000` (FastAPI / SQLAlchemy / SQLite / Uvicorn)  
> **Admin Web UI**: `http://127.0.0.1:8000/admin` (Jinja2 / Vanilla JS / CSS)  
> **Flutter Runtime Target**: Flutter Web in Google Chrome (`localhost:3000`) & Android Native (`com.aifaceattendance.mobile_app`)  
> **Mode**: 100% Exhaustive Read-Only Reverse-Engineering Specification  

---

## TABLE OF CONTENTS
1. [Executive Overview & Mission](#1-executive-overview--mission)
2. [Complete System Architecture](#2-complete-system-architecture)
3. [Backend Engine & Database Schema](#3-backend-engine--database-schema)
4. [Admin Web Management Console (`/admin`)](#4-admin-web-management-console-admin)
5. [Authoritative RBAC & Permission Model](#5-authoritative-rbac--permission-model)
6. [Institutional Timetable & Break Structure](#6-institutional-timetable--break-structure)
7. [Institutional Lunch Break Policy](#7-institutional-lunch-break-policy)
8. [Daily Half-Day Attendance Policy Engine](#8-daily-half-day-attendance-policy-engine)
9. [Biometric Face Enrollment & Verification Pipeline](#9-biometric-face-enrollment--verification-pipeline)
10. [Live Classroom Facial Recognition Flow](#10-live-classroom-facial-recognition-flow)
11. [Attendance Marking Workflow & Window Constraints](#11-attendance-marking-workflow--window-constraints)
12. [Role-Scoped Attendance Reports & Analytics](#12-role-scoped-attendance-reports--analytics)
13. [Historical Attendance Matrix Engine](#13-historical-attendance-matrix-engine)
14. [Flutter Client Architecture & Tech Stack](#14-flutter-client-architecture--tech-stack)
15. [Flutter Directory Structure & File Map](#15-flutter-directory-structure--file-map)
16. [Master Screen Inventory & Role Mapping](#16-master-screen-inventory--role-mapping)
17. [Complete Screen Catalog (Exhaustive 17-Screen Audit)](#17-complete-screen-catalog)
18. [Complete Reusable UI Component Catalog](#18-complete-reusable-ui-component-catalog)
19. [Complete Interactive Button Catalog](#19-complete-interactive-button-catalog)
20. [Form Inputs, Validation & Search Behaviors](#20-form-inputs-validation--search-behaviors)
21. [Card Anatomy, Elevations & Borders](#21-card-anatomy-elevations--borders)
22. [Dialogs, Modals & Bottom Sheets](#22-dialogs-modals--bottom-sheets)
23. [Loading, Error, Empty & Conflict States](#23-loading-error-empty--conflict-states)
24. [Current Design System & Token Specifications](#24-current-design-system--token-specifications)
25. [API-to-UI & UI-to-API Mapping Matrix](#25-api-to-ui--ui-to-api-mapping-matrix)
26. [Database-to-Feature Mapping](#26-database-to-feature-mapping)
27. [User Journeys & Navigation State Machine](#27-user-journeys--navigation-state-machine)
28. [Security Boundaries & Enforcement Points](#28-security-boundaries--enforcement-points)
29. [Responsive Layout & Cross-Platform Behavior](#29-responsive-layout--cross-platform-behavior)
30. [Accessibility & Contrast Audit](#30-accessibility--contrast-audit)
31. [Current UI Flaws, Inconsistencies & Technical Limitations](#31-current-ui-flaws-inconsistencies--technical-limitations)
32. [Testing Framework & Verification Status](#32-testing-framework--verification-status)
33. [WHAT CLAUDE SONNET NEEDS TO KNOW](#33-what-claude-sonnet-needs-to-know)

---

## 1. EXECUTIVE OVERVIEW & MISSION

Attendance Marker (`am-oss`) is an enterprise-grade academic biometric attendance automation system designed for higher education institutions. The project coordinates edge facial detection, server-side vector embedding recognition, institutional timetable scheduling, and authoritative role-scoped attendance reporting.

### Target Objectives for Claude Sonnet
Claude Sonnet is tasked with redesigning the current Flutter mobile application with a world-class, premium visual design language (e.g., refined dark/light modes, micro-elevations, glassmorphism, fluid typography, and ergonomic controls). To ensure the redesign succeeds without regression:
1. **Zero Functional Drift**: All existing business logic, authentication handshakes, RBAC scopes, API endpoints, model parameters, and database schemas must remain completely intact.
2. **Authoritative Scope Enforcement**: The redesign must strictly preserve the verified distinction between **Class Advisor** (whole-class, all subjects, all P1–P7 periods) and **Subject Faculty** (assigned classes and assigned subjects only).
3. **Institutional Timetable Fidelity**: The exact 7-period day, mandatory morning short break, non-creditable lunch break exclusion, and 16:10 day dismissal must be maintained.
4. **Desktop Chrome Web Compatibility**: Testing is conducted exclusively via Flutter Web in Google Chrome (`http://localhost:3000`). All image processing, camera capture, and layout widgets must execute seamlessly in browser environments without relying on native-only device features.

---

## 2. COMPLETE SYSTEM ARCHITECTURE

```
                                      ┌─────────────────────────────────────────────────────────┐
                                      │                   END-USER CLIENTS                      │
                                      └────────────────────────────┬────────────────────────────┘
                                                                   │
                                     ┌─────────────────────────────┴─────────────────────────────┐
                                     ▼                                                           ▼
                      ┌──────────────────────────────┐                           ┌──────────────────────────────┐
                      │    ADMIN WEB CONSOLE (JS)    │                           │    FLUTTER MOBILE CLIENT     │
                      │   http://127.0.0.1:8000/admin│                           │    http://localhost:3000     │
                      │  - Jinja2 Templates          │                           │  - MultiProvider State       │
                      │  - CSS3 Modern Dark Theme    │                           │  - Material 3 / Google Fonts │
                      │  - Vanilla JavaScript API    │                           │  - BlazeFace INT8 Auditor    │
                      └──────────────┬───────────────┘                           └──────────────┬───────────────┘
                                     │                                                          │
                                     │   HTTP / JSON (REST APIs & Multipart File Uploads)       │
                                     └─────────────────────────────┬────────────────────────────┘
                                                                   │
                                                                   ▼
                                      ┌─────────────────────────────────────────────────────────┐
                                      │                 FASTAPI BACKEND SERVER                  │
                                      │               (Python 3.10+ / ASGI Uvicorn)             │
                                      ├─────────────────────────────────────────────────────────┤
                                      │ • Security: JWT Bearer Tokens, Bcrypt Hashes, RBAC      │
                                      │ • AttendancePolicyEngine: 75% Rule, Half-Day, OD Logic  │
                                      │ • Recognition Engine: SCRFD + ArcFace (512-dim vectors) │
                                      │ • Timetable Engine: P1-P7, Window Lockout, Breaks       │
                                      │ • Concurrency: Optimistic Versioning via Timestamps     │
                                      └────────────────────────────┬────────────────────────────┘
                                                                   │
                                                                   ▼
                                      ┌─────────────────────────────────────────────────────────┐
                                      │                 PERSISTENCE LAYER (DB)                  │
                                      │           SQLite via SQLAlchemy 2.0 ORM                 │
                                      ├─────────────────────────────────────────────────────────┤
                                      │ • Tables: users, students, faculty, classes, subjects,   │
                                      │   timetable_entries, class_sessions, attendance_records,│
                                      │   biometric_profiles, attendance_policies, audit_logs   │
                                      └─────────────────────────────────────────────────────────┘
```

---

## 3. BACKEND ENGINE & DATABASE SCHEMA

### Database Schema Highlights
- **`users`**: Central authentication identity table (`id`, `username`, `email`, `hashed_password`, `role`, `is_active`, `force_password_change`, `created_at`). Roles: `ADMIN`, `FACULTY`, `STUDENT`.
- **`faculty`**: Academic staff profiles (`id`, `user_id`, `employee_id`, `full_name`, `department`, `designation`).
- **`students`**: Student records (`id`, `user_id`, `register_number`, `roll_number`, `full_name`, `class_section_id`, `is_enrolled`).
- **`class_sections`**: Academic divisions (`id`, `name`, `grade_level`, `academic_year`, `advisor_faculty_id`). The field `advisor_faculty_id` designates the assigned **Class Advisor**.
- **`subjects`**: Course catalog (`id`, `name`, `code`, `department`, `credits`).
- **`periods`**: Master timetable definition (`id`, `period_number` [1–7], `name`, `start_time`, `end_time`, `session_type` [MORNING/AFTERNOON/BREAK/LUNCH]).
- **`timetable_entries`**: Class schedule mapping (`id`, `class_section_id`, `subject_id`, `faculty_id`, `period_id`, `day_of_week`).
- **`faculty_assignments`**: Authoritative teaching permissions (`id`, `faculty_id`, `class_section_id`, `subject_id`, `is_class_advisor`).
- **`class_sessions`**: Live attendance sessions (`id`, `timetable_entry_id`, `faculty_id`, `session_date`, `status` [ACTIVE/COMPLETED], `started_at`, `ended_at`).
- **`attendance_records`**: Per-period student statuses (`id`, `class_session_id`, `student_id`, `status` [PRESENT/ABSENT/OD/NOT_ENTERED/EXCLUDED], `od_reason`, `last_updated_at`).
- **`biometric_profiles`**: 512-dimensional facial embedding vectors generated by ArcFace (`id`, `student_id`, `embedding_vector`, `pose_type`, `quality_score`).
- **`attendance_policies`**: Configurable calculation rules (`id`, `minimum_percentage` [75.0], `calculation_mode`, `od_calculation_mode`, `unmarked_behavior`, `is_active`).

---

## 4. ADMIN WEB MANAGEMENT CONSOLE (`/admin`)

The Administrative Web UI (`http://127.0.0.1:8000/admin`) is a standalone web application built with Jinja2, custom CSS (`/static/css/admin_style.css`), and JavaScript (`/static/js/admin_app.js`). It is independent of the Flutter mobile client.

### 14 Administrative Modules
1. **Dashboard (`#dashboard`)**: System metrics (Total Students, Total Faculty, Active Classes, Today's Sessions, Today's Attendance %), live system alerts, and real-time session logs.
2. **Students Directory (`#students`)**: Roster search, class/section filter, enrollment status, student creation/editing modal, and face enrollment indicators.
3. **Faculty Directory (`#faculty`)**: Faculty directory, department designations, and teaching workloads.
4. **Attendance Explorer (`#attendance`)**: Multi-filter attendance record viewer (by date, class, subject, period, status) with manual override capabilities.
5. **Class Sessions (`#sessions`)**: Live session monitor showing open sessions, photo captures, and recognition logs.
6. **Biometric Face Profiles (`#biometrics`)**: Audit tool showing enrolled vectors, pose quality scores, and re-enrollment triggers.
7. **Classes & Subjects (`#academic`)**: Setup for academic years, class sections, and course catalogs.
8. **Periods & Timetable (`#timetable`)**: Institutional schedule configuration (P1–P7 timings, tea breaks, lunch intervals).
9. **Faculty Assignments (`#assignments`)**: Links faculty to class sections, subjects, and assigns **Class Advisors** (`is_class_advisor = True`).
10. **User Accounts (`#users`)**: Account creation, active/disabled toggling, password reset, and mandatory password update flags.
11. **Policy & Settings (`#settings`)**: AttendancePolicy configuration (75% threshold, `RECORD_BASED` vs `IMPACT_BASED`, OD mode).
12. **Bulk Import (`#bulk-import`)**: CSV/JSON ingestion pipeline for college rosters, subjects, and schedules.
13. **Password & Support (`#password-control`)**: Diagnostic support mode (temporary admin account inspection) and credential recovery.
14. **Audit Trail (`#audit`)**: Immutable log of administrative actions, actor IDs, timestamps, and IP addresses.

---

## 5. AUTHORITATIVE RBAC & PERMISSION MODEL

Attendance Marker enforces strict, non-negotiable role-based scoping:

```
                  ┌──────────────────────────────────────────────┐
                  │              Authenticated User              │
                  │         (Verified via JWT Bearer)            │
                  └──────────────────────┬───────────────────────┘
                                         │
         ┌───────────────────────────────┴───────────────────────────────┐
         ▼                                                               ▼
┌──────────────────┐                                           ┌──────────────────┐
│   Role: STUDENT  │                                           │  Role: FACULTY   │
└────────┬─────────┘                                           └────────┬─────────┘
         │                                                              │
         ▼                                                      ┌───────┴───────┐
┌──────────────────┐                                            ▼               ▼
│  Own Attendance  │                                     ┌─────────────┐ ┌─────────────┐
│  Own Timetable   │                                     │ Is Advisor: │ │ Is Advisor: │
│  Own Biometrics  │                                     │    FALSE    │ │    TRUE     │
└──────────────────┘                                     └──────┬──────┘ └──────┬──────┘
                                                                │               │
                                  ┌─────────────────────────────┘               └─────────────────────────────┐
                                  ▼                                                                           ▼
                  ┌──────────────────────────────┐                                            ┌──────────────────────────────┐
                  │       SUBJECT FACULTY        │                                            │        CLASS ADVISOR         │
                  │ • Assigned classes only      │                                            │ • Assigned class only        │
                  │ • Assigned subjects only     │                                            │ • ALL subjects in that class │
                  │ • Assigned periods only      │                                            │ • ALL periods (P1–P7)        │
                  │ • Roster for own slot only   │                                            │ • Whole-class daily matrix   │
                  │ • Report: Assigned subject   │                                            │ • Report: "All Subjects"     │
                  └──────────────────────────────┘                                            └──────────────────────────────┘
```

### Authorization Scope Rules
1. **Admin**: Global, unrestricted read/write access across all classes, students, subjects, and dates via `/admin`.
2. **Class Advisor (`is_class_advisor == True`)**:
   - Authorized **ONLY** for their assigned class section.
   - Authorized to view and mark **ALL students**, **ALL subjects**, and **ALL periods (P1–P7)** of that class.
   - Authorized to view historical attendance matrices from the class start date through the current date.
   - **Restriction**: Must receive `403 Forbidden` if attempting to query or mark any other class section.
3. **Subject Faculty (`is_class_advisor == False`)**:
   - Authorized **ONLY** for classes and subjects they are assigned to teach.
   - Authorized **ONLY** for timetable periods belonging to their assigned schedule.
   - **Critical Restriction**: Must **NEVER** view other subjects' attendance, other faculty's periods, or a whole-class multi-subject matrix.
4. **Student**:
   - Authorized **ONLY** for their own attendance history, personal schedule, and personal biometric profile.

---

## 6. INSTITUTIONAL TIMETABLE & BREAK STRUCTURE

The authoritative college timetable schedule is configured as follows:

| Period | Start Time | End Time | Duration | Academic Classification | Attendance Credited? |
|---|---|---|---|---|---|
| **P1** | 09:10 AM | 10:00 AM | 50 mins | Morning Session | **Yes** |
| **P2** | 10:00 AM | 10:50 AM | 50 mins | Morning Session | **Yes** |
| *Short Break* | 10:50 AM | 11:10 AM | 20 mins | Institutional Tea Break | **No (Excluded)** |
| **P3** | 11:10 AM | 12:00 PM | 50 mins | Morning Session | **Yes** |
| **P4** | 12:00 PM | 12:50 PM | 50 mins | Morning Session | **Yes** |
| *Lunch Break* | 12:50 PM | 01:40 PM | 50 mins | Institutional Lunch Break | **Strictly Excluded** |
| **P5** | 01:40 PM | 02:30 PM | 50 mins | Afternoon Session | **Yes** |
| **P6** | 02:30 PM | 03:20 PM | 50 mins | Afternoon Session | **Yes** |
| **P7** | 03:20 PM | 04:10 PM | 50 mins | Afternoon Session | **Yes** |
| *College Ends* | 04:10 PM (16:10) | — | — | Academic Day Dismissal | — |

---

## 7. INSTITUTIONAL LUNCH BREAK POLICY

The lunch break (12:50 PM – 01:40 PM) is an authoritative institutional non-academic interval:
- **Zero Attendance Marking**: No faculty member, advisor, or administrator can initiate an attendance session or mark P/A/OD for this interval.
- **Denominator Exclusion**: The 50-minute interval is strictly excluded from all percentage calculations.
- **Half-Day Independence**: Lunch has no bearing on morning or afternoon half-day statuses.
- **UI Representation**: Represented as a persistent, non-selectable banner across student, advisor, and report views.

---

## 8. DAILY HALF-DAY ATTENDANCE POLICY ENGINE

In `app/engines/policy_engine.py`, the `derive_daily_half_day_status` function computes half-day statuses:

### Session Boundaries
- **Morning Session**: Consists of P1, P2, P3, P4 (scheduled valid count = 4).
- **Afternoon Session**: Consists of P5, P6, P7 (scheduled valid count = 3).

### Mathematical Rules
For any session with $N$ scheduled periods:
$$\text{Threshold} = \max\left(1, \left\lceil \frac{N}{2.0} \right\rceil\right)$$
- Morning Threshold ($N=4$): $\lceil 4 / 2 \rceil = 2$ periods marked `PRESENT` (or `OD`).
- Afternoon Threshold ($N=3$): $\lceil 3 / 2 \rceil = 2$ periods marked `PRESENT` (or `OD`).

### Daily Result Truth Table
| Morning Session Status | Afternoon Session Status | Overall Daily Result (`daily_result`) |
|---|---|---|
| `PRESENT` ($\ge 2$) | `PRESENT` ($\ge 2$) | **`FULL DAY PRESENT`** |
| `ABSENT` ($= 0$) | `ABSENT` ($= 0$) | **`FULL DAY ABSENT`** |
| `PRESENT` | `ABSENT` | **`HALF-DAY PRESENT`** |
| `ABSENT` | `PRESENT` | **`HALF-DAY PRESENT`** |
| `PRESENT` | `NOT ENTERED` or `PARTIAL` | **`HALF-DAY PRESENT`** |
| `ABSENT` | `NOT ENTERED` | **`HALF-DAY ABSENT`** |
| `OD` | `OD` or `NOT ENTERED` | **`OD`** |
| `NOT ENTERED` | `NOT ENTERED` | **`NOT ENTERED`** |
| Other Combinations | Other Combinations | **`PARTIAL / MIXED`** |

---

## 9. BIOMETRIC FACE ENROLLMENT & VERIFICATION PIPELINE

### Student 3-Step Pose Flow (`BiometricEnrollmentScreen`)
1. **Pose 1 (`FRONTAL`)**: Looking straight at the camera.
2. **Pose 2 (`LEFT_15`)**: Head angled 15° to the left.
3. **Pose 3 (`RIGHT_15`)**: Head angled 15° to the right.

### Client-Side Pose Guidance
- Evaluated via `FaceDetectorService` with real-time feedback chips:
  - **Yaw** (Head horizontal turn): Target $\pm 15^\circ$.
  - **Pitch** (Head vertical tilt): Target within $\pm 10^\circ$.
  - **Roll** (Head sideways tilt): Target within $\pm 5^\circ$.
- Displays an oval framing bounding box and a live camera mirror correction toggle.

### Backend Processing
- Images sent via `POST /api/v1/students/face/enroll-pose` (multipart).
- Once all 3 poses are uploaded, calling `POST /api/v1/students/face/enroll` validates vector variance and generates the student's 512-dimensional ArcFace template.

---

## 10. LIVE CLASSROOM FACIAL RECOGNITION FLOW

1. **Session Initialization (`FacultyDashboardScreen`)**: Faculty taps `"START ATTENDANCE SESSION"` on an active slot card $\to$ invokes `POST /api/v1/faculty/sessions/start`.
2. **Photo Capture (`FacultySessionScreen`)**: Faculty selects `"TAKE GROUP PHOTO"`, `"CAMERA"`, or `"GALLERY"`.
3. **Image Preview (`ImagePreviewScreen`)**: Full-screen preview where faculty taps `"Recognize Faces"`. Uploads image to `POST /api/v1/faculty/sessions/{id}/recognize-image`.
4. **Candidate Review (`RecognitionReviewScreen`)**:
   - **High-Confidence Matches**: Face match confidence $\ge 80\%$. Rendered as pre-checked list items.
   - **Uncertain Matches**: Ambiguous faces rendered with radio buttons for candidate selection, plus a `"Mark as Unknown / Ignore"` option.
   - **Unknown Faces Card**: Summary of detected faces that could not be matched.
5. **Confirmation**: Tapping `"Confirm Attendance"` sends confirmed IDs to `POST /api/v1/faculty/sessions/{id}/confirm-recognition`.
6. **Session Finalization**: Tapping `"COMPLETE ATTENDANCE SESSION"` on `FacultySessionScreen` finalizes and locks the session.

---

## 11. ATTENDANCE MARKING WORKFLOW & WINDOW CONSTRAINTS

### Attendance Windows (`FacultyAttendanceScreen` & `FacultyClassAdvisorScreen`)
Attendance marking is restricted to completed periods:
- **`TODAY` Tab**: Periods whose scheduled end time has passed. Future periods are marked `LOCKED` with a lock reason.
- **`YESTERDAY` Tab**: All scheduled periods from the previous calendar day are available for marking.

### Entry Interfaces (`FacultyAttendanceEntryScreen` & `FacultyClassAdvisorEntryScreen`)
- Header shows period number, timings, class section, subject code, and faculty name.
- Real-time counters: `Total`, `Present`, `Absent`, `OD`.
- Bulk actions: `"All Present"` and `"All Absent"`.
- Per-student segmented controls: `P` (Green), `A` (Red), `OD` (Orange).
- Selecting `OD` prompts for an official reason with preset chips (`Sports Event`, `Symposium / Hackathon`, `NSS / NCC Camp`, `Placement Drive`, `Official College Duty`).
- **Advisor Optimistic Concurrency**: The Advisor screen tracks `expected_last_updated`. If a conflict occurs during submission, a `409 Conflict` dialog prompts the advisor to reload the roster.

---

## 12. ROLE-SCOPED ATTENDANCE REPORTS & ANALYTICS

The unified reports interface (`FacultyAttendanceReportScreen`) enforces strict role scoping:

### Control Panel
- **Class Selector**: Dropdown showing authorized classes. If user is Class Advisor, appends `(Class Advisor)`.
- **Subject Selector**:
  - **Class Advisor**: Can select `"All Subjects (Advisor Scope)"` or filter by a specific subject.
  - **Subject Faculty**: Restricted strictly to subjects they are authorized to teach.
- **View Mode Switcher**:
  - `Summary` (`Mode 0`): Roster summary showing total/attended hours, percentages, and below-75% alerts.
  - `Daily Matrix` (`Mode 1`): Period-by-period matrix for a single calendar date.
  - `Historical Matrix` (`Mode 2`): Multi-day historical attendance table.

---

## 13. HISTORICAL ATTENDANCE MATRIX ENGINE

In `Mode 2` of `FacultyAttendanceReportScreen`:
- **Date Range Controls**:
  - Start Date defaults to the class's configured `attendance_start_date`.
  - End Date defaults to the current date (IST).
  - Future dates are strictly non-selectable.
- **Data Matrix Layout**:
  - Sticky Left Column: Student Roll Number and Name.
  - Scrollable Columns: Date and period slots (e.g., `2026-10-01 P1`).
  - Cells: Color-coded status chips (`P`, `A`, `OD`, `-`).
  - Summary Column: Cumulative hours attended vs conducted, with overall percentage.

---

## 14. FLUTTER CLIENT ARCHITECTURE & TECH STACK

- **Framework**: Flutter 3.x (Dart >=3.0.0 <4.0.0).
- **State Management**: `Provider` with 4 root providers:
  - `AuthService`
  - `StudentService`
  - `FacultyService`
  - `BiometricEnrollmentService`
- **Networking**: `ApiClient` wrapping `http.Client`, handling JWT injection, timeouts, and `ApiException` parsing.
- **Storage**:
  - `flutter_secure_storage`: Stores `auth_access_token`.
  - `shared_preferences`: Stores UI preferences (`pref_selected_role_tab`, `pref_custom_backend_url`).
- **Hardware/Media**: `image_picker` for camera/gallery access.

---

## 15. FLUTTER DIRECTORY STRUCTURE & FILE MAP

The mobile application contains exactly 41 Dart source files under `mobile/lib/`:

```
mobile/lib/
├── main.dart
├── auth/
│   ├── screens/
│   │   ├── login_screen.dart
│   │   └── splash_screen.dart
│   └── widgets/
│       └── change_password_dialog.dart
├── core/
│   ├── config/
│   │   └── api_config.dart
│   ├── network/
│   │   └── api_client.dart
│   ├── storage/
│   │   ├── app_preferences.dart
│   │   └── secure_storage.dart
│   └── theme/
│       └── app_theme.dart
├── faculty/
│   └── screens/
│       ├── faculty_attendance_entry_screen.dart
│       ├── faculty_attendance_report_screen.dart
│       ├── faculty_attendance_screen.dart
│       ├── faculty_class_advisor_entry_screen.dart
│       ├── faculty_class_advisor_screen.dart
│       ├── faculty_dashboard_screen.dart
│       ├── faculty_profile_screen.dart
│       ├── faculty_session_screen.dart
│       ├── image_preview_screen.dart
│       └── recognition_review_screen.dart
├── models/
│   ├── biometric_enrollment_model.dart
│   ├── faculty_attendance_model.dart
│   ├── faculty_model.dart
│   ├── faculty_report_model.dart
│   ├── recognition_model.dart
│   ├── student_model.dart
│   └── user_model.dart
├── services/
│   ├── auth_service.dart
│   ├── biometric_enrollment_service.dart
│   ├── face_detector_service.dart
│   ├── faculty_service.dart
│   └── student_service.dart
├── student/
│   └── screens/
│       ├── biometric_enrollment_screen.dart
│       ├── student_attendance_report_screen.dart
│       ├── student_dashboard_screen.dart
│       ├── student_profile_screen.dart
│       └── student_timetable_screen.dart
└── widgets/
    └── attendance/
        ├── attendance_legend.dart
        ├── attendance_summary_card.dart
        ├── date_detail_sheet.dart
        ├── period_status_chip.dart
        └── subject_detail_sheet.dart
```

---

## 16. MASTER SCREEN INVENTORY & ROLE MAPPING

| # | Screen Name | File Path | Role | Navigation Route | Parent Screen |
|---|---|---|---|---|---|
| 1 | Splash Screen | `auth/screens/splash_screen.dart` | Public | Root (`/`) | App Launch |
| 2 | Login Screen | `auth/screens/login_screen.dart` | Public | Push Replacement | `SplashScreen` |
| 3 | Student Dashboard | `student/screens/student_dashboard_screen.dart` | Student | Push Replacement | `LoginScreen` |
| 4 | Student Attendance Reports | `student/screens/student_attendance_report_screen.dart` | Student | Tab Index 1 | `StudentDashboardScreen` |
| 5 | Student Timetable | `student/screens/student_timetable_screen.dart` | Student | Tab Index 2 | `StudentDashboardScreen` |
| 6 | Student Profile | `student/screens/student_profile_screen.dart` | Student | Tab Index 3 | `StudentDashboardScreen` |
| 7 | Biometric Face Enrollment | `student/screens/biometric_enrollment_screen.dart` | Student | Modal Push | `StudentProfileScreen` |
| 8 | Faculty Dashboard | `faculty/screens/faculty_dashboard_screen.dart` | Faculty / Advisor | Push Replacement | `LoginScreen` |
| 9 | Faculty Attendance Windows | `faculty/screens/faculty_attendance_screen.dart` | Faculty | Tab Index 1 | `FacultyDashboardScreen` |
| 10 | Faculty Attendance Entry | `faculty/screens/faculty_attendance_entry_screen.dart` | Faculty | Modal Push | `FacultyAttendanceScreen` |
| 11 | Class Advisor Overview | `faculty/screens/faculty_class_advisor_screen.dart` | Class Advisor | Tab Index 2 (Advisor only) | `FacultyDashboardScreen` |
| 12 | Class Advisor Entry | `faculty/screens/faculty_class_advisor_entry_screen.dart` | Class Advisor | Modal Push | `FacultyClassAdvisorScreen` |
| 13 | Faculty Reports & Matrix | `faculty/screens/faculty_attendance_report_screen.dart` | Faculty / Advisor | Modal Push (AppBar) | `FacultyDashboardScreen` |
| 14 | Active Session Roster | `faculty/screens/faculty_session_screen.dart` | Faculty | Modal Push | `FacultyDashboardScreen` |
| 15 | Image Preview | `faculty/screens/image_preview_screen.dart` | Faculty | Modal Push | `FacultySessionScreen` |
| 16 | Recognition Review | `faculty/screens/recognition_review_screen.dart` | Faculty | Push Replacement | `ImagePreviewScreen` |
| 17 | Faculty Profile | `faculty/screens/faculty_profile_screen.dart` | Faculty / Advisor | Tab Index 4 (or 3) | `FacultyDashboardScreen` |

---

## 17. COMPLETE SCREEN CATALOG

### 1. Splash Screen
- **SCREEN**: Splash Screen
- **FILE PATH**: `mobile/lib/auth/screens/splash_screen.dart`
- **ROLE**: Public / Unauthenticated
- **ROUTE/ENTRY**: Application Launch (`/`)
- **PURPOSE**: Checks secure storage for an existing JWT token and directs the user to their designated dashboard or to the login screen.
- **VISIBLE COMPONENTS**: Centered animated icon (`Icons.school_rounded`), app title `"AI Face Attendance"`, subtitle, and progress spinner.
- **PRIMARY BUTTON**: None (automatic redirection).
- **SECONDARY BUTTONS**: None.
- **DATA**: `auth_access_token` from secure storage.
- **API**: `GET /api/v1/auth/me`.
- **STATE**: Verifying token vs unauthenticated.
- **AUTHORIZATION**: Open to all.
- **NAVIGATION**: Directs to `StudentDashboardScreen`, `FacultyDashboardScreen`, or `LoginScreen`.
- **LOADING**: Centered progress indicator.
- **ERROR**: Clears invalid token and falls back to `LoginScreen`.
- **EMPTY**: Not applicable.
- **SUCCESS**: Seamless transition to the authenticated dashboard.
- **RESPONSIVE BEHAVIOR**: Centered layout across all screen dimensions.
- **REDESIGN RISK**: High; ensure authentication state logic is not broken during visual overhaul.

### 2. Login Screen
- **SCREEN**: Login Screen
- **FILE PATH**: `mobile/lib/auth/screens/login_screen.dart`
- **ROLE**: Public
- **ROUTE/ENTRY**: Pushed by `SplashScreen` or triggered on sign-out.
- **PURPOSE**: Authenticates students and faculty members.
- **VISIBLE COMPONENTS**: Role tab bar (`STUDENT` / `FACULTY`), identifier text field, password field with visibility toggle, login button, and server settings action.
- **PRIMARY BUTTON**: `"Sign In"` (Elevated button).
- **SECONDARY BUTTONS**: Server configuration icon button (`Icons.settings_ethernet`).
- **DATA**: Username/identifier, password string, active role tab.
- **API**: `POST /api/v1/auth/login`.
- **STATE**: Form validation, submitting state, error message display.
- **AUTHORIZATION**: Public.
- **NAVIGATION**: Routes to dashboard matching authenticated role.
- **LOADING**: Button displays loading spinner while request is active.
- **ERROR**: Floating red snackbar with backend error message.
- **EMPTY**: Form fields display validation errors if submitted blank.
- **SUCCESS**: Saves JWT token to secure storage and proceeds to dashboard.
- **RESPONSIVE BEHAVIOR**: Constrained card layout with max-width of 420px.
- **REDESIGN RISK**: Medium; ensure credentials handling and tab switching remain smooth.

### 3. Student Dashboard
- **SCREEN**: Student Dashboard
- **FILE PATH**: `mobile/lib/student/screens/student_dashboard_screen.dart`
- **ROLE**: Student
- **ROUTE/ENTRY**: Pushed upon successful student authentication.
- **PURPOSE**: Displays overall attendance percentage, class schedule, and alerts.
- **VISIBLE COMPONENTS**: Student header, circular attendance gauge, 3 summary stat boxes, below-75% recovery banner, biometric status card, schedule preview, and subject cards.
- **PRIMARY BUTTON**: `"COMPLETE ENROLLMENT"` (if biometrics incomplete).
- **SECONDARY BUTTONS**: Tab navigation items.
- **DATA**: Dashboard summary model, timetable list, subject breakdown.
- **API**: `GET /api/v1/students/me/dashboard`, `GET /api/v1/students/me/timetable`.
- **STATE**: Loading dashboard, error state, active bottom tab index.
- **AUTHORIZATION**: Student only.
- **NAVIGATION**: Bottom navigation bar (`Dashboard`, `Attendance`, `Timetable`, `Profile`).
- **LOADING**: Centered spinner while dashboard data is fetched.
- **ERROR**: Error message with retry button.
- **EMPTY**: Empty states for schedules and subjects.
- **SUCCESS**: Data cards populated with attendance statistics.
- **RESPONSIVE BEHAVIOR**: Single-column vertical scroll with responsive gauge.
- **REDESIGN RISK**: High; maintain the accurate display of attendance percentages and recovery calculations.

### 4. Student Attendance Reports Screen
- **SCREEN**: Student Attendance Reports Screen
- **FILE PATH**: `mobile/lib/student/screens/student_attendance_report_screen.dart`
- **ROLE**: Student
- **ROUTE/ENTRY**: Bottom Navigation Tab 1.
- **PURPOSE**: Offers subject-wise attendance breakdown and daily period matrix views.
- **VISIBLE COMPONENTS**: Tab bar (`Subject-Wise`, `Date-Wise Matrix`), summary card, attendance legend, subject progress list, and daily matrix items.
- **PRIMARY BUTTON**: Subject cards and date rows trigger detail bottom sheets.
- **SECONDARY BUTTONS**: None.
- **DATA**: `AttendanceReportResponse` (subject list and date-wise records).
- **API**: `GET /api/v1/students/me/attendance`.
- **STATE**: Active tab index, expanded date items.
- **AUTHORIZATION**: Student only.
- **NAVIGATION**: Tapping entries opens `SubjectDetailSheet` or `DateDetailSheet`.
- **LOADING**: Centered progress indicator.
- **ERROR**: Error card with retry button.
- **EMPTY**: Informational note if no attendance records exist.
- **SUCCESS**: Rendered subject list and daily matrix.
- **RESPONSIVE BEHAVIOR**: Full-width list view.
- **REDESIGN RISK**: Medium; keep bottom sheets intact.

### 5. Student Timetable Screen
- **SCREEN**: Student Timetable Screen
- **FILE PATH**: `mobile/lib/student/screens/student_timetable_screen.dart`
- **ROLE**: Student
- **ROUTE/ENTRY**: Bottom Navigation Tab 2.
- **PURPOSE**: Allows students to view their 7-day academic timetable.
- **VISIBLE COMPONENTS**: Weekday selector (`Mon`–`Sun`), period cards with badges (`CURRENT CLASS`, `UPCOMING`, `COMPLETED`, `FREE PERIOD`), subject name, and faculty details.
- **PRIMARY BUTTON**: Day selector chips.
- **SECONDARY BUTTONS**: None.
- **DATA**: List of `TimetableItemModel`.
- **API**: `GET /api/v1/students/me/timetable`.
- **STATE**: Selected weekday code.
- **AUTHORIZATION**: Student only.
- **NAVIGATION**: Contained within tab.
- **LOADING**: Spinner while timetable loads.
- **ERROR**: Error container with retry button.
- **EMPTY**: Empty state for weekends and unscheduled days.
- **SUCCESS**: Formatted period schedule.
- **RESPONSIVE BEHAVIOR**: Horizontal day selector bar with vertical period list.
- **REDESIGN RISK**: Low; preserve period order and timing display.

### 6. Student Profile Screen
- **SCREEN**: Student Profile Screen
- **FILE PATH**: `mobile/lib/student/screens/student_profile_screen.dart`
- **ROLE**: Student
- **ROUTE/ENTRY**: Bottom Navigation Tab 3.
- **PURPOSE**: Displays account details, academic affiliation, and security actions.
- **VISIBLE COMPONENTS**: Avatar circle, full name, register number, Academic Details card, Session Info card, Biometric Enrollment button, Change Password, and Sign Out.
- **PRIMARY BUTTON**: `"Face Biometric Enrollment"` / `"Change Password"`.
- **SECONDARY BUTTONS**: `"Sign Out"` (Red outlined button).
- **DATA**: Student user model.
- **API**: `GET /api/v1/students/me`, `POST /api/v1/auth/change-password`.
- **STATE**: Authenticated session.
- **AUTHORIZATION**: Student only.
- **NAVIGATION**: Routes to `BiometricEnrollmentScreen`, opens `ChangePasswordDialog`, or signs out to `LoginScreen`.
- **LOADING**: Standard card rendering.
- **ERROR**: Displayed via snackbars.
- **EMPTY**: Fallback copy if fields are missing.
- **SUCCESS**: Populated profile details.
- **RESPONSIVE BEHAVIOR**: Single-column vertical scroll.
- **REDESIGN RISK**: Low.

### 7. Biometric Face Enrollment Screen
- **SCREEN**: Biometric Face Enrollment Screen
- **FILE PATH**: `mobile/lib/student/screens/biometric_enrollment_screen.dart`
- **ROLE**: Student
- **ROUTE/ENTRY**: Pushed from Profile or Dashboard banner.
- **PURPOSE**: Guides student through 3-step facial pose capture (`FRONTAL`, `LEFT_15`, `RIGHT_15`).
- **VISIBLE COMPONENTS**: Step progress indicator (1, 2, 3), instruction card, live face guidance box with angle chips, camera preview, mirror toggle, capture buttons.
- **PRIMARY BUTTON**: `"TAKE PHOTO"` (Camera) / `"CHOOSE FROM GALLERY"`.
- **SECONDARY BUTTONS**: Mirror toggle, Retake button.
- **DATA**: Captured photo file, pose type, estimated yaw/pitch/roll.
- **API**: `POST /api/v1/students/face/enroll-pose`, `POST /api/v1/students/face/enroll`.
- **STATE**: Active step index, uploading state, pose validation result.
- **AUTHORIZATION**: Student only.
- **NAVIGATION**: Returns to caller upon completion.
- **LOADING**: Upload spinner while transmitting image.
- **ERROR**: Red banner describing face alignment issues.
- **EMPTY**: Initial camera placeholder.
- **SUCCESS**: Step advance animation, completion dialog.
- **RESPONSIVE BEHAVIOR**: Flexible layout with camera preview area.
- **REDESIGN RISK**: High; ensure camera and web image handling remain stable.

### 8. Faculty Dashboard Screen
- **SCREEN**: Faculty Dashboard Screen
- **FILE PATH**: `mobile/lib/faculty/screens/faculty_dashboard_screen.dart`
- **ROLE**: Faculty / Class Advisor
- **ROUTE/ENTRY**: Pushed upon successful faculty authentication.
- **PURPOSE**: Main hub for teaching staff to view schedules, start sessions, and access advisor tools.
- **VISIBLE COMPONENTS**: Advisor card (conditional), Reports card, Password banner, Active Session resume banner, Scheduled Slot card, Quick Access card, Schedule list.
- **PRIMARY BUTTON**: `"START ATTENDANCE SESSION"` / `"MANAGE CLASS ATTENDANCE"`.
- **SECONDARY BUTTONS**: AppBar Reports icon, Logout icon, Timetable tab.
- **DATA**: Active class slot, schedule list, advisor status, active session ID.
- **API**: `GET /api/v1/faculty/me/schedule`, `GET /api/v1/faculty/me/active-slot`, `POST /api/v1/faculty/sessions/start`.
- **STATE**: Loading state, active tab index.
- **AUTHORIZATION**: Faculty and Class Advisor.
- **NAVIGATION**: Bottom navigation bar (4 or 5 tabs), pushes reports screen.
- **LOADING**: Centered progress indicator.
- **ERROR**: Error message with retry button.
- **EMPTY**: "No teaching sessions scheduled for today."
- **SUCCESS**: Populated active slot card and schedule view.
- **RESPONSIVE BEHAVIOR**: Vertical list view.
- **REDESIGN RISK**: High; maintain active slot detection and conditional advisor tab logic.

### 9. Faculty Attendance Windows Screen
- **SCREEN**: Faculty Attendance Windows Screen
- **FILE PATH**: `mobile/lib/faculty/screens/faculty_attendance_screen.dart`
- **ROLE**: Subject Faculty
- **ROUTE/ENTRY**: Bottom Navigation Tab 1.
- **PURPOSE**: Displays periods available to mark for today and yesterday.
- **VISIBLE COMPONENTS**: Tab bar (`TODAY`, `YESTERDAY`), policy notice banner, period cards with status pills (`AVAILABLE`, `RECORDED`, `LOCKED`).
- **PRIMARY BUTTON**: `"MARK ATTENDANCE"` (Green) / `"ATTENDANCE RECORDED"` (Outlined).
- **SECONDARY BUTTONS**: Refresh icon.
- **DATA**: `AvailablePeriodsResponse` (today and yesterday period lists).
- **API**: `GET /api/v1/faculty/attendance/available-periods`.
- **STATE**: Active tab index.
- **AUTHORIZATION**: Subject Faculty.
- **NAVIGATION**: Pushes `FacultyAttendanceEntryScreen`.
- **LOADING**: Centered spinner.
- **ERROR**: Error container with retry button.
- **EMPTY**: "No scheduled classes for this day."
- **SUCCESS**: Interactive period cards.
- **RESPONSIVE BEHAVIOR**: Scrollable tab views.
- **REDESIGN RISK**: Medium; ensure status pill logic is preserved.

### 10. Faculty Attendance Entry Screen
- **SCREEN**: Faculty Attendance Entry Screen
- **FILE PATH**: `mobile/lib/faculty/screens/faculty_attendance_entry_screen.dart`
- **ROLE**: Subject Faculty
- **ROUTE/ENTRY**: Pushed from `FacultyAttendanceScreen`.
- **PURPOSE**: Roster entry interface to mark student attendance (P, A, OD).
- **VISIBLE COMPONENTS**: Slot header card, stat counter bar, `All Present` / `All Absent` buttons, search bar, roster list with segmented buttons, fixed submit button.
- **PRIMARY BUTTON**: `"Submit Attendance"` (Bottom bar).
- **SECONDARY BUTTONS**: `All Present`, `All Absent`, OD reason triggers.
- **DATA**: Period details, student roster list with status flags.
- **API**: `GET /api/v1/faculty/attendance/periods/{id}/roster`, `POST /api/v1/faculty/attendance/window`.
- **STATE**: Search query, submitting state, roster statuses.
- **AUTHORIZATION**: Subject Faculty.
- **NAVIGATION**: Returns `true` to caller upon successful submission.
- **LOADING**: Centered spinner while roster loads; button spinner while submitting.
- **ERROR**: Error view with retry; snackbar on submission failure.
- **EMPTY**: "No matching students found."
- **SUCCESS**: Green snackbar: "Attendance submitted successfully."
- **RESPONSIVE BEHAVIOR**: List view with bottom sheet submission button.
- **REDESIGN RISK**: High; preserve P/A/OD segmented toggle functionality and OD reason dialog.

### 11. Class Advisor Overview Screen
- **SCREEN**: Class Advisor Overview Screen
- **FILE PATH**: `mobile/lib/faculty/screens/faculty_class_advisor_screen.dart`
- **ROLE**: Class Advisor
- **ROUTE/ENTRY**: Bottom Navigation Tab 2 (Advisor only).
- **PURPOSE**: Whole-class attendance overview for P1–P7 periods across all subjects.
- **VISIBLE COMPONENTS**: Advisor header banner, TabBar (`TODAY`, `YESTERDAY`), Daily Summary button, P1–P4 list, short break card, lunch break card, P5–P7 list, end of day card.
- **PRIMARY BUTTON**: `"RECORD ATTENDANCE"` / `"EDIT ATTENDANCE"`.
- **SECONDARY BUTTONS**: `"View Daily Half-Day Summary for this date"`.
- **DATA**: `ClassAdvisorAvailablePeriodsResponse`.
- **API**: `GET /api/v1/faculty/class-advisor/available-periods`, `GET /api/v1/faculty/class-advisor/daily-summary`.
- **STATE**: Active tab index.
- **AUTHORIZATION**: Class Advisor only.
- **NAVIGATION**: Pushes `FacultyClassAdvisorEntryScreen`.
- **LOADING**: Centered progress indicator.
- **ERROR**: Error screen with retry button.
- **EMPTY**: Handled per session block.
- **SUCCESS**: Complete class period list.
- **RESPONSIVE BEHAVIOR**: Vertical list view.
- **REDESIGN RISK**: High; maintain whole-class period listing and break card placements.

### 12. Class Advisor Entry Screen
- **SCREEN**: Class Advisor Entry Screen
- **FILE PATH**: `mobile/lib/faculty/screens/faculty_class_advisor_entry_screen.dart`
- **ROLE**: Class Advisor
- **ROUTE/ENTRY**: Pushed from `FacultyClassAdvisorScreen`.
- **PURPOSE**: Whole-class multi-period attendance marking with optimistic concurrency protection.
- **VISIBLE COMPONENTS**: Slot header, stat counter bar, `All Present` / `All Absent`, search input, student cards with P/A/OD toggles, fixed submit button.
- **PRIMARY BUTTON**: `"Submit Attendance"` (Bottom bar).
- **SECONDARY BUTTONS**: `All Present`, `All Absent`, OD reason triggers.
- **DATA**: Whole-class roster list, `expected_last_updated` token.
- **API**: `GET /api/v1/faculty/class-advisor/periods/{id}/roster`, `POST /api/v1/faculty/class-advisor/attendance`.
- **STATE**: Search query, submitting state, concurrency token.
- **AUTHORIZATION**: Class Advisor only.
- **NAVIGATION**: Displays daily summary dialog on success, then pops screen.
- **LOADING**: Load and submit progress indicators.
- **ERROR**: `409 Conflict` opens concurrency conflict dialog; general errors show snackbars.
- **EMPTY**: "No matching students found."
- **SUCCESS**: Shows summary dialog and returns to overview.
- **RESPONSIVE BEHAVIOR**: List view with bottom sheet submission button.
- **REDESIGN RISK**: High; preserve concurrency token tracking and 409 conflict handling.

### 13. Faculty Attendance Report Screen
- **SCREEN**: Faculty Attendance Report Screen
- **FILE PATH**: `mobile/lib/faculty/screens/faculty_attendance_report_screen.dart`
- **ROLE**: Faculty / Class Advisor
- **ROUTE/ENTRY**: Pushed from Faculty Dashboard AppBar icon.
- **PURPOSE**: Role-scoped attendance reports with Summary, Daily Matrix, and Historical Matrix views.
- **VISIBLE COMPONENTS**: Class selector, Subject selector, mode buttons (`Summary`, `Daily Matrix`, `Historical Matrix`), date picker, date range picker, data tables.
- **PRIMARY BUTTON**: Mode toggle buttons.
- **SECONDARY BUTTONS**: Date selection buttons, student cards trigger detail modals.
- **DATA**: Authorized options model, summary report, date matrix, historical matrix.
- **API**: `GET /api/v1/faculty/reports/*` endpoints.
- **STATE**: Active mode, selected class, selected subject, selected dates.
- **AUTHORIZATION**: Scoped to user's assigned role.
- **NAVIGATION**: Pushes `_StudentDetailModal` on student tap.
- **LOADING**: Centered spinners while fetching options or reports.
- **ERROR**: Error message with retry action.
- **EMPTY**: "No attendance data available."
- **SUCCESS**: Rendered summary cards or scrollable matrix tables.
- **RESPONSIVE BEHAVIOR**: Horizontal and vertical scrolling for matrices.
- **REDESIGN RISK**: Critical; maintain role-scoped dropdown logic and table formatting.

### 14. Faculty Active Session Screen
- **SCREEN**: Faculty Active Session Screen
- **FILE PATH**: `mobile/lib/faculty/screens/faculty_session_screen.dart`
- **ROLE**: Faculty
- **ROUTE/ENTRY**: Pushed when starting or resuming an attendance session.
- **PURPOSE**: Manages real-time classroom attendance with camera integration.
- **VISIBLE COMPONENTS**: Session toolbar (`TAKE GROUP PHOTO`, `CAMERA`, `GALLERY`), attendance counters, roster list with manual mark icons, complete session button.
- **PRIMARY BUTTON**: `"COMPLETE ATTENDANCE SESSION"` (Bottom bar).
- **SECONDARY BUTTONS**: Toolbar photo buttons, per-student P/A/OD action icons.
- **DATA**: Active session ID, roster student list.
- **API**: `GET /api/v1/faculty/sessions/active`, `POST /api/v1/faculty/sessions/{id}/mark`, `POST /api/v1/faculty/sessions/{id}/complete`.
- **STATE**: Submitting states, roster updates.
- **AUTHORIZATION**: Faculty with active session.
- **NAVIGATION**: Pushes `ImagePreviewScreen`; pops when session completes.
- **LOADING**: Standard list rendering.
- **ERROR**: Snackbars for failed actions.
- **EMPTY**: "No enrolled students in roster."
- **SUCCESS**: Live updates to attendance counters.
- **RESPONSIVE BEHAVIOR**: List view with bottom action bar.
- **REDESIGN RISK**: High; preserve session finalization flow.

### 15. Image Preview Screen
- **SCREEN**: Image Preview Screen
- **FILE PATH**: `mobile/lib/faculty/screens/image_preview_screen.dart`
- **ROLE**: Faculty
- **ROUTE/ENTRY**: Pushed from `FacultySessionScreen` after capturing/selecting an image.
- **PURPOSE**: Previews captured classroom photo before facial recognition analysis.
- **VISIBLE COMPONENTS**: Photo display against black background, `"Retake Photo"` / `"Choose Other"`, `"Recognize Faces"`.
- **PRIMARY BUTTON**: `"Recognize Faces"` (Elevated button with spinner).
- **SECONDARY BUTTONS**: `"Retake Photo"` / `"Choose Other"`.
- **DATA**: Selected image file.
- **API**: `POST /api/v1/faculty/sessions/{id}/recognize-image`.
- **STATE**: Uploading state, error message.
- **AUTHORIZATION**: Faculty.
- **NAVIGATION**: Replaces screen with `RecognitionReviewScreen` on success.
- **LOADING**: Button shows loading spinner during upload.
- **ERROR**: Red banner displaying API error.
- **EMPTY**: Not applicable.
- **SUCCESS**: Transitions to recognition review.
- **RESPONSIVE BEHAVIOR**: Contained image layout.
- **REDESIGN RISK**: High; replace any `dart:io` `File` references with `Uint8List` for Web compatibility.

### 16. Recognition Review Screen
- **SCREEN**: Recognition Review Screen
- **FILE PATH**: `mobile/lib/faculty/screens/recognition_review_screen.dart`
- **ROLE**: Faculty
- **ROUTE/ENTRY**: Pushed by `ImagePreviewScreen`.
- **PURPOSE**: Review and confirm AI facial recognition matches.
- **VISIBLE COMPONENTS**: Summary badge bar (Faces, High Match, Uncertain, Unknown), high-confidence matches with checkboxes, uncertain matches with candidate radio groups, unknown faces card, confirm button.
- **PRIMARY BUTTON**: `"Confirm Attendance (N Selected)"` (Bottom bar).
- **SECONDARY BUTTONS**: Checkboxes and candidate radio buttons.
- **DATA**: `RecognitionResultModel`.
- **API**: `POST /api/v1/faculty/sessions/{id}/confirm-recognition`.
- **STATE**: Selected student IDs, confirming state.
- **AUTHORIZATION**: Faculty.
- **NAVIGATION**: Pops back to `FacultySessionScreen` on success.
- **LOADING**: Button shows loading spinner while confirming.
- **ERROR**: Red alert banner on confirmation failure.
- **EMPTY**: Handled within match sections.
- **SUCCESS**: Snackbar: "Attendance recorded for N student(s)."
- **RESPONSIVE BEHAVIOR**: Scrollable review list.
- **REDESIGN RISK**: High; maintain match grouping and selection logic.

### 17. Faculty Profile Screen
- **SCREEN**: Faculty Profile Screen
- **FILE PATH**: `mobile/lib/faculty/screens/faculty_profile_screen.dart`
- **ROLE**: Faculty / Class Advisor
- **ROUTE/ENTRY**: Bottom Navigation Tab 4 (or 3).
- **PURPOSE**: Displays faculty metadata and security actions.
- **VISIBLE COMPONENTS**: Avatar circle, full name, employee ID, Account Details card, Session Info card, Change Password, Sign Out.
- **PRIMARY BUTTON**: `"Change Password"`.
- **SECONDARY BUTTONS**: `"Sign Out"` (Red outlined button).
- **DATA**: Faculty user model.
- **API**: `GET /api/v1/auth/me`, `POST /api/v1/auth/change-password`.
- **STATE**: Authenticated session.
- **AUTHORIZATION**: Faculty and Class Advisor.
- **NAVIGATION**: Opens `ChangePasswordDialog`; sign out returns to `LoginScreen`.
- **LOADING**: Standard card rendering.
- **ERROR**: Snackbars for failed actions.
- **EMPTY**: Fallback copy if fields are missing.
- **SUCCESS**: Populated profile details.
- **RESPONSIVE BEHAVIOR**: Single-column vertical scroll.
- **REDESIGN RISK**: Low.

---

## 18. COMPLETE REUSABLE UI COMPONENT CATALOG

| Name | File Path | Purpose | Used By | Inputs | State | Interaction | Dependencies |
|---|---|---|---|---|---|---|---|
| `PeriodStatusChip` | `widgets/attendance/period_status_chip.dart` | Compact status pill (P, A, OD, -, EXCLUDED) | Reports, Sheets | `status`, `odReason`, `showLabel` | Stateless | None | `AppTheme` |
| `AttendanceLegend` | `widgets/attendance/attendance_legend.dart` | Color key for attendance statuses | Reports, Dashboard | None | Stateless | None | `AppTheme` |
| `AttendanceSummaryCard` | `widgets/attendance/attendance_summary_card.dart` | 4-box summary (Total, Present, Absent, OD) | Student Reports | Counts for each status | Stateless | None | `AppTheme` |
| `DateDetailSheet` | `widgets/attendance/date_detail_sheet.dart` | Bottom sheet with period breakdown for a date | Student Dashboard, Reports | `DateWiseEntryModel` | Stateless | Scrollable sheet | `PeriodStatusChip` |
| `SubjectDetailSheet` | `widgets/attendance/subject_detail_sheet.dart` | Bottom sheet with subject progress bar | Student Dashboard, Reports | `SubjectAttendanceModel` | Stateless | Scrollable sheet | `AppTheme` |
| `ChangePasswordDialog` | `auth/widgets/change_password_dialog.dart` | Form dialog for updating password | Profiles, Dashboard | `isMandatory` | Stateful (Form validation) | Form inputs, submit | `AuthService` |
| `_StudentDetailModal` | `faculty/screens/faculty_attendance_report_screen.dart` | Bottom sheet for single-student subject attendance | Faculty Reports | `studentId`, `subjectId` | Stateful (Async fetch) | Scrollable sheet | `FacultyService` |
| `ServerConfigDialog` | `auth/screens/login_screen.dart` | Modal for configuring backend URL presets | Login Screen | Current URL | Stateful (URL selection) | Radio selection, health check | `AppPreferences` |

---

## 19. COMPLETE INTERACTIVE BUTTON CATALOG

| Button Identifier | Screen | Role | Purpose | Current Behavior | Route / Destination | API Endpoint | State Change | Authorization | Must Preserve |
|---|---|---|---|---|---|---|---|---|---|
| `LoginSubmitBtn` | `LoginScreen` | Public | Authenticates credentials | Validates form and sends login request | Pushes Dashboard | `POST /api/v1/auth/login` | Authenticated | Public | **Yes** |
| `ServerSettingsBtn` | `LoginScreen` | Public | Opens URL presets modal | Displays server config dialog | Dialog overlay | `GET /health` | Updates base URL | Public | **Yes** |
| `StartSessionBtn` | `FacultyDashboard` | Faculty | Initiates active slot session | Starts session and navigates to live view | Pushes `FacultySessionScreen` | `POST /api/v1/faculty/sessions/start` | `activeSessionId` set | Faculty | **Yes** |
| `ResumeSessionBtn` | `FacultyDashboard` | Faculty | Resumes ongoing session | Navigates to active session view | Pushes `FacultySessionScreen` | None | None | Faculty | **Yes** |
| `AdvisorManageBtn` | `FacultyDashboard` | Advisor | Shortcut to advisor tab | Switches bottom nav index to Advisor tab | Tab Index 2 | None | Tab index updated | Class Advisor | **Yes** |
| `ReportsViewBtn` | `FacultyDashboard` | Faculty | Opens reports interface | Pushes reports screen | Pushes `FacultyAttendanceReportScreen` | None | None | Faculty / Advisor | **Yes** |
| `MarkAttendanceBtn` | `FacultyAttendance` | Faculty | Opens available period entry | Navigates to period entry screen | Pushes `FacultyAttendanceEntryScreen` | None | None | Faculty | **Yes** |
| `EditAttendanceBtn` | `FacultyAttendance` | Faculty | Opens recorded period entry | Navigates to period entry screen in edit mode | Pushes `FacultyAttendanceEntryScreen` | None | None | Faculty | **Yes** |
| `AllPresentBtn` | Entry Screens | Faculty / Advisor | Marks all students Present | Sets all roster items to `PRESENT` | In-place | None | Roster state updated | Faculty / Advisor | **Yes** |
| `AllAbsentBtn` | Entry Screens | Faculty / Advisor | Marks all students Absent | Sets all roster items to `ABSENT` | In-place | None | Roster state updated | Faculty / Advisor | **Yes** |
| `StatusToggleP` | Entry Screens | Faculty / Advisor | Marks individual Present | Sets student status to `PRESENT` | In-place | None | Student status updated | Faculty / Advisor | **Yes** |
| `StatusToggleA` | Entry Screens | Faculty / Advisor | Marks individual Absent | Sets student status to `ABSENT` | In-place | None | Student status updated | Faculty / Advisor | **Yes** |
| `StatusToggleOD` | Entry Screens | Faculty / Advisor | Opens OD reason dialog | Prompts for reason and sets status to `OD` | Dialog overlay | None | Student status updated | Faculty / Advisor | **Yes** |
| `SubmitAttendanceBtn` | Entry Screens | Faculty / Advisor | Submits period attendance | Transmits records to backend | Returns to caller | `POST /attendance/window` or `/class-advisor/attendance` | Records persisted | Faculty / Advisor | **Yes** |
| `AdvisorSummaryBtn` | `ClassAdvisorScreen` | Advisor | Opens half-day summary | Fetches and displays daily summary modal | Dialog overlay | `GET /class-advisor/daily-summary` | None | Class Advisor | **Yes** |
| `TakeGroupPhotoBtn` | `FacultySession` | Faculty | Triggers camera capture | Launches camera image picker | Pushes `ImagePreviewScreen` | None | None | Faculty | **Yes** |
| `RecognizeFacesBtn` | `ImagePreview` | Faculty | Submits photo for AI matching | Uploads image and runs recognition | Pushes `RecognitionReviewScreen` | `POST /sessions/{id}/recognize-image` | Upload state updated | Faculty | **Yes** |
| `ConfirmRecognitionBtn` | `RecognitionReview` | Faculty | Confirms face matches | Sends confirmed student IDs | Pops to `FacultySessionScreen` | `POST /sessions/{id}/confirm-recognition` | Session roster updated | Faculty | **Yes** |
| `CompleteSessionBtn` | `FacultySession` | Faculty | Finalizes attendance session | Completes and locks session | Pops screen | `POST /sessions/{id}/complete` | Session marked completed | Faculty | **Yes** |
| `ChangePasswordBtn` | Profile Screens | All | Opens password dialog | Displays password update form | Dialog overlay | `POST /auth/change-password` | Credentials updated | Authenticated | **Yes** |
| `SignOutBtn` | Profile Screens | All | Logs out user | Clears token and resets navigation | Pushes `LoginScreen` | None | Unauthenticated | Authenticated | **Yes** |

---

## 20. FORM INPUTS, VALIDATION & SEARCH BEHAVIORS

### Text Field Specifications
- **Container**: `TextFormField` wrapped in a 12px rounded container.
- **Borders**: 1px solid border (`#2D3139`); 2px orange border (`#F97316`) when focused; 1.5px red border (`#EF4444`) on error.
- **Background**: Filled with `#181A20`.

### Validation Rules
- **Username / Identifier**: Non-empty; trimmed before submission.
- **Password**: Minimum 8 characters.
- **Confirm Password**: Must match new password.
- **Search Inputs**: Instant client-side filtering across names and roll numbers.

---

## 21. CARD ANATOMY, ELEVATIONS & BORDERS

- **Default Card**: Flat 0dp elevation, background `#1E2026`, 1px solid border (`#2D3139`), 14px border radius.
- **Elevated Card**: Flat 0dp elevation, background `#282A32`, 1.5px accent border (`#F97316` or `#10B981`), subtle shadow.
- **Alert Card**: Low-opacity amber (`#78350F` at 15%) or crimson (`#991B1B` at 15%), 1px solid border.

---

## 22. DIALOGS, MODALS & BOTTOM SHEETS

1. **`ChangePasswordDialog`**: Center modal dialog with form validation. Non-dismissible if `isMandatory == true`.
2. **`DateDetailSheet`**: Draggable rounded bottom sheet showing chronological period breakdown for a selected date.
3. **`SubjectDetailSheet`**: Modal bottom sheet showing subject attendance progress and policies.
4. **`_StudentDetailModal`**: Reports drill-down modal showing single-student subject attendance.
5. **Server Settings Dialog**: Diagnostic modal on login screen for backend URL selection.
6. **Concurrency Conflict Dialog**: Non-dismissible dialog warning of concurrent edits, prompting roster reload.
7. **OD Reason Dialog**: Prompt dialog with quick preset chips for on-duty reasons.

---

## 23. LOADING, ERROR, EMPTY & CONFLICT STATES

- **Loading State**: Centered progress indicator with contextual text (e.g., *"Loading faculty dashboard data..."*).
- **Network Error State**: Cloud off icon (`Icons.cloud_off_rounded`, `#EF4444`), error description, and a `"Retry"` button.
- **Empty Schedule State**: Calendar busy icon (`Icons.event_busy_outlined`, `#64748B`), message *"No classes scheduled for today"*.
- **Empty Search State**: Centered text *"No matching students found"*.
- **Conflict State (409)**: Distinct sync icon (`Icons.sync_problem_rounded`, `#F59E0B`) prompting roster reload.

---

## 24. CURRENT DESIGN SYSTEM & TOKEN SPECIFICATIONS

```
┌─────────────────────────────────────────────────────────────┐
│                       CORE PALETTE                          │
├────────────────────────────────┬────────────────────────────┤
│ Color Name                     │ Hex Value / Code           │
├────────────────────────────────┼────────────────────────────┤
│ Primary Brand Orange           │ #F97316 (Color(0xFFF97316))│
│ Accent Warm Amber              │ #FF8811 (Color(0xFFFF8811))│
│ Background Deep Dark           │ #0F1115 (Color(0xFF0F1115))│
│ Surface Dark                   │ #1E2026 (Color(0xFF1E2026))│
│ Surface Elevated               │ #282A32 (Color(0xFF282A32))│
│ Surface Card Dark              │ #181A20 (Color(0xFF181A20))│
│ Subtle Border                  │ #2D3139 (Color(0xFF2D3139))│
│ Text Primary (High Contrast)   │ #F8FAFC (Color(0xFFF8FAFC))│
│ Text Secondary                 │ #94A3B8 (Color(0xFF94A3B8))│
│ Text Muted                     │ #64748B (Color(0xFF64748B))│
│ Status Present (Emerald)       │ #10B981 (Color(0xFF10B981))│
│ Status Absent (Crimson)        │ #EF4444 (Color(0xFFEF4444))│
│ Status On-Duty (Vibrant OD)    │ #F97316 (Color(0xFFF97316))│
│ Status Warning (Amber)         │ #F59E0B (Color(0xFFF59E0B))│
│ Legacy Navy Accent             │ #1E3A8A (Color(0xFF1E3A8A))│
│ Legacy Blue Light              │ #3B82F6 (Color(0xFF3B82F6))│
└────────────────────────────────┴────────────────────────────┘
```

- **Typography**: Google Fonts `'Inter'` with standard weights (300 light, 400 regular, 500 medium, 600 semi-bold, 700 bold).
- **Corner Radii**: 6px (small tags), 8px (buttons/chips), 12px (text fields), 14px–16px (cards), 24px (bottom sheet tops).

---

## 25. API-TO-UI & UI-TO-API MAPPING MATRIX

### Authentication & Account
- `POST /api/v1/auth/login` $\longleftrightarrow$ `LoginScreen`
- `GET /api/v1/auth/me` $\longleftrightarrow$ `SplashScreen`, Profile Screens
- `POST /api/v1/auth/change-password` $\longleftrightarrow$ `ChangePasswordDialog`
- `GET /health` $\longleftrightarrow$ Server Settings Modal

### Student Endpoints
- `GET /api/v1/students/me` $\longleftrightarrow$ `StudentProfileScreen`
- `GET /api/v1/students/me/dashboard` $\longleftrightarrow$ `StudentDashboardScreen`
- `GET /api/v1/students/me/timetable` $\longleftrightarrow$ `StudentTimetableScreen`
- `GET /api/v1/students/me/attendance` $\longleftrightarrow$ `StudentAttendanceReportScreen`
- `POST /api/v1/students/face/enroll-pose` $\longleftrightarrow$ `BiometricEnrollmentScreen`
- `POST /api/v1/students/face/enroll` $\longleftrightarrow$ `BiometricEnrollmentScreen`

### Faculty & Class Advisor Endpoints
- `GET /api/v1/faculty/me/schedule` $\longleftrightarrow$ `FacultyDashboardScreen`
- `GET /api/v1/faculty/me/active-slot` $\longleftrightarrow$ `FacultyDashboardScreen`
- `GET /api/v1/faculty/attendance/available-periods` $\longleftrightarrow$ `FacultyAttendanceScreen`
- `GET /api/v1/faculty/attendance/periods/{id}/roster` $\longleftrightarrow$ `FacultyAttendanceEntryScreen`
- `POST /api/v1/faculty/attendance/window` $\longleftrightarrow$ `FacultyAttendanceEntryScreen`
- `GET /api/v1/faculty/class-advisor/available-periods` $\longleftrightarrow$ `FacultyClassAdvisorScreen`
- `GET /api/v1/faculty/class-advisor/periods/{id}/roster` $\longleftrightarrow$ `FacultyClassAdvisorEntryScreen`
- `POST /api/v1/faculty/class-advisor/attendance` $\longleftrightarrow$ `FacultyClassAdvisorEntryScreen`
- `GET /api/v1/faculty/class-advisor/daily-summary` $\longleftrightarrow$ `FacultyClassAdvisorScreen`

### Facial Recognition Sessions
- `POST /api/v1/faculty/sessions/start` $\longleftrightarrow$ `FacultyDashboardScreen`
- `GET /api/v1/faculty/sessions/active` $\longleftrightarrow$ `FacultySessionScreen`
- `POST /api/v1/faculty/sessions/{id}/recognize-image` $\longleftrightarrow$ `ImagePreviewScreen`
- `POST /api/v1/faculty/sessions/{id}/confirm-recognition` $\longleftrightarrow$ `RecognitionReviewScreen`
- `POST /api/v1/faculty/sessions/{id}/mark` $\longleftrightarrow$ `FacultySessionScreen`
- `POST /api/v1/faculty/sessions/{id}/complete` $\longleftrightarrow$ `FacultySessionScreen`

### Reports & Matrices
- `GET /api/v1/faculty/reports/authorized-options` $\longleftrightarrow$ `FacultyAttendanceReportScreen`
- `GET /api/v1/faculty/reports/class-summary` $\longleftrightarrow$ `FacultyAttendanceReportScreen` (Summary Mode)
- `GET /api/v1/faculty/reports/date-matrix` $\longleftrightarrow$ `FacultyAttendanceReportScreen` (Daily Matrix Mode)
- `GET /api/v1/faculty/reports/historical-matrix` $\longleftrightarrow$ `FacultyAttendanceReportScreen` (Historical Mode)
- `GET /api/v1/faculty/reports/students/{id}/attendance-detail` $\longleftrightarrow$ `_StudentDetailModal`

---

## 26. DATABASE-TO-FEATURE MAPPING

- **`class_sections.advisor_faculty_id`**: Powers the dynamic unlocking of the 5th tab (`Advisor`) on the Faculty Dashboard and grants whole-class P1–P7 attendance marking authority.
- **`timetable_entries`**: Drives the scheduled timetable slots, active slot detection, and period marking permissions.
- **`attendance_records.od_reason`**: Stores and surfaces official on-duty justification strings across rosters, detail sheets, and daily matrices.
- **`attendance_records.last_updated_at`**: Acts as the optimistic concurrency token (`expected_last_updated`) to prevent dirty writes during simultaneous faculty/advisor edits.

---

## 27. USER JOURNEYS & NAVIGATION STATE MACHINE

### 1. Student Journey
`App Launch` $\to$ `SplashScreen` $\to$ `StudentDashboardScreen` $\to$ Inspect percentage gauge $\to$ If $< 75\%$, read recovery guidance $\to$ View today's schedule $\to$ Switch to Tab 1 (`Attendance`) $\to$ View daily matrices $\to$ Switch to Tab 3 (`Profile`) $\to$ If face incomplete, launch `BiometricEnrollmentScreen` $\to$ Complete 3 poses $\to$ Return to Profile.

### 2. Subject Faculty Journey
`App Launch` $\to$ `SplashScreen` $\to$ `FacultyDashboardScreen` $\to$ Active slot card shows class $\to$ Tap `"START ATTENDANCE SESSION"` $\to$ Takes group photo on `FacultySessionScreen` $\to$ Previews photo on `ImagePreviewScreen` $\to$ Reviews face matches on `RecognitionReviewScreen` $\to$ Confirms matches $\to$ Finalizes session on `FacultySessionScreen` $\to$ Returns to Dashboard.

### 3. Class Advisor Journey
`App Launch` $\to$ `SplashScreen` $\to$ `FacultyDashboardScreen` $\to$ Tap `"MANAGE CLASS ATTENDANCE"` on advisor card $\to$ Lands on Tab 2 (`Class Advisor`) $\to$ Views P1–P4 morning, lunch break, P5–P7 afternoon $\to$ Taps `"View Daily Half-Day Summary"` $\to$ Selects P3 $\to$ Lands on `FacultyClassAdvisorEntryScreen` $\to$ Taps `"All Present"` $\to$ Manually switches two students to `OD` $\to$ Taps `"Submit Attendance"` $\to$ Submits with concurrency token $\to$ Returns to Advisor screen.

---

## 28. SECURITY BOUNDARIES & ENFORCEMENT POINTS

1. **Server-Resolved Identity**: The backend derives identity strictly from the authenticated JWT token. Client-supplied roles and scope claims are disregarded.
2. **Strict Class Scope Guard**: If a Class Advisor requests data for an unassigned class, the backend returns `403 Forbidden`.
3. **Strict Subject Scope Guard**: If a Subject Faculty requests reports for an unassigned subject or the whole class, the backend returns `403 Forbidden`.
4. **Optimistic Concurrency Protection**: Multi-period advisor edits send `expected_last_updated`. If data was modified concurrently, the backend returns `409 Conflict`.
5. **Excluded Break Enforcements**: The lunch break cannot be marked as an attendance session.

---

## 29. RESPONSIVE LAYOUT & CROSS-PLATFORM BEHAVIOR

- **Mobile Viewport (360px–430px)**: Single-column scroll, stacked metric cards, full-width bottom navigation.
- **Desktop Chrome Web (`localhost:3000`)**: Centered card constraints (max-width 420px for dialogs), horizontal scrolling for matrix tables, sticky headers.
- **Web-Safe Media Handling**: Camera and image preview widgets must use `Uint8List` bytes (`await xFile.readAsBytes()`) and `Image.memory` rather than direct `dart:io` `File` references to avoid runtime errors on Flutter Web.

---

## 30. ACCESSIBILITY & CONTRAST AUDIT

- **Contrast Compliance**: Text primary (`#F8FAFC`) on dark surface (`#1E2026`) provides a contrast ratio $> 14:1$, exceeding WCAG AAA standards.
- **Colorblind Support**: Status indicators combine color with distinct icons (check circle for Present, cancel cross for Absent, star for OD).
- **Touch Targets**: All buttons, chips, and list tiles meet or exceed the 44x44 dp minimum touch target requirement.

---

## 31. CURRENT UI FLAWS, INCONSISTENCIES & TECHNICAL LIMITATIONS

1. **Branding Inconsistency**: The legacy string `"AI Face Attendance"` appears on the Splash screen, Login screen, `AndroidManifest.xml`, and `web/index.html`. It should be unified to `"Attendance Marker"`.
2. **Color Palette Dissonance**: Faculty session and review screens use legacy Navy Blue (`#1E3A8A`) and Light Blue (`#3B82F6`), while the rest of the application follows the Vibrant Orange (`#F97316`) and Dark Charcoal (`#0F1115`) palette.
3. **Web Image Preview Issue**: In `image_preview_screen.dart`, `Image.file(_currentImage)` crashes on Flutter Web because `dart:io` `File` is unsupported in browser runtimes. It must be refactored to use `Image.memory` with bytes from `XFile`.
4. **Hardcoded Strings**: Several timetable break labels are hardcoded in UI widgets rather than loaded dynamically from configuration.

---

## 32. TESTING FRAMEWORK & VERIFICATION STATUS

- **Backend Daemon**: FastAPI running on `http://127.0.0.1:8000`.
- **Flutter Web Runtime**: Chrome instance running on `http://localhost:3000`.
- **Verified Roles**:
  - Class Advisor (`fac01`): Verified whole-class P1–P7 viewing, Daily Matrix, and Historical Matrix.
  - Subject Faculty (`fac02`): Verified strict single-subject report scoping with no whole-class leakage.
  - Student: Verified personal dashboard, recovery calculations, and attendance matrices.
  - Admin: Verified administrative console at `http://127.0.0.1:8000/admin`.

---

# 33. WHAT CLAUDE SONNET NEEDS TO KNOW

Dear Claude Sonnet,

As the lead designer and Flutter architect redesigning Attendance Marker (`am-oss`), follow these authoritative implementation directives:

### 1. Visual Design Language
- **Transform the Visual Experience**: Replace the utilitarian dark theme with a premium, world-class academic design language (e.g., refined glassmorphism, subtle micro-gradients, crisp borders, sophisticated typography hierarchy).
- **Unify the Brand**: Eliminate all legacy `"AI Face Attendance"` strings. Standardize on `"Attendance Marker"` with an elegant, modern academic identity.
- **Harmonize the Color System**: Resolve the color dissonance between the faculty screens (`#1E3A8A` Navy) and the core theme (`#F97316` Orange). Establish a coherent primary, secondary, and surface hierarchy.

### 2. Functional & Architecture Integrity
- **Preserve All State & Services**: Do not alter `AuthService`, `StudentService`, `FacultyService`, or `BiometricEnrollmentService` method signatures or models.
- **Maintain Strict Role Boundaries**: Ensure Class Advisors retain whole-class access (`"All Subjects"`, P1–P7) and Subject Faculty remain strictly scoped to authorized subjects and slots.
- **Cross-Platform Web & Mobile Safety**: When redesigning photo capture or image previews, avoid direct `dart:io` `File` references. Use `Uint8List` bytes (`await xFile.readAsBytes()`) and `Image.memory` to guarantee flawless execution on both Flutter Web (Google Chrome) and mobile platforms.
- **Preserve the 7-Period Institutional Day**: Keep the morning P1–P4, tea break, lunch break (strictly non-attendance), and afternoon P5–P7 structure intact.
- **Preserve the Concurrency Conflict Guard**: Keep the `expected_last_updated` token check in Class Advisor entry to prevent race conditions.

You have the complete reverse-engineered truth of the system. Build something exceptional!
