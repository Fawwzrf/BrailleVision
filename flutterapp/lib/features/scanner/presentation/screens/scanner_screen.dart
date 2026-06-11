// lib/features/scanner/presentation/screens/scanner_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/scanner_provider.dart';
import '../../services/camera_service.dart';
import '../widgets/permission_gate.dart';
import '../widgets/result_panel.dart';
import '../widgets/viewfinder_overlay.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scannerProvider.notifier).requestPermissionAndInit();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(scannerProvider.notifier);
    if (state == AppLifecycleState.paused) {
      notifier.cameraService.stopStream();
    } else if (state == AppLifecycleState.resumed) {
      notifier.cameraService.startStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onCopyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppConstants.strCopied),
        duration: Duration(milliseconds: AppConstants.snackbarDurationMs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider);
    final notifier = ref.read(scannerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _ScannerAppBar(
        isFlashOn: state.isFlashOn,
        onFlashToggle: notifier.toggleFlash,
        onCameraSwitch: notifier.toggleCamera,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Camera Card ──────────────────────────────────
            Expanded(
              flex: 55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePaddingH,
                  8,
                  AppConstants.pagePaddingH,
                  8,
                ),
                child: _CameraCard(
                  state: state,
                  notifier: notifier,
                ),
              ),
            ),

            // ── Result Card ──────────────────────────────────
            Expanded(
              flex: 45,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    ResultPanel(
                      text: state.translatedText,
                      ttsState: state.ttsState,
                      onSpeak: notifier.speakResult,
                      onStopSpeak: notifier.stopSpeaking,
                      onCopy: () => _onCopyText(state.translatedText),
                    ),

                    // ── MOCK BAR (remove after ML integration) ──
                    // const SizedBox(height: 10),
                    // _MockControlBar(
                    //   detectionState: state.detectionState,
                    //   onStart: notifier.startMockDetection,
                    //   onReset: notifier.resetDetection,
                    // ),
                    // ── END MOCK ────────────────────────────────
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Camera Card ─────────────────────────────────────────────

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.state, required this.notifier});

  final ScannerState state;
  final ScannerNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: AppConstants.cardShadowBlur,
            spreadRadius: AppConstants.cardShadowSpread,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Camera preview or permission/error
          Positioned.fill(
            child: _buildCameraContent(context),
          ),

          // LIVE badge — top left
          Positioned(
            top: 12,
            left: 14,
            child: _LiveBadge(),
          ),

          // Scanning pill — bottom center (only when camera ready)
          if (state.isCameraReady)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: _ScanningPill(detectionState: state.detectionState),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraContent(BuildContext context) {
    if (!state.isPermissionGranted) {
      return PermissionGate(
        isDeniedPermanently:
            state.permissionStatus == PermissionStatus.permanentlyDenied,
        onRequestPermission: () {
          if (state.permissionStatus == PermissionStatus.permanentlyDenied) {
            openAppSettings();
          } else {
            notifier.requestPermissionAndInit();
          }
        },
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.errorMessage!,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!state.isCameraReady) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.primary,
        ),
      );
    }

    return _CameraPreviewWithOverlay(
      controller: notifier.cameraService.controller!,
      detectionState: state.detectionState,
    );
  }
}

// ─── Camera Preview + Viewfinder ─────────────────────────────

class _CameraPreviewWithOverlay extends StatelessWidget {
  const _CameraPreviewWithOverlay({
    required this.controller,
    required this.detectionState,
  });

  final CameraController controller;
  final DetectionState detectionState;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera feed fills card
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize!.height,
                height: controller.value.previewSize!.width,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),

        // Semi-transparent overlay so dots/frame are visible on light bg
        Container(color: const Color(0x22FFFFFF)),

        // Viewfinder overlay centered
        ViewfinderOverlay(detectionState: detectionState),
      ],
    );
  }
}

// ─── AppBar ──────────────────────────────────────────────────

class _ScannerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ScannerAppBar({
    required this.isFlashOn,
    required this.onFlashToggle,
    required this.onCameraSwitch,
  });

  final bool isFlashOn;
  final VoidCallback onFlashToggle;
  final VoidCallback onCameraSwitch;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _AppBarIconButton(
          icon: Icons.flashlight_on_rounded,
          onTap: onFlashToggle,
          isActive: isFlashOn,
        ),
      ),
      title: Text(
        AppConstants.strAppName,
        style: AppTextStyles.appBarTitle,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _AppBarIconButton(
            icon: Icons.flip_camera_ios_rounded,
            onTap: onCameraSwitch,
          ),
        ),
      ],
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            color: isActive ? AppColors.primaryFill : AppColors.surface,
          ),
          child: Icon(
            icon,
            size: AppConstants.appBarIconSize,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── LIVE Badge ──────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.chipRadius),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppConstants.statusDotSize,
            height: AppConstants.statusDotSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.liveGreen,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            AppConstants.strLiveLabel,
            style: AppTextStyles.statusChip.copyWith(
              color: AppColors.textPrimary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scanning Pill ───────────────────────────────────────────

class _ScanningPill extends StatefulWidget {
  const _ScanningPill({required this.detectionState});
  final DetectionState detectionState;

  @override
  State<_ScanningPill> createState() => _ScanningPillState();
}

class _ScanningPillState extends State<_ScanningPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Color get _pillColor {
    return switch (widget.detectionState) {
      DetectionState.idle => AppColors.primary,
      DetectionState.detecting => AppColors.detecting,
      DetectionState.detected => AppColors.detected,
    };
  }

  String get _label {
    return switch (widget.detectionState) {
      DetectionState.idle => AppConstants.strScanningLabel,
      DetectionState.detecting => AppConstants.strStatusDetecting,
      DetectionState.detected => AppConstants.strStatusDetected,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _pillColor,
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        boxShadow: [
          BoxShadow(
            color: _pillColor.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _spin,
            builder: (_, child) => Transform.rotate(
              angle: _spin.value * 2 * 3.14159,
              child: child,
            ),
            child: const Icon(
              Icons.crop_free_rounded,
              size: 15,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(_label, style: AppTextStyles.scanningLabel),
        ],
      ),
    );
  }
}

// ─── Mock Control Bar ────────────────────────────────────────

// class _MockControlBar extends StatelessWidget {
//   const _MockControlBar({
//     required this.detectionState,
//     required this.onStart,
//     required this.onReset,
//   });

//   final DetectionState detectionState;
//   final VoidCallback   onStart;
//   final VoidCallback   onReset;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePaddingH),
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: AppColors.border),
//           color: AppColors.surfaceElevated,
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 const Icon(Icons.science_outlined, size: 11, color: AppColors.textSecondary),
//                 const SizedBox(width: 6),
//                 Text(
//                   'MOCK UI TESTING — HAPUS SETELAH INTEGRASI ML',
//                   style: AppTextStyles.labelSmall.copyWith(
//                     fontSize: 9,
//                     color: AppColors.textSecondary,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 Expanded(
//                   child: _MockBtn(
//                     label:   'SIMULASI DETEKSI',
//                     onTap:   onStart,
//                     color:   AppColors.primary,
//                     enabled: detectionState == DetectionState.idle,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _MockBtn(
//                     label:   'RESET',
//                     onTap:   onReset,
//                     color:   AppColors.textSecondary,
//                     enabled: detectionState != DetectionState.idle,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _MockBtn extends StatelessWidget {
//   const _MockBtn({
//     required this.label,
//     required this.onTap,
//     required this.color,
//     required this.enabled,
//   });

//   final String       label;
//   final VoidCallback onTap;
//   final Color        color;
//   final bool         enabled;

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: enabled ? onTap : null,
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 9),
//         alignment: Alignment.center,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(
//             color: enabled ? color.withOpacity(0.5) : AppColors.border,
//           ),
//           color: enabled ? color.withOpacity(0.08) : Colors.transparent,
//         ),
//         child: Text(
//           label,
//           style: AppTextStyles.labelSmall.copyWith(
//             color: enabled ? color : AppColors.textTertiary,
//             fontSize: 9,
//           ),
//         ),
//       ),
//     );
//   }
// }
