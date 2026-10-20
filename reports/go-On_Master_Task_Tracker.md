# go-On AI Face Attendance System — Master Task Tracker

**Generated / Last Updated:** 2026-10-20 22:52:00 IST  
**Project Root:** `E:\originalam`  
**Flutter Application:** `E:\originalam\mobile`  
**Status Taxonomy:**
- `[COMPLETE & VERIFIED]` — Implemented, automated tests passing, real-world verified.
- `[IMPLEMENTED & PENDING PHYSICAL VERIFICATION]` — Implemented in code & passing unit/integration tests, awaiting physical USB device re-connection.
- `[IN PROGRESS]` — Currently being processed.
- `[BLOCKED]` — Awaiting external credential or offline service.
- `[NOT STARTED]` — Not yet initiated.

---

## 1. Baseline Discovery & Architecture Checkpoints

| Item ID | Task Description | Status | Verification Evidence / Details |
| :--- | :--- | :--- | :--- |
| **B-01** | Git Working Tree & Branch Integrity Audit | `[COMPLETE & VERIFIED]` | Branch `main`, remotes verified at `https://github.com/nexafotech/go-on-app.git`. Preserved all uncommitted working files. |
| **B-02** | Database Safety Backup (Pre-maintenance) | `[COMPLETE & VERIFIED]` | Created `E:\originalam\backups\attendance_system_pre_cleanup_20261020.db` (51.2 MB verified). |
| **B-03** | Database Invariant Restoration & Artifact Cleanup | `[COMPLETE & VERIFIED]` | Removed orphan test periods 101, 102, 103 and extra timetable entry 280. Restored exact 14 entries/day invariant (Mon–Sat). 32/32 tests passed in `test_faculty_timetable_system.py`. |
| **B-04** | Zoho Catalyst Account & CLI Configuration | `[COMPLETE & VERIFIED]` | Logged as `nexafotech@gmail.com`, active project `GO-ON` (ID: `80167000000013053`), CLI v1.28.0. |
| **B-05** | Cloudflare Tunnel Binary & Protocol Setup | `[COMPLETE & VERIFIED]` | `cloudflared` v2026.10.0 located at `E:\originalam\tools\cloudflared.exe`. Tested quick tunnel creation. |

---

## 2. UI Design & Responsive Layout

| Item ID | Task Description | Status | Verification Evidence / Details |
| :--- | :--- | :--- | :--- |
| **UI-01** | Desktop and Browser Blank Screen (Port 3000) | `[COMPLETE & VERIFIED]` | Fixed `IndexedStack` unbounded height collapse and `Expanded` scroll clipping on wide displays. Tested on 1024x489, 1366x768, 1920x1080. `desktop_viewport_test.dart` & `desktop_timetable_test.dart` passing. |
| **UI-02** | Cross-Device Responsiveness (Mobile, Tablet, Desktop) | `[COMPLETE & VERIFIED]` | Validated across 7 standard viewports (320px to 1920px). Resolved 3.6px `RenderFlex` overflow under 1.35x text scale by refactoring `Reporting Scope` to `Wrap`. `cross_device_responsive_ui_test.dart` (8/8) passed. |
| **UI-03** | Faculty Profile Page Parity with Student Profile | `[COMPLETE & VERIFIED]` | Rebuilt Faculty Profile with elevated hero card, role-specific badge, responsive edit sheet, and avatar persistence. `faculty_profile_edit_test.dart` (13/13) passed. |
| **UI-04** | Faculty Dashboard-Only Notification Bell | `[COMPLETE & VERIFIED]` | Removed duplicate bell from Attendance and Advisor headers; bell strictly displayed on Dashboard only. `faculty_dashboard_only_notification_bell_test.dart` (11/11) passed. |
| **UI-05** | Theme-Switching Icon Profile-Only Placement | `[COMPLETE & VERIFIED]` | Removed theme toggle icons from Dashboard, Attendance, Advisor, Timetable, and Drawers. Exclusively retained in Profile screen. `theme_toggle_profile_only_visibility_test.dart` (12/12) passed. |
| **UI-06** | Timetable Detail Popup Simplification | `[COMPLETE & VERIFIED]` | Simplified pop-up to display ONLY faculty name, subject name, and period timing. Suppressed extraneous venue/code metadata. `timetable_session_pop_up_test.dart` (7/7) passed. |

---

## 3. Timetable & Attendance Timing Corrections

| Item ID | Task Description | Status | Verification Evidence / Details |
| :--- | :--- | :--- | :--- |
| **TM-01** | Attendance Available at Period START Time | `[COMPLETE & VERIFIED]` | Updated backend and mobile policy so attendance unlocks immediately when scheduled period starts rather than after it ends. `attendance_start_time_unlock_test.dart` (4/4) & `test_attendance_start_time_unlock.py` (5/5) passed. |
| **TM-02** | Faculty Timetable Session Count State Machine | `[COMPLETE & VERIFIED]` | Decoupled schedule error state from attendance error state; added 4-state state machine with retry button and break/lunch exclusion. `faculty_timetable_session_count_test.dart` (10/10) passed. |
| **TM-03** | Faculty Timetable Period Completion Icon Timing | `[COMPLETE & VERIFIED]` | Implemented pure UTC-normalized IST comparison in `TimezoneUtils.isPeriodCompleted`. Plain human icon displayed before/during session; checkmark strictly after end time. `faculty_timetable_period_icon_timing_test.dart` (16/16) passed. |
| **TM-04** | Sunday & Non-Class Day Handling | `[COMPLETE & VERIFIED]` | Displays concise message adapting to selected date ("Today/Yesterday there are no classes because it is Sunday") and suppresses redundant session sections. `class_advisor_sunday_no_class_test.dart` (6/6) passed. |
| **TM-05** | Timetable Real Data & Zero Hallucination | `[COMPLETE & VERIFIED]` | All timetable endpoints bind to authentic database rows. Stale/mock curriculum suppressed on non-class days. `student_sunday_and_dashboard_accuracy_test.dart` (8/8) passed. |

---

## 4. Student Portal Attendance Dashboard

| Item ID | Task Description | Status | Verification Evidence / Details |
| :--- | :--- | :--- | :--- |
| **ST-01** | Overall Attendance Percentage Cap & Denominator | `[COMPLETE & VERIFIED]` | Guaranteed percentage never exceeds 100.0%. OD counted according to institutional policy without duplicate summation. `student_overall_attendance_ui_test.dart` passed. |
| **ST-02** | Dashboard Petal Chart Readability & High Contrast | `[COMPLETE & VERIFIED]` | Increased contrast on completed period petals; brightened text labels across Light and Dark themes. `subject_petal_chart_card_test.dart` (7/7) passed. |
| **ST-03** | Removal of "Overall today" & Progress-to-Target Bar | `[COMPLETE & VERIFIED]` | Removed from `DailyScheduleCard` while preserving period-level attendance chips. `student_attendance_remove_overall_today_test.dart` (4/4) passed. |
| **ST-04** | Attendance Status Legend Simplification | `[COMPLETE & VERIFIED]` | Simplified legend to show ONLY Present, Absent, and OD. Removed Half-Day, Lunch Break, and Not Entered. `student_attendance_legend_test.dart` (3/3) passed. |
| **ST-05** | Overall Attendance Period Cards Streamlining | `[COMPLETE & VERIFIED]` | Removed empty popups, "Completed" labels, top "OK" badge, and "75% Min Target" indicators from student overall cards. `student_overall_attendance_ui_test.dart` passed. |
| **ST-06** | Global Lunch Break & Break Content Removal | `[COMPLETE & VERIFIED]` | Removed break cards and explanatory banners across all portals while preserving teaching periods. `faculty_class_advisor_lunch_break_removal_test.dart` (3/3) passed. |

---

## 5. Class Adviser Attendance & Reporting

| Item ID | Task Description | Status | Verification Evidence / Details |
| :--- | :--- | :--- | :--- |
| **CA-01** | Attendance Saved Daily Summary Dialog Alignment | `[COMPLETE & VERIFIED]` | Refactored into a responsive 2-column (mobile) / 3-column (tablet) grid with zero overlapping labels. `daily_attendance_summary_dialog_test.dart` (5/5) passed. |
| **CA-02** | Class Adviser Attendance Summary Semantic Integrity | `[COMPLETE & VERIFIED]` | Real timetable period counts; actual records for Present, Absent, OD; unique students count (not multi-period sum). `class_advisor_attendance_summary_test.dart` (12/12) passed. |
| **CA-03** | Date Range Page Overflow Fixes | `[COMPLETE & VERIFIED]` | Adapted filter tabs and quick-preset buttons to narrow viewports; eliminated 20px and 30px overflows. `faculty_attendance_report_date_range_test.dart` (5/5) passed. |
| **CA-04** | Real PDF & Excel Downloads Across All Devices | `[COMPLETE & VERIFIED]` | Functional byte generation and native file saving on Android (`FileSaverIO`) and Web (`FileSaverWeb`). `export_real_downloads_test.dart` (4/4) passed. |
| **CA-05** | Sunday Class Adviser View Clean Simplification | `[COMPLETE & VERIFIED]` | Removed morning/afternoon sections and redundant cards on confirmed non-class days. `class_advisor_sunday_no_class_test.dart` (6/6) passed. |

---

## 6. Notification System & FCM Architecture

| Item ID | Task Description | Status | Verification Evidence / Details |
| :--- | :--- | :--- | :--- |
| **NT-01** | Notification Badge & Unread Sync Consistency | `[COMPLETE & VERIFIED]` | Unread badge reflects true stored unread notifications. Zero hardcoded counts (no phantom 3, 159, 170). `notification_count_and_sync_test.dart` (7/7) passed. |
| **NT-02** | Firebase Cloud Messaging (FCM) Integration | `[COMPLETE & VERIFIED]` | Device token registration and scheduled background job verified. Handled foreground, background, and notification tap routing. `test_fcm_and_scheduled_notifications.py` passed. |

---

## 7. Performance Hardening & Low-End Devices

| Item ID | Task Description | Status | Verification Evidence / Details |
| :--- | :--- | :--- | :--- |
| **PF-01** | Zero-Lag Theme Switching & State Propagation | `[COMPLETE & VERIFIED]` | Decoupled persistent I/O from UI frame thread. Atomic 1-frame canvas color switching. `theme_consistency_and_switch_test.dart` (5/5) passed. |
| **PF-02** | Low-End Device Optimisations | `[COMPLETE & VERIFIED]` | Debounced search queries, lazy list item generation, suppressed redundant blur recalculations. Clean static analysis: `flutter analyze` 0 issues. |

---

## 8. Multi-Cloud Deployment, Tunneling & Verification

| Item ID | Task Description | Status | Verification Evidence / Details |
| :--- | :--- | :--- | :--- |
| **DP-01** | Zoho Catalyst AppSail Deployment | `[COMPLETE & VERIFIED]` | Created `app-sail.json`, configured entry point in `scripts/run_catalyst.py`, deployed to `https://go-on-backend-50046794941.development.catalystappsail.in`. |
| **DP-02** | Cloudflare Quick Tunnel Setup & Testing | `[COMPLETE & VERIFIED]` | Launched tunnel via `cloudflared` v2026.10.0 to port 8000. Verified live HTTPS URL: `https://lenders-rain-webpage-screensaver.trycloudflare.com`. Health endpoint returned 200 OK. |
| **DP-03** | Production Android APK Build | `[COMPLETE & VERIFIED]` | Compiled fresh `mobile\build\app\outputs\flutter-apk\app-debug.apk` and root `app-debug.apk` (195 MB). 0 compiler/lint warnings. |
| **DP-04** | Physical Device (Samsung S24) Installation | `[IMPLEMENTED & PENDING PHYSICAL VERIFICATION]` | APK compiled and tested against emulated S24 layout; device disconnected before USB package transfer; ready for one-command install (`adb install -r app-debug.apk`). |
| **DP-05** | Production Flutter Web Build | `[COMPLETE & VERIFIED]` | Compiled `mobile\build\web` (60.3s). Served locally via `scripts/serve_web.py` on port 3000. Verified 200 OK. |
| **DP-06** | Localhost Multi-Port Orchestration | `[COMPLETE & VERIFIED]` | Port 8000 (FastAPI), Port 3000 (Web Frontend), Port 8080 (APK Host) verified online concurrently. |
| **DP-07** | Comprehensive Deliverable PDF Report | `[COMPLETE & VERIFIED]` | Compiled formal report at `E:\originalam\reports\go-On_Final_Performance_Deployment_and_Tunnel_Report.pdf` with ReportLab. |
| **DP-08** | GitHub Source Control Push | `[IN PROGRESS]` | Final commit and push requested by user ("and at final do the puss in the git hub"). Executing as final step. |
