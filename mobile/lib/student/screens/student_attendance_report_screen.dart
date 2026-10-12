import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';
import '../../services/student_service.dart';
import '../../widgets/widgets.dart';

class StudentAttendanceReportScreen extends StatefulWidget {
  const StudentAttendanceReportScreen({Key? key}) : super(key: key);

  @override
  State<StudentAttendanceReportScreen> createState() => _StudentAttendanceReportScreenState();
}

class _StudentAttendanceReportScreenState extends State<StudentAttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final studentService = Provider.of<StudentService>(context, listen: false);
    await Future.wait([
      studentService.fetchStudentSummary(),
      studentService.fetchSubjects(),
      studentService.fetchAttendanceReportFiltered(subjectId: _selectedSubjectId),
    ]);
  }

  Widget _buildSubjectCard(SubjectAttendanceModel sub) {
    final colors = context.colors;
    final typography = context.typography;

    Color pctColor;
    Color pctBg;
    if (sub.percentage >= 75.0) {
      pctColor = colors.present;
      pctBg = colors.presentBg;
    } else if (sub.percentage >= 65.0) {
      pctColor = colors.warning;
      pctBg = colors.warningBg;
    } else {
      pctColor = colors.absent;
      pctBg = colors.absentBg;
    }

    return GlassCard(
      variant: GlassCardVariant.standard,
      enableBlur: false,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: AppSpacing.md),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => SubjectDetailSheet.show(context, sub),
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.subjectName,
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub.subjectCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pctBg,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: pctColor, width: 1.2),
                    ),
                    child: Text(
                      '${sub.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: pctColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (sub.percentage / 100.0).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: colors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(pctColor),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attended: ${sub.present + sub.od} / ${sub.total}',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Absent: ${sub.absent}',
                    style: TextStyle(fontSize: 12, color: colors.absent, fontWeight: FontWeight.w600),
                  ),
                  if (sub.od > 0)
                    Text(
                      'OD: ${sub.od}',
                      style: TextStyle(fontSize: 12, color: colors.od, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateMatrixCard(DateWiseEntryModel entry) {
    final colors = context.colors;

    // Find status for periods 1 through 7
    String getPeriodStatus(int pNum) {
      final p = entry.periods.where((item) => item.periodNumber == pNum).toList();
      return p.isNotEmpty ? p.first.status : '-';
    }

    String? getPeriodOdReason(int pNum) {
      final p = entry.periods.where((item) => item.periodNumber == pNum).toList();
      return p.isNotEmpty ? p.first.odReason : null;
    }

    Color resultColor;
    Color resultBg;
    switch (entry.dailyResult?.toUpperCase()) {
      case 'FULL_DAY_PRESENT':
        resultColor = colors.present;
        resultBg = colors.presentBg;
        break;
      case 'HALF_DAY_PRESENT':
        resultColor = colors.warning;
        resultBg = colors.warningBg;
        break;
      case 'FULL_DAY_ABSENT':
        resultColor = colors.absent;
        resultBg = colors.absentBg;
        break;
      case 'OD':
        resultColor = colors.od;
        resultBg = colors.odBg;
        break;
      default:
        resultColor = colors.textMuted;
        resultBg = colors.surfaceMuted;
    }

    return GlassCard(
      variant: GlassCardVariant.standard,
      enableBlur: false,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: AppSpacing.md),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => DateDetailSheet.show(context, entry),
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date and Daily Result header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note_rounded, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        entry.date,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (entry.dailyResult != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: resultBg,
                        borderRadius: AppRadius.smallBorder,
                        border: Border.all(color: resultColor, width: 1),
                      ),
                      child: Text(
                        entry.dailyResult!.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: resultColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Period chips row: Morning (P1-P4) | Lunch (Not counted) | Afternoon (P5-P7)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // P1
                    _buildPeriodColumn('P1', getPeriodStatus(1), getPeriodOdReason(1)),
                    const SizedBox(width: 4),
                    // P2
                    _buildPeriodColumn('P2', getPeriodStatus(2), getPeriodOdReason(2)),
                    const SizedBox(width: 4),
                    // P3
                    _buildPeriodColumn('P3', getPeriodStatus(3), getPeriodOdReason(3)),
                    const SizedBox(width: 4),
                    // P4
                    _buildPeriodColumn('P4', getPeriodStatus(4), getPeriodOdReason(4)),
                    const SizedBox(width: 6),

                    // Lunch Break separator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.lunchBg,
                        borderRadius: AppRadius.smallBorder,
                        border: Border.all(color: colors.lunch.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('LUNCH', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colors.lunch)),
                          const SizedBox(height: 2),
                          Text('EXCLUDED', style: TextStyle(fontSize: 7, color: colors.lunch)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // P5
                    _buildPeriodColumn('P5', getPeriodStatus(5), getPeriodOdReason(5)),
                    const SizedBox(width: 4),
                    // P6
                    _buildPeriodColumn('P6', getPeriodStatus(6), getPeriodOdReason(6)),
                    const SizedBox(width: 4),
                    // P7
                    _buildPeriodColumn('P7', getPeriodStatus(7), getPeriodOdReason(7)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Sub-summary info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Morning: ${entry.morningSummary ?? "N/A"}',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  Text(
                    'Afternoon: ${entry.afternoonSummary ?? "N/A"}',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodColumn(String periodLabel, String status, String? odReason) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          periodLabel,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colors.textMuted),
        ),
        const SizedBox(height: 3),
        PeriodStatusChip(
          status: status,
          odReason: odReason,
          size: PeriodChipSize.compact,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final studentService = Provider.of<StudentService>(context);
    final summary = studentService.summary;
    final subjects = studentService.subjects;
    final dateWise = studentService.dateWise;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Attendance Report'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: studentService.isLoading && summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: colors.primary,
              backgroundColor: colors.surface,
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Student Info Header
                    if (summary != null)
                      GlassCard(
                        variant: GlassCardVariant.standard,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: colors.heroChip,
                              child: Text(
                                summary.fullName.isNotEmpty ? summary.fullName[0].toUpperCase() : 'S',
                                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    summary.fullName,
                                    style: typography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Reg: ${summary.registerNumber} • ${summary.className ?? "Class"}',
                                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Overall Summary Card
                    if (summary != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: AttendanceSummaryCard(
                          percentage: summary.percentage,
                          total: summary.total,
                          present: summary.present,
                          absent: summary.absent,
                          od: summary.od,
                          halfDayPresent: summary.halfDayPresent,
                          halfDayAbsent: summary.halfDayAbsent,
                          status: summary.attendanceStatus,
                          minimumRequired: summary.minimumRequired,
                          calculationMode: summary.calculationMode,
                          alertMessage: summary.alertMessage,
                        ),
                      ),

                    // Tab Selector: Subject-wise vs Date-wise Matrix
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: colors.glassSurfaceStrong,
                        borderRadius: AppRadius.largeBorder,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: colors.primary,
                        indicatorWeight: 3,
                        labelColor: colors.primary,
                        unselectedLabelColor: colors.textMuted,
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: const [
                          Tab(text: 'Subject-Wise'),
                          Tab(text: 'Date-Wise Matrix'),
                        ],
                      ),
                    ),

                    // Tab Views
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        if (_tabController.index == 0) {
                          // Subject-wise view
                          if (subjects.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxl),
                              child: Center(
                                child: Text('No subject attendance data available.', style: TextStyle(color: colors.textSecondary)),
                              ),
                            );
                          }
                          return Column(
                            children: subjects.map(_buildSubjectCard).toList(),
                          );
                        } else {
                          // Date-wise Matrix view
                          if (dateWise.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxl),
                              child: Center(
                                child: Text('No date-wise attendance records available.', style: TextStyle(color: colors.textSecondary)),
                              ),
                            );
                          }
                          return Column(
                            children: dateWise.map(_buildDateMatrixCard).toList(),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Attendance Legend
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: AttendanceLegend(),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }
}
