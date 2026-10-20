# go-On — Notification Count and Inbox State Synchronization Engineering Report

**Project:** go-On AI Face Attendance System  
**Component:** Mobile Client Notification Engine & History UI (`mobile/lib/services/notification_service.dart`, `mobile/lib/faculty/screens/faculty_notification_history_screen.dart`, `mobile/lib/services/auth_service.dart`, `backend/app/services/notification_service.py`)  
**Target Environment:** Android (Samsung Galaxy S24 / SM-S921E) & Web/Desktop  
**Date:** October 20, 2026  
**Status:** **VERIFIED & RESOLVED** (100% Tests Passing, Clean Static Analysis, Debug APK Built)

---

## 1. Executive Summary

A critical UI discrepancy was reported in the Notifications page where the AppBar and filter chips displayed an unread count of `3` (e.g. `Notifications 3` and `Unread 3`) while the notification body displayed the empty state:
- *"No notifications yet"*
- *"Class updates and announcements will appear here."*

A thorough architectural audit across backend SQL models, API endpoints, the Flutter service layer, and UI widgets uncovered six distinct root causes that created this discrepancy:
1. **Disconnected Count Calculation**: The AppBar and "Unread" chip displayed `notifService.unreadCount` from a detached backend counter endpoint, whereas the "All" tab computed counts from `notifService.notifications.length`.
2. **Destructive Filter Reloads**: Tapping the "Unread" chip triggered `fetchNotifications(unreadOnly: true)`, overwriting the in-memory `_notifications` list and wiping out the "All" tab count.
3. **Empty State Flash on Initial Frame**: In `FacultyNotificationHistoryScreen.initState`, notifications were fetched asynchronously inside `addPostFrameCallback`. On Frame 1, `isLoading` was `false`, `notifications` was `[]`, and `unreadCount` had already been populated by background polling (`3`), causing the screen to render the empty inbox state simultaneously with unread badges.
4. **Unreconciled Polling & Asynchronous Count Refresh**: When fetching notification items, `_unreadCount` was not reconciled before triggering `notifyListeners()`, leading to temporary race conditions.
5. **Singleton Stale State Across User Sessions**: `NotificationService().clearUserData()` was previously only invoked on explicit `logout()`. Upon session restoration (`restoreSession()`) or account logins (`loginStudent()`, `loginFaculty()`), residual counts and notification collections persisted in memory.
6. **Backend SQLAlchemy Session Synchronization**: The bulk read operation lacked explicit `synchronize_session="fetch"`, risking stale ORM caches across concurrent sessions.

All six root causes have been resolved, verified with unit and widget tests, verified with backend pytest suites, verified through `flutter analyze` with 0 issues, and packaged into the Android debug APK.

---

## 2. Root Cause Analysis Matrix

| # | Subsystem / Layer | Root Cause Identified | Behavioral Impact | Resolution Applied |
|---|---|---|---|---|
| **RC-1** | UI Presentation (`FacultyNotificationHistoryScreen`) | Unread count was sourced from `notifService.unreadCount` while All count was sourced from `notifService.notifications.length`. | If notifications were empty or desynchronized, All showed 0 while Unread showed 3. | Unified count derivation: both `allCount` and `unreadCount` are derived directly from `activeNotifications` in memory. |
| **RC-2** | UI Filter Interaction (`FacultyNotificationHistoryScreen`) | Tapping the "Unread" chip called `_loadNotifications()` with `unreadOnly: true`. | Overwrote `_notifications` with only unread items; All count corrupted to unread count. | Removed destructive remote fetch on tab selection. Filter chips switch tabs instantly using local in-memory filtering. |
| **RC-3** | UI Lifecycle & Loading State (`FacultyNotificationHistoryScreen`) | Post-frame callback left Frame 1 with `isLoading == false` and empty items. | Screen immediately rendered "No notifications yet" while displaying unread badge 3. | Added `_hasInitialLoaded` lifecycle flag and guarded empty state with `Loading notifications...` spinner until fetch completes. |
| **RC-4** | Client Service Layer (`NotificationService`) | `fetchNotifications()` did not reconcile `_unreadCount` before emitting `notifyListeners()`. | UI rendered items with outdated unread counts until background call returned. | Added immediate local recount `activeUnread` in `fetchNotifications()`, `deleteNotification()`, `removeNotificationLocally()`, and `markAsRead()`. |
| **RC-5** | Authentication & Session Lifecycle (`AuthService`) | `NotificationService().clearUserData()` was not called during login or session restore. | Previous user's notification list and counts leaked into newly authenticated session. | Added `NotificationService().clearUserData()` to `restoreSession()`, `loginStudent()`, and `loginFaculty()`. |
| **RC-6** | Backend Database ORM (`app/services/notification_service.py`) | `mark_all_notifications_as_read` query did not specify `synchronize_session="fetch"`. | ORM session could return stale unread objects under concurrent operations. | Added `synchronize_session="fetch"` to the update query. |

---

## 3. Engineering Implementation Details

### A. UI Synchronization (`mobile/lib/faculty/screens/faculty_notification_history_screen.dart`)
1. **Direct Single Source of Truth for Counts**:
   ```dart
   final activeNotifications = notifService.notifications.where((n) => !n.isDeleted).toList();
   final int allCount = activeNotifications.length;
   final int unreadCount = activeNotifications.where((n) => !n.isRead).length;

   final displayedNotifications = _selectedFilterIndex == 1
       ? activeNotifications.where((n) => !n.isRead).toList()
       : activeNotifications;
   ```
2. **Preventing Destructive Tab Switching**:
   ```dart
   Widget _buildFilterChip(int index, String label, int count, AppColors colors) {
     final isSelected = _selectedFilterIndex == index;
     return InkWell(
       onTap: () {
         setState(() {
           _selectedFilterIndex = index;
         });
       },
       // ...
   ```
3. **Eliminating Flash of Empty State**:
   ```dart
   Widget _buildBody(
     List<NotificationItem> items,
     NotificationService notifService,
     AppColors colors,
   ) {
     if ((notifService.isLoading || !_hasInitialLoaded) && notifService.notifications.isEmpty && notifService.errorMessage == null) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             CircularProgressIndicator(color: colors.primary),
             const SizedBox(height: AppSpacing.md),
             Text(
               'Loading notifications...',
               style: TextStyle(color: colors.textSecondary, fontSize: 14),
             ),
           ],
         ),
       );
     }
   ```
4. **Appropriate Empty Messages for Each Tab**:
   - Tab 0 ("All"): `"No notifications yet"` / `"Class updates and announcements will appear here."`
   - Tab 1 ("Unread"): `"No unread notifications"` / `"All your notifications have been marked as read."`

### B. Client Service Reconciliation (`mobile/lib/services/notification_service.dart`)
1. **Immediate Mathematical Alignment in `fetchNotifications`**:
   ```dart
   _notifications = items;
   _sortNotifications();
   _initialPollDone = true;
   _isLoading = false;

   // Authoritative count alignment: exact active unread count
   final activeUnread = items.where((n) => !n.isRead && !n.isDeleted).length;
   _unreadCount = items.isEmpty ? 0 : activeUnread;
   notifyListeners();
   ```
2. **Empty Inbox Guard in `refreshUnreadCount`**:
   ```dart
   final count = (res['unread_count'] as int).clamp(0, 999999);
   final verifiedCount = (_initialPollDone && _notifications.where((n) => !n.isDeleted).isEmpty)
       ? 0
       : count;
   if (verifiedCount != _unreadCount) {
     _unreadCount = verifiedCount;
     notifyListeners();
   }
   ```
3. **Exact Recounting on Mutations**:
   - `markAsRead`: `_unreadCount = _notifications.where((n) => !n.isRead && !n.isDeleted).length;`
   - `deleteNotification`: `_unreadCount = _notifications.where((n) => !n.isRead && !n.isDeleted).length;`
   - `removeNotificationLocally`: `_unreadCount = _notifications.where((n) => !n.isRead && !n.isDeleted).length;`

### C. Session Sanitization (`mobile/lib/services/auth_service.dart`)
- Added `NotificationService().clearUserData()` inside `restoreSession()`, `loginStudent()`, and `loginFaculty()` to ensure completely sanitized notification state upon authentication transitions.

---

## 4. Test Verification Matrix

### Flutter Unit & Widget Test Results (`mobile/test/notification_count_and_sync_test.dart`)
- `NotificationService clearUserData resets counts, notifications, and state`: **PASSED**
- `Empty inbox renders zero counts, hidden header badge, and empty state message`: **PASSED**
- `Populated inbox with 3 unread displays matching header badge and filter counts`: **PASSED**
- `Tapping Unread filter tab filters list in-place without destroying All count`: **PASSED**
- `Unread tab with 0 unread displays correct empty state message without corrupting All tab`: **PASSED**

### Related Notification Regression Tests
- `mobile/test/faculty_notification_bell_and_delivery_test.dart`: **PASSED** (6/6 tests)
- `mobile/test/notification_bulk_delete_test.dart`: **PASSED** (7/7 tests)
- `mobile/test/notification_delete_pin_test.dart`: **PASSED** (7/7 tests)

### Backend Pytest Results
- `tests/test_notification_bulk_delete.py`: **6 passed**
- `tests/test_notification_delete_pin_audit.py`: **6 passed**
- `tests/test_phase11_notifications.py`: **10 passed**
- **Total Backend Tests**: **22 passed in 12.94s**

### Static Code Analysis
- `flutter analyze`: **No issues found!** (0 errors, 0 warnings)

---

## 5. Artifacts and Deliverables
1. **Report Document**: `reports/go-On_Notification_Count_and_Inbox_State_Fix_Report.md`
2. **PDF Audit Report**: `reports/go-On_Notification_Count_and_Inbox_State_Fix_Report.pdf`
3. **Automated Test Suite**: `mobile/test/notification_count_and_sync_test.dart`
4. **Android Build**: `E:\originalam\app-debug.apk`
