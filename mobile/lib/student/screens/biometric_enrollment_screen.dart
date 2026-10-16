import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/biometric_enrollment_model.dart';
import '../../services/biometric_enrollment_service.dart';
import '../../widgets/widgets.dart';

class BiometricEnrollmentScreen extends StatefulWidget {
  const BiometricEnrollmentScreen({Key? key}) : super(key: key);

  @override
  State<BiometricEnrollmentScreen> createState() => _BiometricEnrollmentScreenState();
}

class _BiometricEnrollmentScreenState extends State<BiometricEnrollmentScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _showingIntro = true;
  String _currentStep = 'FRONTAL';
  bool _isMirrored = false;

  @override
  void initState() {
    super.initState();
    _retrieveLostData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<BiometricEnrollmentService>(context, listen: false);
      service.fetchEnrollmentStatus().then((_) {
        _syncCurrentStep(service.status);
      });
    });
  }

  Future<void> _retrieveLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null && mounted) {
        final file = File(response.file!.path);
        setState(() {
          _selectedImage = file;
        });
        final service = Provider.of<BiometricEnrollmentService>(context, listen: false);
        await service.validatePose(file, _currentStep, mirrored: _isMirrored);
      } else if (response.exception != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: ${response.exception!.message}')),
        );
      }
    } catch (_) {}
  }

  void _syncCurrentStep(EnrollmentStatusModel? status) {
    if (status == null) return;
    if (status.templatesCount == 0) {
      _currentStep = 'FRONTAL';
    } else if (status.templatesCount == 1) {
      _currentStep = 'LEFT_15';
    } else if (status.templatesCount == 2) {
      _currentStep = 'RIGHT_15';
    } else {
      _currentStep = 'COMPLETE';
    }
  }

  String _getStepBadgeText(String step) {
    switch (step) {
      case 'FRONTAL':
        return 'STEP 1 / 3 — FRONT';
      case 'LEFT_15':
        return 'STEP 2 / 3 — LEFT ~15°';
      case 'RIGHT_15':
        return 'STEP 3 / 3 — RIGHT ~15°';
      default:
        return 'COMPLETE';
    }
  }

  String _getStepTitle(String step) {
    switch (step) {
      case 'FRONTAL':
        return 'Step 1 of 3: Frontal Reference';
      case 'LEFT_15':
        return 'Step 2 of 3: Slight Left Angle (15°)';
      case 'RIGHT_15':
        return 'Step 3 of 3: Slight Right Angle (15°)';
      default:
        return 'Enrollment Complete';
    }
  }

  String _getStepTargetAngle(String step) {
    switch (step) {
      case 'FRONTAL':
        return 'Target: 0° ±5° (Center)';
      case 'LEFT_15':
        return 'Target: approximately 15° left';
      case 'RIGHT_15':
        return 'Target: approximately 15° right';
      default:
        return 'All captures accepted';
    }
  }

  List<String> _getStepGuidance(String step) {
    switch (step) {
      case 'FRONTAL':
        return const [
          'Look directly at the camera.',
          'Keep your head straight.',
          'Keep both eyes clearly visible.',
          'Keep your nose centered between the eyes.',
          'Do not tilt or rotate your head.'
        ];
      case 'LEFT_15':
        return const [
          'Slowly turn your head slightly to the LEFT.',
          'Do not move the camera.',
          'Keep both eyes visible.',
          'Do not tilt your head upward or downward.'
        ];
      case 'RIGHT_15':
        return const [
          'Slowly turn your head slightly to the RIGHT.',
          'Do not move the camera.',
          'Keep both eyes visible.',
          'Do not tilt your head upward or downward.'
        ];
      default:
        return const ['Enrollment verified.'];
    }
  }

  Future<void> _pickAndValidateImage(ImageSource source) async {
    final service = Provider.of<BiometricEnrollmentService>(context, listen: false);
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      setState(() {
        _selectedImage = file;
      });

      await service.validatePose(file, _currentStep, mirrored: _isMirrored);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing camera/image: $e')),
      );
    }
  }

  Future<void> _submitCapture() async {
    if (_selectedImage == null) return;
    final service = Provider.of<BiometricEnrollmentService>(context, listen: false);
    final colors = context.colors;

    final success = await service.captureTemplate(_selectedImage!, _currentStep, mirrored: _isMirrored);
    if (!mounted) return;

    if (success) {
      setState(() {
        _selectedImage = null;
        _syncCurrentStep(service.status);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.present,
          content: Text(service.successMessage ?? 'Capture accepted!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.absent,
          content: Text(service.errorMessage ?? 'Capture failed validation. Please retry.'),
        ),
      );
    }
  }

  void _confirmReset() {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: BorderSide(color: colors.border),
        ),
        title: Text('Reset Face Enrollment?', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
        content: Text(
          'This will delete all previously captured face templates and restart the 3-step capture process.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final service = Provider.of<BiometricEnrollmentService>(context, listen: false);
              await service.resetEnrollment();
              setState(() {
                _selectedImage = null;
                _currentStep = 'FRONTAL';
              });
            },
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroView() {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Centered floating animated character above the card
              const _FaceCharacterAnimation(),

              // 2. Vertical gap between character and card (12px, within 8–16px spec)
              const SizedBox(height: 12),

              // 3. Existing Face Capture Protocol card
              GlassCard(
                variant: GlassCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: colors.heroChip,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.face_retouching_natural_rounded, color: colors.primary, size: 28),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Face Capture Protocol',
                            style: typography.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Before starting:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('• Use good, even lighting.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('• Keep the camera at eye level.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('• Keep your face fully visible.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('• Remove sunglasses/masks where possible.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('• Keep the camera steady.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('• Do not use another person\'s photo.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'You will capture 3 face templates:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('1. Straight / Front (0° ±5°)', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('2. Slight Left (~15° ±5°)', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('3. Slight Right (~15° ±5°)', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Follow the on-screen guide for each capture.',
                      style: TextStyle(fontStyle: FontStyle.italic, color: colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      text: 'Start Enrollment',
                      isFullWidth: true,
                      onPressed: () {
                        setState(() {
                          _showingIntro = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(EnrollmentStatusModel? status) {
    final colors = context.colors;
    final count = status?.templatesCount ?? 0;
    final isComplete = count >= 3;

    return GlassCard(
      variant: isComplete ? GlassCardVariant.elevated : GlassCardVariant.standard,
      tint: isComplete ? colors.presentBg : null,
      borderColor: isComplete ? colors.present : null,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isComplete ? 'ENROLLMENT COMPLETE' : 'ENROLLMENT IN PROGRESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isComplete ? colors.present : colors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete ? colors.present : colors.primary,
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  '$count / 3 Captures',
                  style: TextStyle(
                    color: isComplete ? Colors.white : colors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (count / 3.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? colors.present : colors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isComplete
                ? 'Face enrollment complete — 3 of 3 captures accepted.'
                : (status?.message ?? 'Complete all 3 captures to finish enrollment.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isComplete ? colors.present : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAssistanceGuide(PoseValidationResultModel val) {
    final colors = context.colors;
    final bool isReady = val.isReady;
    final statusColor = isReady ? colors.present : colors.warning;
    final statusBg = isReady ? colors.presentBg : colors.warningBg;

    // Qualitative guidance mapping (no raw angles displayed!)
    final bool yawOk = _isYawInRange(val);
    final bool pitchOk = _isPitchInRange(val);
    final bool rollOk = _isRollInRange(val);

    String headAngleText;
    if (yawOk) {
      headAngleText = 'Angle: Correct';
    } else if (val.pose != null && val.pose!.yaw < 0) {
      headAngleText = _currentStep == 'RIGHT_15' ? 'Turn slightly RIGHT' : 'Turn slightly RIGHT';
    } else {
      headAngleText = _currentStep == 'LEFT_15' ? 'Turn slightly LEFT' : 'Turn slightly LEFT';
    }

    String tiltText = pitchOk ? 'Tilt: Level' : 'Tilt: Straighten Head';
    String rollText = rollOk ? 'Position: Upright' : 'Position: Keep Level';

    return GlassCard(
      variant: GlassCardVariant.standard,
      borderColor: statusColor,
      borderWidth: 1.8,
      padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Header Badge
          Row(
            children: [
              Icon(
                isReady ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  val.status.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: AppRadius.smallBorder,
                ),
                child: Text(
                  isReady ? 'READY' : 'RETRY NEEDED',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            val.message,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          Divider(height: 20, color: colors.border),

          // Qualitative Pose Guidance Indicators (No raw numeric angles)
          if (val.pose != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQualitativeChip(headAngleText, yawOk),
                _buildQualitativeChip(tiltText, pitchOk),
                _buildQualitativeChip(rollText, rollOk),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Qualitative Quality & Lighting Feedback
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _buildMiniMetric('Face Detection', val.faceBox != null ? 'Detected' : 'Searching'),
              if (val.lighting != null)
                _buildMiniMetric('Lighting', val.lighting!),
              if (val.confidence != null)
                _buildMiniMetric('Clarity', val.confidence! >= 0.8 ? 'Good' : 'Moderate'),
            ],
          ),
        ],
      ),
    );
  }

  bool _isYawInRange(PoseValidationResultModel val) {
    if (val.pose == null) return false;
    final y = val.pose!.yaw;
    if (_currentStep == 'FRONTAL') return y >= -5.0 && y <= 5.0;
    if (_currentStep == 'LEFT_15') return y >= -20.0 && y <= -10.0;
    if (_currentStep == 'RIGHT_15') return y >= 10.0 && y <= 20.0;
    return false;
  }

  bool _isPitchInRange(PoseValidationResultModel val) {
    if (val.pose == null) return false;
    final p = val.pose!.pitch;
    final maxP = _currentStep == 'FRONTAL' ? 5.0 : 7.0;
    return p >= -maxP && p <= maxP;
  }

  bool _isRollInRange(PoseValidationResultModel val) {
    if (val.pose == null) return false;
    final r = val.pose!.roll;
    return r >= -5.0 && r <= 5.0;
  }

  Widget _buildQualitativeChip(String text, bool inRange) {
    final colors = context.colors;
    final color = inRange ? colors.present : colors.warning;
    final bg = inRange ? colors.presentBg : colors.warningBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.smallBorder,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(inRange ? Icons.check_rounded : Icons.sync_problem_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 11, color: colors.textMuted)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary)),
      ],
    );
  }

  Widget _buildImagePreview(BiometricEnrollmentService service) {
    final colors = context.colors;
    final val = service.lastValidation;
    final isReady = val?.isReady ?? false;

    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: Stack(
        alignment: Alignment.center,
        children: [
          kIsWeb
              ? Image.network(
                  _selectedImage!.path,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.contain,
                )
              : Image.file(
                  _selectedImage!,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),

          // Face Center Oval Guide
          Container(
            width: 140,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(
                color: isReady ? colors.present : Colors.white60,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(70),
            ),
          ),

          // Face Center Target Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isReady ? colors.present : Colors.white70,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(EnrollmentStatusModel status) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.presentBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, size: 72, color: colors.present),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Face Enrollment Complete',
              style: typography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '3 of 3 captures accepted.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.present),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your facial recognition biometric templates are verified and active for AI classroom attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              text: 'Return to Profile',
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              icon: Icon(Icons.restart_alt_rounded, color: colors.error),
              label: Text('Re-enroll Biometrics', style: TextStyle(color: colors.error)),
              onPressed: _confirmReset,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final service = Provider.of<BiometricEnrollmentService>(context);
    final status = service.status;
    final bool isAllCompleted = (status?.templatesCount ?? 0) >= 3;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Biometric Face Enrollment'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Capture Guidelines',
            onPressed: () => setState(() => _showingIntro = true),
          ),
          if ((status?.templatesCount ?? 0) > 0)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset Enrollment',
              onPressed: _confirmReset,
            ),
        ],
      ),
      body: Stack(
        children: [
          AppScaffold.buildLiquidAmbientCanvas(context),
          _showingIntro
              ? _buildIntroView()
              : (isAllCompleted
                  ? _buildCompletedView(status!)
                  : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress Banner
                      _buildProgressHeader(status),
                      const SizedBox(height: AppSpacing.md),

                      // Current Step Card
                      GlassCard(
                        variant: GlassCardVariant.standard,
                        padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStepBadgeText(_currentStep),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: colors.accentStrong,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getStepTitle(_currentStep),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getStepTargetAngle(_currentStep),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.accentStrong,
                              ),
                            ),
                            Divider(height: 18, color: colors.glassBorder),
                            ..._getStepGuidance(_currentStep).map(
                              (g) => Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check, size: 14, color: colors.present),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        g,
                                        style: TextStyle(fontSize: 12, color: colors.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Image Preview with Live Assistance
                      if (_selectedImage != null) ...[
                        _buildImagePreview(service),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Live Pose Assistance & Status Card
                      if (service.lastValidation != null) ...[
                        _buildLiveAssistanceGuide(service.lastValidation!),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Front Camera Mirror Correction Toggle
                      GlassCard(
                        variant: GlassCardVariant.muted,
                        padding: EdgeInsets.zero,
                        child: Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            dense: true,
                            title: Text(
                              'Front Camera Mirror Correction',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                            subtitle: Text(
                              'Turn ON if your selfie camera preview is mirrored',
                              style: TextStyle(fontSize: 11, color: colors.textMuted),
                            ),
                            value: _isMirrored,
                            onChanged: (val) {
                              setState(() {
                                _isMirrored = val;
                              });
                              if (_selectedImage != null) {
                                service.validatePose(_selectedImage!, _currentStep, mirrored: _isMirrored);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Action Buttons
                      if (_selectedImage == null) ...[
                        PrimaryButton(
                          text: 'Take Photo for ${_currentStep.replaceAll('_', ' ')}',
                          icon: Icons.camera_alt_rounded,
                          isFullWidth: true,
                          onPressed: () => _pickAndValidateImage(ImageSource.camera),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SecondaryButton(
                          text: 'Select from Gallery',
                          icon: Icons.photo_library_outlined,
                          isFullWidth: true,
                          onPressed: () => _pickAndValidateImage(ImageSource.gallery),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                text: 'Retake',
                                icon: Icons.refresh,
                                isFullWidth: true,
                                onPressed: () => _pickAndValidateImage(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: PrimaryButton(
                                text: 'Accept & Proceed',
                                icon: Icons.check_circle_outline,
                                isFullWidth: true,
                                onPressed: (service.lastValidation?.isReady ?? false) && !service.isLoading
                                    ? _submitCapture
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (service.isLoading) ...[
                        const SizedBox(height: AppSpacing.lg),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _FaceCharacterAnimation extends StatelessWidget {
  const _FaceCharacterAnimation();

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = MediaQuery.of(context).disableAnimations;

    final poster = Image.asset(
      'assets/animations/face-character-poster.png',
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );

    final animatedAsset = Image.asset(
      'assets/animations/face-character-transparent.webp',
      fit: BoxFit.contain,
      alignment: Alignment.center,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/animations/face-character.gif',
        fit: BoxFit.contain,
        alignment: Alignment.center,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => poster,
      ),
    );

    return RepaintBoundary(
      child: Semantics(
        label: 'Face capture character guide',
        child: SizedBox(
          height: 180,
          width: 180,
          child: isReducedMotion ? poster : animatedAsset,
        ),
      ),
    );
  }
}
