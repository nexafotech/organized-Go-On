# Go-On — Clean Android Reinstall & Phase 11 Verification Report

**Date:** 2026-10-09  
**Repository:** `C:\Users\Abishek\Desktop\am-oss`  
**Git Branch:** `feat/phase-11-push-notifications`  
**Latest Commit:** `4b631c9 fix(admin-web): integrate Phase 11 Notification Center into desktop Admin web dashboard with scheduled broadcast support`  
**Target Device:** Physical Phone (`FY6PHIEA69AMQ8HU` — Realme `RMX3998`, Android 14)

---

## 1. Executive Summary

A clean uninstall and fresh release build reinstall of the **Go-On** Android application was successfully performed on the connected physical device (`FY6PHIEA69AMQ8HU`). All preflight safety checks, automated Flutter static analysis, unit test suites, release APK packaging, signature verification, and device-level runtime checks passed with zero errors.

The app launched cleanly into the official **Go-On** login screen with official branding, active server connectivity, and verified high-importance Android notification channels for heads-up alerts. As strictly required, no automated logins were executed, preserving the login screen for manual user access.

---

## 2. Preflight Safety & Environment Audit

1. **Git State Preservation:**
   - Active branch: `feat/phase-11-push-notifications`
   - All backend notification fixes (`app/api/notifications.py`, `app/static/js/admin_app.js`, `app/templates/admin_panel.html`) and test suites (`tests/test_phase11_notifications.py`) were preserved intact without any hard reset or clean operations.
   - Version bump in `mobile/pubspec.yaml`: `1.2.0+3`.

2. **Connected Hardware Identification:**
   - Command: `adb devices`
   - Device Serial: `FY6PHIEA69AMQ8HU`
   - Model: Realme `RMX3998` (`RMX3998IN`), Android 14 (API 34, target SDK 36)
   - Connection state: `device` (Authorized via USB debugging)

3. **Existing Package Inspection:**
   - Package Name: `com.aifaceattendance.mobile_app`
   - Old Installed Version: `versionCode=2`, `versionName=1.1.0`
   - Verified that only the Go-On application package was targeted for replacement.

---

## 3. Flutter Build & Verification

### Static Analysis
```powershell
flutter analyze
```
- **Result:** `No issues found! (ran in 32.4s)` — 0 warnings, 0 errors, 0 lint issues.

### Unit & Integration Test Suite
```powershell
flutter test
```
- **Result:** `00:36 +126: All tests passed!` — 126 out of 126 tests executed and passed.

### Release APK Build
```powershell
flutter build apk --release
```
- **Result:** Successfully compiled to:
  `mobile\build\app\outputs\flutter-apk\app-release.apk`
- **File Size:** `56.5 MB` (59,286,812 bytes)

### Package & Signature Inspection
- **AAPT Badging Audit:**
  - `package: name='com.aifaceattendance.mobile_app'`
  - `versionCode='3'`
  - `versionName='1.2.0'`
  - `application-label:'Go-On'`
  - `launchable-activity: name='com.aifaceattendance.mobile_app.MainActivity'`
- **APK Signature Verification:**
  - Tool: `apksigner verify --verbose`
  - APK Signature Scheme v2: `true`
  - APK Signature Scheme v3: `true`
  - Result: Signature valid, release package integrity verified.

---

## 4. Device Clean Reinstall Execution

1. **Uninstallation of Old Package:**
   ```powershell
   adb -s FY6PHIEA69AMQ8HU uninstall com.aifaceattendance.mobile_app
   ```
   - **Output:** `Success`
   - Verified removal via `pm list packages | findstr mobile_app` (returned empty).
   - Local cached credentials and old package data were cleared.

2. **Streamed Installation of New Release APK:**
   ```powershell
   adb -s FY6PHIEA69AMQ8HU install mobile\build\app\outputs\flutter-apk\app-release.apk
   ```
   - **Output:** `Performing Streamed Install -> Success`

3. **Installed Package State Verification:**
   - `dumpsys package com.aifaceattendance.mobile_app`:
     - `versionCode=3 minSdk=21 targetSdk=36`
     - `versionName=1.2.0`
     - Status: Successfully installed and registered with Android Package Manager.

---

## 5. Application Launch & UI Verification

1. **Launch Command:**
   ```powershell
   adb -s FY6PHIEA69AMQ8HU shell am start -n com.aifaceattendance.mobile_app/.MainActivity
   ```
   - **Activity:** `com.aifaceattendance.mobile_app/.MainActivity` running as top-resumed activity.

2. **Branding & Visual Integrity Audit (`mobile_login_final.png`):**
   - **Launcher & App Identity:** Verified "Go-On" brand assets loaded.
   - **Logo:** Official Go-On golden swirl badge rendered prominently.
   - **Header:** "Go-On" title with "AI Attendance & Campus System" subtitle.
   - **Connection State:** Green "Server Connected" status badge visible.
   - **Form State:** Student / Faculty selector tabs active, clean empty input fields for Registration Number / Password.
   - **No Automated Actions:** App rests cleanly at the login screen for manual user authentication.

---

## 6. Android Notification Channels Audit

Inspected device notification manager state via `dumpsys notification --noredact`:

| Channel ID | Name | Importance | Heads-Up / Banner | Vibration / Sound | Purpose |
|---|---|---|---|---|---|
| `GO_ON_ADMIN` | Admin Announcements | `IMPORTANCE_HIGH` (5 / MAX) | `mShowBanner=true` | Enabled | Critical admin broadcasts & urgent notices |
| `GO_ON_ATTENDANCE` | Attendance Alerts | `IMPORTANCE_HIGH` (5 / MAX) | `mShowBanner=true` | Enabled | Immediate check-in verification & absence alerts |
| `GO_ON_NEXT_CLASS` | Next Class Reminders | `IMPORTANCE_HIGH` (5 / MAX) | `mShowBanner=true` | Enabled | 10-min / 5-min upcoming lecture timetable reminders |
| `GO_ON_ACCOUNT` | Account & Security | `IMPORTANCE_DEFAULT` (3) | Standard notification shade | Enabled | Password changes, profile updates |
| `GO_ON_GENERAL` | General Updates | `IMPORTANCE_DEFAULT` (3) | Standard notification shade | Enabled | Non-urgent system messages |

All high-importance notification channels are configured to trigger full Android heads-up popup banners when notifications arrive.

> [!NOTE]
> On Realme OS (ColorOS / Android 14), runtime permissions (`POST_NOTIFICATIONS`) cannot be granted via ADB CLI due to vendor security restrictions (`java.lang.SecurityException: grantRuntimePermission`). The permission prompt appears within the UI upon login or can be enabled via Android App Info settings.

---

## 7. Firebase Cloud Messaging Status & Production Readiness Checklist

### Current Mode: Development Simulation (Mock) Engine
- Backend notification service (`app/services/fcm_service.py`) operates in **development mock mode** because server-side Firebase service account keys are not yet configured in `.env`.
- Internal notification queues, recipient targeting, scheduled reminder engines, and audit logs are fully operational.
- Verified test broadcast: Sent to 128 recipients via `POST /api/v1/admin/notifications/send` with 200 OK and recorded in audit logs.

### Steps for Production Firebase Cloud Delivery
To transition from development mock mode to live Google Cloud push delivery:
1. **Firebase Console Service Account:**
   - Create or select the Firebase Project (`go-on-attendance`).
   - Navigate to **Project Settings > Service Accounts**.
   - Generate a private key (`serviceAccountKey.json`).
2. **Backend Configuration:**
   - Place `serviceAccountKey.json` on the server or set `FIREBASE_CREDENTIALS_PATH=./serviceAccountKey.json` in `.env`.
   - Alternatively set `FIREBASE_CREDENTIALS_JSON='{"type": "service_account", ...}'`.
3. **Mobile Client Configuration:**
   - Download the production `google-services.json` from Firebase Console.
   - Replace `mobile/android/app/google-services.json`.
4. **Restart Services:**
   - Restart FastAPI backend; FCM service will automatically detect credentials and initialize `firebase_admin`.

---

## 8. Verification Artifacts

- Clean Login Screenshot: `mobile_login_final.png`
- Release APK Binary: `mobile/build/app/outputs/flutter-apk/app-release.apk`
- Phase 11 Notification Test Report: `tests/test_phase11_notifications.py` (All passing)
- Web Admin Notification Center: Fully integrated and operational at `http://localhost:8000/admin#notifications`
