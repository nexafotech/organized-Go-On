# Go-On — Cross-Platform Notification Architecture & iOS Integration Report

**Date:** 2026-10-10  
**Repository:** `C:\Users\Abishek\Desktop\am-oss`  
**Git Branch:** `feat/phase-11-push-notifications`  
**Mobile Framework:** Flutter (Dart >=3.0.0 <4.0.0)  
**Backend:** FastAPI + SQLAlchemy + Firebase Admin SDK  
**Target Platforms:** Android (Production-ready & Verified) & iOS (Scaffolded, Compatible & Documented)

---

## 1. Executive Summary

The **Go-On** mobile application and backend architecture have been structured to maintain a single cross-platform codebase targeting both Android and iOS, backed by the shared FastAPI backend.

The notification engine adheres strictly to a **platform-neutral core with isolated native platform adapters**:
- **Android Configuration:** 100% complete, compiled, and verified on physical hardware (Realme RMX3998, Android 14) with heads-up popup channels (`Importance=5`).
- **iOS Compatibility:** Fully preserved and structured without introducing Android-specific blockers. iOS project scaffolding, native `DarwinInitializationSettings`, `DarwinNotificationDetails`, APNs token resolution hooks, background execution modes, camera/photo usage descriptions, and development `GoogleService-Info.plist` are in place.
- **Backend Multi-Platform Delivery:** FastAPI's `FCMService` dispatches unified payloads with both `AndroidConfig` (channels, priority) and `ApnsConfig` (`Aps` alert, sound, badge, content-available).

> [!IMPORTANT]
> **Honest Verification Boundary:** While iOS code compatibility, static analysis, unit tests, and configuration files pass without errors on the Windows development workstation, **iOS execution and device delivery are classified as NOT TESTED ON HARDWARE** because compiling and signing iOS binaries strictly requires macOS and Xcode.

---

## 2. Cross-Platform Architectural Topology

```text
                     ┌───────────────────────────────────────────────┐
                     │          Go-On FastAPI Backend Server         │
                     │  (Targeting: Students, Faculty, Admins)       │
                     └──────────────────────┬────────────────────────┘
                                            │
                                            ▼
                     ┌───────────────────────────────────────────────┐
                     │          FCMService (Dual Delivery)           │
                     │  - AndroidConfig (channel_id, max priority)   │
                     │  - ApnsConfig (aps alert, sound, badge=1)     │
                     └──────────────┬─────────────────┬──────────────┘
                                    │                 │
                   ┌────────────────┴──────┐   ┌──────┴───────────────┐
                   │ Google Cloud FCM      │   │ Apple APNs           │
                   └──────────────┬────────┘   └──────┬───────────────┘
                                  ▼                   ▼
                     ┌─────────────────────┐   ┌──────────────────────┐
                     │ Android Devices     │   │ iOS Devices          │
                     │ (Channels, Heads-up)│   │ (Banners, Badges)    │
                     └────────────┬────────┘   └──────┬───────────────┘
                                  │                   │
                                  ▼                   ▼
                     ┌───────────────────────────────────────────────┐
                     │       Unified Flutter Mobile Codebase         │
                     │             (mobile/lib/services)             │
                     │                                               │
                     │  NotificationService (Platform-Neutral Core)  │
                     │    ├── Android: LocalNotifications + Channels │
                     │    ├── iOS: DarwinSettings + APNs Resolver    │
                     │    └── Shared: Deep-Link Routing & Auth Token │
                     └───────────────────────────────────────────────┘
```

---

## 3. Platform Isolation Matrix

| Capability | Shared / Platform-Neutral | Android-Specific Implementation | iOS-Specific Implementation |
|---|---|---|---|
| **Plugin Dependencies** | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` in `pubspec.yaml` | Cross-platform compatible | Cross-platform compatible |
| **Local Notifications Init** | `_localNotifications.initialize(...)` | `AndroidInitializationSettings('@drawable/ic_notification')` | `DarwinInitializationSettings(requestAlertPermission: false, ...)` |
| **Notification Channels** | Channel constants defined as static properties | Created via `AndroidFlutterLocalNotificationsPlugin.createNotificationChannel` | Channels are ignored by iOS (iOS uses native APNs categories) |
| **Permission Request** | `NotificationService.requestNotificationPermissions()` | `FirebaseMessaging.instance.requestPermission()` (Android 13+ POST_NOTIFICATIONS) | `FirebaseMessaging.requestPermission()` + `IOSFlutterLocalNotificationsPlugin.requestPermissions()` |
| **Token Resolution** | `FirebaseMessaging.instance.getToken()` | Directly queries Google Play Services | Checks `FirebaseMessaging.instance.getAPNSToken()` prior to FCM token generation |
| **Backend Registration** | `ApiClient.post(ApiConfig.notificationDeviceToken, ...)` | Transmits `'platform': 'android'`, `'device_name': 'Android Device'` | Transmits `'platform': 'ios'`, `'device_name': 'iOS Device'` |
| **Foreground Presentation** | `_handleForegroundMessage(RemoteMessage)` | `AndroidNotificationDetails` (channel, importance, priority) | `DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true)` |
| **Deep-Link Navigation** | `_navigateForData(data)` routes via `_navigatorKey` | Maps `'route'` payload to Flutter screens | Identical Flutter screen routing (`student_timetable`, `faculty_attendance`, `reports`) |

---

## 4. Key Implementation Changes

### 4.1. Flutter Client (`mobile/lib/services/notification_service.dart`)

1. **Dual Initialization Settings:**
   ```dart
   const AndroidInitializationSettings androidSettings =
       AndroidInitializationSettings('@drawable/ic_notification');
   const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
     requestAlertPermission: false,
     requestBadgePermission: false,
     requestSoundPermission: false,
   );
   const InitializationSettings initSettings = InitializationSettings(
     android: androidSettings,
     iOS: iosSettings,
   );
   ```

2. **Cross-Platform Permission Workflow:**
   ```dart
   if (defaultTargetPlatform == TargetPlatform.iOS) {
     final iosPlugin = _localNotifications
         .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
     if (iosPlugin != null) {
       await iosPlugin.requestPermissions(
         alert: true,
         badge: true,
         sound: true,
       );
     }
   }
   ```

3. **APNs-Aware Token Registration:**
   ```dart
   if (defaultTargetPlatform == TargetPlatform.iOS) {
     final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
   }
   final platformStr = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
   final deviceNameStr = defaultTargetPlatform == TargetPlatform.iOS ? 'iOS Device' : 'Android Device';
   await apiClient.post(
     ApiConfig.notificationDeviceToken,
     body: {
       'token': token,
       'platform': platformStr,
       'device_name': deviceNameStr,
     },
   );
   ```

4. **Dual Foreground Presentation Details:**
   ```dart
   const iosDetails = DarwinNotificationDetails(
     presentAlert: true,
     presentBadge: true,
     presentSound: true,
   );
   final notificationDetails = NotificationDetails(
     android: androidDetails,
     iOS: iosDetails,
   );
   ```

### 4.2. iOS Project Scaffolding & Configuration (`mobile/ios/`)

1. **`Info.plist` Additions:**
   - App Display Name: `Go-On`
   - Camera Usage Description: `Go-On requires camera access for facial recognition attendance marking and profile enrollment.`
   - Photo Library Description: `Go-On requires photo library access for batch photo attendance processing.`
   - Background Execution Modes:
     ```xml
     <key>UIBackgroundModes</key>
     <array>
         <string>fetch</string>
         <string>remote-notification</string>
     </array>
     ```

2. **`GoogleService-Info.plist`:**
   - Template placed in `mobile/ios/Runner/GoogleService-Info.plist` with Bundle ID `com.aifaceattendance.attendanceMarkerMobile` and Project ID `go-on-attendance`.

### 4.3. Backend Multi-Platform Notification Dispatch (`app/services/fcm_service.py`)

Configured both `AndroidConfig` and `ApnsConfig` inside `messaging.Message`:
```python
apns_config = messaging.ApnsConfig(
    headers={
        "apns-priority": "10" if high_importance else "5",
    },
    payload=messaging.ApsPayload(
        aps=messaging.Aps(
            alert=messaging.ApsAlert(
                title=title,
                body=body,
            ),
            sound="default",
            badge=1,
            content_available=True,
        ),
        custom_data=str_data,
    ),
)

message = messaging.Message(
    token=token,
    notification=messaging.Notification(title=title, body=body),
    data=str_data,
    android=android_config,
    apns=apns_config,
)
```

---

## 5. Verification & Quality Gates

### 5.1. Flutter Static Analysis
```powershell
flutter analyze
```
- **Result:** `No issues found! (ran in 8.7s)`
- Zero warnings, zero errors across all Dart files.

### 5.2. Flutter Test Suite
```powershell
flutter test
```
- **Result:** `All tests passed! (127/127 tests)`
- All unit, widget, and cross-platform notification tests passed.

### 5.3. Backend Pytest Suite
```powershell
.venv\Scripts\pytest tests/test_phase11_notifications.py -v
```
- **Result:** `10 passed in 11.31s`
- Settings independence, token lifecycle, next-class detection, template substitution, and RBAC verified.

### 5.4. Existing Features Integrity
- **Attendance Marking:** Intact, unchanged.
- **Biometric Recognition:** Intact, unchanged.
- **Authentication & Roles:** Intact, unchanged.
- **Timetable Rules:** Intact, unchanged.

---

## 6. Documented Remaining iOS Production Requirements

To achieve live verification and release on iOS devices, the following steps must be performed on a macOS host with Xcode:

1. **Apple Developer Account Registration:**
   - Enroll in the Apple Developer Program.
   - Register the App ID: `com.aifaceattendance.attendanceMarkerMobile` (or preferred organization bundle identifier).
   - Enable Capabilities: **Push Notifications** and **Background Modes (Remote Notifications)**.

2. **Apple Push Notification service (APNs) Authentication:**
   - In Apple Developer Portal > **Certificates, Identifiers & Profiles** > **Keys**:
     - Create an APNs Auth Key (`.p8` file).
     - Note the Key ID and Team ID.
   - In **Firebase Console** > Project Settings > **Cloud Messaging** > **Apple app configuration**:
     - Upload the APNs Auth Key (`.p8`), entering the Key ID and Team ID.

3. **Firebase iOS App Registration:**
   - In Firebase Console, add an **iOS App** to the project (`go-on-attendance`).
   - Bundle ID: `com.aifaceattendance.attendanceMarkerMobile`.
   - Download the production `GoogleService-Info.plist` and overwrite `mobile/ios/Runner/GoogleService-Info.plist`.

4. **Xcode Workspace Configuration (macOS):**
   - Open `mobile/ios/Runner.xcworkspace` in Xcode.
   - Under **Signing & Capabilities**:
     - Select your Development Team.
     - Add Capability: **Push Notifications**.
     - Add Capability: **Background Modes** (check `Background fetch` and `Remote notifications`).
   - Run `pod install` in `mobile/ios/`.

5. **Build & Hardware Verification:**
   ```bash
   flutter build ipa --release
   # Or run directly on connected iPhone:
   flutter run -d <iphone-device-id>
   ```
   - Verify prompt: "Go-On would like to send you notifications".
   - Confirm APNs token exchanges into a registered FCM token in the FastAPI database (`platform: "ios"`).
   - Dispatch test notification from Web Admin console and verify iOS lock screen banner and banner sound.
