# go-On — Attendance Percentage Calculation & Notification System Fix Report

**Report Date:** October 20, 2026  
**Project Root:** `E:\originalam`  
**Mobile App:** `E:\originalam\mobile`  
**Status:** **RESOLVED & CERTIFIED (100% Tests Passing, Clean Static Analysis, APK Built)**

---

## Executive Summary

This engineering effort resolved two critical defects in the **go-On** attendance system:

1. **Issue 1: Overall attendance graph exceeded 100% (e.g. 107.7%) due to double-counting On-Duty (OD):**
   - Under the project's official academic policy (`od_calculation_mode == 'COUNT_AS_PRESENT'`), OD credit is awarded by counting OD into `present`.
   - When the breakdown pills and graph rings displayed Present ($10/13 = 76.9\%$), Absent ($3/13 = 23.1\%$), and OD ($1/13 = 7.7\%$), OD was counted twice, resulting in an impossible total of $107.7\%$ and $14/13$ classes.
   - **Resolution:** Introduced `pure_present` in policy engine calculations and Flutter models (`StudentSummaryModel` and `SubjectAttendanceModel`). The graph rings and legend pills now display mutually exclusive categories ($9/13 = 69.2\%$ Physical Present, $3/13 = 23.1\%$ Absent, $1/13 = 7.7\%$ OD) summing strictly to **$100.0\%$** ($13/13$ classes), while the center puck accurately reflects the student's official attendance credit ($76.9\%$ ATTENDANCE).

2. **Issue 2: Missing Attendance Notifications for Students:**
   - Although notification channels (`GO_ON_ATTENDANCE`) and database models (`NotificationLog`) were present in the codebase, attendance submission endpoints (`submit_faculty_attendance`, `submit_class_advisor_attendance`, and `admin_correct_attendance`) never triggered notifications.
   - **Resolution:** Implemented `NotificationService.send_attendance_marking_notifications`, wired it directly to faculty and class advisor submission handlers, created FCM push delivery with `GO_ON_ATTENDANCE` channel, recorded in-app `NotificationLog` entries, and updated Flutter deep-linking to route tapped attendance notifications straight to the student attendance report screen.

---

## Root Cause Analysis

### Issue 1: Percentage Calculation & Graph Double Counting

| Metric | Previous Implementation (Buggy) | New Implementation (Mathematically Valid) |
|---|---|---|
| **Present Count & Percentage** | `present = 10` ($10/13 = 76.9\%$) [includes 1 OD] | `purePresent = 9` ($9/13 = 69.2\%$) [mutually exclusive physical present] |
| **Absent Count & Percentage** | `absent = 3` ($3/13 = 23.1\%$) | `absent = 3` ($3/13 = 23.1\%$) |
| **On-Duty Count & Percentage** | `od = 1` ($1/13 = 7.7\%$) | `od = 1` ($1/13 = 7.7\%$) |
| **Breakdown Sum** | **$76.9\% + 23.1\% + 7.7\% = 107.7\%$** (14 / 13) | **$69.2\% + 23.1\% + 7.7\% = 100.0\%$** (13 / 13) |
| **Center Puck Display** | Bound to `presentPct` ($76.9\%$) | Bound to `summary.percentage` ($76.9\%$ ATTENDANCE) |

### Issue 2: Missing Attendance Notification Triggers

- `NotificationType.ATTENDANCE` and `NotificationChannel.GO_ON_ATTENDANCE` existed in `app/models/notification.py`.
- `SystemSetting("notification.attendance_status_enabled")` was configured as `true`.
- **Defect:** No dispatch method existed in `NotificationService`, and no calls to send notifications were made inside `app/engines/attendance_engine.py` during attendance submission.

---

## Key Changes Made

### 1. Backend Engine & Schemas

- **`app/engines/policy_engine.py`:**
  - Updated `_status_counts` to compute `pure_present = max(0, present - od)` when `policy.od_calculation_mode == "COUNT_AS_PRESENT"`.
  - Enriched `calculate_student_attendance`, `calculate_period_attendance`, and `calculate_subject_attendance` with `pure_present`.
- **`app/schemas/student_auth.py`:**
  - Added `pure_present: Optional[int] = None` to `StudentMeOut`, `StudentAttendanceReport`, `SubjectAttendanceRow`, and `PeriodAttendanceRow`.
- **`app/api/student.py`:**
  - Passed `pure_present` in `/student/me`, `/student/attendance`, and `/student/attendance/subjects`.
- **`app/services/notification_service.py`:**
  - Added `NotificationService.send_attendance_marking_notifications(db, session_id, records_data)`:
    - Verifies `notification.attendance_status_enabled`.
    - Dispatches FCM push notifications for `PRESENT`, `ABSENT`, and `OD` statuses.
    - Idempotently creates or updates `NotificationLog` inbox records with `channel_id="GO_ON_ATTENDANCE"`.
    - Resets `is_read = False` if an attendance record is corrected by faculty or class advisor.
- **`app/engines/attendance_engine.py`:**
  - Wired `NotificationService.send_attendance_marking_notifications` into:
    - `submit_faculty_attendance`
    - `submit_class_advisor_attendance`
    - `admin_correct_attendance`

### 2. Flutter Mobile Application

- **`mobile/lib/models/student_model.dart`:**
  - Added `purePresent` field and `purePresentCount` getter to `StudentSummaryModel` and `SubjectAttendanceModel`.
  - Added backward-compatible fallback: `(present - od).clamp(0, total)` if `purePresent` is omitted.
- **`mobile/lib/widgets/attendance/interactive_attendance_overview_card.dart`:**
  - Updated ring drawing and legend pills to use `purePresentCount` (`purePresent / total * 100.0`), guaranteeing all rings and legend pills sum strictly to $100.0\%$.
  - Updated center floating frosted glass puck to display `summary.percentage` ($76.9\%$ ATTENDANCE).
- **`mobile/lib/widgets/attendance/attendance_summary_card.dart`:**
  - Added `purePresent` and `displayPresent` getter.
  - Fixed attended counter text from `${present + od}` to `${displayPresent + od} / $total attended` (avoiding 11/13 attended).
  - Updated Present stat box to show `displayPresent`.
- **`mobile/lib/student/screens/student_attendance_report_screen.dart`:**
  - Passed `purePresent: summary.purePresentCount` to `AttendanceSummaryCard`.
- **`mobile/lib/services/notification_service.dart`:**
  - Imported `student_attendance_report_screen.dart`.
  - Added route handlers for `student_attendance` and `attendance` to navigate directly to `StudentAttendanceReportScreen`.

---

## Verification & Testing

### Backend Unit & Integration Tests (`pytest`)
- `tests/test_attendance_calculation_and_notifications.py`: **2 passed in 2.69s**
- `tests/test_fcm_and_scheduled_notifications.py`: **20 passed in 9.06s**
- `tests/test_policy_and_settings_calculation_mode.py`: **13 passed in 6.68s**
- `tests/test_notification_bulk_delete.py`, `test_notification_delete_pin_audit.py`, `test_notification_timestamps.py`, `test_push_delivery_and_system_tray.py`: **22 passed in 5.96s**
- **Total Backend Tests Passing:** **57 / 57 passed (100%)**

### Flutter Unit & Widget Tests (`flutter test`)
- `test/interactive_attendance_overview_card_test.dart`: **4 passed** (verifies $100.0\%$ sum, mutually exclusive breakdown, and center puck accuracy).
- Flutter test suite (petal chart, legend, notifications, dashboard): **39 / 39 passed**.
- `flutter analyze`: **0 issues found** across all modified files.

### Production Android Build
- Successfully assembled and verified debug APK: `E:\originalam\app-debug.apk` (186 MB).

---

## Artifacts Generated

1. `reports/go-On_Attendance_Calculation_and_Notification_Fix_Report.pdf`
2. `reports/go-On_Attendance_Calculation_and_Notification_Fix_Report.md`
3. `tests/test_attendance_calculation_and_notifications.py`
4. `app-debug.apk`
