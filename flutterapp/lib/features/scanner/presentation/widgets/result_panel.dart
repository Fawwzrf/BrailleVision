// lib/features/scanner/presentation/widgets/result_panel.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/tts_service.dart';

class ResultPanel extends StatelessWidget {
  const ResultPanel({
    super.key,
    required this.text,
    required this.ttsState,
    required this.onSpeak,
    required this.onStopSpeak,
    required this.onCopy,
  });

  final String text;
  final TtsState ttsState;
  final VoidCallback onSpeak;
  final VoidCallback onStopSpeak;
  final VoidCallback onCopy;

  bool get _hasText => text.isNotEmpty;
  bool get _isPlaying => ttsState == TtsState.playing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.pagePaddingH),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          _ResultHeader(hasText: _hasText),

          // Result text body
          _ResultBody(text: text),

          // Waveform / braille dots divider row
          if (_hasText) ...[
            const _WaveformRow(),
            const SizedBox(height: 8),
          ],

          // Read Aloud button
          _ReadAloudButton(
            isPlaying: _isPlaying,
            enabled: _hasText,
            onTap: _isPlaying ? onStopSpeak : onSpeak,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.hasText});
  final bool hasText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          // Check circle icon
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: hasText ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child: hasText
                ? const Icon(Icons.check, size: 12, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            AppConstants.strResultTitle,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 2.0,
                  fontSize: 10,
                ),
          ),
          const Spacer(),
          // Language badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryFill,
              borderRadius: BorderRadius.circular(AppConstants.chipRadius),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Text(
              AppConstants.strLangBadge,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 10,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: AnimatedSwitcher(
        duration: AppConstants.animNormal,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: text.isEmpty
            ? Text(
                key: const ValueKey('placeholder'),
                AppConstants.strPlaceholder,
                style: AppTextStyles.placeholder,
              )
            : SelectableText(
                key: ValueKey(text),
                text,
                style: AppTextStyles.resultText,
              ),
      ),
    );
  }
}

// ─── Waveform Row ─────────────────────────────────────────────

class _WaveformRow extends StatelessWidget {
  const _WaveformRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Animated dot waveform (left)
          _MiniWaveform(),
          const Spacer(),
          // Waveform bars (right)
          _MiniBarWaveform(),
        ],
      ),
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dotSizes = [5.0, 4.0, 6.0, 4.0, 5.0, 3.5, 5.5];
    return Row(
      children: dotSizes
          .map((s) => Container(
                margin: const EdgeInsets.only(right: 5),
                width: s,
                height: s,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brailleDot,
                ),
              ))
          .toList(),
    );
  }
}

class _MiniBarWaveform extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final heights = [8.0, 14.0, 10.0, 16.0, 8.0, 12.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: heights
          .map((h) => Container(
                margin: const EdgeInsets.only(left: 3),
                width: 3,
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.brailleDot,
                  borderRadius: BorderRadius.circular(2),
                ),
              ))
          .toList(),
    );
  }
}

// ─── Read Aloud Button ────────────────────────────────────────

class _ReadAloudButton extends StatelessWidget {
  const _ReadAloudButton({
    required this.isPlaying,
    required this.enabled,
    required this.onTap,
  });

  final bool isPlaying;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Material(
        color: enabled ? AppColors.primary : AppColors.border,
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                  color: AppColors.textOnPrimary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isPlaying
                      ? AppConstants.strStopBtn
                      : AppConstants.strSpeakBtn,
                  style: AppTextStyles.readAloudLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
