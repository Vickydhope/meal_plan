import 'package:flutter/material.dart';

import '../../../../../core/theme/app_typography.dart';

/// The title + subtitle header repeated at the top of every onboarding
/// step.
///
/// Pass [compact] when the step is reused outside the full-screen
/// onboarding flow (e.g. inside a bottom sheet), so the title uses
/// [AppTypography.headlineMedium] instead of the larger full-screen
/// [AppTypography.headlineLarge].
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: compact
              ? AppTypography.headlineMedium
              : AppTypography.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: AppTypography.bodyMedium),
      ],
    );
  }
}
