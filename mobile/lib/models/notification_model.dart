import 'dart:convert';

class NotificationItem {
  final int id;
  final int userId;
  final String notificationType;
  final String channelId;
  final String title;
  final String body;
  final String? dataPayload;
  final String? referenceDate;
  final int? periodId;
  final int? timetableEntryId;
  final String status;
  final String? errorMessage;
  final bool isRead;
  final DateTime? readAt;
  final bool isPinned;
  final DateTime? pinnedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.notificationType,
    required this.channelId,
    required this.title,
    required this.body,
    this.dataPayload,
    this.referenceDate,
    this.periodId,
    this.timetableEntryId,
    required this.status,
    this.errorMessage,
    required this.isRead,
    this.readAt,
    this.isPinned = false,
    this.pinnedAt,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      notificationType: json['notification_type'] as String? ?? 'GENERAL',
      channelId: json['channel_id'] as String? ?? 'GO_ON_GENERAL',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      dataPayload: json['data_payload'] as String?,
      referenceDate: json['reference_date'] as String?,
      periodId: json['period_id'] as int?,
      timetableEntryId: json['timetable_entry_id'] as int?,
      status: json['status'] as String? ?? 'SENT',
      errorMessage: json['error_message'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      pinnedAt: json['pinned_at'] != null ? DateTime.tryParse(json['pinned_at'].toString()) : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> get parsedData {
    if (dataPayload == null || dataPayload!.isEmpty) return {};
    try {
      final decoded = jsonDecode(dataPayload!);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  String? get targetRoute {
    final data = parsedData;
    return data['route'] as String?;
  }

  bool get isHighPriority {
    final data = parsedData;
    final priority = data['priority'] as String?;
    return priority?.toUpperCase() == 'HIGH' || channelId == 'GO_ON_ADMIN';
  }

  NotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
    bool? isPinned,
    DateTime? pinnedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return NotificationItem(
      id: id,
      userId: userId,
      notificationType: notificationType,
      channelId: channelId,
      title: title,
      body: body,
      dataPayload: dataPayload,
      referenceDate: referenceDate,
      periodId: periodId,
      timetableEntryId: timetableEntryId,
      status: status,
      errorMessage: errorMessage,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
    );
  }
}
