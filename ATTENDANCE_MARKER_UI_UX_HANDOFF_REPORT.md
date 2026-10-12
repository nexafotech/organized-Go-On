# MASTER UI/UX DESIGN HANDOFF DISCOVERY REPORT
## Attendance Marker (`am-oss`) — Current Flutter Mobile Application Reverse-Engineering Specification

> **Target Audience**: Claude Sonnet (Lead Mobile UI/UX Designer & Senior Flutter Design Architect)  
> **Repository Root**: `C:\Users\Abishek\Desktop\am-oss`  
> **Flutter App Root**: `C:\Users\Abishek\Desktop\am-oss\mobile`  
> **Target Environment**: Flutter Web (Google Chrome `http://localhost:3000`) & Android Mobile (`com.aifaceattendance.mobile_app`)  
> **Backend Base URL**: `http://127.0.0.1:8000` (FastAPI / SQLAlchemy / SQLite)  
> **Inspection Status**: 100% Exhaustive Read-Only Discovery Completed across all 41 Dart files, configuration manifests, asset structures, and live web runtime.

---

## TABLE OF CONTENTS
1. [01. Executive Summary](#01-executive-summary)
2. [02. App Identity & Current Branding](#02-app-identity--current-branding)
3. [03. Flutter Architecture & Tech Stack](#03-flutter-architecture--tech-stack)
4. [04. Complete Flutter Directory Map](#04-complete-flutter-directory-map)
5. [05. Master Screen Inventory Table](#05-master-screen-inventory-table)
6. [06. Authoritative Role & Permission Model](#06-authoritative-role--permission-model)
7. [07. Navigation Architecture & Route Hierarchy](#07-navigation-architecture--route-hierarchy)
8. [08. Faculty UI & Experience Anatomy](#08-faculty-ui--experience-anatomy)
9. [09. Class Advisor UI & Experience Anatomy](#09-class-advisor-ui--experience-anatomy)
10. [10. Student UI & Experience Anatomy](#10-student-ui--experience-anatomy)
11. [11. Attendance Marking UI & Workflow](#11-attendance-marking-ui--workflow)
12. [12. Attendance Reports UI & Matrix Engine](#12-attendance-reports-ui--matrix-engine)
13. [13. Historical Matrix UI & Inspection](#13-historical-matrix-ui--inspection)
14. [14. Timetable UI & Period Schedules](#14-timetable-ui--period-schedules)
15. [15. Profile & Account Settings UI](#15-profile--account-settings-ui)
16. [16. 3-Step Biometric Face Enrollment UI](#16-3-step-biometric-face-enrollment-ui)
17. [17. Live Facial Recognition Attendance Flow](#17-live-facial-recognition-attendance-flow)
18. [18. Core UI Components & Micro-Widgets](#18-core-ui-components--micro-widgets)
19. [19. Card Designs, Elevations & Borders](#19-card-designs-elevations--borders)
20. [20. Complete Button Catalog & Interaction States](#20-complete-button-catalog--interaction-states)
21. [21. Input Fields, Forms & Search Bars](#21-input-fields-forms--search-bars)
22. [22. Navigation Flows, Transitions & Stacks](#22-navigation-flows-transitions--stacks)
23. [23. Bottom Sheets, Dialogs & Modals](#23-bottom-sheets-dialogs--modals)
24. [24. Loading, Error, Empty & Conflict States](#24-loading-error-empty--conflict-states)
25. [25. Current Design System & Color Palette](#25-current-design-system--color-palette)
26. [26. State Management & Provider Architecture](#26-state-management--provider-architecture)
27. [27. Comprehensive API & Endpoint Mapping](#27-comprehensive-api--endpoint-mapping)
28. [28. Security Boundaries & Authorization Guards](#28-security-boundaries--authorization-guards)
29. [29. Responsive Behavior & Screen Adaptations](#29-responsive-behavior--screen-adaptations)
30. [30. Accessibility & Contrast Audit](#30-accessibility--contrast-audit)
31. [31. Asset Inventory & Iconography](#31-asset-inventory--iconography)
32. [32. Animation & Micro-Interactions](#32-animation--micro-interactions)
33. [33. Device, Hardware & Platform Dependencies](#33-device-hardware--platform-dependencies)
34. [34. Current UI Bugs, Inconsistencies & UX Flaws](#34-current-ui-bugs-inconsistencies--ux-flaws)
35. [35. Redesign Risks, Guardrails & Non-Negotiables](#35-redesign-risks-guardrails--non-negotiables)
36. [36. Screenshot Evidence & Visual Reference Catalog](#36-screenshot-evidence--visual-reference-catalog)
37. [37. Complete Screen Catalog](#37-complete-screen-catalog)
38. [38. Complete Component Catalog](#38-complete-component-catalog)
39. [39. Complete Button Catalog](#39-complete-button-catalog)
40. [40. Claude Sonnet Master Design Handoff Directives](#40-claude-sonnet-master-design-handoff-directives)

---

## 01. EXECUTIVE SUMMARY

The Attendance Marker (`am-oss`) mobile client is an enterprise-grade academic biometric attendance management application built with Flutter. It connects to a high-performance Python FastAPI backend (`http://127.0.0.1:8000`) and serves two distinct user constituencies:
1. **Students**: Who monitor cumulative attendance percentages, inspect daily period-by-period matrices, view 7-day academic schedules, receive automated below-75% attendance recovery warnings, and perform 3-step AI facial pose enrollment (`FRONTAL`, `LEFT_15`, `RIGHT_15`).
2. **Faculty & Class Advisors**: Who view live teaching schedules, start real-time camera-based facial recognition sessions, take class group photos, review high-confidence/uncertain face recognition matches, record single-period attendance windows for today/yesterday, perform whole-class advisor oversight (all 7 periods P1–P7), and inspect authorized historical matrices.

### Crucial System Architecture Principles
- **Authoritative Backend Security**: The Flutter app is strictly a presentation and interaction layer. Role resolution (`ADMIN`, `CLASS_ADVISOR`, `FACULTY`, `STUDENT`) is strictly derived from the backend JWT bearer token. Flutter never dictates authorization scope.
- **Strict Role-Scoped Presentation**: Class Advisors see all students and subjects for their assigned class; regular Subject Faculty see *only* their assigned subjects and timetable slots; Students see *only* their own personal attendance data.
- **Institutional Timetable Policy**: The college timetable operates strictly on a 7-period day: Morning Session (P1–P4, 09:10–12:50), Institutional Short Break (10:50–11:10), Lunch Break (12:50–13:40, strictly excluded from attendance and denominators), Afternoon Session (P5–P7, 13:40–16:10), with authoritative college dismissal at 16:10.
- **Attendance Windows**: Faculty can only mark attendance after a scheduled period ends (past its scheduled end time) or for yesterday's periods. Active sessions lock down concurrency using optimistic concurrency tokens (`expected_last_updated`).

---

## 02. APP IDENTITY & CURRENT BRANDING

### Current Package & Identity Metadata
- **Pubspec Package Name**: `attendance_marker_mobile`
- **Visible Android App Name** (`AndroidManifest.xml`): `AI Face Attendance`
- **Web Title** (`web/index.html`): `AI Face Attendance`
- **Application ID / Package**: `com.aifaceattendance.mobile_app`
- **Version**: `1.1.0+2`
- **Dart SDK Range**: `>=3.0.0 <4.0.0`
- **Flutter Framework Version**: Detected `3.x` with Material 3 compatibility.

### Visual Branding & Inconsistencies
- **Legacy Branding Detected**: The string `"AI Face Attendance"` is still visible in `SplashScreen`, `AndroidManifest.xml`, `web/index.html`, and `login_screen.dart`.
- **Target Product Branding**: `"Attendance Marker (am-oss)"`. Claude Sonnet must unify this branding into a sleek, premium, modern identity.
- **Logos & Graphics**: Currently uses vector icon glyphs (`Icons.school_rounded`, `Icons.face_retouching_natural_rounded`, `Icons.assignment_turned_in_rounded`) inside elevated circular and rounded-rectangular containers. There are no raster `.png` college crests in the codebase.
- **Font Family**: Google Fonts `'Inter'` configured in `AppTheme.darkTheme`, with fallbacks to system sans-serif.

---

## 03. FLUTTER ARCHITECTURE & TECH STACK

### State Management
- **Architecture**: `Provider` (`ChangeNotifierProvider`) with 4 root providers:
  1. `AuthService`: Authentication state, JWT tokens, user role, login/logout, password change.
  2. `StudentService`: Dashboard summaries, timetable, subject breakdown, date-wise reports.
  3. `FacultyService`: Faculty schedule, active slot, active sessions, attendance window, class advisor management, report matrices.
  4. `BiometricEnrollmentService`: 3-step face enrollment flow, pose capture, angle estimation, upload state.

### Networking & Storage
- **Network Client**: Custom `ApiClient` wrapping `http.Client`.
  - Injects `Authorization: Bearer <token>` automatically.
  - Automatically parses `ApiException` with HTTP status codes (400, 401, 403, 404, 409, 422).
  - Handles 401 unauthorized callbacks (`onUnauthorized`) to trigger clean logouts.
  - 15-second timeout on standard REST calls, 30-second timeout on multipart uploads.
- **Persistent Storage**:
  - `flutter_secure_storage`: Stores `auth_access_token` securely.
  - `shared_preferences`: Stores `pref_selected_role_tab` (`student` vs `faculty`) and `pref_custom_backend_url`.

### Camera & Image Processing
- **Image Picker**: `image_picker: ^1.1.2` for camera capture and gallery selection.
- **Local Face Auditor**: `FaceDetectorService` contains a lightweight INT8 BlazeFace weights loader and face box metric calculator to assist students with pose alignment (Yaw/Pitch/Roll).

---

## 04. COMPLETE FLUTTER DIRECTORY MAP

The Flutter mobile application contains exactly 41 Dart files located inside `mobile/lib/`:

```
mobile/lib/
├── main.dart                                       # App entry point, MultiProvider setup, MaterialApp
├── auth/
│   ├── screens/
│   │   ├── login_screen.dart                       # Dual-role Student/Faculty login, server configuration modal
│   │   └── splash_screen.dart                      # Auth token validation splash, animation, auto-redirect
│   └── widgets/
│       └── change_password_dialog.dart             # Password update dialog (voluntary & mandatory enforcement)
├── core/
│   ├── config/
│   │   └── api_config.dart                         # Backend URLs, IP presets (localhost, hotspot), endpoint paths
│   ├── network/
│   │   └── api_client.dart                         # HTTP client, token injection, timeout, multipart post
│   ├── storage/
│   │   ├── app_preferences.dart                    # SharedPreferences wrapper for UI preferences
│   │   └── secure_storage.dart                     # FlutterSecureStorage for JWT access token
│   └── theme/
│       └── app_theme.dart                          # Design system: colors, typography, shapes, card themes
├── faculty/
│   └── screens/
│       ├── faculty_attendance_entry_screen.dart    # Subject faculty period roster, P/A/OD, bulk actions
│       ├── faculty_attendance_report_screen.dart   # Reports engine: Class Summary, Daily Matrix, Historical Matrix
│       ├── faculty_attendance_screen.dart          # Subject faculty available periods (Today & Yesterday)
│       ├── faculty_class_advisor_entry_screen.dart # Advisor period roster, optimistic concurrency conflict guard
│       ├── faculty_class_advisor_screen.dart       # Advisor P1–P7 timetable view, daily summary dialog
│       ├── faculty_dashboard_screen.dart           # Faculty home: active slot card, schedule, BottomNav
│       ├── faculty_profile_screen.dart             # Faculty metadata, session info, change password, logout
│       ├── faculty_session_screen.dart             # Live active session roster, photo capture trigger, finalize
│       ├── image_preview_screen.dart               # Image preview before facial recognition analysis
│       └── recognition_review_screen.dart          # High-confidence & uncertain candidate face review
├── models/
│   ├── biometric_enrollment_model.dart             # Pose status, angles, bounding box, enrollment response
│   ├── faculty_attendance_model.dart               # Available periods, rosters, advisor models, daily summary
│   ├── faculty_model.dart                          # Faculty schedule, active slot, active session models
│   ├── faculty_report_model.dart                   # Authorized report options, class summary, date/historical matrix
│   ├── recognition_model.dart                      # Face matches, confidence scores, distance metrics
│   ├── student_model.dart                          # Dashboard summary, timetable item, subject & date-wise models
│   └── user_model.dart                             # Current authenticated user, role, flags, isClassAdvisor
├── services/
│   ├── auth_service.dart                           # Login, logout, token verification, change password
│   ├── biometric_enrollment_service.dart           # Step-by-step pose enrollment API caller
│   ├── face_detector_service.dart                  # BlazeFace INT8 auditor, angle & box calculation
│   ├── faculty_service.dart                        # Comprehensive faculty business logic & API repository
│   └── student_service.dart                        # Student summaries, timetable & attendance API repository
├── student/
│   └── screens/
│       ├── biometric_enrollment_screen.dart        # 3-step biometric enrollment with live guidance
│       ├── student_attendance_report_screen.dart   # Student tabbed reports (Subject-Wise & Date-Wise Matrix)
│       ├── student_dashboard_screen.dart           # Student home: percentage gauge, stats, quick timetable
│       ├── student_profile_screen.dart             # Student profile metadata, academic info, actions
│       └── student_timetable_screen.dart           # Day-by-day timetable browser (Mon–Sun) with status chips
└── widgets/
    └── attendance/
        ├── attendance_legend.dart                  # Color-coded legend (Present, Absent, OD, Excluded)
        ├── attendance_summary_card.dart            # Compact 4-box summary (Total, Present, Absent, OD)
        ├── date_detail_sheet.dart                  # Bottom sheet showing period breakdown for a single date
        ├── period_status_chip.dart                 # Period pill (P, A, OD, -, EXCLUDED)
        └── subject_detail_sheet.dart               # Bottom sheet showing subject percentage progress bar
```

---

## 05. MASTER SCREEN INVENTORY TABLE

| # | Screen Name | Class / Widget | Primary Role | Navigation Route | Parent / Caller | Child Screens / Sheets | Primary Action |
|---|-------------|----------------|--------------|------------------|-----------------|------------------------|----------------|
| 1 | Splash Screen | `SplashScreen` | All / Public | Root (`/`) | Application Launch | `LoginScreen`, `StudentDashboardScreen`, `FacultyDashboardScreen` | Auto-check JWT Token & Route |
| 2 | Login Screen | `LoginScreen` | Public | Manual Push | `SplashScreen`, Logout | Server Settings Dialog, Password Dialog | Authenticate credentials via TabBar |
| 3 | Student Dashboard | `StudentDashboardScreen` | Student | Push Replacement | `LoginScreen` | `BiometricEnrollmentScreen`, `DateDetailSheet`, `SubjectDetailSheet` | Monitor attendance gauge & timetable |
| 4 | Student Attendance Reports | `StudentAttendanceReportScreen` | Student | Tab Index 1 | `StudentDashboardScreen` | `DateDetailSheet`, `SubjectDetailSheet` | Toggle Subject-Wise vs Date Matrix |
| 5 | Student Timetable | `StudentTimetableScreen` | Student | Tab Index 2 | `StudentDashboardScreen` | None | Filter weekday schedules (Mon–Sun) |
| 6 | Student Profile | `StudentProfileScreen` | Student | Tab Index 3 | `StudentDashboardScreen` | `BiometricEnrollmentScreen`, `ChangePasswordDialog` | Sign Out / Launch Face Enrollment |
| 7 | Biometric Enrollment | `BiometricEnrollmentScreen` | Student | Push | `StudentProfileScreen`, Dashboard Banner | Camera/Gallery Picker | Enroll Frontal, Left 15°, Right 15° poses |
| 8 | Faculty Dashboard | `FacultyDashboardScreen` | Faculty / Advisor | Push Replacement | `LoginScreen` | `FacultyAttendanceReportScreen`, `FacultySessionScreen`, `ChangePasswordDialog` | Start Session / Open Timetable |
| 9 | Faculty Attendance Windows | `FacultyAttendanceScreen` | Faculty | Tab Index 1 | `FacultyDashboardScreen` | `FacultyAttendanceEntryScreen` | Select Available Period to Mark |
| 10 | Faculty Attendance Entry | `FacultyAttendanceEntryScreen` | Faculty | Push | `FacultyAttendanceScreen` | OD Reason Dialog | Mark P/A/OD & Submit Roster |
| 11 | Class Advisor Overview | `FacultyClassAdvisorScreen` | Class Advisor | Tab Index 2 (Advisor only) | `FacultyDashboardScreen` | `FacultyClassAdvisorEntryScreen`, Daily Summary Dialog | View Whole-Class Schedule (P1–P7) |
| 12 | Class Advisor Entry | `FacultyClassAdvisorEntryScreen` | Class Advisor | Push | `FacultyClassAdvisorScreen` | OD Reason Dialog, Conflict Dialog, Summary Dialog | Record/Edit Multi-Period Roster |
| 13 | Faculty Reports & Matrix | `FacultyAttendanceReportScreen` | Faculty / Advisor | Push (AppBar action) | `FacultyDashboardScreen` | Student Detail Modal, Date Picker, Date Range Picker | View Class Summary, Daily/Historical Matrix |
| 14 | Active Session Roster | `FacultySessionScreen` | Faculty | Push | `FacultyDashboardScreen` | `ImagePreviewScreen`, OD Dialog, Complete Confirm Dialog | Capture Photo / Finalize Session |
| 15 | Image Preview | `ImagePreviewScreen` | Faculty | Push | `FacultySessionScreen` | `RecognitionReviewScreen` | Run Face Recognition on Image |
| 16 | Recognition Review | `RecognitionReviewScreen` | Faculty | Push Replacement | `ImagePreviewScreen` | Radio Candidate Picker | Review High/Uncertain Matches & Confirm |
| 17 | Faculty Profile | `FacultyProfileScreen` | Faculty / Advisor | Tab Index 4 (or 3) | `FacultyDashboardScreen` | `ChangePasswordDialog`, Logout Confirm Dialog | Change Password / Sign Out |

---

## 06. AUTHORITATIVE ROLE & PERMISSION MODEL

The application enforces a strict role-based separation:

```
                  ┌──────────────────────────────┐
                  │      Authenticated User      │
                  │   (JWT Token Decoded on API) │
                  └──────────────┬───────────────┘
                                 │
         ┌───────────────────────┴───────────────────────┐
         ▼                                               ▼
┌──────────────────┐                           ┌──────────────────┐
│   Role: STUDENT  │                           │  Role: FACULTY   │
└────────┬─────────┘                           └────────┬─────────┘
         │                                              │
         ▼                                      ┌───────┴───────┐
┌──────────────────┐                            ▼               ▼
│  Own Attendance  │                    ┌──────────────┐ ┌──────────────┐
│  Own Timetable   │                    │ Is Advisor:  │ │ Is Advisor:  │
│  Own Biometrics  │                    │    FALSE     │ │     TRUE     │
└──────────────────┘                    └──────┬───────┘ └──────┬───────┘
                                               │                │
                        ┌──────────────────────┘                └──────────────────────┐
                        ▼                                                              ▼
        ┌────────────────────────────────┐                             ┌────────────────────────────────┐
        │        SUBJECT FACULTY         │                             │         CLASS ADVISOR          │
        │ - Assigned classes only        │                             │ - Assigned class only          │
        │ - Assigned subjects only       │                             │ - ALL subjects in that class   │
        │ - Assigned periods only        │                             │ - ALL periods (P1–P7)          │
        │ - Roster for own slot only     │                             │ - Whole-class summary & matrix │
        │ - Report: Selected subject     │                             │ - Report: "All Subjects" scope │
        └────────────────────────────────┘                             └────────────────────────────────┘
```

### Authorization Scope Matrix
- **Admin**: Has unrestricted system-wide visibility (accessed via Web Admin Console; not a mobile tab).
- **Class Advisor (`is_class_advisor == true`)**:
  - Automatically gets a 5th bottom navigation tab: `"Advisor"`.
  - Can view and mark all 7 periods (P1–P7) for their assigned class section.
  - Can view the complete Class Summary, Daily Matrix, and Historical Matrix across *all subjects* or filtered by specific subject.
  - Changing class ID to an unauthorized class yields `403 Forbidden` from backend.
- **Subject Faculty (`is_class_advisor == false`)**:
  - Has 4 bottom navigation tabs: `"Dashboard"`, `"Attendance"`, `"Timetable"`, `"Profile"`.
  - Sees only the periods they are personally scheduled to teach.
  - Reports dropdown is restricted strictly to their assigned classes and subjects. Cannot see or select "All Subjects".
- **Student**:
  - Completely restricted to their own register/roll number data.
  - Cannot access faculty endpoints (`/api/v1/faculty/*` returns 403).

---

## 07. NAVIGATION ARCHITECTURE & ROUTE HIERARCHY

The Flutter application relies on an imperative navigation model with `Navigator.push` and `Navigator.pushReplacement`. Named routes are intentionally not used to prevent routing state desynchronization across platforms.

### Top-Level State Tree
```
MaterialApp (theme: AppTheme.darkTheme)
 └── SplashScreen
      ├── (Token Valid + Student Role)  ──► StudentDashboardScreen (IndexedStack)
      │                                       ├── [Tab 0] Dashboard View
      │                                       ├── [Tab 1] StudentAttendanceReportScreen
      │                                       ├── [Tab 2] StudentTimetableScreen
      │                                       └── [Tab 3] StudentProfileScreen
      │
      ├── (Token Valid + Faculty Role)  ──► FacultyDashboardScreen (IndexedStack)
      │                                       ├── [Tab 0] Dashboard View
      │                                       ├── [Tab 1] FacultyAttendanceScreen
      │                                       ├── [Tab 2] FacultyClassAdvisorScreen (if Advisor)
      │                                       ├── [Tab 3] Timetable View
      │                                       └── [Tab 4] FacultyProfileScreen
      │
      └── (No Token / Expired)          ──► LoginScreen
```

---

## 08. FACULTY UI & EXPERIENCE ANATOMY

The Faculty Dashboard (`FacultyDashboardScreen`) serves as the command center for teaching faculty:

### Header & App Bar
- Title: Displays dynamic title corresponding to the active tab (`Faculty Dashboard`, `Attendance`, `Class Advisor`, `Faculty Timetable`, `Faculty Profile`).
- Actions:
  - `assessment_rounded` Icon Button: Direct shortcut to `FacultyAttendanceReportScreen`.
  - `logout_rounded` Icon Button: Triggers immediate secure logout and routes to `LoginScreen`.

### Dashboard Body Structure
1. **Class Advisor Callout Card** *(Conditional: only if `is_class_advisor == true`)*:
   - Deep navy background (`Color(0xFF1E293B)`), rounded 14px border.
   - Badge: Amber pill `"CLASS ADVISOR ASSIGNMENT"`.
   - Title: Class Name (e.g. `"II Year CSE - Section A"`).
   - Subtitle: `"Full advisory authority over all timetable periods & subjects"`.
   - Primary Action Button: `"MANAGE CLASS ATTENDANCE"` -> switches bottom nav index to Advisor tab.
2. **Attendance Reports & Analytics Card**:
   - Icon: Orange graph (`Icons.assessment_rounded`).
   - Title: `"Attendance Reports & Matrix"`.
   - Subtitle: `"Class summary rosters & daily P1–P7 matrices"`.
   - Button: `"View"` (Primary Orange).
3. **Mandatory Password Banner** *(Conditional: if `user.forcePasswordChange == true`)*:
   - Amber alert box with `"Update"` button launching `ChangePasswordDialog`.
4. **Active Session Resume Banner** *(Conditional: if `activeSessionId != null`)*:
   - Blue alert banner with button `"RESUME ATTENDANCE SESSION"` routing to `FacultySessionScreen`.
5. **Current Scheduled Slot Card**:
   - Displays real-time teaching status: `"ACTIVE NOW"` (Green pulse dot) vs `"NO ACTIVE CLASS"`.
   - Displays Subject Name, Subject Code, Class Section, Period number (`P1`–`P7`), and time window (`09:10 - 10:00`).
   - Action Button: `"START ATTENDANCE SESSION"` (Elevated Orange button, triggers `POST /api/v1/faculty/sessions/start`).
6. **Mark Attendance Quick Card**:
   - Green badge with button `"Open"` directing to the Attendance tab.
7. **Today's Schedule Overview**:
   - List of periods assigned for today with period badge, subject title, room/time, and faculty tag.

---

## 09. CLASS ADVISOR UI & EXPERIENCE ANATOMY

The Class Advisor feature set is encapsulated in `FacultyClassAdvisorScreen` and `FacultyClassAdvisorEntryScreen`:

### Key Components
- **Advisor Banner**: Displays assigned class name, academic year, and grade level with an indigo badge.
- **Two Tab Windows**:
  - `TODAY`: Periods scheduled for current calendar date.
  - `YESTERDAY`: Periods scheduled for the preceding calendar date.
- **Period Schedule View**:
  - Morning Session (P1–P4).
  - Short Tea Break Card: Inserted automatically between P2 and P3 (10:50 AM – 11:10 AM).
  - Lunch Break Card: Prominent warning banner between P4 and P5 (12:50 PM – 01:40 PM) explicitly labeled: *"Institutional College Break — Strictly excluded from attendance marking and percentage denominators."*
  - Afternoon Session (P5–P7).
  - College Day End Card: Visual anchor showing *"Authoritative College Day Ends at 4:10 PM"*.
- **Period Status Badges**:
  - `AVAILABLE` (Green): Period has concluded and is open for attendance entry.
  - `RECORDED` (Blue/Orange): Attendance already submitted, displays record count (`(32 RECORDED)`), offers `"EDIT ATTENDANCE"`.
  - `LOCKED` (Amber): Future period or period currently in progress; shows lock reason.
- **Daily Half-Day Summary Button**: Opens modal computing:
  - Full Day Present Count
  - Half-Day Present Count
  - Full Day Absent Count
  - On Duty (OD) Count
  - Partial / Mixed Count
  - Per-student status list with `M: Present | A: Absent` indicators.

---

## 10. STUDENT UI & EXPERIENCE ANATOMY

The Student Dashboard (`StudentDashboardScreen`) prioritizes academic standing transparency and biometric readiness:

### Screen Structure
1. **Student Header Bar**:
   - Student Full Name, Roll Number, Department & Semester badge.
   - Avatar circle with initials.
2. **Attendance Gauge & Percentage Card**:
   - Circular percentage indicator with color coding:
     - `>= 75.0%`: Emerald Green (`#10B981`)
     - `65.0% - 74.9%`: Amber Warning (`#F59E0B`)
     - `< 65.0%`: Critical Red (`#EF4444`)
   - 3 Stat Boxes: Total Classes, Attended Classes, Leave/Absent Count.
3. **Mandatory Recovery Alert** *(Conditional: if percentage < 75%)*:
   - Calculates the exact number of consecutive periods the student must attend to cross the 75% threshold.
4. **Biometric Face Enrollment Status Card**:
   - Shows whether face vector enrollment is complete (`3 of 3 poses enrolled`) or pending (`Enrollment Required`).
   - Direct button: `"COMPLETE ENROLLMENT"`.
5. **Today's Class Schedule Preview**:
   - Horizontal or vertical cards showing today's P1–P7 timetable with real-time badges:
     - `CURRENT CLASS` (Pulsing green)
     - `UPCOMING` (Muted)
     - `COMPLETED` (Checkmark)
     - `FREE PERIOD` (Subtle)
6. **Subject-Wise Summary List**:
   - Expandable cards for each registered course showing individual percentages and progress bars.

---

## 11. ATTENDANCE MARKING UI & WORKFLOW

### Roster Entry Screen (`FacultyAttendanceEntryScreen` & `FacultyClassAdvisorEntryScreen`)
- **Header Card**: Displays Period Name (`Period 1`), Time (`09:10 - 10:00`), Class Section, Subject Title, Subject Code, and Faculty Name.
- **Summary & Bulk Action Bar**:
  - Real-time counters: `Total`, `Present`, `Absent`, `OD`.
  - Quick Action Buttons:
    - `All Present` (Outlined Green button with checkmark).
    - `All Absent` (Outlined Red button with cancel mark).
- **Search Bar**: Live client-side text filtering across student full names and register numbers.
- **Student Roster List Item**:
  - Index number `#1`, `#2`, ...
  - Student Name (bold, text-wrapping enabled).
  - Register / Roll Number.
  - **Segmented P / A / OD Selector**:
    - `P` (Present): Emerald Green container when active.
    - `A` (Absent): Crimson Red container when active.
    - `OD` (On Duty): Orange/Amber container when active.
- **On-Duty (OD) Reason Modal**:
  - When `OD` is tapped, a dialog prompts for an official reason.
  - Preset quick chips: `Sports Event`, `Symposium / Hackathon`, `NSS / NCC Camp`, `Placement Drive`, `Official College Duty`.
  - Custom text input for special cases.
- **Submit Attendance Button**:
  - Fixed bottom bar button with loading spinner state.
  - Concurrency Guard (`FacultyClassAdvisorEntryScreen`): Sends `expected_last_updated`. If another faculty marked attendance in the interim, returns `409 Conflict` and prompts: `"Reload Latest Roster"`.

---

## 12. ATTENDANCE REPORTS UI & MATRIX ENGINE

The unified Faculty Attendance Report Screen (`FacultyAttendanceReportScreen`) provides deep inspection:

### Dynamic Selector Panel
- **Class Selector Dropdown**: Lists all authorized classes. If user is Class Advisor, appends `(Class Advisor)` to the label.
- **Subject Selector Dropdown**:
  - For Subject Faculty: Strictly limited to authorized subjects for that class.
  - For Class Advisor: Contains exclusive top option: `"All Subjects (Advisor Scope)"`.
- **Tri-Mode View Switcher**:
  1. `Summary` (`_viewMode = 0`): Student cumulative attendance roster.
  2. `Daily Matrix` (`_viewMode = 1`): Period-by-period matrix for a single calendar date.
  3. `Historical Matrix` (`_viewMode = 2`): Multi-day tabular matrix across date ranges.

### Mode 0: Class Summary View
- Displays total enrolled student count, average class attendance percentage.
- Search bar to find specific students.
- Student Card: Shows student name, roll number, total hours, attended hours, percentage badge.
- Tapping student card opens `_StudentDetailModal` showing subject-by-subject percentage breakdown.

### Mode 1: Daily Matrix View
- Date Picker trigger showing current selected date.
- Header row with Period Numbers (`P1`–`P7`) and Period Timings.
- Horizontally scrollable student roster:
  - Sticky Left Column: Student Name and Roll Number.
  - Period Cells: Color-coded status chips (`P`, `A`, `OD`, `-`, `EXCLUDED`).
  - Daily Result Tag: `FULL DAY PRESENT`, `HALF-DAY PRESENT`, `FULL DAY ABSENT`.

---

## 13. HISTORICAL MATRIX UI & INSPECTION

Mode 2 in `FacultyAttendanceReportScreen` provides the long-range matrix:

### Configuration & Controls
- **Date Range Picker**: Allows selecting `Start Date` to `End Date`.
  - Minimum selectable date: Class attendance start date (configured in backend).
  - Maximum selectable date: Today's current date.
- **Matrix Layout**:
  - Two-dimensional responsive data table:
    - **Rows**: Enrolled students sorted by roll number.
    - **Columns**: Calendar dates and period slots.
    - **Cell Values**: Compact status chips (`P`, `A`, `OD`, `-`).
  - Trailing Column: Total Hours Attended vs Total Conducted Hours and overall percentage.
- **Performance Optimization**: Lazy-loaded cells with horizontal and vertical physics scroll synchronization.

---

## 14. TIMETABLE UI & PERIOD SCHEDULES

Shared across Student (`StudentTimetableScreen`) and Faculty (`FacultyDashboardScreen` Timetable Tab):

### Institutional Timetable Specification
| Period | Start Time | End Time | Duration | Session Type | Attendance Eligibility |
|--------|------------|----------|----------|--------------|------------------------|
| **P1** | 09:10 AM | 10:00 AM | 50 mins | Morning Session | Counted in Attendance |
| **P2** | 10:00 AM | 10:50 AM | 50 mins | Morning Session | Counted in Attendance |
| *Break* | 10:50 AM | 11:10 AM | 20 mins | Institutional Tea Break | **Excluded** |
| **P3** | 11:10 AM | 12:00 PM | 50 mins | Morning Session | Counted in Attendance |
| **P4** | 12:00 PM | 12:50 PM | 50 mins | Morning Session | Counted in Attendance |
| *Lunch* | 12:50 PM | 01:40 PM | 50 mins | Institutional Lunch Break | **Strictly Excluded** |
| **P5** | 01:40 PM | 02:30 PM | 50 mins | Afternoon Session | Counted in Attendance |
| **P6** | 02:30 PM | 03:20 PM | 50 mins | Afternoon Session | Counted in Attendance |
| **P7** | 03:20 PM | 04:10 PM | 50 mins | Afternoon Session | Counted in Attendance |
| *Dismissal* | 04:10 PM | — | — | End of Academic Day | — |

### Weekday Selection Bar
- Segmented pills: `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT`, `SUN`.
- Current day is highlighted with a blue dot and `"TODAY"` tag.
- Empty states: `Weekend — Sunday has no scheduled classes.` or `No assigned periods configured for this day.`

---

## 15. PROFILE & ACCOUNT SETTINGS UI

Both `StudentProfileScreen` and `FacultyProfileScreen` feature consistent account cards:
- **Profile Header**: Circular avatar with user initial, Full Name, Register/Employee ID, and Active Status badge.
- **Account Details Card**: List tiles showing Full Name, Username, Registered Email, Role Designation, and Account Status.
- **Session Information Card**: Authenticated Role, Backend Server Base URL.
- **Security Actions**:
  - `Change Password`: Opens `ChangePasswordDialog`.
  - `Biometric Enrollment` (Students only): Navigates to `BiometricEnrollmentScreen`.
  - `Sign Out`: Confirmation alert dialog clearing secure storage token and resetting providers.

---

## 16. 3-STEP BIOMETRIC FACE ENROLLMENT UI

The student face enrollment flow (`BiometricEnrollmentScreen`) implements strict AI face positioning:

### Protocol Steps
1. **Pose 1: Frontal Look (`FRONTAL`)**: Looking directly into the camera lens with neutral facial expression.
2. **Pose 2: Head Turned 15° Left (`LEFT_15`)**: Slight left yaw turn.
3. **Pose 3: Head Turned 15° Right (`RIGHT_15`)**: Slight right yaw turn.

### UI Anatomy
- **Step Progress Bar**: 3 circular numbered nodes connected by progress lines.
  - Active step highlighted in Vibrant Orange (`#F97316`).
  - Completed steps show checkmarks in Emerald Green (`#10B981`).
- **Live Guidance Box**:
  - Visual diagram showing required face orientation.
  - Real-time Yaw, Pitch, Roll degree chips (via `FaceDetectorService`).
  - Face bounding box metric feedback (e.g. *"Center your face in the oval frame"*).
- **Camera Capture Actions**:
  - Buttons: `"TAKE PHOTO"` (Camera) and `"CHOOSE FROM GALLERY"` (Upload).
  - Mirror Correction Toggle: Flips horizontal orientation for front-facing webcams.
- **Submission & Vector Generation**:
  - Image is sent to `POST /api/v1/students/face/enroll-pose`.
  - Once all 3 poses are uploaded, calls `POST /api/v1/students/face/enroll` to finalize the face embeddings.

---

## 17. LIVE FACIAL RECOGNITION ATTENDANCE FLOW

The faculty classroom live recognition flow spans 3 coordinated screens:

### Step 1: Active Session (`FacultySessionScreen`)
- Initiated from Faculty Dashboard when a scheduled period is active.
- Top toolbar: `"TAKE GROUP PHOTO"`, `"CAMERA"`, `"GALLERY"`.
- Live roster view with real-time counters (`Total`, `Present`, `Absent`, `OD`).
- Button: `"COMPLETE ATTENDANCE SESSION"` (Locks and finalizes session on backend).

### Step 2: Photo Preview (`ImagePreviewScreen`)
- Fullscreen preview of captured classroom image against black backdrop.
- Actions: `"Retake Photo"` / `"Choose Other"` vs `"Recognize Faces"`.
- Uploads photo via `multipartPost` to `/api/v1/faculty/sessions/{id}/recognize-image`.

### Step 3: Recognition Review (`RecognitionReviewScreen`)
- **Summary Badge Bar**: Faces Detected, High Matches, Uncertain Matches, Unknown Faces.
- **High-Confidence Matches**:
  - Checkbox list tile for each student with confidence score (`94.2%`) and cosine distance (`0.32`).
  - Default state: Pre-selected. Faculty can uncheck false positives.
- **Uncertain Matches (Faculty Review Required)**:
  - Shows candidate options in an adaptive radio group for each ambiguous face.
  - Option to select candidate or choose `"Mark as Unknown / Ignore"`.
- **Unknown Faces Alert**:
  - Crimson warning card detailing how many detected faces had no database match.
- **Final Action**: Button `"Confirm Attendance (N Selected)"` sending confirmed student IDs to `/api/v1/faculty/sessions/{id}/confirm-recognition`.

---

## 18. CORE UI COMPONENTS & MICRO-WIDGETS

### Shared Attendance Widgets (`widgets/attendance/`)
1. **`PeriodStatusChip`**:
   - Compact status indicator pill.
   - States:
     - `PRESENT`: Emerald green background, white checkmark / text.
     - `ABSENT`: Crimson red background, white cross / text.
     - `OD`: Vibrant orange/amber background, star / text.
     - `UNMARKED` / `-`: Dark gray background, dash.
     - `EXCLUDED`: Low-opacity gray pill with lock icon.
2. **`AttendanceLegend`**:
   - Reusable key displaying color indicators for Present, Absent, On Duty (OD), and Excluded / Non-Academic periods.
3. **`AttendanceSummaryCard`**:
   - 4-grid responsive container showing Total Classes, Present, Absent, and OD with color-coded typography.
4. **`DateDetailSheet`**:
   - Modal bottom sheet displaying detailed period timeline for a given date, morning session, lunch break exclusion, and afternoon session.
5. **`SubjectDetailSheet`**:
   - Modal bottom sheet with subject percentage, progress bar, attendance stats, and institutional policy note.

---

## 19. CARD DESIGNS, ELEVATIONS & BORDERS

### Card Design Specifications in `AppTheme`
- **Default Card**:
  - Background: `AppTheme.surfaceCard` (`#1E2026`)
  - Elevation: `0` (flat modern aesthetic)
  - Border: `1.0px` solid `AppTheme.border` (`#2D3139`)
  - Border Radius: `14.0px` or `16.0px`
- **Active / Highlight Card**:
  - Background: `AppTheme.surfaceElevated` (`#282A32`)
  - Border: `1.5px` solid `AppTheme.primary` (`#F97316`) or `AppTheme.statusOk` (`#10B981`)
  - Subtle Box Shadow: `rgba(0, 0, 0, 0.25)`, blur 8px, offset (0, 2).
- **Warning / Alert Card**:
  - Background: Low-opacity amber (`#78350F` at 15% opacity) or crimson (`#991B1B` at 15%).
  - Border: `1.0px` solid `#F59E0B` or `#EF4444`.

---

## 20. COMPLETE BUTTON CATALOG & INTERACTION STATES

| Button Identifier | Widget Type | Background Color | Text / Foreground | Corner Radius | Icon | Triggers / Action |
|-------------------|-------------|------------------|-------------------|---------------|------|-------------------|
| Login Button | `ElevatedButton` | `#F97316` (Primary) | White | 12px | None | Form submit & JWT auth |
| Server Settings Button | `IconButton` | Transparent | `#94A3B8` (Muted) | Circle | `settings_ethernet` | Opens server configuration modal |
| Start Session Button | `ElevatedButton.icon` | `#F97316` (Primary) | White | 10px | `add_task_rounded` | `POST /sessions/start` |
| Resume Session Button | `ElevatedButton.icon` | `#2563EB` (Accent) | White | 10px | `edit_note_rounded` | Pushes `FacultySessionScreen` |
| View Reports Button | `ElevatedButton` | `#F97316` (Primary) | White | 8px | None | Pushes `FacultyAttendanceReportScreen` |
| Mark Attendance (Available) | `ElevatedButton.icon` | `#10B981` (Status OK) | White | 8px | `edit_note` | Pushes `FacultyAttendanceEntryScreen` |
| Edit Attendance (Recorded) | `OutlinedButton.icon` | Transparent | `#F97316` | 8px | `check` / `edit` | Pushes entry screen in edit mode |
| All Present Button | `OutlinedButton.icon` | Transparent | `#10B981` | 8px | `check_circle_outline` | Sets all roster items to `PRESENT` |
| All Absent Button | `OutlinedButton.icon` | Transparent | `#EF4444` | 8px | `cancel_outlined` | Sets all roster items to `ABSENT` |
| Status Toggle 'P' | `InkWell` Animated | `#10B981` (Active) | White / Gray | 8px | Text 'P' | Toggles single student to Present |
| Status Toggle 'A' | `InkWell` Animated | `#EF4444` (Active) | White / Gray | 8px | Text 'A' | Toggles single student to Absent |
| Status Toggle 'OD' | `InkWell` Animated | `#F97316` (Active) | White / Gray | 8px | Text 'OD' | Opens OD reason dialog |
| Submit Attendance Button | `ElevatedButton` | `#F97316` (Primary) | White | 10px | None | Submits window to API |
| Complete Session Button | `ElevatedButton.icon` | `#10B981` | White | 10px | `check_box_rounded` | Finalizes live session |
| Take Group Photo Button | `OutlinedButton.icon` | Navy overlay | White | 8px | `groups_rounded` | Triggers camera image picker |
| Confirm Recognition Button| `ElevatedButton.icon` | `#10B981` | White | 10px | `check_circle_rounded`| Commits face matches to session |
| Change Password Button | `ElevatedButton.icon` | `#FF8811` | White | 8px | `key_rounded` | Opens password update dialog |
| Sign Out Button | `OutlinedButton.icon` | Transparent | `#EF4444` | 8px | `logout_rounded` | Clears token & returns to login |

---

## 21. INPUT FIELDS, FORMS & SEARCH BARS

### Text Input Styling in `AppTheme`
- **Border Style**: `OutlineInputBorder` with 12px border radius.
- **Normal Border**: `#2D3139` (`AppTheme.border`).
- **Focused Border**: `2.0px` solid `#F97316` (`AppTheme.primary`).
- **Error Border**: `1.5px` solid `#EF4444` (`AppTheme.statusAbsent`).
- **Filled Background**: `#181A20` (`AppTheme.surfaceElevated`).
- **Prefix Icons**: Always colored `#94A3B8` (unfocused) or `#F97316` (focused).
- **Search Inputs**: Feature `Icons.search` prefix and clear button `Icons.clear` when text is non-empty.

---

## 22. NAVIGATION FLOWS, TRANSITIONS & STACKS

### Navigation Paradigms
- **IndexedStack Navigation**: Used inside `StudentDashboardScreen` and `FacultyDashboardScreen` to preserve scroll offsets and widget state when switching bottom navigation tabs.
- **Modal Routes**: Pushed onto top navigator (`Navigator.of(context).push`) with standard Material page route slide/fade transitions.
- **Unauthenticated Redirection**: When API client encounters 401 Unauthorized or user logs out, invokes `Navigator.pushAndRemoveUntil(..., (route) => false)` to purge navigation history.

---

## 23. BOTTOM SHEETS, DIALOGS & MODALS

1. **`ChangePasswordDialog`**:
   - Center modal dialog with form validation (min 8 chars, password match, current password check).
   - Can be dismissed if voluntary; completely non-dismissible (`canPop: false`) if `isMandatory == true`.
2. **`DateDetailSheet`**:
   - Draggable rounded bottom sheet with top pill handle.
   - Constrained to max 85% screen height.
3. **`SubjectDetailSheet`**:
   - Modal bottom sheet displaying subject breakdown, progress gauge, and policy info.
4. **`_StudentDetailModal`** (in Faculty Reports):
   - Bottom sheet displaying student's individual attendance across all subjects.
5. **Server Settings Dialog** (on Login Screen):
   - Allows developer/admin to switch backend URL presets (`127.0.0.1:8000`, Hotspot IP, or custom IP) and run a live `/health` test.
6. **Concurrency Conflict Dialog** (in Advisor Entry):
   - Barrier-dismissible `false` dialog warning of concurrent edits, with button `"Reload Latest Roster"`.

---

## 24. LOADING, ERROR, EMPTY & CONFLICT STATES

### Standardized UX Patterns
- **Loading State**: Circular progress indicator centered inside a padded container with contextual text (e.g. *"Loading faculty dashboard data..."*).
- **Network Error State**: Cloud off icon (`Icons.cloud_off_rounded`, `#EF4444`), error description from backend, and an explicit `"Retry"` button calling the failed service method.
- **Empty Schedule State**: Calendar busy icon (`Icons.event_busy_outlined`, `#64748B`), message *"No classes scheduled for today"*.
- **Empty Roster Search State**: *"No matching students found"*.
- **Conflict State (HTTP 409)**: Distinct sync icon (`Icons.sync_problem_rounded`, `#F59E0B`) preventing dirty writes and requiring roster reload.

---

## 25. CURRENT DESIGN SYSTEM & COLOR PALETTE

The current design system is defined in `mobile/lib/core/theme/app_theme.dart`:

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

> **Design System Note for Claude Sonnet**: While `AppTheme.darkTheme` is heavily focused on the `#F97316` Orange / `#0F1115` Dark palette, several legacy faculty screens still hardcode `#1E3A8A` (Navy) and `#3B82F6` (Blue). Claude Sonnet should unify these into a cohesive, luxurious, consistent design language.

---

## 26. STATE MANAGEMENT & PROVIDER ARCHITECTURE

### Provider Graph
```
MultiProvider
 ├── ChangeNotifierProvider<AuthService>
 ├── ChangeNotifierProvider<StudentService>
 ├── ChangeNotifierProvider<FacultyService>
 └── ChangeNotifierProvider<BiometricEnrollmentService>
```

### Reactivity & Lifecycle
- `AuthService.checkAuthStatus()` runs at startup in `SplashScreen`.
- When switching tabs or screens, data is loaded lazily via `WidgetsBinding.instance.addPostFrameCallback((_) => ...)`.
- Pull-to-refresh (`RefreshIndicator`) is wired on all dashboard lists, timetable views, and available period rosters.
- Submitting attendance invalidates cache and triggers an immediate reload of the available periods list.

---

## 27. COMPREHENSIVE API & ENDPOINT MAPPING

All backend communication maps to these exact FastAPI endpoints:

### Authentication & Account
- `POST /api/v1/auth/login`: Student & Faculty login (Form URL encoded / JSON).
- `GET /api/v1/auth/me`: Fetches authenticated user profile & role.
- `POST /api/v1/auth/change-password`: Updates password (`current_password`, `new_password`).
- `GET /health`: Server health check.

### Student Endpoints
- `GET /api/v1/students/me`: Student profile & academic metadata.
- `GET /api/v1/students/me/dashboard`: Cumulative percentage, attended/total counts, recent records.
- `GET /api/v1/students/me/timetable`: 7-day scheduled periods.
- `GET /api/v1/students/me/attendance`: Subject-wise breakdown and date-wise matrix.
- `POST /api/v1/students/face/enroll-pose`: Upload single pose photo (`pose_type`, image file).
- `POST /api/v1/students/face/enroll`: Commit 3-pose facial embeddings.

### Faculty Endpoints
- `GET /api/v1/faculty/me/schedule`: Weekly teaching timetable.
- `GET /api/v1/faculty/me/active-slot`: Current scheduled teaching period (or null).
- `GET /api/v1/faculty/attendance/available-periods`: Periods available to mark today & yesterday.
- `GET /api/v1/faculty/attendance/periods/{id}/roster?date=YYYY-MM-DD`: Student roster for period.
- `POST /api/v1/faculty/attendance/window`: Submit period attendance records.

### Class Advisor Endpoints
- `GET /api/v1/faculty/class-advisor/available-periods`: All P1–P7 periods for advised class (Today & Yesterday).
- `GET /api/v1/faculty/class-advisor/periods/{id}/roster?date=YYYY-MM-DD`: Whole-class roster with `last_updated_at`.
- `POST /api/v1/faculty/class-advisor/attendance`: Submit advisor attendance with concurrency check.
- `GET /api/v1/faculty/class-advisor/daily-summary?date=YYYY-MM-DD`: Daily half-day attendance calculation.

### Live Facial Recognition Session Endpoints
- `POST /api/v1/faculty/sessions/start`: Starts real-time session for active slot.
- `GET /api/v1/faculty/sessions/active`: Checks if faculty has an ongoing session.
- `POST /api/v1/faculty/sessions/{id}/recognize-image`: Multipart upload of group photo for AI face matching.
- `POST /api/v1/faculty/sessions/{id}/confirm-recognition`: Submit confirmed student IDs.
- `POST /api/v1/faculty/sessions/{id}/mark`: Manually mark individual student P/A/OD during session.
- `POST /api/v1/faculty/sessions/{id}/complete`: Finalize and lock attendance session.

### Report & Analytics Endpoints (Role-Scoped)
- `GET /api/v1/faculty/reports/authorized-options`: Authorized classes, subjects, attendance start date, current date.
- `GET /api/v1/faculty/reports/class-summary?class_id=X&subject_id=Y`: Class roster attendance summary.
- `GET /api/v1/faculty/reports/date-matrix?class_id=X&date=YYYY-MM-DD&subject_id=Y`: Daily P1–P7 matrix.
- `GET /api/v1/faculty/reports/historical-matrix?class_id=X&subject_id=Y&start_date=A&end_date=B`: Multi-date historical matrix.
- `GET /api/v1/faculty/reports/students/{id}/attendance-detail?subject_id=Y`: Individual student subject drill-down.

---

## 28. SECURITY BOUNDARIES & AUTHORIZATION GUARDS

Claude Sonnet must never alter or compromise these security guardrails:
1. **Never Trust Client-Side State**: Roles are never asserted by the client. The backend verifies permissions on every request.
2. **Strict Parameter Validation**: If a Subject Faculty changes `class_id` or `subject_id` to an unauthorized entity, backend returns `403 Forbidden`. The Flutter UI must handle 403 gracefully with a user-friendly message.
3. **Optimistic Concurrency Protection**: Multi-faculty and advisor edits rely on `expected_last_updated`. 409 responses must trigger a roster reload dialog.
4. **Excluded Intervals**: Lunch break is hardcoded as non-creditable institutional time. It must never be offered as a markable attendance slot.

---

## 29. RESPONSIVE BEHAVIOR & SCREEN ADAPTATIONS

### Supported Display Modes
1. **Mobile Portrait Viewport** (Primary Android / iOS target: 360px – 430px width):
   - Single-column scrolling, stacked cards, full-width bottom navigation.
2. **Flutter Web / Tablet Viewport** (Desktop Chrome `localhost:3000`):
   - Centered container constraints on dialogs (`maxWidth: 420px`).
   - Sticky left headers on matrices with horizontal scrolling data tables.
   - Web compatibility: Must avoid `dart:io` direct instantiation in web mode without platform checks.

---

## 30. ACCESSIBILITY & CONTRAST AUDIT

### Findings
- **High Contrast Compliant**: Text primary (`#F8FAFC`) on dark surface (`#1E2026`) yields a contrast ratio of > 14:1 (exceeds WCAG AAA).
- **Status Contrast**: Status Present (`#10B981`) and Status Critical (`#EF4444`) are augmented with distinct shape icons (check circle vs cancel cross) so colorblind users are not reliant solely on hue.
- **Touch Target Sizes**: All interactive buttons, chips, and list tiles meet or exceed the 44x44 dp minimum touch target requirement.

---

## 31. ASSET INVENTORY & ICONOGRAPHY

### Visual Asset Summary
- **Raster Images**: `assets/images/` contains no required static bitmaps.
- **Vector Icons**: Standard Flutter `Icons.*` Material icon font is utilized throughout:
  - Academic: `Icons.school_rounded`, `Icons.menu_book_rounded`, `Icons.calendar_today_rounded`
  - Attendance: `Icons.assignment_turned_in_rounded`, `Icons.assessment_rounded`, `Icons.check_circle_rounded`
  - AI & Biometrics: `Icons.face_retouching_natural_rounded`, `Icons.camera_alt_rounded`, `Icons.groups_rounded`
  - State: `Icons.cloud_off_rounded`, `Icons.sync_problem_rounded`, `Icons.lock_clock`

---

## 32. ANIMATION & MICRO-INTERACTIONS

### Current Transitions
- `AnimatedContainer`: Used in status buttons (`_buildStatusButton`) with a 150ms ease-in-out transition when toggling P/A/OD.
- `CircularProgressIndicator`: Displayed inside buttons during network calls (`_isSubmitting`).
- `FadeTransition` / `Hero`: Light usage during splash screen branding fade-in.

---

## 33. DEVICE, HARDWARE & PLATFORM DEPENDENCIES

### Dependencies & Caveats
- **Camera Access**: Requires `android.permission.CAMERA` and `NSCameraUsageDescription`.
- **Flutter Web Caveat**: `image_picker` on Web returns virtual blob URLs. `Image.file(File(...))` in `ImagePreviewScreen` is mobile-native; Claude Sonnet should replace it with `Image.network` or `Image.memory` (via `XFile.readAsBytes()`) to guarantee seamless Flutter Web and mobile cross-compatibility.

---

## 34. CURRENT UI BUGS, INCONSISTENCIES & UX FLAWS

1. **Branding Inconsistency**: `"AI Face Attendance"` is still displayed on the Splash and Login screens, whereas the product name is `"Attendance Marker"`.
2. **Color Palette Dissonance**: Faculty session and review screens utilize legacy Navy Blue (`#1E3A8A`) and Light Blue (`#3B82F6`), while the rest of the application adheres to Vibrant Orange (`#F97316`) and Dark Charcoal (`#0F1115`).
3. **Web Image Preview Crash**: In `image_preview_screen.dart`, `Image.file(_currentImage)` crashes on Flutter Web because `dart:io` `File` is unsupported in browser runtime.
4. **Hardcoded Strings**: Several break and timetable intervals are hardcoded in UI widgets rather than loaded dynamically from configuration.

---

## 35. REDESIGN RISKS, GUARDRAILS & NON-NEGOTIABLES

### Critical Guardrails for Claude Sonnet
> [!CAUTION]
> 1. **DO NOT MODIFY BACKEND APIS OR DATA SCHEMAS**: The redesigned Flutter client must interact with the existing backend endpoints without requiring backend modifications.
> 2. **DO NOT ALTER AUTHORIZATION SCOPES**: A Subject Faculty must never see all subjects or periods. Class Advisor whole-class scope must be strictly preserved.
> 3. **DO NOT BREAK THE 7-PERIOD TIMETABLE STRUCTURE**: P1–P4 morning, tea break, lunch break (strictly non-attendance), P5–P7 afternoon, end of day at 16:10.
> 4. **DO NOT REMOVE THE CONCURRENCY CONFLICT GUARD**: The `expected_last_updated` token check in Class Advisor entry must remain intact to prevent data loss.
> 5. **PRESERVE THE 3-STEP BIOMETRIC PROTOCOL**: Step 1 Frontal, Step 2 Left 15°, Step 3 Right 15°.

---

## 36. SCREENSHOT EVIDENCE & VISUAL REFERENCE CATALOG

The following verified screenshot artifacts illustrate the live application state:
- **`advisor_real_summary.png`**: Class Advisor dashboard overview with assigned class callout.
- **`advisor_real_daily_matrix.png`**: Class Advisor Daily Matrix showing all subjects across P1–P7.
- **`advisor_real_historical.png`**: Class Advisor Historical Matrix spanning academic dates.
- **`live_fac02_daily_matrix.png`**: Subject Faculty Daily Matrix scoped strictly to Java Programming Laboratory.
- **`live_fac02_historical.png`**: Subject Faculty Historical Matrix showing only authorized periods.
- **`chrome_step3_reports_summary.png`**: Reports Summary roster with percentage badges and search bar.
- **`device_faculty_dashboard.png`**: Mobile view of Faculty Dashboard with active scheduled slot.

---

## 37. COMPLETE SCREEN CATALOG

### Screen 1: Splash Screen (`auth/screens/splash_screen.dart`)
- **Widget**: `SplashScreen` (StatefulWidget)
- **Role**: All / Public
- **Visuals**: Centered school icon inside glowing circle, app title `"AI Face Attendance"`, subtitle, and spinner.
- **Logic**: Reads secure storage token -> verifies via `/api/v1/auth/me` -> routes to Student or Faculty Dashboard or Login.

### Screen 2: Login Screen (`auth/screens/login_screen.dart`)
- **Widget**: `LoginScreen` (StatefulWidget)
- **Role**: Public
- **Visuals**: Dual tab bar (`STUDENT` vs `FACULTY`), identifier input, password input with eye toggle, sign in button, settings icon in corner.
- **Logic**: Saves role tab in SharedPreferences; authenticates against `POST /api/v1/auth/login`.

### Screen 3: Student Dashboard (`student/screens/student_dashboard_screen.dart`)
- **Widget**: `StudentDashboardScreen` (StatefulWidget)
- **Role**: Student
- **Visuals**: Percentage circular gauge, 3 stat boxes, recovery recommendation banner, face enrollment status card, today's schedule list, subject cards.
- **Navigation**: 4-tab bottom navigation (`Dashboard`, `Attendance`, `Timetable`, `Profile`).

### Screen 4: Student Attendance Reports (`student/screens/student_attendance_report_screen.dart`)
- **Widget**: `StudentAttendanceReportScreen` (StatelessWidget)
- **Role**: Student
- **Visuals**: TabBar (`Subject-Wise` vs `Date-Wise Matrix`), summary card, attendance legend, expandable daily list.

### Screen 5: Student Timetable (`student/screens/student_timetable_screen.dart`)
- **Widget**: `StudentTimetableScreen` (StatefulWidget)
- **Role**: Student
- **Visuals**: Day selector (`Mon`–`Sun`), period cards with status badges (`CURRENT CLASS`, `UPCOMING`, `COMPLETED`, `FREE PERIOD`).

### Screen 6: Student Profile (`student/screens/student_profile_screen.dart`)
- **Widget**: `StudentProfileScreen` (StatelessWidget)
- **Role**: Student
- **Visuals**: Profile header, Academic Details card, Session Info card, Biometric Enrollment trigger, Change Password, Sign Out.

### Screen 7: Biometric Face Enrollment (`student/screens/biometric_enrollment_screen.dart`)
- **Widget**: `BiometricEnrollmentScreen` (StatefulWidget)
- **Role**: Student
- **Visuals**: 3-step progress bar, pose direction graphic, angle guidance chips, camera/gallery buttons, mirror toggle.

### Screen 8: Faculty Dashboard (`faculty/screens/faculty_dashboard_screen.dart`)
- **Widget**: `FacultyDashboardScreen` (StatefulWidget)
- **Role**: Faculty / Class Advisor
- **Visuals**: Advisor card (conditional), Reports card, Password banner, Active Session banner, Active Class Slot card, Quick Access card, Schedule list.
- **Navigation**: 4 or 5 tabs (`Dashboard`, `Attendance`, `[Advisor]`, `Timetable`, `Profile`).

### Screen 9: Faculty Attendance Windows (`faculty/screens/faculty_attendance_screen.dart`)
- **Widget**: `FacultyAttendanceScreen` (StatefulWidget)
- **Role**: Faculty
- **Visuals**: TabBar (`TODAY` vs `YESTERDAY`), informational notice banner, period cards with status pill (`AVAILABLE`, `RECORDED`, `LOCKED`).

### Screen 10: Faculty Attendance Entry (`faculty/screens/faculty_attendance_entry_screen.dart`)
- **Widget**: `FacultyAttendanceEntryScreen` (StatefulWidget)
- **Role**: Faculty
- **Visuals**: Slot header, stat counter bar, `All Present` / `All Absent` buttons, search bar, roster list with P/A/OD segmented buttons, submit bottom bar.

### Screen 11: Class Advisor Overview (`faculty/screens/faculty_class_advisor_screen.dart`)
- **Widget**: `FacultyClassAdvisorScreen` (StatefulWidget)
- **Role**: Class Advisor
- **Visuals**: Class header, TabBar (`TODAY` vs `YESTERDAY`), Daily Summary shortcut button, P1–P4 list, short break, lunch break card, P5–P7 list, end of day footer.

### Screen 12: Class Advisor Entry (`faculty/screens/faculty_class_advisor_entry_screen.dart`)
- **Widget**: `FacultyClassAdvisorEntryScreen` (StatefulWidget)
- **Role**: Class Advisor
- **Visuals**: Roster with P/A/OD, concurrency token tracking, optimistic conflict resolution dialog, submit button.

### Screen 13: Faculty Reports & Matrix (`faculty/screens/faculty_attendance_report_screen.dart`)
- **Widget**: `FacultyAttendanceReportScreen` (StatefulWidget)
- **Role**: Faculty / Class Advisor
- **Visuals**: Class & Subject dropdown selectors, mode toggle (`Summary`, `Daily Matrix`, `Historical Matrix`), date picker, date range picker, interactive data tables.

### Screen 14: Active Session Roster (`faculty/screens/faculty_session_screen.dart`)
- **Widget**: `FacultySessionScreen` (StatefulWidget)
- **Role**: Faculty
- **Visuals**: Session toolbar (`TAKE GROUP PHOTO`, `CAMERA`, `GALLERY`), attendance counters, student roster list with manual mark icons, complete session button.

### Screen 15: Image Preview (`faculty/screens/image_preview_screen.dart`)
- **Widget**: `ImagePreviewScreen` (StatefulWidget)
- **Role**: Faculty
- **Visuals**: Black backdrop photo preview, Retake/Choose Other button, Recognize Faces button with loading state.

### Screen 16: Recognition Review (`faculty/screens/recognition_review_screen.dart`)
- **Widget**: `RecognitionReviewScreen` (StatefulWidget)
- **Role**: Faculty
- **Visuals**: Summary badge bar, high-confidence matches with checkboxes, uncertain matches with candidate radio groups, unknown faces alert card, confirm attendance button.

### Screen 17: Faculty Profile (`faculty/screens/faculty_profile_screen.dart`)
- **Widget**: `FacultyProfileScreen` (StatelessWidget)
- **Role**: Faculty / Class Advisor
- **Visuals**: Faculty avatar header, Account Details card, Session Info card, Change Password, Sign Out.

---

## 38. COMPLETE COMPONENT CATALOG

1. **`PeriodStatusChip`**: Period status pill displaying `PRESENT`, `ABSENT`, `OD`, `UNMARKED`, or `EXCLUDED`.
2. **`AttendanceLegend`**: Color key for attendance statuses.
3. **`AttendanceSummaryCard`**: 4-column summary metric box.
4. **`DateDetailSheet`**: Modal bottom sheet showing chronological period breakdown for a selected date.
5. **`SubjectDetailSheet`**: Modal bottom sheet showing subject attendance progress.
6. **`ChangePasswordDialog`**: Form dialog for updating user credentials.
7. **`_StudentDetailModal`**: Reports drill-down modal showing single-student subject attendance.
8. **`ServerConfigDialog`**: Diagnostic modal on login screen for backend URL selection.
9. **`ScheduleCard`**: Period card showing period number, subject name, code, class section, timings, and faculty.
10. **`StatBox`**: Rounded box showing a numerical value and descriptive label.

---

## 39. COMPLETE BUTTON CATALOG

All interactive buttons in the application are enumerated in [Section 20: Complete Button Catalog & Interaction States](#20-complete-button-catalog--interaction-states).

---

## 40. CLAUDE SONNET MASTER DESIGN HANDOFF DIRECTIVES

Dear Claude Sonnet,

As the lead designer and Flutter architect redesigning Attendance Marker (`am-oss`), follow these authoritative implementation directives:

### 1. Visual Design Language
- **Transform the Visual Experience**: Replace the utilitarian dark theme with a premium, world-class academic design language (e.g. refined glassmorphism, subtle micro-gradients, crisp borders, sophisticated typography hierarchy).
- **Unify the Brand**: Eliminate all legacy `"AI Face Attendance"` strings. Standardize on `"Attendance Marker"` with elegant, modern academic identity.
- **Harmonize the Color System**: Unify the color dissonance between the faculty screens (`#1E3A8A` Navy) and the core theme (`#F97316` Orange). Establish a coherent primary, secondary, and surface hierarchy.

### 2. Functional & Architecture Integrity
- **Preserve All State & Services**: Do not alter `AuthService`, `StudentService`, `FacultyService`, or `BiometricEnrollmentService` method signatures or models.
- **Maintain Strict Role Boundaries**: Ensure Class Advisors retain whole-class access (`"All Subjects"`, P1–P7) and Subject Faculty remain strictly scoped to authorized subjects and slots.
- **Cross-Platform Web & Mobile Safety**: When redesigning photo capture or image previews, avoid direct `dart:io` `File` references. Use `Uint8List` bytes (`await xFile.readAsBytes()`) and `Image.memory` to guarantee flawless execution on both Flutter Web (Google Chrome) and mobile platforms.
- **Preserve the 7-Period Institutional Day**: Never alter the morning P1–P4, lunch break exclusion, and afternoon P5–P7 structure.

You have the complete reverse-engineered truth of the system. Build something exceptional!
