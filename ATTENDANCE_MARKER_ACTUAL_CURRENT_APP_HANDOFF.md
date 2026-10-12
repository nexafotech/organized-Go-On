# ATTENDANCE MARKER — ACTUAL CURRENT PROJECT HANDOFF
## Read-Only Discovery & Technical Specifications of the Existing Codebase

> **Repository Root**: `C:\Users\Abishek\Desktop\am-oss`  
> **Mobile App Root**: `C:\Users\Abishek\Desktop\am-oss\mobile`  
> **Backend Base URL**: `http://127.0.0.1:8000` (FastAPI / SQLite / SQLAlchemy)  
> **Admin Web UI**: `http://127.0.0.1:8000/admin`  
> **Flutter Testing Runtime**: Flutter Web in Google Chrome (`http://localhost:3000`)  
> **Document Status**: 100% Factual Source-Code Audit. No redesign proposals. No invented functionality.  

---

# 1. PROJECT OVERVIEW

- **Application Name**:
  - Codebase / Repository: Attendance Marker (`am-oss`)
  - Flutter Package Name (`pubspec.yaml`): `attendance_marker_mobile` (version `1.1.0+2`)
  - Visible Android App Label (`AndroidManifest.xml`): `AI Face Attendance`
  - Web Title (`web/index.html`): `AI Face Attendance`
  - Application ID / Package Namespace: `com.aifaceattendance.mobile_app`
- **Project Structure**:
  - `app/`: Python FastAPI backend server (API routes, core database, domain engines, schemas, services, static assets, templates).
  - `mobile/`: Flutter client application (cross-platform, tested via Chrome Web and Android Native).
  - `tests/`: Pytest backend test suites (academic models, timetable, attendance windows, policy engine, facial recognition).
  - `college_seed/`: Seed data configuration files (`faculty_assignments.json`, `subjects.json`, `timetable_class1.json`).
  - `docs/`: Production reports and data audit documentation.
- **Backend Technology**:
  - Framework: Python 3.10+ with FastAPI and Starlette.
  - Server / ASGI: Uvicorn (`app.main:app`).
  - ORM: SQLAlchemy 2.0.
  - Migrations: Alembic.
  - Image / AI Processing: OpenCV (`cv2`), NumPy, InsightFace / ONNX Runtime (SCRFD detection + ArcFace 512-dimensional vector embeddings).
  - Security / Auth: `passlib` (Bcrypt password hashing), `python-jose` (JWT Bearer tokens with HS256).
- **Frontend Technology (Mobile Client)**:
  - Framework: Flutter 3.x (Dart SDK `>=3.0.0 <4.0.0`).
  - Material System: Material 3 enabled (`uses-material-design: true`).
  - State Management: `provider: ^6.1.1` (`MultiProvider`, `ChangeNotifierProvider`).
  - Network Client: `http: ^1.2.0` with custom `ApiClient`.
  - Storage: `flutter_secure_storage: ^9.0.0` (encrypted JWT storage) and `shared_preferences: ^2.2.2` (UI configuration).
  - Image Acquisition: `image_picker: ^1.0.7`.
  - Iconography & Fonts: `cupertino_icons: ^1.0.6`, Material Icons font, Google Fonts `'Inter'`.
- **Database Technology**:
  - Engine: SQLite (`sqlite:///./attendance_marker.db`) operated in synchronous mode with foreign key support.
- **Major Modules**:
  1. Administrative Web Console (`/admin`): Complete institutional management panel for students, faculty, classes, subjects, timetables, and audit trails.
  2. Authentication & Security Engine: JWT issuance, role decoding, bcrypt verification, mandatory password updates, diagnostic support mode.
  3. Attendance Policy Engine (`AttendancePolicyEngine`): Centralized percentage calculation, 75% threshold monitoring, OD treatment, morning/afternoon half-day evaluation.
  4. Timetable Engine: 7-period day modeling (P1–P7), break exclusions, active slot detection, attendance window lockouts.
  5. Biometric Face Engine: Multi-pose enrollment (`FRONTAL`, `LEFT_15`, `RIGHT_15`), ArcFace embeddings, classroom group photo recognition.
  6. Attendance Window System: Single-period marking workflows restricted to completed slots for today and yesterday.
  7. Role-Scoped Reports Engine: Summary rosters, daily period-by-period matrices, multi-day historical matrices.
- **Development & Test Environment**:
  - Backend running as a daemon on `http://127.0.0.1:8000`.
  - Mobile testing performed exclusively on Flutter Web in Google Chrome at `http://localhost:3000`. Physical mobile devices and emulators are not used.

---

# 2. FLUTTER PROJECT STRUCTURE

Every file and directory listed below physically exists in `mobile/`:

```
mobile/
├── pubspec.yaml
├── web/
│   ├── index.html
│   └── manifest.json
├── android/
│   ├── app/
│   │   ├── build.gradle.kts
│   │   └── src/main/AndroidManifest.xml
├── test/
│   ├── attendance_report_test.dart
│   ├── auth_service_test.dart
│   ├── biometric_enrollment_test.dart
│   ├── face_detector_service_test.dart
│   ├── faculty_attendance_window_test.dart
│   ├── faculty_dashboard_debug_test.dart
│   ├── login_ux_test.dart
│   ├── profile_and_password_test.dart
│   ├── recognition_test.dart
│   ├── security_and_consistency_test.dart
│   ├── timetable_ux_test.dart
│   └── widget_test.dart
└── lib/
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

# 3. STATE MANAGEMENT

- **Architecture**: `Provider` (`ChangeNotifier` pattern).
- **Application Startup (`mobile/lib/main.dart`)**:
  - `main()` executes `WidgetsFlutterBinding.ensureInitialized()`.
  - Configures a root `MultiProvider` declaring four top-level `ChangeNotifierProvider` instances:
    1. `ChangeNotifierProvider<AuthService>(create: (_) => AuthService())`
    2. `ChangeNotifierProvider<StudentService>(create: (_) => StudentService())`
    3. `ChangeNotifierProvider<FacultyService>(create: (_) => FacultyService())`
    4. `ChangeNotifierProvider<BiometricEnrollmentService>(create: (_) => BiometricEnrollmentService())`
  - Instantiates `MaterialApp` with `theme: AppTheme.darkTheme` and `home: const SplashScreen()`.
- **Services & Responsibilities**:
  - `AuthService` (`mobile/lib/services/auth_service.dart`):
    - Owns `_currentUser` (`UserModel?`), `_isLoading`, `_errorMessage`, `_sessionExpired`.
    - Manages `restoreSession()`, `loginStudent()`, `loginFaculty()`, `changePassword()`, `logout()`, `validateIdentifier()`.
    - Automatically attaches `_handleUnauthorized` callback to `ApiClient` to clear secure storage and flag session expiry on HTTP 401.
  - `StudentService` (`mobile/lib/services/student_service.dart`):
    - Owns `_summary` (`StudentDashboardSummaryModel?`), `_subjects` (`List<SubjectAttendanceModel>`), `_timetable` (`List<TimetableItemModel>`), `_dateWise` (`List<DateWiseEntryModel>`), `_isLoading`, `_errorMessage`.
    - Calls `fetchStudentSummary()`, `fetchSubjects()`, `fetchTimetable()`, `fetchAttendanceReport()`, `loadDashboardData()`.
  - `FacultyService` (`mobile/lib/services/faculty_service.dart`):
    - Owns `_schedule` (`List<FacultyScheduleItem>`), `_activeSlot` (`ActiveClassSlot?`), `_hasActiveSlot`, `_activeSessionId`, `_roster` (`List<RosterStudentModel>`), `_isClassAdvisor`, `_advisedClass` (`AdvisedClassInfo?`).
    - Dispatches session creation, recognition confirmation, window marking submissions, Class Advisor multi-period workflows, and report fetching.
  - `BiometricEnrollmentService` (`mobile/lib/services/biometric_enrollment_service.dart`):
    - Owns `_status` (`EnrollmentStatusModel?`), `_currentStep` (0 = Frontal, 1 = Left 15°, 2 = Right 15°), `_capturedImages` (`Map<PoseType, File>`), `_isComplete`.
    - Validates pose angles, executes upload requests, and handles enrollment reset.
  - `FaceDetectorService` (`mobile/lib/services/face_detector_service.dart`):
    - Lightweight BlazeFace INT8 auditor providing real-time yaw/pitch/roll degree feedback and bounding box coordinates for student guidance.

---

# 4. NAVIGATION

The application uses imperative navigation (`Navigator.push`, `Navigator.pushReplacement`, `Navigator.pushAndRemoveUntil`) without named route generators.

```
                                [App Launch]
                                     │
                                     ▼
                               SplashScreen
                                     │
                 ┌───────────────────┴───────────────────┐
                 │ (No Token / Expired)                  │ (Valid Token)
                 ▼                                       ▼
            LoginScreen                            Role Evaluated
        [Tab 0: Student Tab]                             │
        [Tab 1: Faculty Tab]              ┌──────────────┴──────────────┐
                 │                        │                             │
    ┌────────────┴────────────┐           ▼                             ▼
    ▼                         ▼      (STUDENT)                      (FACULTY)
Login Student           Login Faculty     │                             │
    │                         │           ▼                             ▼
    ▼                         ▼    StudentDashboardScreen       FacultyDashboardScreen
StudentDashboard        FacultyDashboard  (IndexedStack)                (IndexedStack)
                                          Tab 0: Dashboard              Tab 0: Dashboard
                                          Tab 1: Reports                Tab 1: Attendance
                                          Tab 2: Timetable              Tab 2: Advisor (if advisor)
                                          Tab 3: Profile                Tab 3/2: Timetable
                                                                        Tab 4/3: Profile
```

### Detailed Route Specifications
1. **Startup**: `SplashScreen` (`auth/screens/splash_screen.dart`).
   - If `restoreSession()` returns null $\to$ `Navigator.pushReplacement` to `LoginScreen`.
   - If `user.isStudent` $\to$ `Navigator.pushReplacement` to `StudentDashboardScreen`.
   - If `user.isFaculty` $\to$ `Navigator.pushReplacement` to `FacultyDashboardScreen`.
2. **Login Screen**: `LoginScreen` (`auth/screens/login_screen.dart`).
   - Contains a `TabController(length: 2)`.
   - Tab 0: Student Login. Upon success $\to$ `Navigator.pushReplacement` to `StudentDashboardScreen`.
   - Tab 1: Faculty Login. Upon success $\to$ `Navigator.pushReplacement` to `FacultyDashboardScreen`.
3. **Student Navigation Stack**: `StudentDashboardScreen` (`student/screens/student_dashboard_screen.dart`).
   - Utilizes `IndexedStack` governed by `_currentIndex` over `BottomNavigationBar`:
     - **Index 0**: Dashboard Home View (`_buildDashboardTab`).
     - **Index 1**: `StudentAttendanceReportScreen`.
     - **Index 2**: `StudentTimetableScreen`.
     - **Index 3**: `StudentProfileScreen`.
   - Modals pushed from this stack:
     - Dashboard Biometric Banner / Profile Action $\to$ `Navigator.push` to `BiometricEnrollmentScreen`.
     - Date Card Tap $\to$ `showModalBottomSheet` for `DateDetailSheet`.
     - Subject Card Tap $\to$ `showModalBottomSheet` for `SubjectDetailSheet`.
     - Change Password $\to$ `showDialog` for `ChangePasswordDialog`.
4. **Faculty Navigation Stack**: `FacultyDashboardScreen` (`faculty/screens/faculty_dashboard_screen.dart`).
   - Dynamically configures `IndexedStack` based on `isAdvisor`:
     - **If `isAdvisor == true` (5 Tabs)**:
       - **Index 0**: Dashboard Home View.
       - **Index 1**: `FacultyAttendanceScreen` (Mark Attendance).
       - **Index 2**: `FacultyClassAdvisorScreen` (Advisor Management).
       - **Index 3**: Timetable View (`_buildTimetableTab`).
       - **Index 4**: `FacultyProfileScreen`.
     - **If `isAdvisor == false` (4 Tabs)**:
       - **Index 0**: Dashboard Home View.
       - **Index 1**: `FacultyAttendanceScreen`.
       - **Index 2**: Timetable View (`_buildTimetableTab`).
       - **Index 3**: `FacultyProfileScreen`.
   - Routes pushed from Faculty Dashboard:
     - AppBar Reports Icon $\to$ `Navigator.push` to `FacultyAttendanceReportScreen`.
     - Active Slot Card `"START ATTENDANCE SESSION"` $\to$ `Navigator.push` to `FacultySessionScreen`.
     - Active Session Banner `"RESUME ATTENDANCE SESSION"` $\to$ `Navigator.push` to `FacultySessionScreen`.
     - Attendance Window Card `"MARK ATTENDANCE"` $\to$ `Navigator.push` to `FacultyAttendanceEntryScreen`.
     - Advisor Period Card `"RECORD ATTENDANCE"` / `"EDIT ATTENDANCE"` $\to$ `Navigator.push` to `FacultyClassAdvisorEntryScreen`.
     - Faculty Session Toolbar `"TAKE GROUP PHOTO"` $\to$ `Navigator.push` to `ImagePreviewScreen`.
     - Image Preview `"Recognize Faces"` $\to$ `Navigator.pushReplacement` to `RecognitionReviewScreen`.
     - Change Password $\to$ `showDialog` for `ChangePasswordDialog`.
     - Logout Action $\to$ `Navigator.pushReplacement` to `LoginScreen`.

---

# 5. COMPLETE SCREEN INVENTORY

The mobile application contains exactly 17 screens across all roles:

### 1. `SplashScreen`
- **File**: `mobile/lib/auth/screens/splash_screen.dart`
- **Role**: Public / Unauthenticated
- **How Reached**: Application startup (`main.dart` root).
- **Purpose**: Restores user session from encrypted storage and routes to the correct dashboard.
- **Main UI Elements**: Centered circle avatar with `Icons.school_rounded`, text `"AI Face Attendance"`, subtitle `"Face-Recognized Academic Precision"`, `CircularProgressIndicator`.
- **Buttons / Inputs / Lists / Cards / Tabs**: None.
- **Dialogs / Sheets**: None.
- **Data Displayed**: Static branding.
- **API / Service**: `AuthService.restoreSession()`, `GET /api/v1/auth/me`.
- **State Used**: `authService.isLoading`.
- **Navigation Actions**: `pushReplacement` to `StudentDashboardScreen`, `FacultyDashboardScreen`, or `LoginScreen`.
- **Loading State**: Circular progress indicator centered on dark background.
- **Error State**: Non-blocking; clears invalid tokens and defaults to `LoginScreen`.
- **Empty State**: None.
- **Success State**: Smooth transition to destination screen.

### 2. `LoginScreen`
- **File**: `mobile/lib/auth/screens/login_screen.dart`
- **Role**: Public
- **How Reached**: Launched by `SplashScreen` or on logout.
- **Purpose**: Authenticates students and faculty members.
- **Main UI Elements**: Header icon, subtitle `"Enterprise Smart Campus Solution"`, `TabBar` with `"STUDENT"` and `"FACULTY"`, identifier input, password input with visibility toggle, login button, server configuration button.
- **Buttons**: `"Sign In"` (`ElevatedButton`), Server config icon button (`Icons.settings_ethernet`).
- **Inputs**: Student Roll No field, Student Password field, Faculty ID field, Faculty Password field.
- **Lists / Cards**: `Card` wrapping login forms.
- **Tabs**: 2 tabs (`STUDENT`, `FACULTY`).
- **Dialogs / Sheets**: Server configuration dialog (`showDialog`).
- **Data Displayed**: Form inputs, live faculty validation status (`✓ Faculty account recognized` / `Invalid faculty username`).
- **API / Service**: `AuthService.loginStudent()`, `AuthService.loginFaculty()`, `AuthService.validateIdentifier()`, `POST /api/v1/auth/student/login`, `POST /api/v1/auth/login`.
- **State Used**: Form validation keys, password visibility booleans, `FacultyValidationState`.
- **Navigation Actions**: `pushReplacement` to `StudentDashboardScreen` or `FacultyDashboardScreen`.
- **Loading State**: Submission spinner inside button; live checking indicator on username field.
- **Error State**: Floating red SnackBar with exact backend detail string.
- **Empty State**: Standard input hint text.
- **Success State**: Immediate route push.

### 3. `StudentDashboardScreen`
- **File**: `mobile/lib/student/screens/student_dashboard_screen.dart`
- **Role**: Student
- **How Reached**: Following student login or session restoration.
- **Purpose**: Serves as student home; displays attendance standing, recovery targets, schedule preview, and subject cards.
- **Main UI Elements**: Student profile header, circular percentage gauge, 3 summary stat boxes (Total, Attended, Absent), recovery guidance banner, biometric status card, schedule preview cards, expandable subject breakdown cards, bottom navigation bar.
- **Buttons**: `"COMPLETE ENROLLMENT"`, Bottom nav tabs.
- **Inputs**: None.
- **Lists**: `ListView` containing schedule and subject breakdown items.
- **Cards**: Attendance gauge card, Biometric status card, Schedule cards, Subject progress cards.
- **Tabs**: Bottom navigation (Dashboard, Attendance, Timetable, Profile).
- **Dialogs / Sheets**: Tapping dates/subjects launches `DateDetailSheet` or `SubjectDetailSheet`.
- **Data Displayed**: Full name, roll number, overall percentage, attended/total class counts, recovery classes needed.
- **API / Service**: `StudentService.loadDashboardData()`, `GET /api/v1/students/me/dashboard`, `GET /api/v1/students/me/timetable`.
- **State Used**: `StudentService.summary`, `StudentService.timetable`, `StudentService.isLoading`.
- **Navigation Actions**: Bottom navigation index switching; push to `BiometricEnrollmentScreen`.
- **Loading State**: Centered `CircularProgressIndicator`.
- **Error State**: Retry button with error message.
- **Empty State**: Informational cards for missing timetable or attendance records.
- **Success State**: Populated dashboard metrics.

### 4. `StudentAttendanceReportScreen`
- **File**: `mobile/lib/student/screens/student_attendance_report_screen.dart`
- **Role**: Student
- **How Reached**: Student Bottom Nav Index 1.
- **Purpose**: Displays subject-wise progress and daily date-wise period matrices.
- **Main UI Elements**: `TabBar` (`Subject-Wise`, `Date-Wise Matrix`), `AttendanceSummaryCard`, `AttendanceLegend`, subject progress list, date-wise matrix card list with lunch break banner.
- **Buttons**: Subject items and date rows trigger detail sheets.
- **Inputs**: None.
- **Lists**: `ListView` of subjects or date entries.
- **Cards**: `AttendanceSummaryCard`, daily matrix expandable cards.
- **Tabs**: 2 tabs (`Subject-Wise`, `Date-Wise Matrix`).
- **Dialogs / Sheets**: `SubjectDetailSheet`, `DateDetailSheet`.
- **Data Displayed**: Subject attendance percentages, daily period status chips (P, A, OD, -, EXCLUDED).
- **API / Service**: `StudentService.fetchAttendanceReport()`, `GET /api/v1/student/attendance`.
- **State Used**: `studentService.dateWise`, `studentService.subjects`.
- **Navigation Actions**: Bottom sheet launches.
- **Loading State**: Centered spinner.
- **Error State**: Error card with retry button.
- **Empty State**: "No attendance records found."
- **Success State**: Fully rendered lists.

### 5. `StudentTimetableScreen`
- **File**: `mobile/lib/student/screens/student_timetable_screen.dart`
- **Role**: Student
- **How Reached**: Student Bottom Nav Index 2.
- **Purpose**: Displays 7-day student timetable.
- **Main UI Elements**: Day selector row (`Mon`–`Sun`), period cards with badges (`CURRENT CLASS`, `UPCOMING`, `COMPLETED`, `FREE PERIOD`), subject name, room, faculty name, timings.
- **Buttons**: Day selector chips.
- **Inputs**: None.
- **Lists**: `ListView` of timetable period items.
- **Cards**: Period schedule cards.
- **Tabs**: Weekday selector bar.
- **Dialogs / Sheets**: None.
- **Data Displayed**: Period number, start/end times, subject title, subject code, teacher name.
- **API / Service**: `StudentService.fetchTimetable()`, `GET /api/v1/student/timetable`.
- **State Used**: `_selectedDayCode`, `studentService.timetable`.
- **Navigation Actions**: In-tab day switching.
- **Loading State**: Centered progress indicator.
- **Error State**: Error view with retry action.
- **Empty State**: "No classes scheduled for [Day]."
- **Success State**: Populated timetable list.

### 6. `StudentProfileScreen`
- **File**: `mobile/lib/student/screens/student_profile_screen.dart`
- **Role**: Student
- **How Reached**: Student Bottom Nav Index 3.
- **Purpose**: Displays student metadata, academic details, and security actions.
- **Main UI Elements**: Avatar header, Academic Details card, Session Info card, Biometric Enrollment tile, Change Password button, Sign Out button.
- **Buttons**: `"Biometric Face Enrollment"`, `"Change Password"`, `"Sign Out"`.
- **Inputs**: None.
- **Lists**: `ListView` of account details.
- **Cards**: Academic Details, Session Info, Account Actions.
- **Tabs**: None.
- **Dialogs / Sheets**: `ChangePasswordDialog`, Logout confirmation dialog.
- **Data Displayed**: Full name, roll number, register number, class/section, semester, email, backend base URL.
- **API / Service**: `AuthService.currentUser`, `AuthService.logout()`.
- **State Used**: `authService.currentUser`.
- **Navigation Actions**: Pushes `BiometricEnrollmentScreen`, opens password dialog, logs out to `LoginScreen`.
- **Loading State**: Standard rendering.
- **Error State**: None.
- **Empty State**: Fallback text if fields are absent.
- **Success State**: Populated profile.

### 7. `BiometricEnrollmentScreen`
- **File**: `mobile/lib/student/screens/biometric_enrollment_screen.dart`
- **Role**: Student
- **How Reached**: Pushed from Student Profile or Dashboard banner.
- **Purpose**: 3-step biometric facial pose capture (`FRONTAL`, `LEFT_15`, `RIGHT_15`).
- **Main UI Elements**: Step progress indicator (1, 2, 3), instruction card, live angle guidance chips (Yaw, Pitch, Roll), camera view/preview, mirror correction toggle, capture buttons.
- **Buttons**: `"TAKE PHOTO"`, `"CHOOSE FROM GALLERY"`, `"Retake"`, Mirror toggle.
- **Inputs**: None.
- **Lists**: None.
- **Cards**: Protocol card, Live assistance card.
- **Tabs**: None.
- **Dialogs / Sheets**: Completion dialog.
- **Data Displayed**: Current pose title, angle metrics, face box instructions.
- **API / Service**: `BiometricEnrollmentService`, `POST /api/v1/student/enroll-face/validate-pose`, `POST /api/v1/student/enroll-face/capture`.
- **State Used**: `_currentStep`, `_capturedImages`, `_isUploading`.
- **Navigation Actions**: Returns to caller when done.
- **Loading State**: Spinner during pose validation and image transmission.
- **Error State**: Red banner describing face positioning errors.
- **Empty State**: Camera placeholder prior to capture.
- **Success State**: Step advance animation.

### 8. `FacultyDashboardScreen`
- **File**: `mobile/lib/faculty/screens/faculty_dashboard_screen.dart`
- **Role**: Faculty / Class Advisor
- **How Reached**: Following faculty authentication or session restoration.
- **Purpose**: Main workspace for faculty to view active slots, start sessions, and access advisor tools.
- **Main UI Elements**: Class Advisor callout card (if advisor), Reports card, Password update banner, Active Session resume banner, Scheduled Slot card (`ACTIVE NOW` vs `NO ACTIVE CLASS`), Quick Access card, Schedule list, Bottom navigation bar.
- **Buttons**: `"START ATTENDANCE SESSION"`, `"MANAGE CLASS ATTENDANCE"`, `"View"` (Reports), `"Open"` (Attendance window), AppBar Reports icon, Logout icon.
- **Inputs**: None.
- **Lists**: `ListView` of today's schedule items.
- **Cards**: Class Advisor card, Scheduled Slot card, Mark Attendance quick card, Reports card.
- **Tabs**: 4 tabs (Standard Faculty) or 5 tabs (Class Advisor).
- **Dialogs / Sheets**: `ChangePasswordDialog`.
- **Data Displayed**: Subject title, subject code, class section, period timing, teacher name, active slot status.
- **API / Service**: `FacultyService.loadDashboardData()`, `FacultyService.startAttendanceSession()`, `GET /api/v1/faculty/timetable`, `GET /api/v1/faculty/active-class`, `POST /api/v1/faculty/sessions/start`.
- **State Used**: `facultyService.schedule`, `facultyService.activeSlot`, `facultyService.activeSessionId`, `facultyService.isClassAdvisor`.
- **Navigation Actions**: Bottom nav index switching; pushes `FacultyAttendanceReportScreen`, `FacultySessionScreen`, `FacultyAttendanceScreen`.
- **Loading State**: Centered progress indicator with message.
- **Error State**: Error container with retry button.
- **Empty State**: "No teaching sessions scheduled for today."
- **Success State**: Populated schedule and active slot cards.

### 9. `FacultyAttendanceScreen`
- **File**: `mobile/lib/faculty/screens/faculty_attendance_screen.dart`
- **Role**: Subject Faculty
- **How Reached**: Faculty Bottom Nav Index 1.
- **Purpose**: Displays completed periods available for attendance marking for today and yesterday.
- **Main UI Elements**: `TabBar` (`TODAY`, `YESTERDAY`), informational notice banner, period cards with status pills (`AVAILABLE`, `RECORDED`, `LOCKED`).
- **Buttons**: `"MARK ATTENDANCE"` (Green button), `"ATTENDANCE RECORDED"` (Outlined button), Refresh icon.
- **Inputs**: None.
- **Lists**: `ListView` for each tab.
- **Cards**: Available period cards.
- **Tabs**: 2 tabs (`TODAY`, `YESTERDAY`).
- **Dialogs / Sheets**: None.
- **Data Displayed**: Period number, timings, subject title, subject code, class section, lock reason.
- **API / Service**: `FacultyService.fetchAvailableAttendancePeriods()`, `GET /api/v1/faculty/attendance/available-periods`.
- **State Used**: `_data` (`AvailablePeriodsResponse`), `_isLoading`.
- **Navigation Actions**: Pushes `FacultyAttendanceEntryScreen`.
- **Loading State**: Centered spinner.
- **Error State**: Error view with retry action.
- **Empty State**: "No scheduled classes for this day."
- **Success State**: Populated period cards.

### 10. `FacultyAttendanceEntryScreen`
- **File**: `mobile/lib/faculty/screens/faculty_attendance_entry_screen.dart`
- **Role**: Subject Faculty
- **How Reached**: Pushed from `FacultyAttendanceScreen`.
- **Purpose**: Allows subject faculty to record per-student attendance (P, A, OD) for a completed period.
- **Main UI Elements**: Period header card, stat counter bar (Total, Present, Absent, OD), `All Present` and `All Absent` action buttons, search bar, roster list with segmented P/A/OD controls, fixed submit button.
- **Buttons**: `"Submit Attendance"` (`ElevatedButton`), `"All Present"` (`OutlinedButton`), `"All Absent"` (`OutlinedButton`), segmented status buttons (`P`, `A`, `OD`).
- **Inputs**: Student search text field.
- **Lists**: `ListView` of students.
- **Cards**: Header info card, Student roster card.
- **Tabs**: None.
- **Dialogs / Sheets**: OD reason prompt dialog (`showDialog`).
- **Data Displayed**: Student name, roll number, index number, assigned status.
- **API / Service**: `FacultyService.fetchAttendanceRoster()`, `FacultyService.submitAttendanceWindow()`, `GET /api/v1/faculty/attendance/roster/{id}`, `POST /api/v1/faculty/attendance/submit`.
- **State Used**: `_students`, `_isSubmitting`, `_searchQuery`.
- **Navigation Actions**: Pops back to caller returning `true` on success.
- **Loading State**: Roster loading spinner; button spinner during submission.
- **Error State**: Error view with retry; floating red snackbar on submission error.
- **Empty State**: "No matching students found."
- **Success State**: Green snackbar: "Attendance submitted successfully."

### 11. `FacultyClassAdvisorScreen`
- **File**: `mobile/lib/faculty/screens/faculty_class_advisor_screen.dart`
- **Role**: Class Advisor
- **How Reached**: Faculty Bottom Nav Index 2 (Advisor only).
- **Purpose**: Provides whole-class attendance oversight across all P1–P7 periods and all subjects.
- **Main UI Elements**: Advisor class banner, `TabBar` (`TODAY`, `YESTERDAY`), `"View Daily Half-Day Summary for this date"` button, Morning session list (P1–P4), Short break card (10:50–11:10), Lunch break card (12:50–13:40), Afternoon session list (P5–P7), College end card (16:10).
- **Buttons**: `"RECORD ATTENDANCE"` (Green button), `"EDIT ATTENDANCE"` (Outlined button), `"View Daily Half-Day Summary for this date"`.
- **Inputs**: None.
- **Lists**: `ListView` of morning and afternoon periods.
- **Cards**: Period cards, Break cards, Class header.
- **Tabs**: 2 tabs (`TODAY`, `YESTERDAY`).
- **Dialogs / Sheets**: Daily half-day summary dialog (`showDialog`).
- **Data Displayed**: Class name, grade/year, teacher names, period status pills (`AVAILABLE`, `RECORDED`, `LOCKED`).
- **API / Service**: `FacultyService.fetchClassAdvisorAvailablePeriods()`, `FacultyService.fetchClassAdvisorDailySummary()`, `GET /api/v1/faculty/class-advisor/available-periods`, `GET /api/v1/faculty/class-advisor/daily-summary`.
- **State Used**: `_data` (`ClassAdvisorAvailablePeriodsResponse`), `_isLoading`.
- **Navigation Actions**: Pushes `FacultyClassAdvisorEntryScreen`.
- **Loading State**: Centered progress indicator.
- **Error State**: Error message with retry action.
- **Empty State**: "No morning/afternoon timetable periods scheduled."
- **Success State**: Populated whole-class schedule.

### 12. `FacultyClassAdvisorEntryScreen`
- **File**: `mobile/lib/faculty/screens/faculty_class_advisor_entry_screen.dart`
- **Role**: Class Advisor
- **How Reached**: Pushed from `FacultyClassAdvisorScreen`.
- **Purpose**: Multi-period whole-class attendance marking interface with optimistic concurrency protection.
- **Main UI Elements**: Period header card, stat counter bar, `All Present` and `All Absent` buttons, search bar, roster list with segmented P/A/OD controls, fixed submit button.
- **Buttons**: `"Submit Attendance"` (`ElevatedButton`), `"All Present"`, `"All Absent"`, segmented status buttons (`P`, `A`, `OD`).
- **Inputs**: Student search text field.
- **Lists**: `ListView` of students.
- **Cards**: Slot header, Student cards.
- **Tabs**: None.
- **Dialogs / Sheets**: OD reason prompt dialog, Concurrency conflict dialog (on 409), Daily summary dialog (on success).
- **Data Displayed**: Student name, roll number, assigned status, `last_updated_at` tracking.
- **API / Service**: `FacultyService.fetchClassAdvisorRoster()`, `FacultyService.submitClassAdvisorAttendance()`, `GET /api/v1/faculty/class-advisor/roster/{id}`, `POST /api/v1/faculty/class-advisor/submit`.
- **State Used**: `_students`, `_lastUpdatedAt`, `_isSubmitting`, `_searchQuery`.
- **Navigation Actions**: Pops back to caller after showing daily summary.
- **Loading State**: Roster spinner; submit button spinner.
- **Error State**: On 409, launches non-dismissible dialog: `"Concurrency Conflict - Reload Latest Roster"`.
- **Empty State**: "No matching students found."
- **Success State**: Displays daily summary dialog.

### 13. `FacultyAttendanceReportScreen`
- **File**: `mobile/lib/faculty/screens/faculty_attendance_report_screen.dart`
- **Role**: Faculty / Class Advisor
- **How Reached**: Pushed from Faculty Dashboard AppBar icon or Dashboard Reports card.
- **Purpose**: Role-scoped attendance reports with Summary, Daily Matrix, and Historical Matrix views.
- **Main UI Elements**: Class dropdown, Subject dropdown, Mode toggle buttons (`Summary`, `Daily Matrix`, `Historical Matrix`), Date picker / Date range picker, Roster summary list, Period matrix table, Historical matrix table.
- **Buttons**: Mode toggle buttons, Date picker button, Date range picker button.
- **Inputs**: Student search field, Class selector dropdown, Subject selector dropdown.
- **Lists / Tables**: Roster list, horizontally scrollable `DataTable` or custom matrix grids.
- **Cards**: Class Summary card, Student metric card, Selector container.
- **Tabs**: Tri-mode selector buttons.
- **Dialogs / Sheets**: `_StudentDetailModal` (bottom sheet on student tap), DatePicker dialog, DateRangePicker dialog.
- **Data Displayed**: Class average percentage, total hours, attended hours, P1–P7 period attendance status chips, calendar dates.
- **API / Service**: `FacultyService.fetchReportAuthorizedOptions()`, `FacultyService.fetchClassSummaryReport()`, `FacultyService.fetchDateMatrixReport()`, `FacultyService.fetchHistoricalMatrixReport()`, `GET /api/v1/faculty/reports/*`.
- **State Used**: `_selectedClass`, `_selectedSubject`, `_viewMode` (0, 1, 2), `_selectedDate`, `_histStartDate`, `_histEndDate`.
- **Navigation Actions**: Launches `_StudentDetailModal`.
- **Loading State**: Spinner during option loading and report fetching.
- **Error State**: Error message with retry action.
- **Empty State**: "No attendance data available."
- **Success State**: Populated summary rosters or matrix tables.

### 14. `FacultySessionScreen`
- **File**: `mobile/lib/faculty/screens/faculty_session_screen.dart`
- **Role**: Faculty
- **How Reached**: Pushed when starting or resuming an attendance session.
- **Purpose**: Live classroom session manager with camera integration and roster overview.
- **Main UI Elements**: Session toolbar (`TAKE GROUP PHOTO`, `CAMERA`, `GALLERY`), attendance counters (Total, Present, Absent, OD), roster list with manual mark icons, complete session button.
- **Buttons**: `"TAKE GROUP PHOTO"`, `"CAMERA"`, `"GALLERY"`, `"COMPLETE ATTENDANCE SESSION"`, per-student mark icons (Check, Cancel, Card).
- **Inputs**: None.
- **Lists**: `ListView` of students.
- **Cards**: Student list tiles.
- **Tabs**: None.
- **Dialogs / Sheets**: OD reason prompt dialog, Session completion confirmation dialog.
- **Data Displayed**: Active session ID, student names, roll numbers, attendance statuses.
- **API / Service**: `FacultyService.checkActiveSession()`, `FacultyService.markAttendance()`, `FacultyService.completeSession()`, `POST /api/v1/faculty/sessions/{id}/attendance`, `POST /api/v1/faculty/sessions/{id}/complete`.
- **State Used**: `facultyService.activeSessionId`, `facultyService.roster`.
- **Navigation Actions**: Pushes `ImagePreviewScreen`; pops back to dashboard upon completion.
- **Loading State**: Button spinner during completion.
- **Error State**: Floating snackbars.
- **Empty State**: "No enrolled students in roster."
- **Success State**: Real-time counter updates.

### 15. `ImagePreviewScreen`
- **File**: `mobile/lib/faculty/screens/image_preview_screen.dart`
- **Role**: Faculty
- **How Reached**: Pushed from `FacultySessionScreen` after capturing/selecting an image.
- **Purpose**: Previews captured classroom photo before submitting for AI face recognition.
- **Main UI Elements**: Full-screen photo view against black background, `"Retake Photo"` / `"Choose Other"` button, `"Recognize Faces"` button with spinner.
- **Buttons**: `"Recognize Faces"`, `"Retake Photo"` / `"Choose Other"`.
- **Inputs**: None.
- **Lists**: None.
- **Cards**: Error banner card.
- **Tabs**: None.
- **Dialogs / Sheets**: None.
- **Data Displayed**: Photo preview.
- **API / Service**: `FacultyService.uploadGroupPhoto()`, `POST /api/v1/faculty/sessions/{id}/recognize-image`.
- **State Used**: `_currentImage`, `_isUploading`, `_errorMessage`.
- **Navigation Actions**: `pushReplacement` to `RecognitionReviewScreen` on success.
- **Loading State**: Circular progress indicator inside button.
- **Error State**: Red banner displaying server error.
- **Empty State**: None.
- **Success State**: Route transition to review screen.

### 16. `RecognitionReviewScreen`
- **File**: `mobile/lib/faculty/screens/recognition_review_screen.dart`
- **Role**: Faculty
- **How Reached**: Pushed by `ImagePreviewScreen` following recognition.
- **Purpose**: Review and confirm AI facial recognition matches.
- **Main UI Elements**: Summary badge bar (Faces, High Match, Uncertain, Unknown), high-confidence matches with checkboxes, uncertain matches with candidate radio groups, unknown faces card, confirm button.
- **Buttons**: `"Confirm Attendance (N Selected)"`, match checkboxes, candidate radio buttons.
- **Inputs**: Radio groups for uncertain candidates.
- **Lists**: `ListView` of match categories.
- **Cards**: Match cards, Unknown faces warning card.
- **Tabs**: None.
- **Dialogs / Sheets**: None.
- **Data Displayed**: Confidence score percentage, distance score, candidate names and roll numbers.
- **API / Service**: `FacultyService.confirmRecognition()`, `POST /api/v1/faculty/sessions/{id}/confirm-recognition`.
- **State Used**: `_selectedHighConfidenceIds`, `_uncertainSelections`, `_isConfirming`.
- **Navigation Actions**: Pops back to `FacultySessionScreen` on success.
- **Loading State**: Confirm button shows spinner.
- **Error State**: Red banner on confirmation failure.
- **Empty State**: "No close candidates found."
- **Success State**: Snackbar: "Attendance recorded for N student(s)."

### 17. `FacultyProfileScreen`
- **File**: `mobile/lib/faculty/screens/faculty_profile_screen.dart`
- **Role**: Faculty / Class Advisor
- **How Reached**: Faculty Bottom Nav Tab 4 (or 3).
- **Purpose**: Displays faculty metadata, session info, and account actions.
- **Main UI Elements**: Avatar header card, Account Details card, Session Info card, Change Password button, Sign Out button.
- **Buttons**: `"Change Password"`, `"Sign Out"`.
- **Inputs**: None.
- **Lists**: `ListView` of account details.
- **Cards**: Profile header card, Account Details card, Session Info card, Account Actions card.
- **Tabs**: None.
- **Dialogs / Sheets**: `ChangePasswordDialog`, Logout confirmation dialog.
- **Data Displayed**: Full name, username/employee ID, email, role, active status, backend URL.
- **API / Service**: `AuthService.currentUser`, `AuthService.logout()`.
- **State Used**: `authService.currentUser`.
- **Navigation Actions**: Opens `ChangePasswordDialog`, signs out to `LoginScreen`.
- **Loading State**: Standard card rendering.
- **Error State**: None.
- **Empty State**: Fallback text if fields are absent.
- **Success State**: Populated profile.

---

# 6. COMPLETE WIDGET INVENTORY

The codebase contains 8 primary reusable components:

### 1. `PeriodStatusChip`
- **File**: `mobile/lib/widgets/attendance/period_status_chip.dart`
- **Purpose**: Renders a compact status pill for a period slot.
- **Used By**: `StudentAttendanceReportScreen`, `DateDetailSheet`, `FacultyAttendanceReportScreen`.
- **Inputs / Props**: `String? status`, `String? odReason`, `bool showLabel`, `double fontSize`.
- **State**: Stateless.
- **User Interactions**: None (display only).

### 2. `AttendanceLegend`
- **File**: `mobile/lib/widgets/attendance/attendance_legend.dart`
- **Purpose**: Displays a color-coded legend explaining attendance statuses.
- **Used By**: `StudentAttendanceReportScreen`, `FacultyAttendanceReportScreen`.
- **Inputs / Props**: None.
- **State**: Stateless.
- **User Interactions**: None.

### 3. `AttendanceSummaryCard`
- **File**: `mobile/lib/widgets/attendance/attendance_summary_card.dart`
- **Purpose**: 4-column summary metric box (Total, Present, Absent, OD).
- **Used By**: `StudentAttendanceReportScreen`.
- **Inputs / Props**: `int total`, `int present`, `int absent`, `int od`.
- **State**: Stateless.
- **User Interactions**: None.

### 4. `DateDetailSheet`
- **File**: `mobile/lib/widgets/attendance/date_detail_sheet.dart`
- **Purpose**: Draggable modal bottom sheet displaying period breakdown for a selected date.
- **Used By**: `StudentDashboardScreen`, `StudentAttendanceReportScreen`.
- **Inputs / Props**: `DateWiseEntryModel entry`.
- **State**: Stateless.
- **User Interactions**: Draggable scroll view; close on tap outside or drag down.

### 5. `SubjectDetailSheet`
- **File**: `mobile/lib/widgets/attendance/subject_detail_sheet.dart`
- **Purpose**: Modal bottom sheet showing subject attendance progress and policies.
- **Used By**: `StudentDashboardScreen`, `StudentAttendanceReportScreen`.
- **Inputs / Props**: `SubjectAttendanceModel subject`.
- **State**: Stateless.
- **User Interactions**: Scrollable sheet.

### 6. `ChangePasswordDialog`
- **File**: `mobile/lib/auth/widgets/change_password_dialog.dart`
- **Purpose**: Form dialog for updating user passwords (voluntary or mandatory).
- **Used By**: `StudentProfileScreen`, `FacultyProfileScreen`, `StudentDashboardScreen`, `FacultyDashboardScreen`.
- **Inputs / Props**: `bool isMandatory`.
- **State**: Stateful (`_formKey`, text controllers, visibility flags, submitting state).
- **User Interactions**: Password text entry, visibility toggling, cancel, submit, sign out (if mandatory).

### 7. `_StudentDetailModal`
- **File**: `mobile/lib/faculty/screens/faculty_attendance_report_screen.dart`
- **Purpose**: Modal bottom sheet showing single-student subject attendance breakdown.
- **Used By**: `FacultyAttendanceReportScreen`.
- **Inputs / Props**: `int studentId`, `int? subjectId`.
- **State**: Stateful (fetches data on launch via `fetchStudentDetailReport`).
- **User Interactions**: Scrollable sheet.

### 8. `ServerConfigDialog`
- **File**: `mobile/lib/auth/screens/login_screen.dart`
- **Purpose**: Modal dialog for selecting or entering backend server URL presets.
- **Used By**: `LoginScreen`.
- **Inputs / Props**: Current URL.
- **State**: Stateful (radio selection, custom text controller, connection test result).
- **User Interactions**: Radio selection, text entry, test connection, save.

---

# 7. BUTTON / ACTION INVENTORY

| Action | Screen | Role | File Path | What It Does | API / Service | Navigation Result |
|---|---|---|---|---|---|---|
| **Sign In** | `LoginScreen` | Public | `auth/screens/login_screen.dart` | Submits login credentials | `AuthService.loginStudent` or `loginFaculty` | `pushReplacement` to Dashboard |
| **Server Settings** | `LoginScreen` | Public | `auth/screens/login_screen.dart` | Opens server configuration dialog | `GET /health` | Dialog overlay |
| **Start Session** | `FacultyDashboard` | Faculty | `faculty/screens/faculty_dashboard_screen.dart` | Starts attendance session for active slot | `FacultyService.startAttendanceSession` | Pushes `FacultySessionScreen` |
| **Resume Session** | `FacultyDashboard` | Faculty | `faculty/screens/faculty_dashboard_screen.dart` | Resumes ongoing attendance session | None | Pushes `FacultySessionScreen` |
| **Advisor Shortcut** | `FacultyDashboard` | Advisor | `faculty/screens/faculty_dashboard_screen.dart` | Switches bottom nav to Advisor tab | None | Switches tab index to 2 |
| **Reports View** | `FacultyDashboard` | Faculty | `faculty/screens/faculty_dashboard_screen.dart` | Opens attendance reports screen | None | Pushes `FacultyAttendanceReportScreen` |
| **Mark Attendance** | `FacultyAttendance` | Faculty | `faculty/screens/faculty_attendance_screen.dart` | Opens entry screen for available period | None | Pushes `FacultyAttendanceEntryScreen` |
| **Edit Attendance** | `FacultyAttendance` | Faculty | `faculty/screens/faculty_attendance_screen.dart` | Opens entry screen for recorded period | None | Pushes `FacultyAttendanceEntryScreen` |
| **All Present** | Entry Screens | Faculty / Advisor | Entry screen files | Sets all roster items to `PRESENT` | None | Updates roster in place |
| **All Absent** | Entry Screens | Faculty / Advisor | Entry screen files | Sets all roster items to `ABSENT` | None | Updates roster in place |
| **Toggle P** | Entry Screens | Faculty / Advisor | Entry screen files | Sets student status to `PRESENT` | None | Updates student in place |
| **Toggle A** | Entry Screens | Faculty / Advisor | Entry screen files | Sets student status to `ABSENT` | None | Updates student in place |
| **Toggle OD** | Entry Screens | Faculty / Advisor | Entry screen files | Opens OD reason prompt dialog | None | Dialog overlay; sets `OD` |
| **Submit Attendance** | Entry Screens | Faculty / Advisor | Entry screen files | Submits marked roster to backend | `FacultyService.submitAttendanceWindow` or `submitClassAdvisorAttendance` | Pops screen on success |
| **Advisor Summary** | `ClassAdvisorScreen`| Advisor | `faculty/screens/faculty_class_advisor_screen.dart` | Opens daily half-day summary | `FacultyService.fetchClassAdvisorDailySummary` | Dialog overlay |
| **Take Group Photo**| `FacultySession` | Faculty | `faculty/screens/faculty_session_screen.dart` | Triggers camera capture | `ImagePicker.pickImage` | Pushes `ImagePreviewScreen` |
| **Recognize Faces** | `ImagePreview` | Faculty | `faculty/screens/image_preview_screen.dart` | Submits photo for facial recognition | `FacultyService.uploadGroupPhoto` | `pushReplacement` to `RecognitionReviewScreen` |
| **Confirm Attendance**| `RecognitionReview`| Faculty | `faculty/screens/recognition_review_screen.dart` | Submits confirmed face matches | `FacultyService.confirmRecognition` | Pops to `FacultySessionScreen` |
| **Complete Session** | `FacultySession` | Faculty | `faculty/screens/faculty_session_screen.dart` | Finalizes and locks attendance session | `FacultyService.completeSession` | Pops to dashboard |
| **Enroll Face** | Student Profile | Student | `student/screens/student_profile_screen.dart` | Opens biometric enrollment flow | None | Pushes `BiometricEnrollmentScreen` |
| **Change Password** | Profiles | All | Profile screen files | Opens password update dialog | `AuthService.changePassword` | Dialog overlay |
| **Sign Out** | Profiles | All | Profile screen files | Clears token and resets navigation | `AuthService.logout` | `pushAndRemoveUntil` to `LoginScreen` |

---

# 8. ROLE MODEL

### Enums & Code Entities
- **Backend Model (`app/models/user.py`)**:
  - `UserRole` Enum: `ADMIN = "ADMIN"`, `FACULTY = "FACULTY"`, `STUDENT = "STUDENT"`.
- **Client Model (`mobile/lib/models/user_model.dart`)**:
  - `role`: String (`"STUDENT"`, `"FACULTY"`, `"ADMIN"`).
  - `isClassAdvisor`: Boolean field (`json['is_class_advisor'] ?? false`).
  - `advisedClassId`: Integer ID of assigned class section.
  - `advisedClassName`: Name of assigned class section.
  - Helper Getters:
    - `bool get isStudent => role == 'STUDENT'`
    - `bool get isFaculty => role == 'FACULTY' || role == 'ADMIN'`
    - `bool get isAdmin => role == 'ADMIN'`

### Role Resolution Logic
The client resolves role and advisor status strictly from the backend response at `/api/v1/auth/me`. The client does not independently infer permissions.
- If `role == 'STUDENT'`: Client mounts `StudentDashboardScreen`.
- If `role == 'FACULTY'`: Client mounts `FacultyDashboardScreen`.
- If `is_class_advisor == true`: `FacultyDashboardScreen` dynamically injects the 5th bottom navigation tab (`FacultyClassAdvisorScreen`) and displays the advisor card.

---

# 9. AUTHENTICATION

- **Login Screen**: `mobile/lib/auth/screens/login_screen.dart`.
- **Identifiers**:
  - Student: Register Number or Roll Number.
  - Faculty: Username or Employee ID.
- **Passwords**: Case-sensitive string; minimum 8 characters enforced on creation/change.
- **API Endpoints**:
  - Student Login: `POST /api/v1/auth/student/login` (Body: `{"identifier": "...", "password": "..."}`).
  - Faculty Login: `POST /api/v1/auth/login` (Body: `{"username": "...", "password": "..."}`).
  - User Verification: `GET /api/v1/auth/me` (Header: `Authorization: Bearer <token>`).
- **Token Persistence**:
  - Handled by `SecureStorageService` (`mobile/lib/core/storage/secure_storage.dart`) using `flutter_secure_storage`. Key: `auth_access_token`.
- **Session Expiry**:
  - On HTTP 401, `ApiClient.onUnauthorized` triggers `AuthService._handleUnauthorized()`, clearing secure storage, resetting `_currentUser` to null, and displaying an expiration notice.
- **Mandatory Password Updates**:
  - If `user.forcePasswordChange == true`, an alert banner appears on dashboards and launches `ChangePasswordDialog` with `isMandatory: true` (`PopScope(canPop: false)`).

---

# 10. STUDENT EXPERIENCE

- **Dashboard**: `student_dashboard_screen.dart`.
  - Circular attendance gauge color-coded: $\ge 75\%$ green (`#10B981`), $65\%-74.9\%$ amber (`#F59E0B`), $< 65\%$ red (`#EF4444`).
  - Stat boxes: Total classes, attended classes, absent classes.
  - Recovery alert: Calculates minimum consecutive classes needed to reach $75\%$.
  - Biometric card: Shows enrollment status with direct button to enroll.
- **Attendance Report**: `student_attendance_report_screen.dart`.
  - Tab 0: Subject-wise breakdown with progress bars and percentage pills.
  - Tab 1: Daily period-by-period matrix cards with non-academic lunch banners.
- **Timetable**: `student_timetable_screen.dart`.
  - Weekday tabs (Mon–Sun), period cards with real-time status badges (`CURRENT CLASS`, `UPCOMING`, `COMPLETED`, `FREE PERIOD`).
- **Profile**: `student_profile_screen.dart`.
  - Displays register number, roll number, department, semester, face enrollment trigger, password change, sign out.
- **Biometric Enrollment**: `biometric_enrollment_screen.dart`.
  - Guided 3-step capture workflow with real-time angle feedback.

---

# 11. FACULTY EXPERIENCE

- **Dashboard**: `faculty_dashboard_screen.dart`.
  - Active scheduled slot card with `"START ATTENDANCE SESSION"` button.
  - Quick action card to open attendance marking window.
  - Today's teaching schedule list.
- **Attendance Windows**: `faculty_attendance_screen.dart`.
  - Displays completed periods for `TODAY` and `YESTERDAY`. Future periods are marked `LOCKED`.
- **Attendance Entry**: `faculty_attendance_entry_screen.dart`.
  - Roster view with search, `All Present`, `All Absent`, segmented P/A/OD controls, OD reason modal, and submit button.
- **Timetable Tab**: Weekday browser showing scheduled teaching assignments.
- **Reports**: `faculty_attendance_report_screen.dart`. Scoped strictly to assigned subjects.
- **Active Session**: `faculty_session_screen.dart`. Live classroom management with photo capture toolbar.
- **Image Preview**: `image_preview_screen.dart`. Full-screen photo check prior to recognition.
- **Recognition Review**: `recognition_review_screen.dart`. Review candidate face matches and confirm attendance.

---

# 12. CLASS ADVISOR EXPERIENCE

- **Advisor Indicator**: `is_class_advisor == true` on user profile.
- **Dashboard Callout**: High-contrast card with `"MANAGE CLASS ATTENDANCE"` button.
- **Advisor Tab**: Dedicated 5th bottom navigation tab: `FacultyClassAdvisorScreen`.
- **Whole-Class Authority**: Can mark and edit all 7 periods (P1–P7) across all subjects for their assigned class section.
- **Schedule Structure**:
  - Morning Session: P1–P4.
  - Short Tea Break: 10:50 AM – 11:10 AM.
  - Lunch Break: 12:50 PM – 01:40 PM (explicit non-academic notice).
  - Afternoon Session: P5–P7.
  - Day End: 16:10 dismissal notice.
- **Daily Half-Day Summary**: Dedicated modal computing morning, afternoon, and overall daily statuses.
- **Reports Access**: Class Advisor can view reports for `"All Subjects (Advisor Scope)"`.
- **Optimistic Concurrency**: Tracked via `expected_last_updated` token on `FacultyClassAdvisorEntryScreen`. Conflicts return `409 Conflict`.

---

# 13. ATTENDANCE

- **Statuses**:
  - `PRESENT`: Counted as attended.
  - `ABSENT`: Counted as missed.
  - `OD`: On-Duty. Counted as present by policy (`od_calculation_mode == "COUNT_AS_PRESENT"`). Requires official reason.
  - `NOT_ENTERED` / `UNMARKED`: Unrecorded slot.
  - `EXCLUDED`: Institutional non-academic slot (breaks, holidays).
- **Windows**:
  - Today's completed periods (past scheduled end time).
  - Yesterday's scheduled periods.
  - Future periods and periods older than yesterday are locked.
- **Submission**:
  - Subject Faculty: `POST /api/v1/faculty/attendance/submit`.
  - Class Advisor: `POST /api/v1/faculty/class-advisor/submit` (includes concurrency token).

---

# 14. ATTENDANCE REPORTS

- **Screen**: `FacultyAttendanceReportScreen` (`faculty/screens/faculty_attendance_report_screen.dart`).
- **Controls & Selectors**:
  - Class dropdown: Authorized classes.
  - Subject dropdown: Authorized subjects (plus `"All Subjects"` for Class Advisor).
  - Mode toggle: `Summary` (0), `Daily Matrix` (1), `Historical Matrix` (2).
  - Date picker / Date range picker.
- **Modes**:
  - **Summary**: Roster showing student names, roll numbers, total hours, attended hours, percentage pills. Tap opens `_StudentDetailModal`.
  - **Daily Matrix**: Single-date view showing P1–P7 period status chips and daily half-day result tags.
  - **Historical Matrix**: Date range table showing multi-day attendance cells across academic calendar dates.

---

# 15. AUTHORIZATION / PRIVACY

- **Enforcement Level**: Calculated server-side on every request based on JWT claims.
- **Class Advisor**: Restricted to assigned class section. Querying other classes returns `403 Forbidden`.
- **Subject Faculty**: Restricted to assigned classes and subjects. Querying other subjects or whole-class matrices returns `403 Forbidden`.
- **Student**: Restricted strictly to own student ID. Querying other students returns `403 Forbidden`.
- **Admin**: Dedicated access via Web Console (`/admin`).

---

# 16. HISTORICAL MATRIX

- **Endpoint**: `GET /api/v1/faculty/reports/historical-matrix`.
- **Screen**: Mode 2 in `FacultyAttendanceReportScreen`.
- **Date Boundaries**:
  - Minimum Date: Class `attendance_start_date`.
  - Maximum Date: Current date (IST). Future dates are disabled.
- **Matrix Layout**:
  - Sticky left columns for student roll number and name.
  - Horizontal scrolling columns for date and period slots.
  - Cells display compact status chips (`P`, `A`, `OD`, `-`).
  - Cumulative summary columns show hours attended vs conducted and percentage.

---

# 17. TIMETABLE

The database and backend schedule verify as follows:

| Period | Start Time | End Time | Classification | Attendance Credited? |
|---|---|---|---|---|
| **P1** | 09:10 | 10:00 | Morning Session | **Yes** |
| **P2** | 10:00 | 10:50 | Morning Session | **Yes** |
| *Short Break* | 10:50 | 11:10 | Tea Break | **No (Excluded)** |
| **P3** | 11:10 | 12:00 | Morning Session | **Yes** |
| **P4** | 12:00 | 12:50 | Morning Session | **Yes** |
| *Lunch Break* | 12:50 | 13:40 | Lunch Interval | **Strictly Excluded** |
| **P5** | 13:40 | 14:30 | Afternoon Session | **Yes** |
| **P6** | 14:30 | 15:20 | Afternoon Session | **Yes** |
| **P7** | 15:20 | 16:10 | Afternoon Session | **Yes** |
| *Dismissal* | 16:10 | — | Day End | — |

---

# 18. HALF-DAY

In `app/engines/policy_engine.py`, `derive_daily_half_day_status` implements:
- **Morning Session**: P1, P2, P3, P4 (valid count = 4). Threshold: $\lceil 4 / 2 \rceil = 2$ Present $\to$ `PRESENT`.
- **Lunch Break**: 12:50 PM – 01:40 PM. Excluded from calculations and denominator (`counted: False`).
- **Afternoon Session**: P5, P6, P7 (valid count = 3). Threshold: $\lceil 3 / 2 \rceil = 2$ Present $\to$ `PRESENT`.
- **Daily Result Rules**:
  - Morning Present + Afternoon Present $\to$ `FULL DAY PRESENT`.
  - Morning Absent + Afternoon Absent $\to$ `FULL DAY ABSENT`.
  - One Present + One Absent $\to$ `HALF-DAY PRESENT`.
  - One Present + One Not Entered $\to$ `HALF-DAY PRESENT`.
  - One Absent + One Not Entered $\to$ `HALF-DAY ABSENT`.
  - All Not Entered $\to$ `NOT ENTERED`.

---

# 19. BIOMETRIC ENROLLMENT

- **Entry Point**: Student Dashboard banner or Student Profile tile.
- **Workflow**: 3 steps capturing `FRONTAL`, `LEFT_15`, `RIGHT_15`.
- **Guidance**: Real-time yaw/pitch/roll chips and bounding box oval via `FaceDetectorService`.
- **Endpoints**: `POST /api/v1/student/enroll-face/validate-pose`, `POST /api/v1/student/enroll-face/capture`.
- **Browser Compatibility**: Flutter Web uses blob URLs; image uploads transmit bytes.

---

# 20. LIVE FACE ATTENDANCE

- **Workflow**:
  1. `FacultyDashboardScreen`: Tap `"START ATTENDANCE SESSION"` on active slot.
  2. `FacultySessionScreen`: Tap `"TAKE GROUP PHOTO"`.
  3. `ImagePreviewScreen`: Review image and tap `"Recognize Faces"`.
  4. `RecognitionReviewScreen`: Review high-confidence checkboxes ($\ge 80\%$) and uncertain candidate radio groups.
  5. Tap `"Confirm Attendance"` $\to$ updates session roster.
  6. `FacultySessionScreen`: Tap `"COMPLETE ATTENDANCE SESSION"` to finalize.

---

# 21. PROFILE

- **Identity**: Full Name, Register/Roll Number or Employee ID, Active status badge.
- **Academic Info**: Class section, semester, department.
- **Security**: Password change dialog, logout action.
- **Session Info**: User role, backend server URL.

---

# 22. ADMIN WEB UI

- **URL**: `http://127.0.0.1:8000/admin`.
- **Architecture**: Jinja2 HTML templates, vanilla JavaScript (`/static/js/admin_app.js`), custom CSS (`/static/css/admin_style.css`).
- **14 Tabs**:
  1. `dashboard`: System overview and metrics.
  2. `students`: Student directory and creation/editing.
  3. `faculty`: Faculty directory and workloads.
  4. `attendance`: Attendance record explorer with overrides.
  5. `sessions`: Class session monitor and logs.
  6. `biometrics`: Biometric profile audit and vector counts.
  7. `academic`: Class sections, grade levels, and subjects.
  8. `timetable`: Period configurations and timetable schedules.
  9. `assignments`: Faculty course mappings and **Class Advisor pairings**.
  10. `users`: User account credentials and active states.
  11. `settings`: Policy settings (75% threshold, OD calculation mode).
  12. `bulk-import`: CSV/JSON data ingestion pipeline.
  13. `password-control`: Diagnostic support mode and credential resets.
  14. `audit`: Immutable event logs.

---

# 23. CURRENT VISUAL DESIGN

- **Theme**: Dark theme defined in `AppTheme.darkTheme`.
- **Colors**:
  - Background: `#0F1115`
  - Surface Card: `#1E2026`
  - Elevated Surface: `#282A32`
  - Card Dark: `#181A20`
  - Border: `#2D3139`
  - Primary Brand Orange: `#F97316`
  - Accent Amber: `#FF8811`
  - Text Primary: `#F8FAFC`
  - Text Secondary: `#94A3B8`
  - Text Muted: `#64748B`
  - Status Present: `#10B981`
  - Status Absent: `#EF4444`
  - Status Warning: `#F59E0B`
  - Legacy Navy Accent: `#1E3A8A`
  - Legacy Blue Light: `#3B82F6`
- **Typography**: Google Fonts `'Inter'` with weights 300 to 700.
- **Radii**: 6px (tags), 8px (buttons), 12px (inputs), 14px–16px (cards), 24px (bottom sheets).

---

# 24. CURRENT RESPONSIVE BEHAVIOR

- **Mobile Viewport (360px–430px)**: Vertical single-column scroll, stacked metric cards, full-width bottom navigation.
- **Desktop Chrome Web (`localhost:3000`)**: Constrained dialog widths (max 420px), horizontal scrolling for matrix tables, sticky header rows.

---

# 25. CURRENT LIMITATIONS / KNOWN ISSUES

- **Branding Debt** [KNOWN LIMITATION]: Legacy string `"AI Face Attendance"` is present on splash, login, and manifests.
- **Color Inconsistency** [KNOWN LIMITATION]: Faculty session and review screens use legacy Navy/Blue accents instead of the core Orange theme.
- **Web Image Preview** [KNOWN LIMITATION]: `Image.file(_currentImage)` in `image_preview_screen.dart` is native-only; Web requires `Image.memory` with bytes.
- **Break Labels** [IMPLEMENTED]: Institutional break notices are currently hardcoded in UI widgets rather than dynamic.

---

# 26. API MAP

- `LoginScreen` $\to$ `AuthService.loginStudent` $\to$ `POST /api/v1/auth/student/login` $\to$ `UserModel`
- `LoginScreen` $\to$ `AuthService.loginFaculty` $\to$ `POST /api/v1/auth/login` $\to$ `UserModel`
- `StudentDashboard` $\to$ `StudentService.fetchStudentSummary` $\to$ `GET /api/v1/student/attendance` $\to$ `_summary`
- `FacultyDashboard` $\to$ `FacultyService.fetchSchedule` $\to$ `GET /api/v1/faculty/timetable` $\to$ `_schedule`
- `FacultyDashboard` $\to$ `FacultyService.startAttendanceSession` $\to$ `POST /api/v1/faculty/sessions/start` $\to$ `_activeSessionId`
- `FacultyAttendanceEntry` $\to$ `FacultyService.submitAttendanceWindow` $\to$ `POST /api/v1/faculty/attendance/submit` $\to$ Records persisted
- `FacultyClassAdvisorEntry` $\to$ `FacultyService.submitClassAdvisorAttendance` $\to$ `POST /api/v1/faculty/class-advisor/submit` $\to$ Concurrency validated
- `FacultyReports` $\to$ `FacultyService.fetchDateMatrixReport` $\to$ `GET /api/v1/faculty/reports/date-matrix` $\to$ `FacultyDateMatrixModel`
- `FacultyReports` $\to$ `FacultyService.fetchHistoricalMatrixReport` $\to$ `GET /api/v1/faculty/reports/historical-matrix` $\to$ `FacultyHistoricalMatrixModel`

---

# 27. FILE MAP

| Feature Area | File Paths | Key Responsibility |
|---|---|---|
| **Auth & Security** | `auth/screens/login_screen.dart`, `auth/screens/splash_screen.dart`, `auth/widgets/change_password_dialog.dart`, `services/auth_service.dart`, `core/storage/secure_storage.dart` | Credential entry, JWT handling, password updates |
| **Student UI** | `student/screens/student_dashboard_screen.dart`, `student/screens/student_attendance_report_screen.dart`, `student/screens/student_timetable_screen.dart`, `student/screens/student_profile_screen.dart`, `services/student_service.dart` | Percentage gauge, recovery alerts, reports, schedules |
| **Faculty UI** | `faculty/screens/faculty_dashboard_screen.dart`, `faculty/screens/faculty_attendance_screen.dart`, `faculty/screens/faculty_attendance_entry_screen.dart`, `faculty/screens/faculty_profile_screen.dart`, `services/faculty_service.dart` | Teaching schedules, active slot, single-period marking |
| **Class Advisor** | `faculty/screens/faculty_class_advisor_screen.dart`, `faculty/screens/faculty_class_advisor_entry_screen.dart` | Whole-class P1–P7 schedule, multi-period roster, concurrency |
| **Biometrics** | `student/screens/biometric_enrollment_screen.dart`, `services/biometric_enrollment_service.dart`, `services/face_detector_service.dart` | 3-step pose capture, angle guidance, vector submission |
| **Live Recognition** | `faculty/screens/faculty_session_screen.dart`, `faculty/screens/image_preview_screen.dart`, `faculty/screens/recognition_review_screen.dart` | Real-time session management, photo analysis, review |
| **Reports Engine** | `faculty/screens/faculty_attendance_report_screen.dart`, `widgets/attendance/period_status_chip.dart`, `widgets/attendance/attendance_legend.dart` | Roster summaries, Daily Matrix, Historical Matrix |

---

# 28. DATA FLOW

```
[Flutter UI Event (e.g. Tap Submit)]
       │
       ▼
[Provider / Service Method Call]
       │
       ▼
[ApiClient (Injects Bearer Token, Serializes JSON)]
       │
       ▼
[FastAPI Route Handler (Validates JWT, Checks Permissions)]
       │
       ▼
[Domain Engine (AttendancePolicyEngine / TimetableEngine)]
       │
       ▼
[SQLAlchemy ORM -> SQLite Database Query / Transaction]
       │
       ▼
[FastAPI Returns JSON Response / Error Status]
       │
       ▼
[ApiClient Deserializes Response -> Returns to Service]
       │
       ▼
[Service Updates Observable State -> Dispatches notifyListeners()]
       │
       ▼
[Flutter Widgets Rebuild via Consumer / Provider.of]
```

---

# 29. TESTING

- **`flutter analyze`**:
  - Result: `No issues found! (ran in 63.1s)`
  - Status: 100% clean across all 41 Dart files.
- **`flutter test`**:
  - Result: `All tests passed! (76 test cases passed in 7.0s)`
  - Suites verified: `login_ux_test.dart`, `security_and_consistency_test.dart`, `timetable_ux_test.dart`, `faculty_dashboard_debug_test.dart`, `widget_test.dart`.
- **Backend Tests (`pytest`)**:
  - Suites: Academic models, timetable conflicts, policy calculation modes, facial recognition pipelines.
  - Verified window constraint: Attendance marking rejected for dates older than yesterday (`400 Bad Request`).
- **Chrome Web Runtime**:
  - Verified running at `http://localhost:3000`.

---

# 30. DESIGN-AGENT HANDOFF ("CURRENT APP FACTS FOR DESIGN AGENT")

- **Roles**: Admin (Web only), Class Advisor (Assigned class, all subjects, all P1–P7), Subject Faculty (Assigned classes/subjects only), Student (Own data only).
- **Screens**: Exactly 17 screens across the application.
- **Timetable**:
  - P1: 09:10–10:00
  - P2: 10:00–10:50
  - Short Break: 10:50–11:10 (Excluded)
  - P3: 11:10–12:00
  - P4: 12:00–12:50
  - Lunch Break: 12:50–13:40 (Strictly excluded from attendance, percentage denominators, and sessions)
  - P5: 13:40–14:30
  - P6: 14:30–15:20
  - P7: 15:20–16:10
  - Dismissal: 16:10 (4:10 PM)
- **Half-Day Formulas**:
  - Morning (P1–P4): Threshold = 2 Present.
  - Afternoon (P5–P7): Threshold = 2 Present.
- **Biometrics**: 3 poses (`FRONTAL`, `LEFT_15`, `RIGHT_15`).
- **Testing**: Must execute via Flutter Web in Google Chrome (`http://localhost:3000`). No physical mobile devices.
- **Concurrency**: Class Advisor entry tracks `expected_last_updated` and handles HTTP 409 conflicts.
