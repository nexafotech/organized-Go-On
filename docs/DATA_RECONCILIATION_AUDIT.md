# Production Data Reconciliation & System Audit Report

**Project**: Attendance Marker (`am-oss`)  
**Authoritative Path**: `C:\Users\Abishek\Desktop\am-oss`  
**Audit Timestamp**: September 27, 2026 — 18:28 IST  
**Database Backup Created**: `attendance_system_backup_20260927_181943.db`  
**Status**: Comprehensive Read-Only Audit Completed

---

## SECTION 1: Current DB Counts

The audited SQLite database (`attendance_system.db`) currently contains the following counts:

| Table / Entity | Current Count | Status / Notes |
| :--- | :--- | :--- |
| **users** | 130 | 1 Admin, 10 Faculty (2 test + 8 official), 119 Students |
| **class_sections** | 5 | 3 test/demo classes + 2 official academic classes |
| **faculty** | 10 | 2 test/demo faculty (`EMP-101`, `EMP-102`) + 8 official (`FAC01`-`FAC08`) |
| **students** | 119 | 64 in Class 1, 55 in Class 2 (100% authoritative roster) |
| **subjects** | 36 | 9 test/demo subjects (IDs 1–9) + 27 authoritative curriculum subjects (IDs 10–36) |
| **periods** | 9 | 7 official academic periods (P1–P7) + 2 test slots (P88, P99) |
| **faculty_assignments** | 30 | 15 for Class 1, 15 for Class 2 (all official classes) |
| **assignment_authorized_faculty** | 10 | Co-faculty links for multi-faculty courses (ACE-I, TWM, ASSOC, DPCO, DMC) |
| **timetable_entries** | 84 | 42 slots for Class 1 (Mon–Sat P1–P7) + 42 slots for Class 2 (Mon–Sat P1–P7) |
| **class_sessions** | 0 | Clean state (0 historical sessions) |
| **attendance_records** | 0 | Clean state (0 historical records) |
| **face_embeddings** | 0 | Clean state (ready for official student biometric enrollment) |
| **attendance_policies** | 1 | Standard college attendance policy active |
| **system_settings** | 0 | Standard configuration |
| **password_change_windows**| 0 | No active forced password windows |
| **admin_support_sessions** | 0 | No active support sessions |
| **audit_logs** | 11 | Historical admin and lifecycle audit events recorded |

---

## SECTION 2: Authoritative Expected Entities

1. **Class Sections (2 Classes)**:
   - ID 4: `II Year CSE Cyber Security - Class 1` (Grade: II Year, Year: 2026-2027)
   - ID 5: `III Year CSE Cyber Security - Class 2` (Grade: III Year, Year: 2026-2027)
2. **Students (119 Students)**:
   - Class 1: 64 students (`721025149001` through `721025149064`)
   - Class 2: 55 students (`721024149001` through `721024149055`)
3. **Faculty (8 Official Faculty Accounts)**:
   - `FAC01` / `fac01`: Mathu Metlda
   - `FAC02` / `fac02`: Showmiya
   - `FAC03` / `fac03`: Sivakumar
   - `FAC04` / `fac04`: Shankar
   - `FAC05` / `fac05`: Santhiya
   - `FAC06` / `fac06`: Lakshmi Narayanan
   - `FAC07` / `fac07`: Princy
   - `FAC08` / `fac08`: Gowri Manohari
4. **Subjects (27 Authoritative Curriculum Subjects)**:
   - Class 1: `FDS`, `DMC`, `FDS LAB`, `DPCO`, `OOPS`, `DS`, `ACE-I`, `UHV`, `IKS`, `DS LAB`, `IIC`, `JAVA LAB`, `TWM`, `LIB`, `ASSOC` (15 subjects)
   - Class 2: `AIML`, `LP`, `SDBMS`, `ESSS`, `SDBMS LAB`, `CC`, `E&I`, `CC-I`, `LINUX LAB`, `ESSS LAB`, `CF`, `CF LAB`, plus institutional `IIC`, `TWM`, `LIB` (15 subjects)
5. **Periods (7 Official Daily Periods)**:
   - P1: 09:10 – 10:00
   - P2: 10:00 – 10:50
   - P3: 11:10 – 12:00
   - P4: 12:50 – 13:40
   - P5: 13:40 – 14:30
   - P6: 14:30 – 15:20
   - P7: 15:20 – 16:10
6. **Timetable Matrix (84 Slots)**:
   - 6 Days: Monday through Saturday
   - 7 Periods per day
   - 42 slots for Class 1 (including verified academic corrections: Thursday P2 = `IKS`, Saturday P1 = `IKS`)
   - 42 slots for Class 2
7. **Official Class 2 Manual Assignment Selections**:
   - `TWM`: All Faculty Members (`FAC01`–`FAC08`)
   - `LINUX LAB`: Sivakumar (`FAC03`)
   - `CF LAB`: Santhiya (`FAC05`)
   - `ESSS LAB`: Showmiya (`FAC02`)

---

## SECTION 3: Suspicious & Test Entities

Audit proves conclusively that the following entities are test/demo artifacts originating from Milestone 1/2 seeding (`seed_db.py`, `test_milestone1.py`, `test_milestone2.py`):

### 1. Test Class Sections (IDs 1, 2, 3)
- `ID 1: CSE-3A` (Grade: Year 3, Year: 2025-2026) — 0 students, 0 assignments, 0 timetable slots, 0 sessions.
- `ID 2: CSE-3B` (Grade: Year 3, Year: 2025-2026) — 0 students, 0 assignments, 0 timetable slots, 0 sessions.
- `ID 3: TEST-CLASS-101` (Grade: Year 1, Year: 2026) — 0 students, 0 assignments, 0 timetable slots, 0 sessions.

### 2. Test Faculty Accounts & Linked Users (IDs 1, 2)
- `Faculty ID 1: EMP-101` — Dr. Alan Turing (Linked user ID 2: `faculty`, `faculty@college.edu`).
  - References: 0 primary assignments, 0 co-assignments, 0 sessions.
- `Faculty ID 2: EMP-102` — Dr. Grace Hopper (Linked user ID 3: `faculty2`, `faculty2@college.edu`).
  - References: 0 primary assignments, 0 co-assignments, 0 sessions.

### 3. Test Subjects (IDs 1 through 9)
- `ID 1: PTS` (Probability & Technical Statistics) — 0 assignments, 0 timetable slots, 0 sessions.
- `ID 2: TT` (Technical Training) — 0 assignments, 0 timetable slots, 0 sessions.
- `ID 3: CET-II` (Computer Networks II) — 0 assignments, 0 timetable slots, 0 sessions.
- `ID 4: EC` (Electronic Circuits) — 0 assignments, 0 timetable slots, 0 sessions.
- `ID 5: PPP` (Python Programming Practice) — 0 assignments, 0 timetable slots, 0 sessions.
- `ID 6: BEEE` (Basic Electrical & Electronics Eng) — 0 assignments, 0 timetable slots, 0 sessions.
- `ID 7: EG-LAB` (Engineering Graphics Lab) — 0 assignments, 0 timetable slots, 0 sessions.
- `ID 8: PE-LAB` (Physics Electronics Lab) — 0 assignments, 0 timetable slots, 0 sessions.
- `ID 9: SUB-999` (Testing Subject / Automated Unit Test Subject) — 0 assignments, 0 timetable slots, 0 sessions.

### 4. Test Periods (IDs 7, 8)
- `Period ID 7: Period 99` ('Night Slot', 20:00 – 21:00) — 0 timetable slots, 0 sessions.
- `Period ID 8: Period 88` ('Current Active Test Slot', 00:00 – 23:59) — 0 timetable slots, 0 sessions.

---

## SECTION 4: Orphan Records

- **Subjects with 0 relationships**: Exactly the 9 test subjects identified above. All 27 official subjects are linked to valid assignments and timetable slots.
- **Periods with 0 relationships**: Periods 88 and 99. Periods 1–7 are linked to exactly 12 timetable slots each ($12 \times 7 = 84$).
- **Classes with 0 relationships**: `CSE-3A`, `CSE-3B`, `TEST-CLASS-101`.
- **Faculty with 0 relationships**: `EMP-101`, `EMP-102`.
- **Assignments**: All 30 active assignments belong to Class 4 or Class 5, and map to subjects 10–36. No orphan assignment records exist.

---

## SECTION 5: Duplicate Records

- **Students**: 0 duplicate roll numbers, 0 duplicate usernames.
- **Faculty**: 0 duplicate employee IDs, 0 duplicate usernames.
- **Classes**: 0 duplicate class section names.
- **Timetable Slots**: 0 duplicate slots per `(day_of_week, period_id, class_id)`.

---

## SECTION 6: Broken Relationships

- Prior to our previous cleanup pass, legacy demo assignments 1–9 linked to `CSE-3A` and `CSE-3B` were orphaned; these were already pruned.
- Currently, **0 broken foreign keys exist in the database**. `PRAGMA foreign_key_check;` returns clean.

---

## SECTION 7: Frontend Hardcoded Data & Mappings

1. **Faculty Account Classification Bug**:
   - `app/api/admin.py` hardcoded `DEV_FACULTY_EMP_IDS = {"FAC01", "FAC02", ...}`, labeling all official faculty as "Development" while treating fake faculty Alan Turing and Grace Hopper as "Official".
   - **Correction**: `FAC01`–`FAC08` are official college faculty. `is_dev_account` must be `False` for official college faculty.
2. **Timetable Dropdown Selection**:
   - In `app/static/js/admin_app.js`, `timetableClassSelect` defaulted to `classes[0].id`. Because `CSE-3A` was ID 1, it selected `CSE-3A` by default. Purging test classes naturally defaults selection to `II Year CSE Cyber Security - Class 1`.
3. **Infinite Loading States**:
   - `admin_panel.html` hardcoded static `<tr><td colspan="10" class="text-center">Loading attendance records...</td></tr>` and `<tr><td colspan="8" class="text-center">Loading class sessions...</td></tr>`.
   - In `admin_app.js`, `apiFetch` failures caught errors with toast only, leaving the table stuck on "Loading".
   - **Correction**: Provide structured loading spinners, explicit empty states ("No attendance records yet.", "No class sessions yet."), and clear error banners with retry buttons.
4. **Dropdown Width & Option Clipping**:
   - `.search-filter-box` was constrained to `max-width: 500px`, squishing up to 6 filter controls and clipping long subject and class names.
   - **Correction**: Remove `max-width: 500px` limitation, apply responsive `flex-wrap: wrap`, set `min-width: 150px` on filter dropdowns, and style `<option>` tags with explicit dark-theme padding and text overflow.

---

## SECTION 8: Seed & Bootstrap Pollution

1. `seed_db.py`: Injected `admin`, `faculty` (EMP-101 Alan Turing), `CSE-3A`, `CSE-3B`, and 8 Milestone 1 test subjects.
2. `test_milestone1.py` & `test_milestone2.py`: Injected `TEST-CLASS-101`, `SUB-999`, `Period 88`, `Period 99`, and Grace Hopper when run directly against `attendance_system.db`.
3. `scripts/restore_development_database.py`: Was not purging test classes, test subjects, or test faculty.
4. **Safety Rule**: Neither `app/main.py` nor `app/core/database.py` calls `seed_db.py`. However, `scripts/restore_development_database.py` must be upgraded to ensure test entities are pruned if restoration is ever invoked.

---

## SECTION 9: Timetable Mismatches

1. **Admin Timetable Matrix**: Contains exactly 84 slots (42 for Class 1, 42 for Class 2) spanning Monday–Saturday, Periods 1–7.
2. **Sunday Slot Configuration**: Sunday has 0 scheduled classes in accordance with official college policy.
3. **Academic Corrections**:
   - Class 1: Thursday Period 2 = `IKS` (Indian Knowledge System, Santhiya)
   - Class 1: Saturday Period 1 = `IKS` (Indian Knowledge System, Santhiya)
   - Both confirmed intact in database.

---

## SECTION 10: Faculty Assignment Mismatches

- **Class 1**: 15 curriculum assignments (14 assigned, 1 unassigned `FDS LAB`).
- **Class 2**: 15 curriculum assignments. 4 assignments currently have `faculty_id = NULL`:
  - `TWM` -> target: All Faculty Members
  - `LINUX LAB` -> target: Sivakumar (`FAC03`)
  - `CF LAB` -> target: Santhiya (`FAC05`)
  - `ESSS LAB` -> target: Showmiya (`FAC02`)
- **Action**: Apply these 4 explicit assignments to reconcile Class 2 with confirmed academic policy.

---

## SECTION 11: Mobile / Admin Inconsistencies

1. **Sunday Day Mapping Bug**:
   - `mobile/lib/student/screens/student_timetable_screen.dart` and `mobile/lib/faculty/screens/faculty_dashboard_screen.dart` defined `_weekdays` with only 6 elements (Monday–Saturday).
   - On Sunday (`now.weekday == 7`), `_getCurrentWeekdayName()` defaulted to `'MONDAY'` and `_isToday('MONDAY')` evaluated to `true`, mistakenly showing Monday as "TODAY" on Sundays.
   - **Correction**: Expand `_weekdays` to 7 days (`MONDAY` through `SUNDAY`), map `now.weekday` directly using `DateTime.sunday`, attach the TODAY indicator strictly to the calendar day, and render "Weekend - No academic classes scheduled for Sunday" on Sundays.
2. **Mobile Timetable Empty State**:
   - `StudentTimetableScreen.initState()` did not trigger `fetchTimetable()`. If the dashboard preload had not completed or had failed silently, the screen remained showing "0 Periods".
   - **Correction**: Trigger `fetchTimetable()` on `initState` via post-frame callback, add explicit loading, empty, and retry states.
3. **Backend API URL Configuration**:
   - `mobile/lib/core/config/api_config.dart` had `hotspotUrl = 'http://10.254.103.195:8000'`.
   - Verified that `defaultUrl = 'http://192.168.0.114:8000'` is the active Wi-Fi backend.

---

## SECTION 12: Proposed Cleanup Actions

1. **Database Mutation Plan (via `scripts/reconcile_production_dataset.py`)**:
   - Delete test classes: IDs 1 (`CSE-3A`), 2 (`CSE-3B`), 3 (`TEST-CLASS-101`).
   - Delete test faculty: IDs 1 (`EMP-101`), 2 (`EMP-102`).
   - Delete test users: IDs 2 (`faculty`), 3 (`faculty2`).
   - Delete test subjects: IDs 1 through 9 (`PTS`, `TT`, `CET-II`, `EC`, `PPP`, `BEEE`, `EG-LAB`, `PE-LAB`, `SUB-999`).
   - Delete test periods: IDs 7 (`Period 99`), 8 (`Period 88`).
   - Reconcile Class 2 manual assignments:
     - `TWM`: Primary `FAC01`, authorized co-faculty `FAC01`..`FAC08`.
     - `LINUX LAB`: Sivakumar (`FAC03`).
     - `CF LAB`: Santhiya (`FAC05`).
     - `ESSS LAB`: Showmiya (`FAC02`).
   - Record `PRODUCTION_DATA_RECONCILIATION` in `AuditLog`.
2. **Backend Code Adjustments**:
   - `app/api/admin.py`: Redefine `is_dev_account` to `False` for official college faculty.
3. **Frontend Admin Panel Adjustments**:
   - `admin_panel.html` & `admin_app.js`: Fix loading, empty, and error states for Attendance Records and Class Sessions.
   - `admin_style.css`: Fix `.search-filter-box` flex wrapping, remove 500px max-width, set min-widths, and dark `<option>` styling.
4. **Mobile Client Adjustments**:
   - `student_timetable_screen.dart` & `faculty_dashboard_screen.dart`: Implement 7-day Sunday mapping and empty state.
   - `student_service.dart`: Add timetable fetch call in screen `initState`.
