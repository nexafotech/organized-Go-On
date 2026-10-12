# Attendance Marker UI/UX Specification & Design System
**Academic Year 2026–2027 College Attendance System**
**Milestone 8.4 — Design System & Screen Specifications**

---

## 1. Design System Tokens & Foundations

### 1.1 Color Palette
The color system adheres to WCAG 2.1 AA accessibility contrast guidelines ($\ge 4.5:1$ for normal text, $\ge 3.0:1$ for large headings/UI controls).

```css
/* Color System Tokens */
:root {
  /* Brand Core */
  --color-primary: #1E293B;        /* Deep Slate / Navy Header */
  --color-primary-light: #334155;  /* Slate Hover */
  --color-accent: #2563EB;         /* Vibrant Blue Action Button */
  --color-accent-hover: #1D4ED8;   /* Deep Blue Focus */

  /* Neutral Surface */
  --color-bg-main: #F8FAFC;        /* Light Neutral Canvas */
  --color-surface-card: #FFFFFF;   /* Pure White Card Container */
  --color-border: #E2E8F0;         /* Subtle Soft Divider */
  --color-text-main: #0F172A;      /* High Contrast Text Body */
  --color-text-muted: #64748B;     /* Subtitle / Secondary Caption */

  /* Semantic Attendance Status Colors */
  --color-status-present: #059669; /* Emeral Green - Present */
  --color-status-absent: #DC2626;  /* Crimson Red - Absent */
  --color-status-od: #D97706;      /* Amber / Orange - On Duty (OD) */
  --color-status-uncertain: #EAB308;/* Warning Yellow - Needs Review */

  /* Attendance Risk Threshold Badges */
  --color-risk-safe: #10B981;     /* Safe Status (>75%) */
  --color-risk-warning: #F59E0B;  /* Warning Status (70% - 74.9%) */
  --color-risk-critical: #EF4444; /* Critical Status (<70%) */
}
```

### 1.2 Typography & Scale
Font Family: **Inter** (Primary UI Font), **Roboto** (Mobile Fallback), system-ui sans-serif.

| Token | Size | Weight | Line Height | Application |
| :--- | :--- | :--- | :--- | :--- |
| `font-display` | $28\text{px}$ ($1.75\text{rem}$) | Bold (700) | $1.2$ | Main Dashboard Header |
| `font-h1` | $22\text{px}$ ($1.375\text{rem}$) | SemiBold (600) | $1.3$ | Section Titles / Card Headers |
| `font-h2` | $18\text{px}$ ($1.125\text{rem}$) | SemiBold (600) | $1.4$ | Modal Titles / Tab Labels |
| `font-body` | $15\text{px}$ ($0.9375\text{rem}$) | Regular (400) | $1.5$ | Primary Text, Form Inputs |
| `font-caption` | $13\text{px}$ ($0.8125\text{rem}$) | Medium (500) | $1.4$ | Timetable Period, Subtitles |
| `font-micro` | $11\text{px}$ ($0.6875\text{rem}$) | SemiBold (600) | $1.2$ | Badges, Status Indicators |

### 1.3 Touch Targets & Spacing Scale
- **Minimum Touch Target Size**: $48 \times 48 \text{ dp/px}$ for all primary buttons, mobile list items, and form controls.
- **Spacing Scale**: 4px base grid ($4\text{px}, 8\text{px}, 12\text{px}, 16\text{px}, 24\text{px}, 32\text{px}$).
- **Corner Radius**: Cards ($8\text{px}$), Modals ($12\text{px}$), Badges ($999\text{px}$ full pill).

---

## 2. Component Design Specifications

### 2.1 Buttons
- **Primary Action**: Solid Accent Blue (`#2563EB`), White text, $48\text{px}$ height, $8\text{px}$ border radius.
- **Secondary Action**: Border Outline (`1px solid #CBD5E1`), Slate text (`#334155`).
- **Danger Action**: Crimson Red (`#DC2626`), White text (Delete/Disable actions).

### 2.2 Status Badges & Cards
Status badges display text labels alongside color indicators to support color-blind accessibility:

- **Present**: `<span class="badge badge-success"><i class="fa-check"></i> Present</span>`
- **Absent**: `<span class="badge badge-danger"><i class="fa-xmark"></i> Absent</span>`
- **On Duty (OD)**: `<span class="badge badge-warning"><i class="fa-building"></i> On Duty</span>`
- **Uncertain Match**: `<span class="badge badge-alert"><i class="fa-exclamation-triangle"></i> Review Required</span>`

---

## 3. Admin Web Panel UX Specifications

The Admin Web Panel provides desktop-optimized control over college configuration, accounts, academic schedules, policies, AI parameters, and security audit trails.

### Screen Layouts & Capabilities:

1. **Dashboard Overview**: Real-time counter metrics (Total Students, Faculty, Classes, Active Sessions), overall attendance %, and recent security audit log list.
2. **Student Management**: Filterable list with roll number search, class filter dropdown, Create Student modal, Enable/Disable toggle, Reset Password modal, Force Password Change flag, and Face Enrollment trigger.
3. **Faculty Management**: Department search filter, Create Faculty modal, Enable/Disable toggle, Reset Password modal, and Faculty Subject Assignments.
4. **Academic Timetable Editor**: Interactive matrix filtering by Class Section. Displays Period Timing, Day of Week, Subject Code, and Assigned Faculty. Includes conflict warning indicators for period time collisions.
5. **Attendance Policy Settings**: Inputs for Minimum Attendance % ($75\%$), Period/Class/Day Loss values, OD Marking permissions, and Calculation Modes (`EXACT_PERCENTAGE` vs `WEIGHTED`).
6. **AI Engine Configuration**: Quantized Model Toggle (ON by default). When disabled on a low-spec device, displays:
   $$\text{\textsf{⚠️ Full-precision mode may increase processing time and memory usage on this device.}}$$
7. **Bulk Seed Data Import Center**: Import cards for Students, Faculty, Subjects, Classes, Timetable, and Official `college_seed/` bundle. Modal statistics output: `imported`, `skipped_existing`, `skipped_unassigned`, `conflicts`, `errors`.

---

## 4. Faculty Mobile UX Specifications

Designed for low-end Android mobile devices with an emphasis on **capture-driven, offline-capable attendance marking**.

### Navigation Flow:
$$\text{Login} \rightarrow \text{Dashboard} \rightarrow \text{Today's Timetable} \rightarrow \text{Current Class} \rightarrow \text{Start Session} \rightarrow \text{Attendance Session}$$

### Attendance Session Action Options:
- `[ TAKE GROUP PHOTO ]`: Triggers device camera for single photo capture.
- `[ CHOOSE FROM GALLERY ]`: Imports local photograph from mobile storage.
- `[ MANUAL ATTENDANCE ]`: Direct roster list with individual Present/Absent/OD toggles.
- `[ MARK OD ]`: Bulk On-Duty selection modal with reason text field.

---

## 5. Recognition UX State Machine

The Faculty Recognition flow is explicitly capture-driven and steps through 9 progress states with teacher-friendly status indicators:

```text
[1. EMPTY]
    │  (Faculty taps Take Photo / Select Image)
    ▼
[2. IMAGE_SELECTED]  ──► Preview cropped image
    │  (Faculty taps Process Recognition)
    ▼
[3. UPLOADING]       ──► Progress: "Uploading image..."
    │
    ▼
[4. DETECTING_FACES] ──► Progress: "Detecting faces..."
    │
    ▼
[5. MATCHING]        ──► Progress: "Matching students with class roster..."
    │
    ▼
[6. REVIEW]          ──► Displays Candidate List & High/Uncertain/Unknown Categories
    │  (Faculty verifies uncertain candidates & taps Confirm)
    ▼
[7. CONFIRMING]      ──► Progress: "Saving attendance records..."
    │
    ▼
[8. SUCCESS]        ──► Displays "Attendance Completed Successfully" Toast
    │  (Or if failure occurs)
    └──────────────────► [9. ERROR] ──► Displays human-readable error banner
```

### Candidate Categorization Rules on Review Screen:
- **Total Faces Detected**: Summary banner (e.g. "12 Faces Detected").
- **High-Confidence Matches ($d \le 0.45$)**: Pre-selected checkboxes with green border.
- **Uncertain Matches ($0.45 < d \le 0.60$)**: Highlighted with yellow warning card; **UNCHECKED by default; MUST require explicit faculty tap**.
- **Unknown Faces ($d > 0.60$)**: Isolated in unknown faces tray; **MUST remain unmarked**.

---

## 6. Student Mobile UX Specifications

### Navigation Flow:
$$\text{Login} \rightarrow \text{Dashboard} \rightarrow \text{Attendance Overview} \rightarrow \text{Subject Details} \rightarrow \text{Period History} \rightarrow \text{Profile}$$

### Dashboard Status Threshold Cards:
The dashboard displays the student's name, register number, class section, and overall attendance percentage with a prominent status banner:

- **SAFE Status ($\ge 75\%$)**: Emerald Green card border.
  - Message: *"Attendance is above required minimum."*
  - Stat: *"Classes you can miss while remaining safe: X classes."*
- **WARNING Status ($70\% - 74.9\%$)**: Amber Yellow card border.
  - Message: *"Attendance nearing minimum threshold."*
  - Stat: *"Required classes to attend: Y classes."*
- **CRITICAL Status ($< 70\%$)**: Crimson Red card border.
  - Message: *"Attendance below required minimum."*
  - Stat: *"Required classes to reach minimum: Z classes."*

### Period-Level & Subject Breakdown Presentation:
Displays subject-wise breakdown (e.g., `FDS: 85%`, `DMC: 78%`, `OOPS: 92%`) with expandable period-level metrics:

```text
Foundations of Data Science (FDS) — Overall: 85.0%
├── Period 1 (09:10 - 10:00) | Present: 17 | Absent: 3 | Rate: 85.0%
└── Period 4 (12:00 - 12:50) | Present: 17 | Absent: 3 | Rate: 85.0%
```

---

## 7. User-Facing Error & Empty State Messages

| Internal System Condition | User-Facing Message String | Actionable Guidance |
| :--- | :--- | :--- |
| **No Network / Offline** | *"No Internet Connection"* | *"Attendance can be taken offline. Sync will complete when online."* |
| **Backend Unavailable** | *"Server Unavailable"* | *"Unable to connect to college server. Please try again shortly."* |
| **Invalid Credentials** | *"Incorrect Login ID or Password"* | *"Please verify your roll number/employee ID and password."* |
| **Account Disabled** | *"Account Access Disabled"* | *"Your account has been deactivated. Please contact college admin."* |
| **Session Expired** | *"Session Expired"* | *"For your security, please sign in again."* |
| **Recognition Failed** | *"Photo Recognition Unsuccessful"* | *"Could not analyze faces clearly. Please retake photo with better light."* |
| **No Face Detected** | *"No Faces Found in Photo"* | *"Ensure students are facing the camera clearly and retake photo."* |
| **Session Completed** | *"Attendance Session Locked"* | *"This class session has already been completed and finalized."* |

---

## 8. Low-End Mobile Device Optimizations

1. **Zero Heavy Animations**: Eliminates complex Lottie animations, 3D transitions, and continuous blur filters.
2. **Local Image Downscaling**: Photo uploads are downscaled to max $1920 \times 1080$ on client device before transmission to reduce network overhead and memory spikes.
3. **Lazy Rendering**: Mobile list views utilize `ListView.builder` / virtualized scrolling to render only visible DOM/widget nodes.
4. **Single-Pass Capture**: Disables continuous 30fps camera AI processing; executes AI exclusively on single static photo captures.

---

## 9. Privacy & Biometric Communication UX

- **Biometric Privacy Notice**: Displays a clear notification during face enrollment: *"Your facial photo is used strictly to generate a 128D mathematical embedding vector for college attendance. Raw photos are not stored on mobile devices."*
- **Vector Masking**: Raw vector arrays (e.g. `[0.124, -0.045, ...]`) are strictly hidden from UI screens, client local storage, and mobile log outputs.
