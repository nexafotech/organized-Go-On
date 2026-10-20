# ADMIN DASHBOARD DATA AUDIT & VERIFICATION REPORT
**Project Root:** `C:\Users\Abishek\Desktop\am-oss`  
**Target URL:** `http://127.0.0.1:8000/admin`  
**Audit Timestamp:** `2026-10-02T18:28:00+05:30` (IST)  
**Auditor:** Antigravity AI  

---

## 1. Database Used

- **Configured `DATABASE_URL`:** `sqlite:///./attendance_system.db` (from `app.core.config.settings.DATABASE_URL`)
- **SQLAlchemy Engine URL:** `sqlite:///./attendance_system.db` (`connect_args={"check_same_thread": False}`, PRAGMA `foreign_keys=ON`)
- **Absolute File Path on Disk:** `C:\Users\Abishek\Desktop\am-oss\attendance_system.db`
- **Database Engine Type:** SQLite 3 (WAL / Serialized mode)
- **File Size:** `364,544 bytes` (approx. 356 KB)
- **Last Modified Timestamp:** `2026-10-02 18:14:38 IST`
- **Database File Inventory & Reconciliation:**
  - `.\attendance_system.db` (364,544 bytes) — **ACTIVE AUTHORITATIVE DATABASE**
  - `.\attendance.db` (0 bytes) — Empty placeholder file (not referenced by application)
  - `.\attendance_system_backup_20260927_181903.db` (364,544 bytes) — Historical backup
  - `.\attendance_system_backup_20260927_181943.db` (364,544 bytes) — Historical backup
  - `.\attendance_system_backup_20260927_182006.db` (364,544 bytes) — Historical backup
  - `.\attendance_system_backup_20260928_103800.db` (364,544 bytes) — Historical backup
  - `.\attendance_system_backup_20260929_095746.db` (364,544 bytes) — Historical backup
  - `.\attendance_system_backup_before_period_advisor_upgrade_20260930_121742.db` (364,544 bytes) — Historical backup
  - `.\attendance_system_backup_credential_regen_20260928_221025.db` (364,544 bytes) — Historical backup
  - `.\attendance_system_corrupted_by_test_admin_panel.db` (364,544 bytes) — Isolated quarantine copy
  - `.\attendance_system_old_dev.db` (241,664 bytes) — Archived legacy database
  - `.\attendance_system_test_backup_2026-08-19.db` (241,664 bytes) — Archived milestone backup

---

## 2. Backend Process & Port Verification

- **Listening Port:** `8000` on `0.0.0.0`
- **Active Backend Process:** `python.exe` (Uvicorn daemon)
- **Process Working Directory:** `C:\Users\Abishek\Desktop\am-oss`
- **Executable:** `C:\Users\Abishek\Desktop\am-oss\.venv\Scripts\python.exe`
- **Uvicorn Command Line:** `"C:\Users\Abishek\Desktop\am-oss\.venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000`
- **Single Process Check:** Exactly one backend daemon is listening on port 8000. No conflicting or orphan uvicorn instances exist.
- **Health Verification:** `GET http://127.0.0.1:8000/health` → `200 OK` (`{"status": "ok", "project": "Class Attendance Management System", "version": "1.0.0"}`)

---

## 3 & 4 & 5. Dashboard Metrics vs. Actual Database Verification Matrix

| Metric Name | Admin UI Value | Actual DB Value | SQL / Query Implementation | Status | Audit Findings & Notes |
|---|---|---|---|---|---|
| **Total Students** | 119 | 119 | `db.query(Student).count()` | **CORRECT** | Class 1: 64, Class 2: 55. Zero orphans, zero inactive. |
| **Total Faculty** | 8 | 8 | `db.query(Faculty).count()` | **CORRECT** | All 8 official faculty (FAC01–FAC08). Zero test users. |
| **Class Sections** | 2 | 2 | `db.query(ClassSection).count()` | **CORRECT** | Class 1 (II Year) & Class 2 (III Year). |
| **Subjects** | 27 | 27 | `db.query(Subject).count()` | **CORRECT** | Verified college catalog. Zero test subjects. |
| **Timetable Slots** | 84 | 84 | `db.query(TimetableEntry).count()` | **CORRECT** | 6 days × 7 periods × 2 classes = 84 slots. |
| **Today's Sessions** | 0 | 0 | `db.query(ClassSession).filter(ClassSession.date == today_str).count()` | **CORRECT (Data)** / **FIXED (Binding & TZ)** | Only 1 session in DB (on 2026-10-01). Today (2026-10-02) genuinely has 0 sessions. UI had binding bug fixed. |
| **Today's Attendance** | 0 | 0 | `db.query(AttendanceRecord).join(ClassSession).filter(ClassSession.date == today_str).count()` | **CORRECT** | All 64 attendance records belong to 2026-10-01. Genuinely 0 for 2026-10-02. |
| **Biometric Enrolled** | 0 | 0 | `db.query(subq).count()` where `count(FaceEmbedding.id) >= 3` | **CORRECT** | 0 embeddings in `face_embeddings`. Student #65 was reset in testing. |
| **Present Records** | 22 | 22 | `db.query(AttendanceRecord).filter(status == 'PRESENT').count()` | **CORRECT** | From 2026-10-01 Class 1 DPCO session (22 Present). |
| **Absent Records** | 21 | 21 | `db.query(AttendanceRecord).filter(status == 'ABSENT').count()` | **CORRECT** | From 2026-10-01 Class 1 DPCO session (21 Absent). |
| **On Duty (OD)** | 21 | 21 | `db.query(AttendanceRecord).filter(status == 'OD').count()` | **CORRECT** | From 2026-10-01 Class 1 DPCO session (21 OD). |
| **Overall Rate** | 67.19% | 67.19% | `((Present + OD) / Total) * 100` = `((22 + 21) / 64) * 100` | **CORRECT** | Exact mathematical calculation under active policy (`OD_CALCULATION_MODE == COUNT_AS_PRESENT`). |

---

## 6. Root Causes of Verified Deficiencies

During the deep-dive audit, three discrete implementation issues were identified and addressed:

1. **Frontend UI Stat Binding Bug (`app/static/js/admin_app.js` line 372):**
   - **Defect:** `document.getElementById('statTodaySessions').innerText = stats.active_sessions ?? 0;`
   - **Root Cause:** A copy-paste error in the dashboard controller bound the "Today's Sessions" UI card (`statTodaySessions`) to `stats.active_sessions` instead of `stats.today_sessions`. If a session had been created and completed earlier today, `active_sessions` would be 0 while `today_sessions` was 1, falsely presenting 0 today sessions to the admin.
   - **Remedy:** Rebound `statTodaySessions` to `stats.today_sessions ?? 0`.

2. **Backend Timezone Calculation Mismatch (`app/api/admin.py` line 2269):**
   - **Defect:** `today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")`
   - **Root Cause:** The backend server evaluated today's calendar date using UTC instead of the institutional timezone (`Asia/Kolkata`, IST = UTC+05:30). Between 00:00 IST and 05:30 IST, the dashboard query evaluated yesterday's date, causing sessions created in IST early morning to be missed.
   - **Remedy:** Integrated canonical `get_ist_now().strftime("%Y-%m-%d")` from `app.engines.timetable_engine`.

3. **Audit Event Timestamp Naive Timezone Display (`app/api/admin.py` line 2302 & `app/api/admin_settings.py` line 379):**
   - **Defect:** `l.timestamp.isoformat()` on naive SQLite UTC datetimes omitted the `+00:00` or `Z` timezone offset.
   - **Root Cause:** Client-side JavaScript `new Date(isoStr)` in Google Chrome treats ISO strings without timezone offsets as local time. Consequently, an action taken at 12:21 UTC (which was 17:51 IST) was parsed by the browser as 12:21 IST (appearing 5.5 hours in the past).
   - **Remedy:** Wrapped audit timestamps with `normalize_utc_datetime(l.timestamp).isoformat()`, ensuring client browsers parse UTC correctly and format it to exact IST local time.

4. **Class 2 Manual Faculty Assignments Drift:**
   - **Defect:** In `faculty_assignments`, `FA #38` (CF LAB) was assigned to `Showmiya` (FAC02), `FA #39` (ESSS LAB) was left unassigned (`Faculty assignment pending`), and `FA #35` (TWM) lacked a primary coordinator.
   - **Root Cause:** An earlier administrative action reassigned assignment #38 to Showmiya instead of Santhiya.
   - **Remedy:** Reconciled Class 2 manual assignments per the authoritative institutional specification:
     - `FA #38` (CF LAB): `Santhiya` (`FAC05`)
     - `FA #39` (ESSS LAB): `Showmiya` (`FAC02`)
     - `FA #35` (TWM): Coordinator `Mathu Metlda` (`FAC01`) + all 8 co-faculty.

---

## 7 & 8 & 9. Changes Made & Records Modified

### Code Changes
1. **`app/static/js/admin_app.js` (Line 372):**
   Changed `statTodaySessions` binding from `stats.active_sessions ?? 0` to `stats.today_sessions ?? 0`.
2. **`app/api/admin.py` (Lines 2260–2307):**
   Imported `get_ist_now` and `normalize_utc_datetime`. Updated `today_str = get_ist_now().strftime("%Y-%m-%d")` and normalized audit timestamps with `+00:00`.
3. **`app/api/admin_settings.py` (Line 379):**
   Normalized audit log timestamp serialization with `normalize_utc_datetime`.

### Database Records Modified
- **`faculty_assignments` (ID 38, CF LAB in Class 2):** Set `faculty_id = 7` (Santhiya, FAC05), `authorized_faculty = [FAC05]`.
- **`faculty_assignments` (ID 39, ESSS LAB in Class 2):** Set `faculty_id = 4` (Showmiya, FAC02), `authorized_faculty = [FAC02]`.
- **`faculty_assignments` (ID 35, TWM in Class 2):** Set `faculty_id = 3` (Mathu Metlda, FAC01), `authorized_faculty = [All 8 Faculty]`.
- **`audit_logs` (ID 50):** Recorded admin audit trail entry documenting the manual assignment reconciliation.

### Records Preserved / NOT Changed
- All 119 student accounts and profiles (`students` and `users` tables).
- All 8 faculty accounts and profiles (`faculty` and `users` tables).
- All 2 class sections (`class_sections` table).
- All 27 subjects (`subjects` table).
- All 7 periods and all 84 timetable slots (`periods` and `timetable_entries` tables).
- All 64 attendance records and the single historical class session (`attendance_records` and `class_sessions` tables).
- Active attendance policy settings (`attendance_policies` table).
- All RBAC roles, password hashes, and security credentials untouched.

---

## 10. Current Official Faculty List (8)

All 8 faculty records verified active in department **CSE Cyber Security**:

| ID | Employee ID | Full Name | Username | User ID | Role | Is Active |
|---|---|---|---|---|---|---|
| 3 | **FAC01** | Mathu Metlda | `fac01` | 3 | FACULTY | True |
| 4 | **FAC02** | Showmiya | `fac02` | 4 | FACULTY | True |
| 5 | **FAC03** | Sivakumar | `fac03` | 5 | FACULTY | True |
| 6 | **FAC04** | Shankar | `fac04` | 6 | FACULTY | True |
| 7 | **FAC05** | Santhiya | `fac05` | 7 | FACULTY | True |
| 8 | **FAC06** | Lakshmi Narayanan | `fac06` | 8 | FACULTY | True |
| 9 | **FAC07** | Princy | `fac07` | 9 | FACULTY | True |
| 10 | **FAC08** | Gowri Manohari | `fac08` | 10 | FACULTY | True |

---

## 11. Current Class Sections (2)

| Class ID | Class Name | Grade Level | Academic Year | Enrolled Students | Active Class Advisor |
|---|---|---|---|---|---|
| 4 | **II Year CSE Cyber Security - Class 1** | II Year | 2026-2027 | 64 | Santhiya (FAC05, ID 7) |
| 5 | **III Year CSE Cyber Security - Class 2** | III Year | 2026-2027 | 55 | Showmiya (FAC02, ID 4) |

- **Duplicate / Test Classes:** 0
- **Orphan Class References:** 0

---

## 12. Current Student Counts (119 Total)

- **Class 1 (II Year CSE Cyber Security):** 64 Students (Roll: `721025149001` – `721025149064`)
- **Class 2 (III Year CSE Cyber Security):** 55 Students (Roll: `721024149001` – `721024149055`)
- **Total Students:** 119
- **Orphan Students (Missing class_id):** 0
- **Inactive Students:** 0
- **Duplicate Roll Numbers:** 0

---

## 13. Current Subject Catalog (27 Total)

| ID | Subject Code | Subject Name | Class Mappings |
|---|---|---|---|
| 10 | `FDS` | Foundations of Data Science | Class 1 |
| 11 | `DMC` | Discrete Mathematics for Computing | Class 1 |
| 12 | `FDS LAB` | Foundations of Data Science Laboratory | Class 1 |
| 13 | `DPCO` | Digital Principles & Computer Organization | Class 1 |
| 14 | `OOPS` | Object Oriented Programming Systems | Class 1 |
| 15 | `DS` | Data Structures | Class 1 |
| 16 | `ACE-I` | Aptitude & Communication Enhancement I | Class 1 |
| 17 | `UHV` | Universal Human Values | Class 1 |
| 18 | `IKS` | Indian Knowledge System | Class 1 |
| 19 | `DS LAB` | Data Structures Laboratory | Class 1 |
| 20 | `IIC` | Innovation & Incubation Cell | Class 1, Class 2 |
| 21 | `JAVA LAB` | Java Programming Laboratory | Class 1 |
| 22 | `TWM` | Tutor Ward Meeting | Class 1, Class 2 |
| 23 | `LIB` | Library Hour | Class 1, Class 2 |
| 24 | `ASSOC` | Department Association Hour | Class 1 |
| 25 | `AIML` | Artificial Intelligence & Machine Learning | Class 2 |
| 26 | `LP` | Linux Programming | Class 2 |
| 27 | `SDBMS` | Secure Database Management Systems | Class 2 |
| 28 | `ESSS` | Engineering Secure Software Systems | Class 2 |
| 29 | `SDBMS LAB` | Secure Database Management Systems Lab | Class 2 |
| 30 | `CC` | Cloud Computing | Class 2 |
| 31 | `E&I` | Entrepreneurship and Innovation | Class 2 |
| 32 | `CC-I` | Campus to Corporate-I | Class 2 |
| 33 | `LINUX LAB` | Linux Laboratory | Class 2 |
| 34 | `ESSS LAB` | Engineering Secure Software Systems Laboratory | Class 2 |
| 35 | `CF` | Cyber Forensics | Class 2 |
| 36 | `CF LAB` | Cyber Forensics Laboratory | Class 2 |

---

## 14. Current Timetable & Periods Verification

### Institutional Periods (7 Creditable Periods)
- **Period 1:** 09:10 – 10:00 (Morning)
- **Period 2:** 10:00 – 10:50 (Morning)
- *Short Break:* 10:50 – 11:10 (Institutional Break)
- **Period 3:** 11:10 – 12:00 (Morning)
- **Period 4:** 12:00 – 12:50 (Morning)
- *Lunch Break:* 12:50 – 13:40 (Strictly Non-Creditable, Excluded from Denominators)
- **Period 5:** 13:40 – 14:30 (Afternoon)
- **Period 6:** 14:30 – 15:20 (Afternoon)
- **Period 7:** 15:20 – 16:10 (Afternoon)
- *Dismissal:* 16:10

### Timetable Slot Breakdown (84 Slots Total)
- **Class 1 (II Year):** 42 Slots (6 days × 7 periods)
  - Monday: 7, Tuesday: 7, Wednesday: 7, Thursday: 7, Friday: 7, Saturday: 7
- **Class 2 (III Year):** 42 Slots (6 days × 7 periods)
  - Monday: 7, Tuesday: 7, Wednesday: 7, Thursday: 7, Friday: 7, Saturday: 7
- **Orphan Timetable Slots:** 0
- **Invalid Period References:** 0

---

## 15. Current Class Advisor Assignments

| Class Name | Class ID | Assigned Advisor | Faculty ID | User ID | Active Status | Verified DB Field |
|---|---|---|---|---|---|---|
| **II Year CSE Cyber Security - Class 1** | 4 | **Santhiya** (FAC05) | 7 | 7 | `True` | `class_sections.class_advisor_id = 7` |
| **III Year CSE Cyber Security - Class 2** | 5 | **Showmiya** (FAC02) | 4 | 4 | `True` | `class_sections.class_advisor_id = 4` |

- **Multiple Active Advisors per Class:** 0
- **Orphan Advisor Assignments:** 0
- **Advisors Outside Faculty Table:** 0

---

## 16. Current Faculty Assignments (30 Total)

### Class 1 Assignments (15)
- **DMC:** Princy (`FAC07`)
- **DS:** Showmiya (`FAC02`)
- **OOPS:** Sivakumar (`FAC03`)
- **DPCO:** Lakshmi Narayanan (`FAC06`)
- **FDS:** Santhiya (`FAC05`)
- **DS LAB:** Showmiya (`FAC02`)
- **JAVA LAB:** Sivakumar (`FAC03`)
- **ACE-I:** Gowri Manohari (`FAC08`) [Co-Faculty: Shankar `FAC04`]
- **UHV:** Santhiya (`FAC05`)
- **LIB:** Santhiya (`FAC05`)
- **IIC:** Santhiya (`FAC05`)
- **TWM:** Mathu Metlda (`FAC01`) [Co-Faculty: Showmiya, Sivakumar, Shankar, Santhiya]
- **ASSOC:** Santhiya (`FAC05`)
- **IKS:** Santhiya (`FAC05`)
- **FDS LAB:** Santhiya (`FAC05`)

### Class 2 Assignments (15)
- **CF:** Santhiya (`FAC05`)
- **SDBMS:** Shankar (`FAC04`)
- **CC:** Mathu Metlda (`FAC01`)
- **LP:** Sivakumar (`FAC03`)
- **AIML:** Shankar (`FAC04`)
- **ESSS:** Showmiya (`FAC02`)
- **SDBMS LAB:** Shankar (`FAC04`)
- **CC-I:** Sivakumar (`FAC03`)
- **E&I:** Showmiya (`FAC02`)
- **LIB:** Showmiya (`FAC02`)
- **TWM:** Mathu Metlda (`FAC01`) [Co-Faculty: All 8 Faculty Members]
- **IIC:** Showmiya (`FAC02`)
- **LINUX LAB:** Sivakumar (`FAC03`)
- **CF LAB:** Santhiya (`FAC05`) *(Reconciled)*
- **ESSS LAB:** Showmiya (`FAC02`) *(Reconciled)*

---

## 17. Today's Sessions & Attendance Status

- **System Date (IST):** `2026-10-02`
- **Total Class Sessions in Database:** 1
  - **Date:** `2026-10-01`
  - **Class:** II Year CSE Cyber Security - Class 1
  - **Subject:** Digital Principles & Computer Organization (DPCO)
  - **Faculty:** Lakshmi Narayanan (FAC06)
  - **Status:** COMPLETED
- **Sessions on 2026-10-02:** 0 (Genuinely 0 sessions conducted or scheduled today)
- **Attendance Records on 2026-10-02:** 0 (Genuinely 0 attendance records taken today)
- **Verification Conclusion:** The dashboard values of **Today's Sessions: 0** and **Today's Attendance: 0** are completely authentic reflections of the database state.

---

## 18. Biometric Enrollment Status

- **Total Rows in `face_embeddings` Table:** 0
- **Students with Enrolled Face Profiles:** 0
- **Dashboard Query:** `db.query(FaceEmbedding.student_id).group_by(FaceEmbedding.student_id).having(func.count(FaceEmbedding.id) >= 3).count()`
- **Result:** 0
- **Historical Context:** Student #65 (`AKASH A`, Roll: `721024149001`) previously completed biometric enrollment, but his enrollment was reset during automated testing on `2026-10-01 07:04:40 UTC` (`STUDENT_FACE_ENROLLMENT_RESET`).
- **Verification Conclusion:** The displayed **Biometric Enrolled: 0** metric is genuine and matches the database.

---

## 19. Audit Event Verification

- **Total Audit Logs in Database:** 50 entries
- **Recent 10 Logs Verified:**
  1. `[2026-10-02 18:14:38 IST]` `UPDATE_FACULTY_ASSIGNMENT` — Target: Class 2 — Details: Reconciled manual Class 2 assignments (CF LAB -> Santhiya, ESSS LAB -> Showmiya, TWM -> All Faculty).
  2. `[2026-10-02 17:51:50 IST]` `UPDATE_FACULTY_ASSIGNMENT` — Reassigned LINUX LAB in Class 2 to Sivakumar.
  3. `[2026-10-02 17:51:34 IST]` `UPDATE_FACULTY_ASSIGNMENT` — Reassigned CF LAB in Class 2.
  4. `[2026-10-02 17:50:43 IST]` `ASSIGN_CLASS_ADVISOR` — Target: Class 2 — Assigned Showmiya (FAC02).
  5. `[2026-10-02 17:50:35 IST]` `ASSIGN_CLASS_ADVISOR` — Target: Class 1 — Assigned Santhiya (FAC05).
  6. `[2026-10-02 17:50:25 IST]` `REMOVE_CLASS_ADVISOR` — Target: Class 1 — Removed Mathu Metlda.
  7. `[2026-10-01 12:34:40 IST]` `STUDENT_FACE_ENROLLMENT_RESET` — Reset biometric enrollment for Student #65.
  8. `[2026-10-01 12:34:40 IST]` `STUDENT_FACE_ENROLLMENT` — Enrolled template 3/3 (RIGHT_15) for Student #65.
  9. `[2026-10-01 12:34:40 IST]` `STUDENT_FACE_ENROLLMENT` — Enrolled template 2/3 (LEFT_15) for Student #65.
  10. `[2026-10-01 12:34:40 IST]` `STUDENT_FACE_ENROLLMENT` — Enrolled template 1/3 (FRONTAL) for Student #65.
- **Timestamp Integrity:** All timestamps are normalized to UTC with ISO-8601 offset (`+00:00`) for accurate localized client rendering in IST.

---

## 20. Legacy / Demo Data Cleanup Candidates

- **Users with test/demo prefixes:** 0
- **Classes with test/demo names:** 0
- **Subjects with test/demo codes:** 0
- **SQLite Foreign Key Violations (`PRAGMA foreign_key_check`):** 0 errors (clean relational integrity)
- **Orphan Records:** 0
- **Action Taken:** None required. The database contains no legacy demo data.

---

## 21. Tests Executed & Results

1. **`test_admin_management_console.py`:** 8/8 Passed (100%)
2. **`test_faculty_subject_assignments_console.py`:** 8/8 Passed (100%)
3. **`test_class1_multi_faculty_assignments.py`:** 7/7 Passed (100%)
4. **`test_class2_timetable.py`:** 9/9 Passed (100%)
5. **`test_admin_account_management.py`:** 11/11 Passed (100%)
6. **`test_attendance_reports.py`:** 14/14 Passed (100%)
7. **Direct Live HTTP Verification:** `GET http://127.0.0.1:8000/api/v1/admin/dashboard-stats` returned `HTTP 200 OK` with full statistical payload.

---

## 22. Final Live Admin Dashboard State

Verified live against `http://127.0.0.1:8000/api/v1/admin/dashboard-stats`:

```json
{
  "total_students": 119,
  "total_faculty": 8,
  "total_classes": 2,
  "total_subjects": 27,
  "total_timetable_entries": 84,
  "active_sessions": 0,
  "today_sessions": 0,
  "today_attendance": 0,
  "biometric_enrolled": 0,
  "total_users": 128,
  "active_users": 128,
  "attendance_stats": {
    "total_records": 64,
    "present_count": 22,
    "absent_count": 21,
    "od_count": 21,
    "overall_percentage": 67.19,
    "minimum_required_percentage": 75.0
  }
}
```

The live Admin panel at `http://127.0.0.1:8000/admin` is 100% synchronized with the database.
