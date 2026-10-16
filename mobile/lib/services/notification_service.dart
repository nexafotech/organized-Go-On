import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../student/screens/student_timetable_screen.dart';
import '../faculty/screens/faculty_attendance_screen.dart';
import '../faculty/screens/faculty_attendance_report_screen.dart';
import '../faculty/screens/faculty_notification_history_screen.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // Background message received while app is terminated or in background
  if (kDebugMode) {
    print('[Go-On Background Notification] Title: ${message.notification?.title}, Data: ${message.data}');
  }
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String? _currentFcmToken;
  GlobalKey<NavigatorState>? _navigatorKey;

  // In-App Notification State
  int _unreadCount = 0;
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollTimer;
  ApiClient? _pollingApiClient;
  final Set<int> _knownNotificationIds = {};
  final Set<int> _deletedNotificationIds = {};
  bool _initialPollDone = false;
  bool _isBulkDeleting = false;

  bool get isInitialized => _isInitialized;
  String? get currentFcmToken => _currentFcmToken;
  int get unreadCount => _unreadCount;
  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isBulkDeleting => _isBulkDeleting;
  String? get errorMessage => _errorMessage;
  Set<int> get knownNotificationIds => Set.unmodifiable(_knownNotificationIds);
  bool isNotificationPinned(int id) => _notifications.any((n) => n.id == id && n.isPinned);

  void clearUserData() {
    _notifications = [];
    _unreadCount = 0;
    _deletedNotificationIds.clear();
    _knownNotificationIds.clear();
    _initialPollDone = false;
    _isBulkDeleting = false;
    _errorMessage = null;
    notifyListeners();
  }

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // ---------------------------------------------------------------------------
  // Android Notification Channels
  // ---------------------------------------------------------------------------
  static const AndroidNotificationChannel channelNextClass = AndroidNotificationChannel(
    'GO_ON_NEXT_CLASS',
    'Next Class Reminders',
    description: 'Timetable and upcoming class reminders',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel channelAttendance = AndroidNotificationChannel(
    'GO_ON_ATTENDANCE',
    'Attendance Alerts',
    description: 'Attendance markings, session open/close, and alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel channelAdmin = AndroidNotificationChannel(
    'GO_ON_ADMIN',
    'Administration Announcements',
    description: 'Official announcements and notices from college administration',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel channelAccount = AndroidNotificationChannel(
    'GO_ON_ACCOUNT',
    'Account & Security',
    description: 'Account security and credentials updates',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  static const AndroidNotificationChannel channelGeneral = AndroidNotificationChannel(
    'GO_ON_GENERAL',
    'General Updates',
    description: 'General system notifications',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      if (kDebugMode) print('[Go-On Notifications] Web environment detected - running web stub.');
      _isInitialized = true;
      return;
    }

    // 1. Initialize Local Notifications & Android Channels FIRST (Guaranteed resilience)
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('ic_notification');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            _handleNotificationTapPayload(response.payload!);
          }
        },
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channelNextClass);
        await androidPlugin.createNotificationChannel(channelAttendance);
        await androidPlugin.createNotificationChannel(channelAdmin);
        await androidPlugin.createNotificationChannel(channelAccount);
        await androidPlugin.createNotificationChannel(channelGeneral);
      }
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Local notification initialization error: $e');
    }

    // 2. Initialize Firebase (Guarded so lack of cloud credentials never blocks local engine)
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationOpenMessage(message);
      });

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpenMessage(initialMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Go-On Notifications] Firebase Cloud Messaging not configured or unavailable: $e');
      }
    }

    _isInitialized = true;
    if (kDebugMode) print('[Go-On Notifications] Notification engine initialized successfully.');
  }

  // ---------------------------------------------------------------------------
  // Permissions (Android 13+ & iOS)
  // ---------------------------------------------------------------------------
  Future<bool> requestNotificationPermissions() async {
    if (kIsWeb) return true;
    bool granted = false;

    // 1. Android 13+ runtime POST_NOTIFICATIONS permission
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final localGranted = await androidPlugin.requestNotificationsPermission();
        if (localGranted == true) granted = true;
      }
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Local permission check notice: $e');
    }

    // 2. iOS local notification permissions
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      } catch (e) {
        if (kDebugMode) print('[Go-On Notifications] iOS permission check notice: $e');
      }
    }

    // 3. Firebase Messaging permission (if Firebase is active)
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        granted = true;
      }
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Firebase Messaging permission notice: $e');
    }

    return granted;
  }

  // ---------------------------------------------------------------------------
  // Device Token Lifecycle (Cross-Platform)
  // ---------------------------------------------------------------------------
  Future<void> registerTokenWithBackend(ApiClient apiClient, {UserModel? user}) async {
    if (kIsWeb) return;
    try {
      await initialize();
      await requestNotificationPermissions();

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await FirebaseMessaging.instance.getAPNSToken();
        } catch (_) {}
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      _currentFcmToken = token;
      notifyListeners();

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
      if (kDebugMode) {
        print('[Go-On Notifications] FCM Token registered with backend ($platformStr): ${token.substring(0, 10)}...');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _currentFcmToken = newToken;
        notifyListeners();
        try {
          await apiClient.post(
            ApiConfig.notificationDeviceToken,
            body: {
              'token': newToken,
              'platform': platformStr,
              'device_name': deviceNameStr,
            },
          );
        } catch (_) {}
      });
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] FCM token registration skipped or failed: $e');
    }
  }

  Future<void> unregisterTokenFromBackend(ApiClient apiClient) async {
    if (_currentFcmToken != null && _currentFcmToken!.isNotEmpty) {
      try {
        await apiClient.delete(
          '${ApiConfig.notificationDeviceToken}?token=$_currentFcmToken',
        );
        _currentFcmToken = null;
        notifyListeners();
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Authenticated In-App Notification History & Actions
  // ---------------------------------------------------------------------------
  Future<List<NotificationItem>> fetchNotifications(
    ApiClient apiClient, {
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.get(
        '${ApiConfig.notificationHistory}?limit=$limit&unread_only=$unreadOnly',
      );

      final List<NotificationItem> items = [];
      if (res is List) {
        for (final entry in res) {
          if (entry is Map<String, dynamic>) {
            final item = NotificationItem.fromJson(entry);
            if (!item.isDeleted && !_deletedNotificationIds.contains(item.id)) {
              items.add(item);
            }
          } else if (entry is Map) {
            final item = NotificationItem.fromJson(Map<String, dynamic>.from(entry));
            if (!item.isDeleted && !_deletedNotificationIds.contains(item.id)) {
              items.add(item);
            }
          }
        }
      }

      _notifications = items;
      _sortNotifications();
      if (!unreadOnly) {
        _unreadCount = items.where((it) => !it.isRead).length;
      }
      _initialPollDone = true;
      _isLoading = false;
      notifyListeners();
      return items;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load notifications: $e';
      notifyListeners();
      return [];
    }
  }

  void _sortNotifications() {
    _notifications.sort((a, b) {
      // Pinned first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      if (a.isPinned && b.isPinned) {
        final aPin = a.pinnedAt ?? a.createdAt;
        final bPin = b.pinnedAt ?? b.createdAt;
        final cmp = bPin.compareTo(aPin);
        if (cmp != 0) return cmp;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void removeNotificationLocally(int notificationId) {
    final existingIndex = _notifications.indexWhere((n) => n.id == notificationId);
    if (existingIndex != -1) {
      if (_notifications[existingIndex].isPinned) {
        if (kDebugMode) print('[Go-On Notifications] Blocked local removal of pinned notification: $notificationId');
        return;
      }
      _deletedNotificationIds.add(notificationId);
      final item = _notifications.removeAt(existingIndex);
      if (!item.isRead && _unreadCount > 0) {
        _unreadCount--;
      }
      notifyListeners();
    }
  }

  Future<bool> deleteNotification(ApiClient apiClient, int notificationId) async {
    final existingIndex = _notifications.indexWhere((n) => n.id == notificationId);
    if (existingIndex != -1 && _notifications[existingIndex].isPinned) {
      if (kDebugMode) print('[Go-On Notifications] Blocked deletion of pinned notification: $notificationId');
      return false;
    }
    _deletedNotificationIds.add(notificationId);
    NotificationItem? removedItem;
    if (existingIndex != -1) {
      removedItem = _notifications.removeAt(existingIndex);
      if (!removedItem.isRead && _unreadCount > 0) {
        _unreadCount--;
      }
      notifyListeners();
    }

    try {
      await apiClient.delete(ApiConfig.notificationDelete(notificationId));
      return true;
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Failed to delete notification on server: $e');
      if (removedItem != null) {
        _deletedNotificationIds.remove(notificationId);
        _notifications.insert(existingIndex, removedItem);
        if (!removedItem.isRead) {
          _unreadCount++;
        }
        _sortNotifications();
        notifyListeners();
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> deleteAllUnpinnedNotifications(ApiClient apiClient) async {
    if (_isBulkDeleting) {
      return {
        'success': false,
        'message': 'Bulk deletion is already in progress.',
        'deleted_count': 0,
        'pinned_preserved_count': _notifications.where((n) => n.isPinned).length,
      };
    }

    final unpinned = _notifications.where((n) => !n.isPinned && !n.isDeleted).toList();
    final pinned = _notifications.where((n) => n.isPinned && !n.isDeleted).toList();

    if (unpinned.isEmpty) {
      return {
        'success': true,
        'deleted_count': 0,
        'pinned_preserved_count': pinned.length,
        'message': pinned.isNotEmpty
            ? 'All notifications are pinned. None were deleted.'
            : 'No notifications available to delete.',
      };
    }

    _isBulkDeleting = true;
    notifyListeners();

    // Snapshot state for rollback on error
    final previousNotifications = List<NotificationItem>.from(_notifications);
    final previousUnreadCount = _unreadCount;
    final deletedIds = unpinned.map((n) => n.id).toSet();

    // Optimistically track deleted IDs and remove unpinned from active list
    _deletedNotificationIds.addAll(deletedIds);
    _notifications = pinned;
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    _sortNotifications();
    notifyListeners();

    try {
      final res = await apiClient.delete(ApiConfig.notificationDeleteUnpinned);
      _isBulkDeleting = false;

      int deletedCount = unpinned.length;
      int pinnedPreserved = pinned.length;

      if (res is Map) {
        if (res['deleted_count'] is int) deletedCount = res['deleted_count'] as int;
        if (res['pinned_preserved_count'] is int) pinnedPreserved = res['pinned_preserved_count'] as int;
      }

      notifyListeners();
      return {
        'success': true,
        'deleted_count': deletedCount,
        'pinned_preserved_count': pinnedPreserved,
        'message': 'Deleted $deletedCount unpinned notification(s); kept $pinnedPreserved pinned.',
      };
    } catch (e) {
      _isBulkDeleting = false;
      if (kDebugMode) print('[Go-On Notifications] Bulk delete failed on server: $e');

      // Reconcile / rollback to previous state
      for (final id in deletedIds) {
        _deletedNotificationIds.remove(id);
      }
      _notifications = previousNotifications;
      _unreadCount = previousUnreadCount;
      _sortNotifications();
      notifyListeners();

      return {
        'success': false,
        'deleted_count': 0,
        'pinned_preserved_count': pinned.length,
        'error': e.toString(),
        'message': 'Failed to delete unpinned notifications on server: $e',
      };
    }
  }

  Future<bool> pinNotification(ApiClient apiClient, int notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(
        isPinned: true,
        pinnedAt: DateTime.now(),
      );
      _sortNotifications();
      notifyListeners();
    }

    try {
      await apiClient.post(ApiConfig.notificationPin(notificationId));
      return true;
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Failed to pin notification on server: $e');
      if (idx != -1 && idx < _notifications.length) {
        _notifications[idx] = _notifications[idx].copyWith(
          isPinned: false,
          pinnedAt: null,
        );
        _sortNotifications();
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> unpinNotification(ApiClient apiClient, int notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    DateTime? oldPinnedAt;
    if (idx != -1) {
      oldPinnedAt = _notifications[idx].pinnedAt;
      _notifications[idx] = _notifications[idx].copyWith(
        isPinned: false,
        pinnedAt: null,
      );
      _sortNotifications();
      notifyListeners();
    }

    try {
      await apiClient.post(ApiConfig.notificationUnpin(notificationId));
      return true;
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Failed to unpin notification on server: $e');
      if (idx != -1 && idx < _notifications.length) {
        _notifications[idx] = _notifications[idx].copyWith(
          isPinned: true,
          pinnedAt: oldPinnedAt,
        );
        _sortNotifications();
        notifyListeners();
      }
      return false;
    }
  }

  Future<int> refreshUnreadCount(ApiClient apiClient) async {
    try {
      final res = await apiClient.get(ApiConfig.notificationUnreadCount);
      if (res is Map && res['unread_count'] != null) {
        final count = res['unread_count'] as int;
        if (count != _unreadCount) {
          _unreadCount = count;
          notifyListeners();
        }
        return count;
      }
    } catch (_) {}
    return _unreadCount;
  }

  Future<bool> markAsRead(ApiClient apiClient, int notificationId) async {
    try {
      await apiClient.post(ApiConfig.notificationMarkRead(notificationId));

      // Locally update item
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true, readAt: DateTime.now());
      }
      if (_unreadCount > 0) {
        _unreadCount--;
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Failed to mark notification read: $e');
      return false;
    }
  }

  Future<int> markAllAsRead(ApiClient apiClient) async {
    try {
      final res = await apiClient.post(ApiConfig.notificationReadAll);
      final count = res is Map && res['count'] != null ? res['count'] as int : _unreadCount;

      _notifications = _notifications.map((n) => n.copyWith(isRead: true, readAt: DateTime.now())).toList();
      _unreadCount = 0;
      notifyListeners();
      return count;
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Failed to mark all notifications read: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // In-App Real-Time Polling & Local Notification Surfacing
  // ---------------------------------------------------------------------------
  void startInAppPolling(ApiClient apiClient, {Duration interval = const Duration(seconds: 25)}) {
    _pollingApiClient = apiClient;
    stopInAppPolling();

    // Initial immediate fetch: seed known notification IDs so historical items aren't surfaced as new heads-up
    refreshUnreadCount(apiClient);
    fetchNotifications(apiClient, limit: 20).then((items) {
      for (final item in items) {
        _knownNotificationIds.add(item.id);
      }
      _initialPollDone = true;
    }).catchError((_) {});

    _pollTimer = Timer.periodic(interval, (_) async {
      if (_pollingApiClient == null) return;
      try {
        final oldCount = _unreadCount;
        final newCount = await refreshUnreadCount(_pollingApiClient!);

        // If unread count changed or first check, check latest notifications
        if (newCount > oldCount || !_initialPollDone) {
          final latest = await fetchNotifications(_pollingApiClient!, limit: 10);
          // If we find new unread notifications that arrived since last check, surface heads-up
          for (final item in latest) {
            if (!item.isRead && !_knownNotificationIds.contains(item.id)) {
              _knownNotificationIds.add(item.id);
              showLocalNotification(item);
            }
          }
          _initialPollDone = true;
        }
      } catch (_) {}
    });
  }

  void stopInAppPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Foreground & Local System Display
  // ---------------------------------------------------------------------------
  Future<void> showLocalNotification(NotificationItem item) async {
    if (kIsWeb) return;
    _knownNotificationIds.add(item.id);
    final selectedChannel = _resolveChannel(item.channelId);

    final androidDetails = AndroidNotificationDetails(
      selectedChannel.id,
      selectedChannel.name,
      channelDescription: selectedChannel.description,
      importance: selectedChannel.importance,
      priority: selectedChannel.importance == Importance.max ? Priority.high : Priority.defaultPriority,
      icon: 'ic_notification',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payloadMap = {
      'id': item.id,
      'route': item.targetRoute ?? 'dashboard',
      'channel_id': item.channelId,
      'title': item.title,
      'body': item.body,
    };

    try {
      await _localNotifications.show(
        id: item.id != 0 ? item.id : (item.title.hashCode & 0x7FFFFFFF),
        title: item.title,
        body: item.body,
        notificationDetails: notificationDetails,
        payload: jsonEncode(payloadMap),
      );
    } catch (e) {
      if (kDebugMode) {
        print('[Go-On Notifications] Local notification display notice: $e');
      }
    }
  }

  AndroidNotificationChannel _resolveChannel(String channelId) {
    switch (channelId) {
      case 'GO_ON_NEXT_CLASS':
        return channelNextClass;
      case 'GO_ON_ATTENDANCE':
        return channelAttendance;
      case 'GO_ON_ADMIN':
        return channelAdmin;
      case 'GO_ON_ACCOUNT':
        return channelAccount;
      default:
        return channelGeneral;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Go-On';
    final body = notification?.body ?? message.data['body'] ?? '';
    final channelId = message.data['channel_id'] ?? 'GO_ON_GENERAL';
    final selectedChannel = _resolveChannel(channelId);

    // Extract deterministic integer notification ID to prevent duplicates
    final int notifId = int.tryParse(message.data['id']?.toString() ?? '') ??
        (message.messageId?.hashCode ?? DateTime.now().millisecond);

    // Deduplicate: if already displayed, do not duplicate in system tray
    if (_knownNotificationIds.contains(notifId)) {
      return;
    }
    _knownNotificationIds.add(notifId);

    final androidDetails = AndroidNotificationDetails(
      selectedChannel.id,
      selectedChannel.name,
      channelDescription: selectedChannel.description,
      importance: selectedChannel.importance,
      priority: selectedChannel.importance == Importance.max ? Priority.high : Priority.defaultPriority,
      icon: 'ic_notification',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final payloadJson = jsonEncode(message.data);

    _localNotifications.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payloadJson,
    );

    // Refresh unread count if apiClient is active
    if (_pollingApiClient != null) {
      refreshUnreadCount(_pollingApiClient!);
      fetchNotifications(_pollingApiClient!, limit: 20);
    }
  }

  void _handleNotificationOpenMessage(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      navigateForData(message.data);
    }
  }

  void _handleNotificationTapPayload(String payloadStr) {
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      // If notification has an ID, mark it read
      final id = data['id'] as int?;
      if (id != null && _pollingApiClient != null) {
        markAsRead(_pollingApiClient!, id);
      }
      navigateForData(data);
    } catch (e) {
      if (kDebugMode) print('[Go-On Notifications] Could not parse tap payload: $e');
    }
  }

  void navigateForData(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    final context = _navigatorKey?.currentContext;
    if (context == null || route == null) return;

    if (kDebugMode) print('[Go-On Notifications] Deep-linking to route: $route');

    switch (route) {
      case 'student_timetable':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StudentTimetableScreen()),
        );
        break;
      case 'faculty_timetable':
      case 'faculty_attendance':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FacultyAttendanceScreen()),
        );
        break;
      case 'reports':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FacultyAttendanceReportScreen()),
        );
        break;
      case 'notifications':
      case 'announcements':
      case 'admin_custom':
      case 'inbox':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FacultyNotificationHistoryScreen()),
        );
        break;
      case 'dashboard':
      case 'profile':
      default:
        break;
    }
  }

  @override
  void dispose() {
    stopInAppPolling();
    super.dispose();
  }
}
