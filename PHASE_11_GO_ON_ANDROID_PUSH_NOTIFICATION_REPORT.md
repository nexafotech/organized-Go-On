# Phase 11 — Go-On Android Push Notification + Heads-Up Popup System & Role-Specific Next-Class Reminder Engine Report

**Product Name:** Go-On  
**Target Repository:** `C:\Users\Abishek\Desktop\am-oss`  
**Git Branch:** `feat/phase-11-push-notifications`  
**Execution Date:** 2026-10-09  

---

## 1. Executive Summary

Phase 11 implements a production-grade Android push notification system and an automated, role-specific next-class reminder engine for Go-On. Built with a real Android system notification architecture using Firebase Cloud Messaging (FCM) on the backend and Flutter (`firebase_messaging` + `flutter_local_notifications`), Go-On delivers high-importance heads-up banners across foreground, background, and terminated application states.

All notifications feature the official Go-On monochrome white silhouette icon with alpha transparency across all standard Android display densities (`mdpi` to `xxxhdpi`), strictly eliminating all default Flutter icons.

Furthermore, Phase 11 incorporates an authoritative, idempotent background scheduler that monitors classroom schedules in the `Asia/Kolkata` timezone, safely filtering out Morning Breaks and Lunch breaks, and dispatching timely class reminders with independent lead times for students and faculty. Administrators are equipped with an in-app Notification Center featuring an audience-targeted broadcast composer with live template variables (`{{subject}}`, `{{class_name}}`, `{{name}}`, `{{period}}`, `{{date}}`) and comprehensive delivery audit logs.

All existing biometric authentication, face recognition pipelines, retrospective attendance marking, and Flutter Web compatibility remain 100% intact with zero regressions.

---

## 2. Push Notification Architecture

Go-On enforces strict backend-driven notification delivery. Mobile clients cannot arbitrarily broadcast messages to other users.

```
+-----------------------------------------------------------------------------------------+
|                                    BACKEND (FastAPI)                                    |
|                                                                                         |
|  +---------------------------+       +-----------------------------------------------+  |
|  | Periodic Background Loop  |       | Admin Composer Endpoint                       |  |
|  | (Asia/Kolkata, 60s tick)  |       | (POST /api/v1/admin/notifications/send)       |  |
|  +-------------+-------------+       +-----------------------+-----------------------+  |
|                |                                             |                          |
|                v                                             v                          |
|  +-----------------------------------------------------------------------------------+  |
|  | NotificationService & NotificationLog                                             |  |
|  | - Timetable schedule evaluation       - Break/lunch exclusion                     |  |
|  | - Independent lead-time calculation   - Strict idempotency & deduplication check  |  |
|  +-------------------------------------------+---------------------------------------+  |
|                                              |                                          |
|                                              v                                          |
|  +-----------------------------------------------------------------------------------+  |
|  | FCMService (Firebase Admin SDK / Mock Fallback for Dev)                           |  |
|  | - Resolves active DeviceTokens        - Dispatches multicast message payload      |  |
|  | - Unregisters stale/unregistered tokens automatically                             |  |
|  +-------------------------------------------+---------------------------------------+  |
+----------------------------------------------|------------------------------------------+
                                               |
                                               v
                          +------------------------------------------+
                          |      Firebase Cloud Messaging (FCM)      |
                          +--------------------+---------------------+
                                               |
                                               v
+-----------------------------------------------------------------------------------------+
|                                  ANDROID DEVICE (Flutter)                               |
|                                                                                         |
|  +-----------------------------------------------------------------------------------+  |
|  | FirebaseMessagingService Background & Foreground Handlers                         |  |
|  |                                                                                   |  |
|  | [Foreground] ----> flutter_local_notifications ----> High-Importance Heads-Up Popup|  |
|  | [Background] ----> Android Notification Tray   ----> Heads-Up Banner               |  |
|  | [Terminated] ----> System Notification Click   ----> Cold Start Deep Linking       |  |
|  +-----------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------+
```

---

## 3. High-Importance Notification Channels

To ensure critical updates alert students and faculty immediately, Android notification channels were established with `Importance.max` and `Priority.high`.

| Channel ID | Channel Name | Importance | Heads-Up Enabled | Sound / Vibration | Purpose |
|---|---|---|---|---|---|
| `GO_ON_NEXT_CLASS` | Next Class Reminders | High / Max | Yes | Yes (Double Pulse) | Upcoming lecture reminders for students & teaching reminders for faculty |
| `GO_ON_ATTENDANCE` | Attendance Updates | High / Max | Yes | Yes | Live face-recognition attendance confirmations and manual marks |
| `GO_ON_ADMIN` | Campus Announcements | High / Max | Yes | Yes | Critical institutional alerts and broadcast bulletins from administrators |
| `GO_ON_ACCOUNT` | Account & Security | Default | No | Default | Password reset alerts, new session detections |
| `GO_ON_GENERAL` | General Updates | Default | No | Default | Informational notices |

---

## 4. Official Go-On Monochrome Notification Icon

In strict compliance with Google Android Notification Design Guidelines, the notification small icon must be a pure white silhouette on a transparent background. Colored or boxed icons result in an illegible solid white square on Android 12+.

The official Go-On logo (`go_on_logo.png`) was processed to generate crisp, anti-aliased white silhouettes matching Android standard icon density metrics:

| Density Variant | File Path | Resolution | Color Specification |
|---|---|---|---|
| Default | `mobile/android/app/src/main/res/drawable/ic_notification.png` | 96 x 96 px | `#FFFFFF` Alpha Silhouette |
| MDPI (1x) | `mobile/android/app/src/main/res/drawable-mdpi/ic_notification.png` | 24 x 24 px | `#FFFFFF` Alpha Silhouette |
| HDPI (1.5x) | `mobile/android/app/src/main/res/drawable-hdpi/ic_notification.png` | 36 x 36 px | `#FFFFFF` Alpha Silhouette |
| XHDPI (2x) | `mobile/android/app/src/main/res/drawable-xhdpi/ic_notification.png` | 48 x 48 px | `#FFFFFF` Alpha Silhouette |
| XXHDPI (3x) | `mobile/android/app/src/main/res/drawable-xxhdpi/ic_notification.png` | 72 x 72 px | `#FFFFFF` Alpha Silhouette |
| XXXHDPI (4x) | `mobile/android/app/src/main/res/drawable-xxxhdpi/ic_notification.png` | 96 x 96 px | `#FFFFFF` Alpha Silhouette |

### Manifest & Color Metadata:
- **Small Icon Meta-Data:** `com.google.firebase.messaging.default_notification_icon` set to `@drawable/ic_notification`.
- **Accent Color Meta-Data:** `com.google.firebase.messaging.default_notification_color` configured to `@color/notification_color` (`#4B2E1E`, approved Espresso Brand accent).
- **Permissions:** `android.permission.POST_NOTIFICATIONS` declared for Android 13+ (API 33+) dynamic permission prompt.

---

## 5. Automatic Role-Specific Next-Class Reminder Engine

### 5.1 Independent Lead-Time Configuration
Students and faculty have distinct scheduling workflows. Administrators can independently configure reminder lead times stored in the `system_settings` table:

- `student_class_reminder_lead_minutes` (Default: **10 minutes**)
- `faculty_class_reminder_lead_minutes` (Default: **15 minutes**)

### 5.2 Authoritative Timetable Source of Truth
The engine queries active timetable schedules mapped to students and faculty for the current weekday (`Asia/Kolkata`). Teaching periods are strictly defined:
- **P1:** `09:10 - 10:00`
- **P2:** `10:00 - 10:50`
- **P3:** `11:10 - 12:00`
- **P4:** `12:00 - 12:50`
- **P5:** `13:40 - 14:30`
- **P6:** `14:30 - 15:20`
- **P7:** `15:20 - 16:10`

### 5.3 Morning Break & Lunch Period Exclusion Mechanics
The engine enforces programmatic filtering for recess intervals:
- **Morning Break:** `10:50 - 11:10`
- **Lunch Break:** `12:50 - 13:40`
Any schedule entries or gaps containing "break", "lunch", "recess", "interval", or matching these non-teaching times are automatically ignored.

### 5.4 User-Friendly 12-Hour Presentation
Timetable start and end times (e.g. `09:10` and `10:00`) are converted into human-friendly 12-hour timestamps with AM/PM indicators (e.g. `09:10 AM - 10:00 AM`).

- **Student Notification Message:**  
  `Next Class Reminder: Data Structures at 11:10 AM - 12:00 PM in Room LH-101 with Prof. Dr. Ramanujan`
- **Faculty Notification Message:**  
  `Teaching Reminder: Data Structures for CSE-A at 11:10 AM - 12:00 PM in Room LH-101`

### 5.5 Idempotent Delivery & Deduplication
To prevent duplicate alerts when the 60-second background loop ticks repeatedly across a reminder window:
- The database schema includes a compound uniqueness index:  
  `ix_notif_log_idempotency` ON `notification_logs (user_id, scheduled_date, period_id, reminder_type)`.
- Prior to sending, `check_and_reserve_idempotency()` performs an atomic check. If a log exists for that user, date, and period, dispatch is safely bypassed.

---

## 6. Custom Admin Notification Composer & Audience Targeting

Administrators access a dedicated **Notification Center** directly from the Go-On Admin screen AppBar (`mobile/lib/admin/screens/admin_notification_screen.dart`).

### Features:
1. **Audience Targeting Options:**
   - `ALL_STUDENTS`: Dispatches to all enrolled student devices.
   - `ALL_FACULTY`: Dispatches to all registered faculty devices.
   - `SPECIFIC_CLASS`: Targets all students belonging to an academic section (e.g., `CSE-A`).
   - `SPECIFIC_USER`: Targets an individual student or faculty member by ID.
2. **Safe Dynamic Template Variables:**
   - Supported variables: `{{subject}}`, `{{class_name}}`, `{{name}}`, `{{period}}`, `{{date}}`.
   - Dynamic chips in the Flutter UI allow administrators to insert variables with a single tap.
3. **Channel Selection:**
   - Admins can designate the priority channel (`GO_ON_ADMIN`, `GO_ON_ATTENDANCE`, `GO_ON_GENERAL`).
4. **Deep Linking Directives:**
   - Configurable route destinations: `student_timetable`, `faculty_attendance`, `reports`, `profile`.
5. **Real-Time Audit Logs:**
   - Tab 3 displays audit logs showing recipient, title, payload, channel, delivery status (`DELIVERED`, `FAILED`, `PENDING`), and timestamp.

---

## 7. Security, Token Lifecycle & RBAC Protection

1. **Authentication Guard:** Only authenticated users can register their FCM tokens via `POST /api/v1/notifications/device-token`.
2. **Clean Logout Lifecycle:** Calling `authService.logout()` invokes `DELETE /api/v1/notifications/device-token`, deactivating the token so subsequent notifications are not delivered to a signed-out device.
3. **Invalid Token Cleanup:** FCM errors indicating expired or unregistered tokens (`registration-token-not-registered`, `invalid-registration-token`) trigger automatic deactivation (`is_active = False`) in the database.
4. **Role-Based Access Control:** All admin notification management endpoints (`/api/v1/admin/notifications/*`) require valid Admin credentials verified by `require_admin`. Students and faculty attempting to access admin notification endpoints receive `403 Forbidden`.

---

## 8. Verification & Test Results

### 8.1 Automated Backend Notification Test Suite
The dedicated test suite `tests/test_phase11_notifications.py` executed across 8 comprehensive scenarios:

```text
============================= test session starts =============================
platform win32 -- Python 3.13.15, pytest-9.1.1, pluggy-1.6.0
rootdir: C:\Users\Abishek\Desktop\am-oss, configfile: pytest.ini
collected 8 items

tests/test_phase11_notifications.py::test_time_formatting_and_break_detection PASSED [ 12%]
tests/test_phase11_notifications.py::test_template_substitution PASSED   [ 25%]
tests/test_phase11_notifications.py::test_notification_settings_independence PASSED [ 37%]
tests/test_phase11_notifications.py::test_device_token_lifecycle PASSED  [ 50%]
tests/test_phase11_notifications.py::test_student_next_class_finder_and_deduplication PASSED [ 62%]
tests/test_phase11_notifications.py::test_custom_admin_notification_targeting_and_audit PASSED [ 75%]
tests/test_phase11_notifications.py::test_faculty_next_class_finder_and_deduplication PASSED [ 87%]
tests/test_phase11_notifications.py::test_api_endpoints_and_rbac PASSED  [100%]

======================== 8 passed in 163.91s (0:02:43) ========================
```

### 8.2 Flutter Client Static Analysis & Unit Tests
- `flutter analyze`: **0 issues found** across all mobile source files.
- `flutter test`: `notification_service_test.dart` and `go_on_branding_test.dart` **100% PASSED**.

### 8.3 Android Gradle & Desugaring Integration
- Integrated `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` into `mobile/android/app/build.gradle.kts`.
- Enabled `isCoreLibraryDesugaringEnabled = true` to support modern Java time and stream APIs required by `flutter_local_notifications`.

---

## 9. Modified and Created Files

### Backend:
- `app/models/notification.py`: Schema definitions for `DeviceToken`, `NotificationLog`, and notification enums.
- `app/schemas/notification.py`: Pydantic schemas for token registration, admin settings, and custom broadcast payloads.
- `app/services/fcm_service.py`: Firebase Admin SDK dispatch engine with mock fallback and token invalidation.
- `app/services/notification_service.py`: Next-class timetable resolution, break filtering, lead-time matching, and audience-targeted broadcasts.
- `app/api/notifications.py`: Public and Admin REST API endpoints.
- `app/api/__init__.py`: Router registration.
- `app/main.py`: Lifespan background scheduler loop (`Asia/Kolkata` 60s periodic evaluator).
- `tests/test_phase11_notifications.py`: Automated pytest test suite (8 test cases).

### Mobile App:
- `mobile/pubspec.yaml`: Added `flutter_local_notifications: ^22.3.1`, `firebase_core: ^4.15.0`, `firebase_messaging: ^16.7.0`.
- `mobile/android/app/build.gradle.kts`: Configured Google Services plugin, JDK 17, and core library desugaring.
- `mobile/android/settings.gradle.kts`: Google Services plugin declaration.
- `mobile/android/app/google-services.json`: Configured Firebase project credentials for `com.aifaceattendance.mobile_app`.
- `mobile/android/app/src/main/AndroidManifest.xml`: Added notification permission and icon metadata.
- `mobile/android/app/src/main/res/drawable*/ic_notification.png`: Official Go-On white silhouette notification icons (all densities).
- `mobile/lib/services/notification_service.dart`: Client-side notification service (FCM token management, high-importance heads-up channel setup, foreground presentation, deep link routing).
- `mobile/lib/admin/screens/admin_notification_screen.dart`: Complete Admin Notification Center UI (Reminders & Settings, Broadcast Composer, Audit Logs).
- `mobile/lib/admin/screens/admin_student_face_screen.dart`: Added Notification Center icon button to AppBar.
- `mobile/lib/services/auth_service.dart`: Integrated token registration on login/session restore and unregistration on logout.
- `mobile/lib/main.dart`: Initialized `NotificationService` and wired global `appNavigatorKey`.
- `mobile/test/notification_service_test.dart`: Unit tests for token registration and payload handling.
