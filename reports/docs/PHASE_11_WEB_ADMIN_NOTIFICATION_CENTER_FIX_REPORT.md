# Phase 11 — Web Admin Notification Center Fix Report

**Product Name:** Go-On  
**Target Repository:** `C:\Users\Abishek\Desktop\am-oss`  
**Git Branch:** `feat/phase-11-push-notifications`  
**Execution Date:** 2026-10-09  

---

## 1. Executive Summary & Root Cause Analysis

### 1.1 Problem Statement
The user reported that although the Phase 11 report stated that the Admin Notification Center had been implemented, no "Notifications" entry was present in the desktop Web Admin dashboard at `http://localhost:8000/admin`.

### 1.2 Root Cause
In the initial Phase 11 implementation:
1. The client-side Notification Center UI was created exclusively as a Flutter mobile screen (`mobile/lib/admin/screens/admin_notification_screen.dart`), intended for administrators accessing Go-On via the mobile client.
2. The FastAPI backend provided all required REST API endpoints (`/api/v1/admin/notifications/*`), models, and FCM delivery services.
3. However, no corresponding HTML view, CSS styles, sidebar navigation entry, or JavaScript controllers had been wired into the desktop Web Admin dashboard template (`app/templates/admin_panel.html` and `app/static/js/admin_app.js`).

### 1.3 Resolution Summary
1. Integrated a **Notifications** navigation item into the Web Admin sidebar with icon `<i class="fa-solid fa-bell"></i>`, seamlessly placed under "Policy & Settings".
2. Built a complete, dedicated Web Admin Notification Center view (`<section id="tab-notifications" class="tab-content">`) in `app/templates/admin_panel.html`.
3. Added genuine backend and frontend support for **Scheduled Notifications**:
   - Model `ScheduledNotification` in `app/models/notification.py`.
   - Automatic execution of due scheduled notifications in the 60-second background scheduler loop (`app/main.py`).
   - Management endpoints `GET /api/v1/admin/notifications/scheduled` and `DELETE /api/v1/admin/notifications/scheduled/{id}`.
4. Implemented full JavaScript controllers in `app/static/js/admin_app.js` using authenticated `apiFetch` (Bearer token) for reminder settings, manual triggers, broadcast composer, template quick-chips, delivery timing mode, and delivery audit logs.
5. Verified with 10/10 passing pytest tests, 0 Flutter analysis issues, and live verification on `http://localhost:8000/admin`.

---

## 2. Web Admin Notification Center Features Delivered

### 2.1 Overview Metric Cards
At the top of the Notifications tab, four real-time metric cards display key operational data:
- **Active Device Tokens:** Number of active user accounts with registered devices.
- **Student Reminders:** Indicates Active/Disabled state with configured lead time (e.g. `Active (10m)`).
- **Faculty Reminders:** Indicates Active/Disabled state with configured lead time (e.g. `Active (15m)`).
- **Total Dispatched Logs:** Live count of sent notifications.

### 2.2 Next-Class Reminder Engine Settings
Allows administrators to configure automated classroom reminders:
- **Student Next-Class Alerts:** Independent checkbox toggle + Lead Time dropdown (5, 10, 15, 20, 30, 45, 60 minutes).
- **Faculty Teaching Reminders:** Independent checkbox toggle + Lead Time dropdown (5, 10, 15, 20, 30, 45, 60 minutes).
- **Channel Toggles:** Live Attendance Marking notifications and Custom Campus Announcements.
- **Save Action:** Saves directly to `system_settings` via `PUT /api/v1/admin/notifications/settings`.
- **On-Demand Evaluator:** Includes an on-demand trigger (`triggerManualReminderCheck()`) allowing administrators to simulate reminder windows with an optional reference time (e.g. `09:00`) without waiting for the 60s background tick.

### 2.3 Custom Broadcast Notification Composer
Equipped with targeting, channel selection, dynamic variables, and timing:
- **Target Audience:** `STUDENT`, `FACULTY`, `ALL` (campus-wide).
- **Targeting Scope:**
  - `ALL` (broadcasts to all selected users).
  - `CLASS` (reveals a dynamic class selector dropdown loaded from `/api/v1/admin/classes`).
  - `USER` (reveals a specific user ID / roll number text input).
- **Priority Channels & Levels:**
  - `GO_ON_ADMIN`: High-Importance Heads-Up Popup banner.
  - `GO_ON_ATTENDANCE`, `GO_ON_NEXT_CLASS`, `GO_ON_GENERAL`.
  - Priority levels: `NORMAL` or `HIGH`.
- **In-App Deep Link Routes:** `dashboard`, `student_timetable`, `faculty_timetable`, `faculty_attendance`, `reports`, `profile`.
- **Dynamic Variable Quick-Insert Chips:** Single-click insertion of `{{name}}`, `{{subject}}`, `{{class_name}}`, `{{period}}`, and `{{date}}` into the cursor position.
- **Delivery Timing Options:**
  - **Send Immediately:** Dispatches to targeted users right away.
  - **Schedule for Later:** Reveals an HTML `<input type="datetime-local">` to schedule the broadcast for a future time in `Asia/Kolkata`.

### 2.4 Genuine Scheduled Broadcast Queue
- When scheduled for the future, notifications are recorded with status `PENDING` in the new `scheduled_notifications` table.
- The 60-second background scheduler loop in `app/main.py` invokes `NotificationService.process_due_scheduled_notifications(db)` to process and deliver due items.
- The Web Admin displays a dedicated "Pending Scheduled Broadcasts" table with the option to Cancel any pending item before delivery.

### 2.5 Delivery Audit Logs & History
- Table displaying: ID, Timestamp (`Asia/Kolkata`), Recipient User, Type & Channel, Title & Message, Status badge (`SENT`, `SCHEDULED`, `FAILED`, `SKIPPED`), and Payload Inspector button.
- Filterable by notification type (`ADMIN`, `NEXT_CLASS_STUDENT`, `NEXT_CLASS_FACULTY`, `ATTENDANCE`, `ACCOUNT`).
- "Data" action button launches a modal displaying the formatted JSON payload.

---

## 3. Architecture & Data Flow

```
                      +------------------------------------------+
                      |       Desktop Web Admin Dashboard        |
                      |        http://localhost:8000/admin       |
                      +--------------------+---------------------+
                                           |
                         Sidebar: [ Notifications ]
                                           |
                         +-----------------+-----------------+
                         |                                   |
                         v                                   v
          +-----------------------------+     +-----------------------------+
          | Reminder Settings & Trigger |     | Broadcast Composer Form     |
          |  (Student/Faculty toggles & |     |  (Audience, Variables,      |
          |   lead-time dropdowns)      |     |   Send-Now vs Scheduled)    |
          +--------------+--------------+     +--------------+--------------+
                         |                                   |
                         +-----------------+-----------------+
                                           |
                           apiFetch(Bearer Token in Header)
                                           |
                                           v
+-----------------------------------------------------------------------------------------+
|                                    BACKEND (FastAPI)                                    |
|                                                                                         |
|  GET/PUT /api/v1/admin/notifications/settings                                           |
|  POST    /api/v1/admin/notifications/send (immediate dispatch or schedule)              |
|  GET/DEL /api/v1/admin/notifications/scheduled (queue management)                       |
|  POST    /api/v1/admin/notifications/trigger-reminders (on-demand evaluator)            |
|  GET     /api/v1/admin/notifications/logs (audit logs)                                  |
|                                                                                         |
|  +-----------------------------------------------------------------------------------+  |
|  | Periodic Background Task (60s tick, Asia/Kolkata):                                |  |
|  | 1. NotificationService.process_due_scheduled_notifications(db)                    |  |
|  | 2. NotificationService.check_and_send_next_class_reminders(db)                      |  |
|  +-----------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------+
```

---

## 4. Verification & Automated Test Results

### 4.1 Pytest Suite Results
The full test suite (`tests/test_phase11_notifications.py`) was executed with 10 comprehensive tests covering unit logic, integration, Web Admin HTML presence, scheduled lifecycle, and RBAC security:

```text
============================= test session starts =============================
platform win32 -- Python 3.13.15, pytest-9.1.1, pluggy-1.6.0
rootdir: C:\Users\Abishek\Desktop\am-oss, configfile: pytest.ini
collected 10 items

tests/test_phase11_notifications.py::test_time_formatting_and_break_detection PASSED [ 10%]
tests/test_phase11_notifications.py::test_template_substitution PASSED   [ 20%]
tests/test_phase11_notifications.py::test_notification_settings_independence PASSED [ 30%]
tests/test_phase11_notifications.py::test_device_token_lifecycle PASSED  [ 40%]
tests/test_phase11_notifications.py::test_student_next_class_finder_and_deduplication PASSED [ 50%]
tests/test_phase11_notifications.py::test_custom_admin_notification_targeting_and_audit PASSED [ 60%]
tests/test_phase11_notifications.py::test_faculty_next_class_finder_and_deduplication PASSED [ 70%]
tests/test_phase11_notifications.py::test_api_endpoints_and_rbac PASSED  [ 80%]
tests/test_phase11_notifications.py::test_web_admin_notification_center_integration PASSED [ 90%]
tests/test_phase11_notifications.py::test_scheduled_notification_lifecycle_and_rbac PASSED [100%]

============================= 10 passed in 5.04s ==============================
```

### 4.2 Flutter Client Static Analysis & Unit Tests
- `flutter test test/notification_service_test.dart`: **100% PASSED** (All tests passed).
- `flutter analyze`: **0 issues found** across notification services and admin screens.

### 4.3 Live HTTP Server Verification
- Verified `GET http://localhost:8000/admin` returns HTTP 200 with `<a href="#notifications" class="menu-item" data-tab="notifications">` and `<section id="tab-notifications" class="tab-content">`.
- Live server reload confirmed with uvicorn reloader.

---

## 5. Summary of Files Changed

| File Path | Description of Changes |
|---|---|
| `app/templates/admin_panel.html` | Added "Notifications" sidebar menu link and comprehensive `<section id="tab-notifications">` containing metric cards, reminder configuration form, broadcast composer, scheduled queue, and audit logs table. |
| `app/static/css/admin_style.css` | Added styling for notification glow colors (`bg-purple-glow`, `bg-info-glow`), interactive variable chips, checkbox/radio alignment, and delivery status badges. |
| `app/static/js/admin_app.js` | Added tab routing (`switchTab`), event listeners, `loadNotificationsTab()`, settings loader/updater, manual evaluator trigger, broadcast dispatcher, scheduled queue manager, and delivery log viewer. |
| `app/models/notification.py` | Added `ScheduledNotification` database model with index on `scheduled_at`. |
| `app/models/__init__.py` | Exported `ScheduledNotification`. |
| `app/schemas/notification.py` | Added `ScheduledNotificationOut` Pydantic response schema. |
| `app/services/notification_service.py` | Factored out `_dispatch_notification_to_recipients`, updated `send_custom_admin_notification` to support future scheduling, and added `process_due_scheduled_notifications` and `cancel_scheduled_notification`. |
| `app/api/notifications.py` | Added `GET /api/v1/admin/notifications/scheduled` and `DELETE /api/v1/admin/notifications/scheduled/{schedule_id}`. |
| `app/main.py` | Updated periodic scheduler loop to process due scheduled notifications every 60s alongside timetable reminder checks. |
| `tests/test_phase11_notifications.py` | Added `test_web_admin_notification_center_integration` and `test_scheduled_notification_lifecycle_and_rbac`. |

---

## 6. Firebase & Production Deployment Notes

1. **Development / Local Environment:**
   - In the absence of a live Firebase Service Account JSON, the backend automatically uses `FCMService`'s simulated mock engine. It generates full delivery logs, evaluates recipient groups, validates tokens, and executes scheduled jobs with zero runtime errors.
2. **Production Firebase Activation:**
   - Place the official Firebase Service Account key at the path specified by `FIREBASE_CREDENTIALS_PATH` in `.env` (or environment variable).
   - Set `FIREBASE_ENABLED=True`.
   - `FCMService` will automatically detect the credential file, initialize the Firebase Admin SDK app, and deliver real Android push notifications via Firebase Cloud Messaging.
