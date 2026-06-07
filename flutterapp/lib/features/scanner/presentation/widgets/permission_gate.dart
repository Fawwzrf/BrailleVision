// lib/features/scanner/presentation/widgets/permission_gate.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.onRequestPermission,
    this.isDeniedPermanently = false,
  });

  final VoidCallback onRequestPermission;
  final bool         isDeniedPermanently;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryFill,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isDeniedPermanently
                  ? AppConstants.strPermissionDenied
                  : AppConstants.strPermissionTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(
                fontSize: 14,
                letterSpacing: 2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isDeniedPermanently
                  ? AppConstants.strPermissionBodyDenied
                  : AppConstants.strPermissionBody,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
                child: InkWell(
                  onTap: onRequestPermission,
                  borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      isDeniedPermanently
                          ? AppConstants.strPermissionSettingBtn
                          : AppConstants.strPermissionBtn,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.readAloudLabel.copyWith(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
