import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// The thin progress bar at the top of the onboarding flow, filled
/// proportionally to how many of the six steps are done.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({super.key, required this.progress});

  /// 0.0-1.0.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 4,
        backgroundColor: AppColors.divider,
        valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
      ),
    );
  }
}
