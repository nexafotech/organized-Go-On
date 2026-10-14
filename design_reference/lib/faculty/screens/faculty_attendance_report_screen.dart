import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/file_saver.dart';
import '../../models/faculty_report_model.dart';
import '../../services/faculty_service.dart';
import '../../widgets/widgets.dart';

class FacultyAttendanceReportScreen extends StatefulWidget {
  final int? initialClassId;
  final int? initialSubjectId;

  const FacultyAttendanceReportScreen({
    Key? key,
    this.initialClassId,
    this.initialSubjectId,
  }) : super(key: key);

  @override
  State<FacultyAttendanceReportScreen> createState() => _FacultyAttendanceReportScreenState();
}

class _FacultyAttendanceReportScreenState extends State<FacultyAttendanceReportScreen> {
  bool _isLoadingOptions = true;
  bool _isLoadingReport = false;
  String? _errorMessage;

  FacultyAuthorizedReportOptionsModel? _options;
  AuthorizedClassOptionModel? _selectedClass;
  AuthorizedSubjectOptionModel? _selectedSubject; // null means "All Subjects" for Advisor

  // View Mode: 0 = Class Summary, 1 = Daily Matrix, 2 = Historical Matrix, 3 = Date Range Export
  int _viewMode = 0;

  // Class Summary State
  FacultyClassSummaryModel? _classSummary;
  String _searchQuery = '';

  // Date Matrix State
  FacultyDateMatrixModel? _dateMatrix;
  DateTime _selectedDate = DateTime.now();

  // Historical Matrix State
  FacultyHistoricalMatrixModel? _historicalMatrix;
  DateTime? _histStartDate;
  DateTime? _histEndDate;
  DateTime? _minAttendanceDate;
  DateTime? _maxAllowedDate;

  // Phase 9: Date Range Report & Export State
  AttendanceRangeReportModel? _rangeReport;
  DateTime _rangeFromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangeToDate = DateTime.now();
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;
  String? _rangeValidationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAuthorizedOptions();
    });
  }

  String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _loadAuthorizedOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _errorMessage = null;
    });

    try {
      final facultyService = Provider.of<FacultyService>(context, listen: false);
      final options = await facultyService.fetchReportAuthorizedOptions();

      if (options.attendanceStartDate != null && options.attendanceStartDate!.isNotEmpty) {
        _minAttendanceDate = DateTime.tryParse(options.attendanceStartDate!);
        _histStartDate = _minAttendanceDate;
      }
      if (options.currentDate != null && options.currentDate!.isNotEmpty) {
        _maxAllowedDate = DateTime.tryParse(options.currentDate!);
        _histEndDate = _maxAllowedDate;
        if (_maxAllowedDate != null) {
          _selectedDate = _maxAllowedDate!;
        }
      }
      _minAttendanceDate ??= DateTime(2024, 1, 1);
      _maxAllowedDate ??= DateTime.now();
      _histStartDate ??= _minAttendanceDate;
      _histEndDate ??= _maxAllowedDate;
      _rangeToDate = _maxAllowedDate ?? DateTime.now();
      _rangeFromDate = _rangeToDate.subtract(const Duration(days: 7));
      if (_minAttendanceDate != null && _rangeFromDate.isBefore(_minAttendanceDate!)) {
        _rangeFromDate = _minAttendanceDate!;
      }

      AuthorizedClassOptionModel? chosenClass;
      AuthorizedSubjectOptionModel? chosenSubject;

      if (options.classes.isNotEmpty) {
        if (widget.initialClassId != null) {
          chosenClass = options.classes.firstWhere(
            (c) => c.id == widget.initialClassId,
            orElse: () => options.classes.first,
          );
        } else if (options.advisedClass != null) {
          chosenClass = options.classes.firstWhere(
            (c) => c.id == options.advisedClass!.id,
            orElse: () => options.classes.first,
          );
        } else {
          chosenClass = options.classes.first;
        }

        if (chosenClass.subjects.isNotEmpty) {
          if (widget.initialSubjectId != null) {
            chosenSubject = chosenClass.subjects.firstWhere(
              (s) => s.id == widget.initialSubjectId,
              orElse: () => chosenClass!.subjects.first,
            );
          } else if (!chosenClass.isAdvisorForClass) {
            chosenSubject = chosenClass.subjects.first;
          }
        }
      }

      setState(() {
        _options = options;
        _selectedClass = chosenClass;
        _selectedSubject = chosenSubject;
        _isLoadingOptions = false;
      });

      if (_selectedClass != null) {
        _loadCurrentReport();
      }
    } catch (e) {
      setState(() {
        _isLoadingOptions = false;
        _errorMessage = 'Failed to load authorized classes: $e';
      });
    }
  }

  Future<void> _loadCurrentReport() async {
    if (_selectedClass == null) return;

    setState(() {
      _isLoadingReport = true;
      _errorMessage = null;
    });

    final facultyService = Provider.of<FacultyService>(context, listen: false);

    try {
      if (_viewMode == 0) {
        // Load Class Summary
        final summary = await facultyService.fetchClassSummaryReport(
          classId: _selectedClass!.id,
          subjectId: _selectedSubject?.id,
        );
        setState(() {
          _classSummary = summary;
          _isLoadingReport = false;
        });
      } else if (_viewMode == 1) {
        // Load Date Matrix
        try {
          final matrix = await facultyService.fetchDateMatrixReport(
            classId: _selectedClass!.id,
            date: _formatDate(_selectedDate),
            subjectId: _selectedSubject?.id,
          );
          setState(() {
            _dateMatrix = matrix;
            _isLoadingReport = false;
          });
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('future') || errStr.contains('400')) {
            setState(() {
              _dateMatrix = null;
              _isLoadingReport = false;
              _errorMessage = null;
            });
          } else {
            setState(() {
              _isLoadingReport = false;
              _errorMessage = 'Failed to load report data: $e';
            });
          }
        }
      } else if (_viewMode == 2) {
        // Load Historical Matrix
        try {
          final histMatrix = await facultyService.fetchHistoricalMatrixReport(
            classId: _selectedClass!.id,
            subjectId: _selectedSubject?.id,
            startDate: _histStartDate != null ? _formatDate(_histStartDate!) : null,
            endDate: _histEndDate != null ? _formatDate(_histEndDate!) : null,
          );
          setState(() {
            _historicalMatrix = histMatrix;
            _isLoadingReport = false;
          });
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('future') || errStr.contains('400')) {
            setState(() {
              _historicalMatrix = null;
              _isLoadingReport = false;
              _errorMessage = null;
            });
          } else {
            setState(() {
              _isLoadingReport = false;
              _errorMessage = 'Failed to load report data: $e';
            });
          }
        }
      } else {
        // Load Date Range Report (_viewMode == 3)
        if (_rangeFromDate.isAfter(_rangeToDate)) {
          setState(() {
            _rangeValidationError = 'From date cannot be after To date.';
            _isLoadingReport = false;
          });
          return;
        }
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day, 23, 59, 59);
        if (_rangeToDate.isAfter(todayMidnight)) {
          setState(() {
            _rangeValidationError = 'To date cannot be in the future.';
            _isLoadingReport = false;
          });
          return;
        }
        setState(() {
          _rangeValidationError = null;
        });

        try {
          final rangeReport = await facultyService.fetchAttendanceRangeReport(
            classId: _selectedClass!.id,
            fromDate: _formatDate(_rangeFromDate),
            toDate: _formatDate(_rangeToDate),
            subjectId: _selectedSubject?.id,
          );
          setState(() {
            _rangeReport = rangeReport;
            _isLoadingReport = false;
          });
        } catch (e) {
          setState(() {
            _rangeReport = null;
            _isLoadingReport = false;
            final errStr = e.toString().toLowerCase();
            if (!errStr.contains('404') && !errStr.contains('no records')) {
              _errorMessage = 'Failed to load date range report: $e';
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingReport = false;
        _errorMessage = 'Failed to load report data: $e';
      });
    }
  }

  void _onClassChanged(AuthorizedClassOptionModel? newClass) {
    if (newClass == null || newClass.id == _selectedClass?.id) return;
    setState(() {
      _selectedClass = newClass;
      if (newClass.isAdvisorForClass) {
        _selectedSubject = null; // Default to All Subjects for Advisor
      } else if (newClass.subjects.isNotEmpty) {
        _selectedSubject = newClass.subjects.first;
      } else {
        _selectedSubject = null;
      }
    });
    _loadCurrentReport();
  }

  void _onSubjectChanged(AuthorizedSubjectOptionModel? newSubject) {
    setState(() {
      _selectedSubject = newSubject;
    });
    _loadCurrentReport();
  }

  Future<void> _pickDate() async {
    final colors = context.colors;
    final calendarFirstDate = DateTime(2020, 1, 1);
    final calendarLastDate = DateTime(2035, 12, 31);
    final initial = _selectedDate.isBefore(calendarFirstDate)
        ? calendarFirstDate
        : (_selectedDate.isAfter(calendarLastDate) ? calendarLastDate : _selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: calendarFirstDate,
      lastDate: calendarLastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              surface: colors.surface,
              onSurface: colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadCurrentReport();
    }
  }

  Future<void> _pickDateRange() async {
    final colors = context.colors;
    final calendarFirstDate = DateTime(2020, 1, 1);
    final calendarLastDate = DateTime(2035, 12, 31);
    final start = _histStartDate ?? calendarFirstDate;
    final end = _histEndDate ?? DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: start.isBefore(calendarFirstDate)
            ? calendarFirstDate
            : (start.isAfter(calendarLastDate) ? calendarLastDate : start),
        end: end.isAfter(calendarLastDate)
            ? calendarLastDate
            : (end.isBefore(calendarFirstDate) ? calendarFirstDate : end),
      ),
      firstDate: calendarFirstDate,
      lastDate: calendarLastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              surface: colors.surface,
              onSurface: colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _histStartDate = picked.start;
        _histEndDate = picked.end;
      });
      _loadCurrentReport();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Phase 9: Date Range Pickers & Export Actions
  // ─────────────────────────────────────────────────────────────

  Future<void> _pickRangeFromDate() async {
    final colors = context.colors;
    final calendarFirstDate = DateTime(2020, 1, 1);
    final calendarLastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeFromDate.isBefore(calendarFirstDate)
          ? calendarFirstDate
          : (_rangeFromDate.isAfter(calendarLastDate) ? calendarLastDate : _rangeFromDate),
      firstDate: calendarFirstDate,
      lastDate: calendarLastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              surface: colors.surface,
              onSurface: colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _rangeFromDate = picked;
      });
      _loadCurrentReport();
    }
  }

  Future<void> _pickRangeToDate() async {
    final colors = context.colors;
    final calendarFirstDate = DateTime(2020, 1, 1);
    final calendarLastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeToDate.isBefore(calendarFirstDate)
          ? calendarFirstDate
          : (_rangeToDate.isAfter(calendarLastDate) ? calendarLastDate : _rangeToDate),
      firstDate: calendarFirstDate,
      lastDate: calendarLastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              surface: colors.surface,
              onSurface: colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _rangeToDate = picked;
      });
      _loadCurrentReport();
    }
  }

  Future<void> _exportPdf() async {
    if (_selectedClass == null || _isExportingPdf || _isExportingExcel) return;
    if (_rangeFromDate.isAfter(_rangeToDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date cannot be after To date.')),
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    final facultyService = Provider.of<FacultyService>(context, listen: false);

    try {
      final bytes = await facultyService.downloadAttendanceRangePdf(
        classId: _selectedClass!.id,
        fromDate: _formatDate(_rangeFromDate),
        toDate: _formatDate(_rangeToDate),
        subjectId: _selectedSubject?.id,
      );

      final subjectPart = _selectedSubject != null ? 'sub_${_selectedSubject!.id}' : 'all_subjects';
      final fileName =
          'attendance_report_${_selectedClass!.id}_${subjectPart}_${_formatDate(_rangeFromDate)}_${_formatDate(_rangeToDate)}.pdf';
      final savedPath = await saveFile(bytes, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colors.primary,
            content: Text(
              savedPath != null && savedPath.isNotEmpty
                  ? 'PDF generated: $fileName'
                  : 'PDF report generated successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to generate PDF: $e';
        if (e is ApiException) {
          msg = e.message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colors.error,
            content: Text(msg),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  Future<void> _exportExcel() async {
    if (_selectedClass == null || _isExportingPdf || _isExportingExcel) return;
    if (_rangeFromDate.isAfter(_rangeToDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date cannot be after To date.')),
      );
      return;
    }

    setState(() => _isExportingExcel = true);
    final facultyService = Provider.of<FacultyService>(context, listen: false);

    try {
      final bytes = await facultyService.downloadAttendanceRangeExcel(
        classId: _selectedClass!.id,
        fromDate: _formatDate(_rangeFromDate),
        toDate: _formatDate(_rangeToDate),
        subjectId: _selectedSubject?.id,
      );

      final subjectPart = _selectedSubject != null ? 'sub_${_selectedSubject!.id}' : 'all_subjects';
      final fileName =
          'attendance_report_${_selectedClass!.id}_${subjectPart}_${_formatDate(_rangeFromDate)}_${_formatDate(_rangeToDate)}.xlsx';
      final savedPath = await saveFile(bytes, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colors.primary,
            content: Text(
              savedPath != null && savedPath.isNotEmpty
                  ? 'Excel generated: $fileName'
                  : 'Excel report generated successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to export Excel: $e';
        if (e is ApiException) {
          msg = e.message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colors.error,
            content: Text(msg),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingExcel = false);
      }
    }
  }


  Future<void> _showStudentDetail(int studentId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentDetailModal(
        studentId: studentId,
        subjectId: _selectedSubject?.id,
      ),
    );
  }

  Widget _buildModeTab(int mode, String label, IconData icon) {
    final isSelected = _viewMode == mode;
    final colors = context.colors;
    final typography = context.typography;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_viewMode != mode) {
            setState(() => _viewMode = mode);
            _loadCurrentReport();
          }
        },
        borderRadius: AppRadius.smallBorder,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: AppRadius.smallBorder,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.copyWith(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectors() {
    if (_options == null || _options!.classes.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final typography = context.typography;
    final isAdvisorForSelected = _selectedClass?.isAdvisorForClass ?? false;

    return GlassCard(
      variant: GlassCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Class Selector Dropdown
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.school_rounded, size: 18, color: colors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Class:',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<AuthorizedClassOptionModel>(
                  initialValue: _selectedClass,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  dropdownColor: colors.surface,
                  items: _options!.classes.map((c) {
                    return DropdownMenuItem<AuthorizedClassOptionModel>(
                      value: c,
                      child: Text(
                        c.name + (c.isAdvisorForClass ? ' (Class Advisor)' : ''),
                        style: typography.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onClassChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Subject Selector Dropdown
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.menu_book_rounded, size: 18, color: colors.accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Subject:',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<AuthorizedSubjectOptionModel?>(
                  key: ValueKey('${_selectedClass?.id}_${_selectedSubject?.id}_$isAdvisorForSelected'),
                  initialValue: _selectedSubject,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  dropdownColor: colors.surface,
                  items: [
                    if (isAdvisorForSelected)
                      DropdownMenuItem<AuthorizedSubjectOptionModel?>(
                        value: null,
                        child: Text(
                          'All Subjects (Advisor Scope)',
                          style: typography.bodyMedium.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ...(_selectedClass?.subjects ?? []).map((s) {
                      return DropdownMenuItem<AuthorizedSubjectOptionModel?>(
                        value: s,
                        child: Text(
                          '${s.code} - ${s.name}',
                          style: typography.bodyMedium.copyWith(
                            fontSize: 13,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: _onSubjectChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Mode Toggle: Class Summary (0) vs Daily Matrix (1) vs Historical Matrix (2) vs Date Range (3)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surfaceMuted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                _buildModeTab(0, 'Summary', Icons.people_alt_rounded),
                const SizedBox(width: 2),
                _buildModeTab(1, 'Daily Matrix', Icons.calendar_today_rounded),
                const SizedBox(width: 2),
                _buildModeTab(2, 'Historical', Icons.history_rounded),
                const SizedBox(width: 2),
                _buildModeTab(3, 'Date Range', Icons.summarize_rounded),
              ],
            ),
          ),

          // Date Picker bar if in Daily Matrix mode
          if (_viewMode == 1) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Date: ${_formatDate(_selectedDate)}',
                          style: typography.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Change Date',
                      style: typography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Date Range bar if in Historical Matrix mode
          if (_viewMode == 2) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.date_range_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Range: ${_histStartDate != null ? _formatDate(_histStartDate!) : "Start"} → ${_histEndDate != null ? _formatDate(_histEndDate!) : "Today"}',
                          style: typography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Filter Range',
                      style: typography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Notice bar if in Date Range Export mode
          if (_viewMode == 3) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded, size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PDF & Excel Export with customizable date range',
                      style: typography.caption.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoRecordsAvailableCard({
    required String title,
    required String message,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.standard,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 38,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: typography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: typography.bodyMedium.copyWith(
                color: colors.textMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSummaryView() {
    if (_classSummary == null || !_classSummary!.hasAttendanceRecords) {
      return _buildNoRecordsAvailableCard(
        title: 'NO RECORDS AVAILABLE',
        message:
            'No attendance records are available for this class selection. The class has no recorded attendance.',
      );
    }

    final colors = context.colors;
    final typography = context.typography;
    final s = _classSummary!;
    final filteredStudents = s.students.where((st) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return st.fullName.toLowerCase().contains(query) || st.rollNumber.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Class Stats Aggregate Card
        GlassCard(
          variant: GlassCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.className,
                          style: typography.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.subjectName ?? 'All Subjects Aggregate',
                          style: typography.bodySmall.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: colors.primary, width: 1.2),
                    ),
                    child: Text(
                      '${s.percentage.toStringAsFixed(1)}% Avg',
                      style: typography.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _buildMiniStat('Periods', '${s.totalPeriods}', colors.textPrimary),
                  const SizedBox(width: AppSpacing.xs),
                  _buildMiniStat('Present', '${s.present}', colors.present),
                  const SizedBox(width: AppSpacing.xs),
                  _buildMiniStat('Absent', '${s.absent}', colors.absent),
                  const SizedBox(width: AppSpacing.xs),
                  _buildMiniStat('OD', '${s.od}', colors.od),
                  const SizedBox(width: AppSpacing.xs),
                  _buildMiniStat('Students', '${s.students.length}', colors.textPrimary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Search Field
        TextField(
          style: typography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by student name or roll number...',
            hintStyle: typography.bodyMedium.copyWith(color: colors.textMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: colors.textMuted),
            isDense: true,
            filled: true,
            fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide(color: colors.border),
            ),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim();
            });
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // Students Roster List
        if (filteredStudents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'No students match the criteria.',
                style: typography.bodyMedium.copyWith(color: colors.textMuted),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredStudents.length,
            itemBuilder: (ctx, idx) {
              final student = filteredStudents[idx];
              Color pctColor = student.percentage >= 75.0
                  ? colors.present
                  : (student.percentage >= 65.0 ? colors.warning : colors.error);

              return GlassCard(
                variant: GlassCardVariant.standard,
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.surfaceMuted,
                    child: Text(
                      '${idx + 1}',
                      style: typography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  title: Text(
                    student.fullName,
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Roll: ${student.rollNumber} • P: ${student.present} | A: ${student.absent} | OD: ${student.od}',
                    style: typography.bodySmall.copyWith(color: colors.textMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: pctColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          border: Border.all(color: pctColor, width: 1),
                        ),
                        child: Text(
                          '${student.percentage.toStringAsFixed(1)}%',
                          style: typography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: pctColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: colors.textMuted, size: 20),
                    ],
                  ),
                  onTap: () => _showStudentDetail(student.studentId),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    final colors = context.colors;
    final typography = context.typography;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: colors.surfaceMuted.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: typography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: typography.caption.copyWith(
                fontSize: 9,
                color: colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixTable({
    required List<DateMatrixPeriodHeaderModel> periods,
    required List<DateMatrixStudentRowModel> students,
    required bool isAdvisorScope,
    required String lunchInterval,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    if (periods.isEmpty) {
      return GlassCard(
        variant: GlassCardVariant.standard,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No authorized periods scheduled for this date.',
            style: typography.bodyMedium.copyWith(color: colors.textMuted),
          ),
        ),
      );
    }

    if (students.isEmpty) {
      return GlassCard(
        variant: GlassCardVariant.standard,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No student records available.',
            style: typography.bodyMedium.copyWith(color: colors.textMuted),
          ),
        ),
      );
    }

    final morningPeriods = periods.where((p) => p.periodNumber <= 4).toList();
    final afternoonPeriods = periods.where((p) => p.periodNumber >= 5).toList();

    return GlassCard(
      variant: GlassCardVariant.standard,
      padding: EdgeInsets.zero,
      enableBlur: false, // Performance optimization for large tables
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          headingRowHeight: 48,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          horizontalMargin: 14,
          headingRowColor: WidgetStateProperty.all(colors.surfaceMuted.withValues(alpha: 0.5)),
          columns: isAdvisorScope
              ? [
                  DataColumn(
                    label: Text('Roll No', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  ),
                  DataColumn(
                    label: Text('Student', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  ),
                  // Morning P1 to P4
                  ...morningPeriods.map((p) {
                    final title = p.subjectCode != null && p.subjectCode!.isNotEmpty ? '${p.subjectCode}\nP${p.periodNumber}' : 'P${p.periodNumber}';
                    return DataColumn(
                      label: Text(title, style: typography.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 10, color: colors.primary), textAlign: TextAlign.center),
                    );
                  }),
                  // Lunch Break (Not Counted)
                  DataColumn(
                    label: Text('LUNCH\n(Not Counted)', style: typography.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 9, color: colors.textMuted), textAlign: TextAlign.center),
                  ),
                  // Afternoon P5 to P7
                  ...afternoonPeriods.map((p) {
                    final title = p.subjectCode != null && p.subjectCode!.isNotEmpty ? '${p.subjectCode}\nP${p.periodNumber}' : 'P${p.periodNumber}';
                    return DataColumn(
                      label: Text(title, style: typography.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 10, color: colors.primary), textAlign: TextAlign.center),
                    );
                  }),
                  // Daily Result
                  DataColumn(
                    label: Text('Daily Result', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  ),
                ]
              : [
                  DataColumn(
                    label: Text('Roll No', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  ),
                  DataColumn(
                    label: Text('Student', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  ),
                  ...periods.map((p) {
                    final title = p.subjectCode != null && p.subjectCode!.isNotEmpty ? '${p.subjectCode}\nP${p.periodNumber}' : 'P${p.periodNumber}';
                    return DataColumn(
                      label: Text(title, style: typography.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 10, color: colors.primary), textAlign: TextAlign.center),
                    );
                  }),
                  DataColumn(
                    label: Text('Status', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  ),
                ],
          rows: students.map((student) {
            Color dailyColor = colors.textMuted;
            switch (student.dailyResult.toUpperCase()) {
              case 'FULL_DAY_PRESENT':
              case 'PRESENT':
                dailyColor = colors.present;
                break;
              case 'HALF_DAY_PRESENT':
                dailyColor = colors.warning;
                break;
              case 'FULL_DAY_ABSENT':
              case 'ABSENT':
                dailyColor = colors.absent;
                break;
              case 'OD':
                dailyColor = colors.od;
                break;
            }

            final nameCell = DataCell(
              InkWell(
                onTap: () => _showStudentDetail(student.studentId),
                child: Text(
                  student.fullName,
                  style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
              ),
            );

            final rollCell = DataCell(
              Text(student.rollNumber, style: typography.bodySmall.copyWith(fontSize: 11, color: colors.textMuted)),
            );

            final statusResultCell = DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: dailyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: dailyColor, width: 1),
                ),
                child: Text(
                  student.dailyResult.replaceAll('_', ' '),
                  style: typography.caption.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: dailyColor),
                ),
              ),
            );

            if (isAdvisorScope) {
              return DataRow(
                cells: [
                  rollCell,
                  nameCell,
                  ...morningPeriods.map((p) => DataCell(_buildMatrixCell(student.periodStatuses[p.periodNumber.toString()] ?? student.periodStatuses['${p.periodNumber}'] ?? '-'))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('L', style: typography.caption.copyWith(fontSize: 10, color: colors.textMuted)),
                    ),
                  ),
                  ...afternoonPeriods.map((p) => DataCell(_buildMatrixCell(student.periodStatuses[p.periodNumber.toString()] ?? student.periodStatuses['${p.periodNumber}'] ?? '-'))),
                  statusResultCell,
                ],
              );
            } else {
              return DataRow(
                cells: [
                  rollCell,
                  nameCell,
                  ...periods.map((p) => DataCell(_buildMatrixCell(student.periodStatuses[p.periodNumber.toString()] ?? student.periodStatuses['${p.periodNumber}'] ?? '-'))),
                  statusResultCell,
                ],
              );
            }
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDateMatrixView() {
    final formattedDate = _formatDate(_selectedDate);

    if (_dateMatrix == null || !_dateMatrix!.hasAttendanceRecords) {
      return _buildNoRecordsAvailableCard(
        title: 'NO RECORDS AVAILABLE',
        message:
            'No attendance records are available for $formattedDate. The class has no recorded attendance for this date.',
      );
    }

    final colors = context.colors;
    final typography = context.typography;
    final m = _dateMatrix!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Matrix Header Info
        GlassCard(
          variant: GlassCardVariant.standard,
          padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m.date} (${m.dayOfWeek})',
                      style: typography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.className} • ${m.subjectName ?? "All Subjects"} • ${m.students.length} Students',
                      style: typography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'LUNCH BREAK',
                      style: typography.caption.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colors.textMuted,
                      ),
                    ),
                    Text(
                      m.lunchInterval,
                      style: typography.bodySmall.copyWith(
                        fontSize: 9,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Matrix Table
        _buildMatrixTable(
          periods: m.periods,
          students: m.students,
          isAdvisorScope: m.isClassAdvisorScope,
          lunchInterval: m.lunchInterval,
        ),
      ],
    );
  }

  Widget _buildHistoricalStudentSummary(FacultyHistoricalMatrixModel hm) {
    if (hm.students.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.standard,
      padding: EdgeInsets.zero,
      enableBlur: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 44,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          horizontalMargin: 14,
          headingRowColor: WidgetStateProperty.all(colors.surfaceMuted.withValues(alpha: 0.5)),
          columns: [
            DataColumn(label: Text('Roll No', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
            DataColumn(label: Text('Student', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary))),
            DataColumn(label: Text('Total', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textMuted))),
            DataColumn(label: Text('P', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.present))),
            DataColumn(label: Text('A', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.absent))),
            DataColumn(label: Text('OD', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.od))),
            DataColumn(label: Text('Attendance %', style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.primary))),
          ],
          rows: hm.students.map((st) {
            Color pctColor = st.percentage >= 75.0
                ? colors.present
                : (st.percentage >= 65.0 ? colors.warning : colors.error);

            return DataRow(
              cells: [
                DataCell(Text(st.rollNumber, style: typography.bodySmall.copyWith(fontSize: 11, color: colors.textMuted))),
                DataCell(
                  InkWell(
                    onTap: () => _showStudentDetail(st.studentId),
                    child: Text(
                      st.fullName,
                      style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                  ),
                ),
                DataCell(Text('${st.total}', style: typography.bodySmall.copyWith(fontSize: 11, color: colors.textPrimary))),
                DataCell(Text('${st.present}', style: typography.bodySmall.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: colors.present))),
                DataCell(Text('${st.absent}', style: typography.bodySmall.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: colors.absent))),
                DataCell(Text('${st.od}', style: typography.bodySmall.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: colors.od))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pctColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: pctColor, width: 1),
                    ),
                    child: Text(
                      '${st.percentage.toStringAsFixed(1)}%',
                      style: typography.caption.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: pctColor),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoricalDateCard(HistoricalMatrixDateEntryModel dateEntry, bool isAdvisorScope) {
    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.standard,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: colors.surfaceMuted,
            child: Icon(Icons.event_note_rounded, size: 16, color: colors.primary),
          ),
          title: Text(
            '${dateEntry.date} (${dateEntry.dayOfWeek})',
            style: typography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
          subtitle: Text(
            dateEntry.hasAttendanceRecords
                ? '${dateEntry.periods.length} scheduled period(s) • ${dateEntry.students.length} students'
                : 'No attendance records',
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: dateEntry.hasAttendanceRecords
                  ? _buildMatrixTable(
                      periods: dateEntry.periods,
                      students: dateEntry.students,
                      isAdvisorScope: isAdvisorScope,
                      lunchInterval: dateEntry.lunchInterval,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No attendance records are available for ${dateEntry.date}.',
                        style: typography.bodyMedium.copyWith(color: colors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalMatrixView() {
    if (_historicalMatrix == null || !_historicalMatrix!.hasAttendanceRecords) {
      final rangeText = (_histStartDate != null && _histEndDate != null)
          ? '${_formatDate(_histStartDate!)} to ${_formatDate(_histEndDate!)}'
          : (_historicalMatrix != null
              ? '${_historicalMatrix!.startDate} to ${_historicalMatrix!.endDate}'
              : 'the selected date range');
      return _buildNoRecordsAvailableCard(
        title: 'NO RECORDS AVAILABLE',
        message:
            'No attendance records are available for $rangeText. The class has no recorded attendance for these dates.',
      );
    }

    final colors = context.colors;
    final typography = context.typography;
    final hm = _historicalMatrix!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Historical Header Card
        GlassCard(
          variant: GlassCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hm.className,
                          style: typography.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hm.subjectName != null
                              ? '${hm.subjectCode} - ${hm.subjectName}'
                              : 'All Subjects (Class Advisor Scope)',
                          style: typography.bodySmall.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hm.isClassAdvisorScope
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(
                        color: hm.isClassAdvisorScope ? colors.primary : colors.accent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      hm.isClassAdvisorScope ? 'Advisor Scope' : 'Subject Faculty',
                      style: typography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hm.isClassAdvisorScope ? colors.primary : colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Range: ${hm.startDate} to ${hm.endDate}',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${hm.totalDates} Day(s) • ${hm.students.length} Students',
                    style: typography.bodySmall.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Start Date: ${hm.attendanceStartDate} | Today (IST): ${hm.currentDate}',
                style: typography.bodySmall.copyWith(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Section Title: Student Overall Aggregate
        Text(
          'Student Aggregate in Range',
          style: typography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Student Aggregate Table
        _buildHistoricalStudentSummary(hm),
        const SizedBox(height: AppSpacing.lg),

        // Section Title: Date-by-Date Breakdown
        Text(
          'Date-wise Period Attendance Breakdown',
          style: typography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Date-by-Date Accordions
        ...hm.dates.map((dateEntry) => _buildHistoricalDateCard(dateEntry, hm.isClassAdvisorScope)).toList(),
      ],
    );
  }

  Widget _buildMatrixCell(String status) {
    return PeriodStatusChip(
      status: status,
      size: PeriodChipSize.compact,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Phase 9: Date Range Report View Components
  // ─────────────────────────────────────────────────────────────

  Widget _buildDateRangeReportView() {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date Range Selector Card
        GlassCard(
          variant: GlassCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Date Range Selection',
                    style: typography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickRangeFromDate,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          border: Border.all(color: colors.glassBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From Date',
                              style: typography.caption.copyWith(color: colors.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(_rangeFromDate),
                                  style: typography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Icon(Icons.calendar_today_rounded, size: 14, color: colors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
                      onTap: _pickRangeToDate,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          border: Border.all(color: colors.glassBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To Date',
                              style: typography.caption.copyWith(color: colors.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(_rangeToDate),
                                  style: typography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Icon(Icons.calendar_today_rounded, size: 14, color: colors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_rangeValidationError != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _rangeValidationError!,
                  style: typography.caption.copyWith(color: colors.error, fontWeight: FontWeight.bold),
                ),
              ],

              const SizedBox(height: AppSpacing.sm),
              // Quick date range presets
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildRangePresetChip('Past 7 Days', 7),
                  _buildRangePresetChip('Past 14 Days', 14),
                  _buildRangePresetChip('Past 30 Days', 30),
                  _buildRangePresetChip('This Month', -1),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Export Buttons Bar
              Row(
                children: [
                  // Generate PDF Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isExportingPdf || _isExportingExcel ? null : _exportPdf,
                        icon: _isExportingPdf
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded, size: 20),
                        label: Text(
                          _isExportingPdf ? 'Generating PDF...' : 'Generate PDF',
                          style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Export Excel Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isExportingPdf || _isExportingExcel ? null : _exportExcel,
                        icon: _isExportingExcel
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.table_view_rounded, size: 20),
                        label: Text(
                          _isExportingExcel ? 'Exporting...' : 'Export Excel',
                          style: typography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Report preview / results
        if (_rangeReport == null || !_rangeReport!.hasRecords)
          _buildNoRecordsAvailableCard(
            title: 'NO RECORDS AVAILABLE',
            message:
                'No attendance records found for this class and subject in the selected date range (${_formatDate(_rangeFromDate)} to ${_formatDate(_rangeToDate)}).',
          )
        else ...[
          // Summary Header Card
          _buildRangeSummaryCard(_rangeReport!),
          const SizedBox(height: AppSpacing.md),
          // Student Summary Table Card
          _buildRangeStudentSummaryCard(_rangeReport!),
          const SizedBox(height: AppSpacing.md),
          // Periods Conducted Summary Card
          _buildRangePeriodSummaryCard(_rangeReport!),
        ],
      ],
    );
  }

  Widget _buildRangePresetChip(String label, int days) {
    final colors = context.colors;
    final typography = context.typography;
    final now = DateTime.now();

    return ActionChip(
      label: Text(label, style: typography.caption.copyWith(fontSize: 11)),
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      onPressed: () {
        setState(() {
          _rangeToDate = now;
          if (days > 0) {
            _rangeFromDate = now.subtract(Duration(days: days));
          } else {
            // This Month (from 1st of current month)
            _rangeFromDate = DateTime(now.year, now.month, 1);
          }
          if (_minAttendanceDate != null && _rangeFromDate.isBefore(_minAttendanceDate!)) {
            _rangeFromDate = _minAttendanceDate!;
          }
        });
        _loadCurrentReport();
      },
    );
  }

  Widget _buildRangeSummaryCard(AttendanceRangeReportModel report) {
    final colors = context.colors;
    final typography = context.typography;
    final avgPct = report.percentage ?? 0.0;
    Color pctColor = avgPct >= 75.0
        ? colors.present
        : (avgPct >= 65.0 ? colors.warning : colors.error);

    return GlassCard(
      variant: GlassCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.className,
                      style: typography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.subjectName != null
                          ? '${report.subjectCode} - ${report.subjectName}'
                          : 'All Subjects (Class Advisor Scope)',
                      style: typography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                    if (report.scopeNote != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        report.scopeNote!,
                        style: typography.caption.copyWith(color: colors.accent, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: pctColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: pctColor, width: 1.2),
                ),
                child: Text(
                  report.percentage != null
                      ? '${report.percentage!.toStringAsFixed(1)}%'
                      : 'N/A',
                  style: typography.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: pctColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Range: ${report.fromDate} to ${report.toDate}',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                '${report.totalDays} Day(s) • ${report.totalPeriodsConducted} Conducted',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildMiniStat('Total Marked', '${report.totalMarked}', colors.textPrimary),
              const SizedBox(width: AppSpacing.xs),
              _buildMiniStat('Present', '${report.present}', colors.present),
              const SizedBox(width: AppSpacing.xs),
              _buildMiniStat('Absent', '${report.absent}', colors.absent),
              const SizedBox(width: AppSpacing.xs),
              _buildMiniStat('OD', '${report.od}', colors.od),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            report.percentageBasis,
            style: typography.caption.copyWith(
              color: colors.textMuted,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeStudentSummaryCard(AttendanceRangeReportModel report) {
    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Summary (${report.summary.length})',
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'Policy Percentage',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: AppSpacing.xs),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: colors.surfaceElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '#',
                    style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textMuted),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Student',
                    style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.textMuted),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    'P',
                    textAlign: TextAlign.center,
                    style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.present),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    'A',
                    textAlign: TextAlign.center,
                    style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.absent),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    'OD',
                    textAlign: TextAlign.center,
                    style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.od),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    'Att %',
                    textAlign: TextAlign.end,
                    style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Student Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.summary.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
            itemBuilder: (ctx, idx) {
              final st = report.summary[idx];
              final pct = st.percentage;
              Color pctColor = colors.textMuted;
              if (pct != null) {
                pctColor = pct >= 75.0
                    ? colors.present
                    : (pct >= 65.0 ? colors.warning : colors.error);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${idx + 1}',
                        style: typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            st.fullName,
                            style: typography.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            st.rollNumber,
                            style: typography.caption.copyWith(fontSize: 10, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${st.present}',
                        textAlign: TextAlign.center,
                        style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${st.absent}',
                        textAlign: TextAlign.center,
                        style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${st.od}',
                        textAlign: TextAlign.center,
                        style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        pct != null ? '${pct.toStringAsFixed(1)}%' : '—',
                        textAlign: TextAlign.end,
                        style: typography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: pctColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRangePeriodSummaryCard(AttendanceRangeReportModel report) {
    if (report.periodSummary.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;

    return GlassCard(
      variant: GlassCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Periods Conducted (${report.periodSummary.length})',
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: AppSpacing.xs),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.periodSummary.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
            itemBuilder: (ctx, idx) {
              final p = report.periodSummary[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        'P${p.periodNumber}',
                        style: typography.caption.copyWith(fontWeight: FontWeight.bold, color: colors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.date} • ${p.periodName}',
                            style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          Text(
                            '${p.subjectCode} - ${p.subjectName}',
                            style: typography.caption.copyWith(color: colors.textMuted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('P:${p.present} ', style: typography.caption.copyWith(color: colors.present, fontWeight: FontWeight.bold)),
                        Text('A:${p.absent} ', style: typography.caption.copyWith(color: colors.absent, fontWeight: FontWeight.bold)),
                        Text('OD:${p.od}', style: typography.caption.copyWith(color: colors.od, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdvisor = _selectedClass?.isAdvisorForClass ?? false;
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          isAdvisor ? 'CLASS ADVISOR ATTENDANCE MATRIX' : 'FACULTY ATTENDANCE REPORT',
          style: typography.headlineMedium.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadCurrentReport,
          ),
        ],
      ),
      body: _isLoadingOptions
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              onRefresh: _loadCurrentReport,
              color: colors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error message banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colors.errorBg,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: colors.error),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: colors.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: typography.bodySmall.copyWith(color: colors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Class and Subject Selectors + Mode Buttons
                    _buildSelectors(),
                    const SizedBox(height: AppSpacing.md),

                    // Body: Loading or Selected View
                    if (_isLoadingReport)
                      Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator(color: colors.primary)),
                      )
                    else if (_viewMode == 0)
                      _buildClassSummaryView()
                    else if (_viewMode == 1)
                      _buildDateMatrixView()
                    else if (_viewMode == 2)
                      _buildHistoricalMatrixView()
                    else
                      _buildDateRangeReportView(),

                    const SizedBox(height: AppSpacing.lg),

                    // Status Legend
                    const AttendanceLegend(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Student Detail Modal (When Faculty taps a student row)
// ─────────────────────────────────────────────────────────────

class _StudentDetailModal extends StatefulWidget {
  final int studentId;
  final int? subjectId;

  const _StudentDetailModal({
    Key? key,
    required this.studentId,
    this.subjectId,
  }) : super(key: key);

  @override
  State<_StudentDetailModal> createState() => _StudentDetailModalState();
}

class _StudentDetailModalState extends State<_StudentDetailModal> {
  bool _loading = true;
  String? _error;
  FacultyStudentDetailModel? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final facultyService = Provider.of<FacultyService>(context, listen: false);
      final detail = await facultyService.fetchStudentDetailReport(
        studentId: widget.studentId,
        subjectId: widget.subjectId,
      );
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load student details: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(child: CircularProgressIndicator(color: colors.primary)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  _error!,
                  style: typography.bodyMedium.copyWith(color: colors.error),
                ),
              ),
            )
          else if (_detail != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _detail!.fullName,
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Roll: ${_detail!.rollNumber} • ${_detail!.className}',
                          style: typography.bodySmall.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: colors.primary, width: 1.2),
                    ),
                    child: Text(
                      '${_detail!.percentage.toStringAsFixed(1)}%',
                      style: typography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildDetailMiniStat('Total', '${_detail!.total}', colors.textPrimary),
                  const SizedBox(width: AppSpacing.xs),
                  _buildDetailMiniStat('Present', '${_detail!.present}', colors.present),
                  const SizedBox(width: AppSpacing.xs),
                  _buildDetailMiniStat('Absent', '${_detail!.absent}', colors.absent),
                  const SizedBox(width: AppSpacing.xs),
                  _buildDetailMiniStat('OD', '${_detail!.od}', colors.od),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            Divider(height: 20, color: colors.border),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _detail!.dateWise.length,
                itemBuilder: (ctx, idx) {
                  final d = _detail!.dateWise[idx];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              d.date,
                              style: typography.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (d.dailyResult != null)
                              Text(
                                d.dailyResult!.replaceAll('_', ' '),
                                style: typography.caption.copyWith(
                                  fontSize: 10,
                                  color: colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: d.periods.map((p) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'P${p.periodNumber}: ',
                                  style: typography.caption.copyWith(
                                    fontSize: 10,
                                    color: colors.textMuted,
                                  ),
                                ),
                                PeriodStatusChip(
                                  status: p.status,
                                  odReason: p.odReason,
                                  size: PeriodChipSize.compact,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailMiniStat(String label, String value, Color color) {
    final colors = context.colors;
    final typography = context.typography;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: colors.surfaceMuted.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: typography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: typography.caption.copyWith(
                fontSize: 9,
                color: colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
