// lib/features/scanner/presentation/widgets/viewfinder_overlay.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/camera_service.dart';

class ViewfinderOverlay extends StatefulWidget {
  const ViewfinderOverlay({
    super.key,
    required this.detectionState,
  });

  final DetectionState detectionState;

  @override
  State<ViewfinderOverlay> createState() => _ViewfinderOverlayState();
}

class _ViewfinderOverlayState extends State<ViewfinderOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppConstants.scanLineDurationMs),
    )..repeat();
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Color get _frameColor {
    return switch (widget.detectionState) {
      DetectionState.idle => AppColors.idle,
      DetectionState.detecting => AppColors.detecting,
      DetectionState.detected => AppColors.detected,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth * AppConstants.viewfinderWidthFactor;
      final h = w / AppConstants.viewfinderAspectRatio;

      return Stack(
        alignment: Alignment.center,
        children: [
          // ── Corner frame ──────────────────────────────────
          AnimatedContainer(
            duration: AppConstants.animNormal,
            width: w,
            height: h,
            child: CustomPaint(
              painter: _CornerFramePainter(
                color: _frameColor,
                strokeWidth: AppConstants.viewfinderCornerStroke,
                cornerLength: AppConstants.viewfinderCornerLength,
                radius: AppConstants.cornerRadius,
              ),
            ),
          ),

          // ── Dashed scan line (always visible) ─────────────
          SizedBox(
            width: w - 16,
            height: h,
            child: AnimatedBuilder(
              animation: _scanAnimation,
              builder: (_, __) => CustomPaint(
                painter: _DashedScanLinePainter(
                  progress: _scanAnimation.value,
                  color: _frameColor,
                ),
              ),
            ),
          ),

          // ── Braille dot grid (decorative) ─────────────────
          Positioned(
            bottom: h * 0.08,
            child: SizedBox(
              width: w - 32,
              child: _BrailleDotGrid(
                detectionState: widget.detectionState,
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ─── Corner Frame ─────────────────────────────────────────────

class _CornerFramePainter extends CustomPainter {
  const _CornerFramePainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corners = <List<Offset>>[
      // top-left
      [
        Offset(radius, cornerLength),
        Offset(radius, radius),
        Offset(cornerLength, radius)
      ],
      // top-right
      [
        Offset(size.width - cornerLength, radius),
        Offset(size.width - radius, radius),
        Offset(size.width - radius, cornerLength),
      ],
      // bottom-right
      [
        Offset(size.width - radius, size.height - cornerLength),
        Offset(size.width - radius, size.height - radius),
        Offset(size.width - cornerLength, size.height - radius),
      ],
      // bottom-left
      [
        Offset(cornerLength, size.height - radius),
        Offset(radius, size.height - radius),
        Offset(radius, size.height - cornerLength),
      ],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CornerFramePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// ─── Dashed Scan Line ─────────────────────────────────────────

class _DashedScanLinePainter extends CustomPainter {
  const _DashedScanLinePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Top-aligned scan position (like the design): stays in upper 40%
    final y = size.height * 0.10 + (size.height * 0.25 * progress);

    final paint = Paint()
      ..color = color.withOpacity(0.75)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw dashed line
    const dashWidth = 6.0;
    const gapWidth = 5.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, y), Offset(math.min(x + dashWidth, size.width), y), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(_DashedScanLinePainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Braille Dot Grid ─────────────────────────────────────────

class _BrailleDotGrid extends StatelessWidget {
  const _BrailleDotGrid({required this.detectionState});

  final DetectionState detectionState;

  @override
  Widget build(BuildContext context) {
    const cols = AppConstants.brailleColumns;
    const rows = AppConstants.brailleRows;
    const dotSize = AppConstants.brailleDotSize;

    // Fake dot sizes to mimic Braille character patterns
    final rng = math.Random(42); // fixed seed for consistent pattern

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cols, (c) {
              final isBig = rng.nextBool();
              final size = isBig ? dotSize : dotSize * 0.75;
              final color = detectionState == DetectionState.detected
                  ? AppColors.primary.withOpacity(0.5)
                  : AppColors.brailleDot;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
