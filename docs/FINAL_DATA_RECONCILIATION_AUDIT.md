# FINAL DATA RECONCILIATION AUDIT REPORT
**Project:** Attendance Marker — am-oss  
**Audit Date:** 2026-09-28  
**Auditor:** Antigravity AI  
**DB Backup (pre-audit):** `attendance_system_backup_20260928_103800.db`  
**DB Backup (post-cleanup):** `attendance_system_backup_20260927_181943.db` (from cleanup session)

---

## 1. Backup Path

| Backup | Path | Created |
|--------|------|---------|
| Pre-audit (current state) | `attendance_system_backup_20260928_103800.db` | 2026-09-28 |
| Post-cleanup reference | `attendance_system_backup_20260927_181943.db` | 2026-09-27 |

---

## 2. Initial DB Counts (At Audit Start)

| Table | Count |
|-------|-------|
| users | 128 |
| students | 119 |
| faculty | 8 |
| class_sections | 2 |
| subjects | 27 |
| periods | 7 |
| timetable_entries | 84 |
| faculty_assignments | 30 |
| class_sessions | 0 |
| attendance_records | 0 |
| face_embeddings | 0 |
| audit_logs | 12 |

---

## 3. Confirmed Test Records Removed (Prior Session)

These were purged in the 2026-09-27 cleanup session:

| Type | Records Purged |
|------|---------------|
| Classes | CSE-3A (ID 1), CSE-3B (ID 2), TEST-CLASS-101 (ID 3) |
| Faculty | EMP-101 (Dr. Alan Turing), EMP-102 (Dr. Grace Hopper) + their user accounts |
| Users | `faculty` (ID 2), `faculty2` (ID 3) |
| Periods | Period 88, Period 99 |
| Subjects | PTS, TT, CET-II, EC, PPP, BEEE, EG-LAB, PE-LAB, SUB-999 (9 test subjects) |

---

## 4. Confirmed Orphaned Records

| Check | Result |
|-------|--------|
| Students with no class_section | **0** |
| Face embeddings with no student | **0** |
| Faculty with no user account | **0** |
| Subjects with no assignment | **0** |
| FK constraint check (PRAGMA foreign_key_check) | **0 errors** |

---

## 5. Records Removed (This Session)

**None.** No additional test/legacy data was found. DB is clean.

---

## 6. Records Preserved (Authoritative Data)

### Classes (2)
| ID | Name | Academic Year |
|----|------|---------------|
| 4 | II Year CSE Cyber Security - Class 1 | 2026-2027 |
| 5 | III Year CSE Cyber Security - Class 2 | 2026-2027 |

### Faculty (8)
| employee_id | Full Name | Username | Active |
|-------------|-----------|----------|--------|
| FAC01 | Mathu Metlda | fac01 | ✅ |
| FAC02 | Showmiya | fac02 | ✅ |
| FAC03 | Sivakumar | fac03 | ✅ |
| FAC04 | Shankar | fac04 | ✅ |
| FAC05 | Santhiya | fac05 | ✅ |
| FAC06 | Lakshmi Narayanan | fac06 | ✅ |
| FAC07 | Princy | fac07 | ✅ |
| FAC08 | Gowri Manohari | fac08 | ✅ |

### Students (119)
- Class 1 (II Year CSE Cyber Security): **64 students**
- Class 2 (III Year CSE Cyber Security): **55 students**

### Subjects (27)
All 27 subjects linked to assignments. No orphaned subjects.

**Class 1 Subjects (15):** ACE-I, ASSOC, DMC, DPCO, DS, DS LAB, FDS, FDS LAB, IIC, IKS, JAVA LAB, LIB, OOPS, TWM, UHV  
**Class 2 Subjects (12):** AIML, CC, CC-I, CF, CF LAB, E&I, ESSS, ESSS LAB, IIC, LIB, LINUX LAB, LP, SDBMS, SDBMS LAB, TWM

> **Note:** IIC, LIB, TWM appear in both classes with separate assignments.

### Timetable (84 slots total)
- 42 slots per class × 2 = 84
- 14 slots per day × 6 days (Mon–Sat) = 84
- Class 1: Thu P2=IKS, Sat P1=IKS ✅

### Faculty Assignments (30)
- 29 assigned, 1 legitimately unassigned: **FDS LAB (Class 1) — faculty_id = NULL** (intentional, pending admin allocation)

### Periods (7)
P1–P7 with correct times (09:10–16:10)

---

## 7. Seed/Bootstrap Protection

| Risk | Status |
|------|--------|
| `app/main.py` on startup | **No seeding called** ✅ |
| `app/core/database.py` init | **No seeding called** ✅ |
| `seed_temporary_dev_timetable()` | Only called via `POST /api/v1/admin/timetable/reset-dev` (admin-auth required) ✅ |
| `import_college_seed_bundle()` | Only called via `POST /api/v1/admin/import/*` (admin-auth required) ✅ |
| Test data references in `college_importer.py` | **None found** (CSE-3A, EMP-101, etc. not present in seeder) ✅ |
| `scripts/restore_development_database.py` | Updated to purge test records before reset ✅ |

**Verdict: Backend restart WILL NOT recreate test data.** Production DB is safe on restart.

---

## 8. API Fixes Applied

| Fix | Status |
|-----|--------|
| Faculty classification — removed hardcoded `DEV_FACULTY_EMP_IDS = {"FAC01", ...}` | ✅ Done |
| Dynamic `_is_dev_faculty_account()` function using env var | ✅ Done |
| FAC01–FAC08 now show as "Official" (green) in admin panel | ✅ Done |

### Admin Attendance Records & Class Sessions
- `/api/v1/admin/attendance` — HTTP 200, returns `[]` when empty ✅
- `/api/v1/admin/sessions` — HTTP 200, returns `[]` when empty ✅
- JS `renderAttendanceTable()` shows "No attendance records yet." when `records.length === 0` ✅
- JS `renderSessionsTable()` shows "No class sessions yet." when `sessions.length === 0` ✅
- **Root cause of previous 404:** Admin JS was pre-loading without auth token during anonymous health checks. Authenticated requests return 200. No fix needed.

### Dashboard Stats
- `/api/v1/admin/dashboard-stats` — all counts are **live DB queries** (no hardcoding) ✅
- `statStudents`, `statFaculty`, `statClasses` all populated from API response ✅

---

## 9. Mobile Timetable Fix

| Fix | Status |
|-----|--------|
| `_weekdays` array extended to include `'SUNDAY'` | ✅ Done |
| `_dayLabels` extended to include `'Sun'` | ✅ Done |
| `_getCurrentWeekdayName()` handles `DateTime.sunday` | ✅ Done |
| Sunday empty state: "No Classes Scheduled / Weekend" | ✅ Done |
| Same fix applied to `faculty_dashboard_screen.dart` | ✅ Done |
| Physical device verified (Realme Narzo 70 Pro 5G) | ✅ Verified |

---

## 10. Sunday / TODAY Badge Fix

| Fix | Status |
|-----|--------|
| Sunday maps to `'SUNDAY'` (not `'MONDAY'`) | ✅ Fixed |
| TODAY badge highlights correct day on Sunday | ✅ Fixed |
| Day selector bar overflow fixed (Expanded pattern) | ✅ Fixed |
| Font size reduced 13→12 for day labels | ✅ Fixed |
| Verified on device — Sunday shows weekend message | ✅ Verified |

---

## 11. Admin Loading State Fixes

| Page | Status |
|------|--------|
| Attendance Records — "Loading..." stuck | ✅ Resolved (API returns 200 + empty array; JS shows "No attendance records yet.") |
| Class Sessions — "Loading..." stuck | ✅ Resolved (same) |
| Error state with Retry button shown on network failure | ✅ Already implemented |

---

## 12. Final DB Counts

| Table | Count |
|-------|-------|
| users | 128 |
| students | 119 |
| faculty | 8 |
| class_sections | 2 |
| subjects | 27 |
| periods | 7 |
| timetable_entries | 84 |
| faculty_assignments | 30 (29 assigned, 1 unassigned: FDS LAB) |
| class_sessions | 0 |
| attendance_records | 0 |
| face_embeddings | 0 |
| audit_logs | 12 |

---

## 13. pytest Result

```
====================== 205 passed, 18 warnings in 972.89s (0:16:12) ======================
```

✅ **PASSED — 205/205 tests (100% pass rate)**

All test suites verified clean:
- `test_admin_account_management.py`: 12 passed
- `test_admin_management_console.py`: 12 passed
- `test_admin_subject_management.py`: 10 passed
- `test_admin_timetable.py`: 9 passed
- `test_class1_multi_faculty_assignments.py`: 9 passed
- `test_class1_student_onboarding.py`: 6 passed
- `test_class1_student_roster.py`: 6 passed
- `test_class2_account_validation_e2e.py`: 7 passed
- `test_class2_student_onboarding.py`: 5 passed
- `test_class2_student_roster.py`: 14 passed
- `test_class2_timetable.py`: 9 passed
- `test_faculty_assignments.py`: 7 passed
- `test_faculty_attendance_e2e.py`: 7 passed
- `test_faculty_live_validation.py`: 10 passed
- `test_faculty_subject_assignments_console.py`: 8 passed
- `test_password_policy_and_support_mode.py`: 15 passed
- `test_production_import_workflow.py`: 7 passed
- `test_recognition_engine_abstraction.py`: 9 passed
- `test_scrfd_arcface_engine.py`: 10 passed
- `test_student_face_pose_enrollment.py`: 15 passed
- `test_timetable_conflicts.py`: 14 passed

---

## 14. flutter analyze Result

```
Analyzing mobile...
No issues found! (ran in 6.8s)
```

✅ **PASSED — 0 issues**

---

## 15. flutter test Result

```
00:18 +56: All tests passed!
```

✅ **PASSED — 56/56 tests**

---

## 16. Physical Device Verification

**Device:** Realme Narzo 70 Pro 5G (RMX3998) — ADB serial: `FY6PHIEA69AMQ8HU`

| Check | Result |
|-------|--------|
| App installed (debug APK) | ✅ |
| Student login: 721025149002 / Password123! | ✅ |
| Student dashboard loads | ✅ |
| Monday timetable: 7 periods with real subjects | ✅ |
| Sunday: "No Classes Scheduled / Weekend" message | ✅ |
| Day selector bar: all 7 days visible, no overflow | ✅ |
| ADB reverse tcp:8000 active | ✅ (must re-run after each cable reconnect) |

---

## 17. Remaining Uncertainties / Open Items

| Item | Status |
|------|--------|
| FDS LAB (Class 1) — unassigned faculty | **Intentional** — awaiting admin assignment |
| `hotspotUrl = 'http://10.254.103.195:8000'` in `api_config.dart` | **Intentional** — kept as secondary dev endpoint (hotspot mode). Not a bug. |
| `force_password_change = True` for 118 students | **Expected** — students must change on first login |
| `721025149002` (ABISHEK A) — `force_password_change = False` | **Expected** — password was changed to `Password123!` |
| Admin `force_password_change` | Verified = False (admin can login) |
| Faculty dashboard screenshot | Was ChatGPT overlay (device wandered) — faculty login itself was unverified physically (API-tested only) |
| DO NOT COMMIT / DO NOT PUSH | Constraint honored — no git commits made |

---

## Appendix: Stale URL Audit

| Location | URL Found | Action |
|----------|-----------|--------|
| `mobile/lib/core/config/api_config.dart` line 3 | `http://10.254.103.195:8000` (as `hotspotUrl`) | **Retained** — intentional alternate dev endpoint |
| `mobile/lib/auth/screens/login_screen.dart` line 803 | `10.254.103.195` label in quick-select chip | **Retained** — user-facing hotspot quick-select button |
| Backend / Python code | None found | N/A |

---

*Report generated: 2026-09-28 by Antigravity AI. No commits made. No data deleted in this session.*
