import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AttendanceGauge extends StatefulWidget {
  final double percentage;
  final double size;
  final double strokeWidth;
  final bool showStatusText;
  final bool animate;

  const AttendanceGauge({
    Key? key,
    required this.percentage,
    this.size = 140.0,
    this.strokeWidth = 10.0,
    this.showStatusText = true,
    this.animate = true,
  }) : super(key: key);

  @override
  State<AttendanceGauge> createState() => _AttendanceGaugeState();
}

class _AttendanceGaugeState extends State<AttendanceGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.percentage.clamp(0.0, 100.0)).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.emphasizedDecel),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AttendanceGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.percentage.clamp(0.0, 100.0),
      ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.emphasizedDecel));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations && _controller.value < 1.0) {
      _controller.value = 1.0;
    }

    final statusStyle = colors.healthStyle(widget.percentage);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentVal = disableAnimations ? widget.percentage : _animation.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _GaugePainter(
                      percentage: currentVal,
                      trackColor: colors.surfaceMuted,
                      progressColor: statusStyle.fg,
                      strokeWidth: widget.strokeWidth,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${currentVal.toStringAsFixed(1)}%',
                        style: (widget.size >= 120.0 ? typography.numeric : typography.titleMedium).copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'ATTENDANCE',
                        style: typography.caption.copyWith(
                          fontSize: 9.0,
                          color: colors.textMuted,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.showStatusText) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusStyle.bg,
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusStyle.icon, size: AppIconSize.statusChip, color: statusStyle.fg),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      statusStyle.label,
                      style: typography.caption.copyWith(
                        color: statusStyle.fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _GaugePainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    final sweepAngle = (percentage / 100.0) * 2 * math.pi;
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Start from top (-pi / 2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
