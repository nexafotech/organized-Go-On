import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/timezone_utils.dart';
import '../../widgets/widgets.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({Key? key}) : super(key: key);

  @override
  State<AdminNotificationScreen> createState() => _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiClient _apiClient = ApiClient();

  // Settings State
  bool _isLoadingSettings = false;
  bool _studentEnabled = true;
  int _studentLeadMinutes = 10;
  bool _facultyEnabled = true;
  int _facultyLeadMinutes = 15;
  bool _attendanceEnabled = true;
  bool _announcementsEnabled = true;

  // Composer State
  String _audience = 'STUDENT'; // STUDENT, FACULTY, ALL
  String _targetType = 'ALL'; // ALL, CLASS, USER
  final TextEditingController _targetIdController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _channel = 'GO_ON_ADMIN';
  String _priority = 'HIGH';
  String _route = 'student_timetable';
  bool _isSending = false;

  // Logs State
  bool _isLoadingLogs = false;
  List<dynamic> _logs = [];

  final List<int> _allowedLeadTimes = [5, 10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _loadLogs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetIdController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final res = await _apiClient.get(ApiConfig.adminNotificationSettings);
      if (res is Map<String, dynamic>) {
        setState(() {
          _studentEnabled = res['student_next_class_enabled'] ?? true;
          _studentLeadMinutes = res['student_next_class_lead_minutes'] ?? 10;
          _facultyEnabled = res['faculty_next_class_enabled'] ?? true;
          _facultyLeadMinutes = res['faculty_next_class_lead_minutes'] ?? 15;
          _attendanceEnabled = res['attendance_status_enabled'] ?? true;
          _announcementsEnabled = res['admin_announcements_enabled'] ?? true;
        });
      }
    } catch (e) {
      _showSnackbar('Failed to load settings: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final res = await _apiClient.put(
        ApiConfig.adminNotificationSettings,
        body: {
          'student_next_class_enabled': _studentEnabled,
          'student_next_class_lead_minutes': _studentLeadMinutes,
          'faculty_next_class_enabled': _facultyEnabled,
          'faculty_next_class_lead_minutes': _facultyLeadMinutes,
          'attendance_status_enabled': _attendanceEnabled,
          'admin_announcements_enabled': _announcementsEnabled,
        },
      );
      if (res is Map<String, dynamic>) {
        _showSnackbar('Notification settings updated successfully');
      }
    } catch (e) {
      _showSnackbar('Failed to save settings: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _triggerReminderCheck() async {
    try {
      final res = await _apiClient.post(ApiConfig.adminNotificationTrigger);
      if (res is Map<String, dynamic>) {
        final sentStu = res['student_reminders_sent'] ?? 0;
        final sentFac = res['faculty_reminders_sent'] ?? 0;
        final skippedStu = res['student_reminders_skipped'] ?? 0;
        final skippedFac = res['faculty_reminders_skipped'] ?? 0;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Next-Class Reminder Engine Run'),
            content: Text(
              'Engine Time (Asia/Kolkata): ${res['current_time']}\n\n'
              '• Student Reminders Sent: $sentStu (Skipped: $skippedStu)\n'
              '• Faculty Reminders Sent: $sentFac (Skipped: $skippedFac)\n\n'
              'Authoritative timetable evaluated with idempotency.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        _loadLogs();
      }
    } catch (e) {
      _showSnackbar('Failed to trigger reminders: $e', isError: true);
    }
  }

  Future<void> _sendCustomNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      _showSnackbar('Please enter a notification title', isError: true);
      return;
    }
    if (body.isEmpty) {
      _showSnackbar('Please enter a notification message', isError: true);
      return;
    }

    setState(() => _isSending = true);
    try {
      final res = await _apiClient.post(
        ApiConfig.adminNotificationSend,
        body: {
          'audience': _audience,
          'target_type': _targetType,
          'target_id': _targetType == 'ALL' ? null : _targetIdController.text.trim(),
          'channel': _channel,
          'priority': _priority,
          'route': _route,
          'title': title,
          'body': body,
        },
      );

      if (res is Map<String, dynamic>) {
        final count = res['recipients_count'] ?? 0;
        _showSnackbar('Broadcast sent to $count recipient(s)!');
        _titleController.clear();
        _bodyController.clear();
        _loadLogs();
      }
    } catch (e) {
      _showSnackbar('Failed to send broadcast: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final res = await _apiClient.get('${ApiConfig.adminNotificationLogs}?limit=50');
      if (res is List) {
        setState(() => _logs = res);
      }
    } catch (e) {
      // Ignored for background log refresh
    } finally {
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.hero,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoOnLogo(size: 28),
            const SizedBox(width: 10),
            Text(
              'Notification Terminal',
              style: typography.titleMedium.copyWith(color: colors.onHero, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.accent,
          labelColor: colors.onHero,
          unselectedLabelColor: colors.onHeroSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.alarm_rounded), text: 'Reminders'),
            Tab(icon: Icon(Icons.send_rounded), text: 'Composer'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Audit Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSettingsTab(),
          _buildComposerTab(),
          _buildLogsTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: SETTINGS & REMINDERS
  // ---------------------------------------------------------------------------
  Widget _buildSettingsTab() {
    final colors = context.colors;
    final typography = context.typography;

    if (_isLoadingSettings) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: colors.accent, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Role-Specific Next-Class Engine',
                      style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Independent reminder settings for Students and Faculty using timetable source of truth in Asia/Kolkata timezone.',
                  style: typography.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Student Card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school_rounded, color: colors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Student Reminders',
                          style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Switch(
                      value: _studentEnabled,
                      onChanged: (val) => setState(() => _studentEnabled = val),
                      activeThumbColor: colors.accent,
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lead Time Before Class:', style: typography.bodyMedium),
                    DropdownButton<int>(
                      value: _studentLeadMinutes,
                      dropdownColor: colors.surface,
                      items: _allowedLeadTimes.map((m) {
                        return DropdownMenuItem<int>(
                          value: m,
                          child: Text('$m minutes'),
                        );
                      }).toList(),
                      onChanged: _studentEnabled
                          ? (val) {
                              if (val != null) setState(() => _studentLeadMinutes = val);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Faculty Card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_pin_rounded, color: colors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Faculty Reminders',
                          style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Switch(
                      value: _facultyEnabled,
                      onChanged: (val) => setState(() => _facultyEnabled = val),
                      activeThumbColor: colors.accent,
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lead Time Before Class:', style: typography.bodyMedium),
                    DropdownButton<int>(
                      value: _facultyLeadMinutes,
                      dropdownColor: colors.surface,
                      items: _allowedLeadTimes.map((m) {
                        return DropdownMenuItem<int>(
                          value: m,
                          child: Text('$m minutes'),
                        );
                      }).toList(),
                      onChanged: _facultyEnabled
                          ? (val) {
                              if (val != null) setState(() => _facultyLeadMinutes = val);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: _saveSettings,
              text: 'Save Notification Settings',
              icon: Icons.save_rounded,
            ),
          ),
          const SizedBox(height: 12),

          // Trigger Button
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              onPressed: _triggerReminderCheck,
              text: 'Test & Trigger Next-Class Engine Now',
              icon: Icons.play_arrow_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: COMPOSER
  // ---------------------------------------------------------------------------
  Widget _buildComposerTab() {
    final colors = context.colors;
    final typography = context.typography;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Audience Card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Target Audience', style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Students'),
                      selected: _audience == 'STUDENT',
                      onSelected: (val) => setState(() {
                        _audience = 'STUDENT';
                        _route = 'student_timetable';
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Faculty'),
                      selected: _audience == 'FACULTY',
                      onSelected: (val) => setState(() {
                        _audience = 'FACULTY';
                        _route = 'faculty_attendance';
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All Users'),
                      selected: _audience == 'ALL',
                      onSelected: (val) => setState(() {
                        _audience = 'ALL';
                        _route = 'profile';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Scope:', style: typography.bodyMedium),
                    DropdownButton<String>(
                      value: _targetType,
                      dropdownColor: colors.surface,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Broadcast to All')),
                        DropdownMenuItem(value: 'CLASS', child: Text('Specific Class')),
                        DropdownMenuItem(value: 'USER', child: Text('Specific User')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _targetType = val);
                      },
                    ),
                  ],
                ),
                if (_targetType != 'ALL') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _targetIdController,
                    decoration: InputDecoration(
                      labelText: _targetType == 'CLASS' ? 'Class Name or ID' : 'Roll Number or Employee ID',
                      hintText: _targetType == 'CLASS' ? 'e.g. CSE-3A' : 'e.g. 721025149001 or FAC01',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Message Content Card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('2. Message Content', style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Special Timetable Announcement',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message Body',
                    hintText: 'e.g. Classes for {{class_name}} will commence at 10:00 AM on {{date}}.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Template Variables:', style: typography.caption.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('{{name}}'),
                      onPressed: () => _insertTemplate('{{name}}'),
                    ),
                    ActionChip(
                      label: const Text('{{class_name}}'),
                      onPressed: () => _insertTemplate('{{class_name}}'),
                    ),
                    ActionChip(
                      label: const Text('{{subject}}'),
                      onPressed: () => _insertTemplate('{{subject}}'),
                    ),
                    ActionChip(
                      label: const Text('{{date}}'),
                      onPressed: () => _insertTemplate('{{date}}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Channel & Priority Card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('3. Channel & Priority', style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Channel:', style: typography.bodyMedium),
                    DropdownButton<String>(
                      value: _channel,
                      dropdownColor: colors.surface,
                      items: const [
                        DropdownMenuItem(value: 'GO_ON_ADMIN', child: Text('GO_ON_ADMIN (Heads-Up)')),
                        DropdownMenuItem(value: 'GO_ON_GENERAL', child: Text('GO_ON_GENERAL')),
                        DropdownMenuItem(value: 'GO_ON_ATTENDANCE', child: Text('GO_ON_ATTENDANCE')),
                        DropdownMenuItem(value: 'GO_ON_NEXT_CLASS', child: Text('GO_ON_NEXT_CLASS')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _channel = val);
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Priority:', style: typography.bodyMedium),
                    DropdownButton<String>(
                      value: _priority,
                      dropdownColor: colors.surface,
                      items: const [
                        DropdownMenuItem(value: 'HIGH', child: Text('HIGH (Popup / Heads-Up)')),
                        DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL (Tray Notification)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _priority = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Send Action
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: _isSending ? null : _sendCustomNotification,
              text: _isSending ? 'Sending Broadcast...' : 'SEND BROADCAST NOW',
              icon: Icons.send_rounded,
            ),
          ),
        ],
      ),
    );
  }

  void _insertTemplate(String tag) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      _bodyController.text = '$text $tag';
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 3: AUDIT LOGS
  // ---------------------------------------------------------------------------
  Widget _buildLogsTab() {
    final colors = context.colors;
    final typography = context.typography;

    if (_isLoadingLogs && _logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: colors.textSecondary),
            const SizedBox(height: 8),
            Text('No notifications recorded yet', style: typography.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, index) {
          final item = _logs[index] as Map<String, dynamic>;
          final type = item['notification_type'] ?? 'GENERAL';
          final title = item['title'] ?? 'Notification';
          final body = item['body'] ?? '';
          final dateStr = TimezoneUtils.formatIstDateTime(item['created_at']);

          return _buildCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: type == 'NEXT_CLASS_STUDENT' || type == 'NEXT_CLASS_FACULTY'
                      ? Colors.amber.shade700
                      : colors.primary,
                  radius: 18,
                  child: Icon(
                    type.contains('NEXT_CLASS') ? Icons.alarm_rounded : Icons.notifications_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: typography.caption.copyWith(color: colors.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(body, style: typography.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
