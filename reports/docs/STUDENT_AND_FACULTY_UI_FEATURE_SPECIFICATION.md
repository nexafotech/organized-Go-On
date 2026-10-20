# Attendance Marker (am-oss): UI & Feature Design Specification
**Complete UI Component, Feature Architecture & Button Placement Guide for UI/UX Designers**  
*Covers Both Student and Faculty Mobile Applications*

---

## 1. Executive Summary & Design System

The **Attendance Marker** mobile client is built on a responsive multi-role Flutter framework supporting two principal user experiences:
1. **Faculty Application**: Schedule tracking, class session activation, attendance window management, roster verification, and biometric exception overrides.
2. **Student Application**: Attendance percentage monitoring (overall & subject-wise), mandatory security management, multi-pose biometric face enrollment, and academic timetable lookup.

### Global Design Tokens

| Token Name | Value / Hex Code | Usage in App |
| :--- | :--- | :--- |
| **Primary Navy** | `#1E3A8A` / `#0F172A` | App bars, prominent headers, primary solid buttons |
| **Accent Blue** | `#2563EB` / `#3B82F6` | Active tab icons, link buttons, focus borders, circular loading |
| **Surface Dark (Canvas)** | `#0F172A` | Scaffold dark background |
| **Card Container** | `#1E293B` (Dark) / `#FFFFFF` (Light) | Rounded card containers (`border-radius: 12px`, elevation: 1.5) |
| **Success Emerald** | `#16A34A` / `#22C55E` | Attendance ≥ 75%, Present pills, Active window chips, Verified state |
| **Warning Amber** | `#D97706` / `#F59E0B` | Attendance 65%–74.9%, Pending review badge, Warning alerts |
| **Critical Crimson** | `#DC2626` / `#EF4444` | Attendance < 65%, Absent pills, Sign Out actions, Sync error banner |
| **Muted Slate** | `#64748B` / `#94A3B8` | Subtitles, helper text, empty state descriptions, card outlines |
| **Touch Target Rule** | Min `48 x 48 dp` | Every tappable icon, toggle, pill, or button |

---

## 2. Shared Screens (Authentication & Network Configuration)

### 2.1 Unified Login Screen
- **Visual Composition**:
  - **Top Area**: Centered 64×64 dp application emblem, "Attendance Marker" title (`22sp bold`), and "Smart Academic Attendance Suite" subtitle (`13sp`).
  - **Top-Right Corner**: `[ Server Settings ]` action button (gear icon, `48x48 dp` hit target).
  - **Form Inputs**:
    - **Username / Registration Number**: Outlined input field, prefix person icon, clear text button, auto-capitalization enabled.
    - **Password**: Outlined input field, prefix lock icon, trailing eye toggle icon to show/hide obscured text.
  - **Action Button**:
    - **`[ Sign In ]`**: Full-width elevated button, height `50 dp`, background `#1E3A8A`, text white bold. Displays centered `CircularProgressIndicator` during submission.
  - **Auto-Routing**: Evaluates JWT claims upon login to route seamlessly to either the Faculty Dashboard or Student Dashboard.

### 2.2 Server Configuration Modal (Bottom Sheet)
- **Visual Composition**:
  - **Header**: "Backend Server Configuration" title with close `(X)` icon.
  - **Server URL Input**: Outlined text field pre-filled with active URL (`http://127.0.0.1:8000`).
  - **Action Buttons**:
    - **`[ Test Connection ]`**: Outlined button (height `42 dp`), calls `/health` endpoint and renders dynamic status pill (`Connected (200 OK)` or `Unreachable`).
    - **`[ Save & Apply ]`**: Solid button (height `46 dp`), persists new endpoint to local secure preferences.

---

## 3. Faculty Mobile Application Specification

The Faculty app uses a 4-tab bottom navigation bar: **Dashboard**, **Attendance**, **Timetable**, and **Profile**.

### 3.1 Faculty Tab 1: Dashboard Screen
- **Profile Header Card**:
  - Renders unconditionally at the top of the screen.
  - Left: Circular avatar with initials (e.g. "RS").
  - Center: Full Name (e.g. `Dr. R. Sharma`), Employee Code (`FAC04`), Department (`Computer Science & Engineering`).
  - Right: "Faculty" status pill badge.
- **Active Class Slot Card**:
  - Automatically identifies whether an assigned period is running at the current wall-clock time.
  - If Active:
    - Subject Name (e.g. "Distributed Systems - CS701") & Section badge (e.g. "CSE-A").
    - Room Number badge (e.g. "LH-204") and Period Timing (e.g. "09:00 AM - 09:50 AM").
    - **Window Status Pill**: Green `Active Window` or Amber `Window Opens in 10m`.
    - **`[ Take / Resume Attendance ]` Button**: Placed at bottom of active card (solid green, height `44 dp`). Tapping opens the Attendance tab pre-selected for this period.
  - If No Class Active:
    - Renders calm empty-slot card: "No active class currently in session. Next class starts at 11:00 AM."
- **Today's Schedule Stream**:
  - Chronological vertical list of cards for today's classes.
  - Each item card shows: Time Interval, Subject Code, Subject Name, Section, and Room.
- **Network Error Card & Retry Button**:
  - If schedule fetching fails or is offline:
    - Red-tinted card with warning icon and message: "Unable to refresh schedule."
    - **`[ Retry ]` Button**: Centered outlined button (height `38 dp`) to trigger on-demand refresh.

### 3.2 Faculty Tab 2: Attendance Roster & Marking Screen
- **Dual Mode Switcher**:
  - Top segmented tab: `[ Scheduled Slots ]` | `[ Manual Override / Roster ]`.
- **Period Dropdown**:
  - Lets faculty select any active or past period assigned to them today.
- **Attendance Summary Stats Banner**:
  - 3 metric columns: **Total Enrolled** (Grey), **Present** (Green), **Absent** (Red).
- **Batch Action Bar**:
  - **`[ Mark All Present ]`**: Outlined green button (height `36 dp`). Sets all students to present in memory.
  - **`[ Reset ]`**: Outlined neutral button. Restores original detected status.
- **Student Roster List**:
  - Scrollable list of registered students.
  - Each item row displays:
    - Student avatar, Roll Number, and Full Name.
    - Biometric match confidence tag (e.g. `94% Biometric Verified`).
    - **`[ P ]` / `[ A ]` Toggle Buttons**: Right-aligned pill pair (`36x32 dp` each). Green when P is selected, Red when A is selected.
- **Sticky Submit Bar**:
  - Fixed at screen bottom: **`[ Finalize & Submit Attendance ]`** button (full width, height `52 dp`, solid `#1E3A8A`).

### 3.3 Faculty Tab 3: Weekly Timetable Screen
- **Horizontal Day Selector**:
  - Mon, Tue, Wed, Thu, Fri, Sat pill buttons. Active day highlighted in Accent Blue.
- **Chronological Period Cards**:
  - Time tag, Subject code, Class title, Section, and Room number.

### 3.4 Faculty Tab 4: Profile & Settings Screen
- **Faculty Details Card**:
  - Photo/Avatar, Name, Faculty ID, Department, Email.
- **Account Actions**:
  - **`[ Change Password ]`**: Opens password update sheet.
  - **`[ Sign Out ]`**: Crimson outlined button at bottom of view.

---

## 4. Student Mobile Application Specification

The Student app uses a 4-tab bottom navigation bar: **Overview**, **Biometric Register**, **Timetable**, and **Profile**.

### 4.1 Student Tab 1: Overview & Attendance Dashboard Screen
- **Student Profile Header Card**:
  - Student avatar with monogram initials.
  - Full Name (e.g. "Aditya Verma"), Registration Number (e.g. "2024BCSE042"), Section ("CSE-B"), Semester ("Sem 5").
- **Mandatory Password Update Banner**:
  - Displayed if the student is using the default initial password.
  - Amber warning box with lock icon: "Security requirement: Please change your default password."
  - **`[ Update Password Now ]` Button**: Right-aligned inside banner (height `34 dp`, amber solid).
- **Overall Attendance Radial Gauge Card**:
  - Semi-circular radial percentage meter (e.g. `82.4%`).
  - Dynamic status color:
    - Green (≥ 75%): "Good Standing - Eligible for exams".
    - Amber (65%–74.9%): "Warning - 4 more classes required for 75%".
    - Red (< 65%): "Critical Shortage - Ineligible for exams".
- **Quick Stat Counters (2x2 Grid)**:
  - **Total Conducted**: Total academic classes held to date.
  - **Attended**: Number of classes attended in person.
  - **Missed**: Number of recorded absences.
  - **Approved ODs**: On-Duty / institutional participation credits.
- **Subject-Wise Breakdown Cards**:
  - Scrollable list of enrolled courses. Each card contains:
    - Subject Code & Course Title (e.g. "CS501 - Database Engineering").
    - Fractional count (e.g. `32 / 36 Classes`).
    - Percentage progress bar with minimum 75% target marker.
    - Status chip (`On Track` green or `At Risk` red).

### 4.2 Student Tab 2: Biometric Multi-Pose Face Enrollment Screen
- **Guidance Instruction Banner**:
  - Illustrated guide showing correct lighting, direct gaze, and neutral facial expression.
- **Pose Progress Stepper**:
  - 3-step numbered breadcrumb indicator:
    1. **Frontal Pose** (0° ± 5°)
    2. **Left Angle** (15°)
    3. **Right Angle** (15°)
- **Live Camera Viewfinder**:
  - Centered elliptical face outline guide.
  - Dynamic bounding box: turns **Green** when face is detected, well-lit, and aligned; turns **Amber/Red** if skewed or too dark.
  - Live Telemetry overlay: Yaw, Pitch, Roll angles and face quality score.
- **Capture Button**:
  - **`[ Capture Pose Photo ]`**: Large circular floating shutter button (`68x68 dp`) centered at bottom.
- **Pose Review & Next Steps**:
  - Modal sheet pops up after capture:
    - Shows captured frame thumbnail.
    - **`[ Retake ]` Button**: Left-aligned, outlined.
    - **`[ Confirm & Next Pose ]` Button**: Right-aligned, solid green.
- **Final Submission**:
  - Upon completing all 3 poses: **`[ Submit Face Templates for Approval ]`** button activates.

### 4.3 Student Tab 3: Weekly Timetable Screen
- **Day Selector Bar**:
  - Monday to Saturday horizontal filter chips.
- **Daily Period Cards**:
  - Time slot (e.g. `08:30 - 09:20`), Course Name, Instructor Name, and Room Number.
  - Currently ongoing period is highlighted with a pulsing "In Progress" badge and elevated border.

### 4.4 Student Tab 4: Student Profile & Settings Screen
- **Identity & Academic Info**:
  - Official photo, Full Name, Roll No, Registration No, Batch, Department, Email.
- **Biometric Enrollment Status Tile**:
  - Displays status: `Enrolled & Approved (Green)` or `Not Enrolled (Amber)`.
  - **`[ Re-enroll Face ]` Button**: Triggers enrollment flow if template update is required.
- **Security & Preferences**:
  - **`[ Change Password ]`**: Opens password modification dialog.
- **Sign Out Button**:
  - **`[ Log Out ]`**: Crimson outlined button at bottom of view.

---

## 5. Master Button Placement & Interaction Matrix

| Screen / Context | Button Label | Exact Screen Placement | Visual Styling & Dimensions | Target Action / Outcome |
| :--- | :--- | :--- | :--- | :--- |
| **Login Screen** | `[ Sign In ]` | Below password field, full width with 24dp horizontal margins | Solid Navy `#1E3A8A`, H=50dp, R=10dp, White bold text | Authenticates credentials, navigates to role dashboard |
| **Login Screen** | `[ Server Config ]` | Top-right AppBar action icon | Icon-only (Gear), 48x48dp touch target, Slate color | Opens modal sheet to edit backend URL |
| **Faculty Dashboard** | `[ Take / Resume Attendance ]` | Bottom of Active Class Slot Card | Solid Emerald `#16A34A`, H=44dp, R=8dp, White text | Opens Attendance Marking tab for current period |
| **Faculty Dashboard** | `[ Retry ]` | Centered inside network error card | Outlined Blue, H=38dp, R=6dp | Retries fetching dashboard schedule and session |
| **Faculty Attendance** | `[ Mark All Present ]` | Above roster, right side of batch action bar | Outlined Emerald Green, H=36dp, R=6dp | Marks all enrolled students present in memory |
| **Faculty Attendance** | `[ P ] / [ A ] Toggles` | Right edge of each student roster card | Dual pill pair, each 36x32dp (Green P / Red A) | Toggles single student attendance state |
| **Faculty Attendance** | `[ Submit Attendance ]` | Sticky fixed bottom bar across screen bottom | Full-width solid Navy `#1E3A8A`, H=52dp, White text | Transmits finalized attendance roster to backend |
| **Student Dashboard** | `[ Update Password ]` | Inside mandatory password alert banner, right aligned | Solid Amber `#D97706`, H=36dp, R=6dp, White text | Opens password update modal sheet |
| **Student Biometric** | `[ Capture Pose Photo ]` | Bottom-center of camera viewfinder, 24dp above edge | Circular shutter button, 68x68dp, White/Blue border | Captures photo & triggers pose validation |
| **Student Biometric** | `[ Confirm & Next ]` | Inside pose review modal sheet, right side | Solid Emerald `#16A34A`, H=46dp, R=8dp, White text | Accepts current pose and advances to next angle |
| **Student Biometric** | `[ Retake Pose ]` | Inside pose review modal sheet, left side | Outlined Grey/Red, H=46dp, R=8dp | Re-opens camera viewfinder for retake |
| **Student Profile** | `[ Re-enroll Face ]` | Inside Biometric Status tile, right aligned | Outlined Blue, H=34dp, R=6dp | Starts multi-pose face enrollment flow |
| **Profile (Both Roles)**| `[ Sign Out ]` | Bottom of Profile scroll view, centered / full-width | Outlined Crimson `#DC2626`, H=48dp, R=8dp | Clears tokens and redirects to Login screen |

---

## 6. Document File Locations

- **Consolidated PDF Specification (Ready for UI Designer)**:
  - `C:\Users\Abishek\Desktop\STUDENT_AND_FACULTY_UI_FEATURE_SPECIFICATION.pdf`
  - `C:\Users\Abishek\Desktop\am-oss\STUDENT_AND_FACULTY_UI_FEATURE_SPECIFICATION.pdf`
- **Consolidated Markdown Specification**:
  - `C:\Users\Abishek\Desktop\am-oss\STUDENT_AND_FACULTY_UI_FEATURE_SPECIFICATION.md`
  - `C:\Users\Abishek\.gemini\antigravity\brain\7f90dbc7-1f76-43d0-a6a4-acccb732defd\STUDENT_AND_FACULTY_UI_FEATURE_SPECIFICATION.md`
