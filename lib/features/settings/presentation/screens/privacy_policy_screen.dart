import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Reachable signed out: from Settings, and from Health Connect's
/// privacy-policy / permission-rationale links on Android (`MainActivity`
/// opens this route directly).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _lastUpdated = 'September 27, 2026';

  static const _sections = [
    (
      'What we collect',
      '• Account: your email address and password (stored hashed by our '
          'authentication provider).\n'
          '• Profile: name, username, phone, profile photo, sex, date of '
          'birth, height, weight, activity level, goal, calorie goal and '
          'diet notes — whatever you choose to enter.\n'
          '• Meals: photos you take, meal names, ingredients, calories and '
          'macros, and water intake.\n'
          '• Ask AI: the questions you ask and the conversation history.\n'
          '• Health data, only if you turn it on in Settings: steps, active '
          'calories burned and weight read from Apple Health or Health '
          'Connect.\n'
          '• Crash reports: technical details about errors, used to fix '
          'bugs.',
    ),
    (
      'How we use it',
      'Only to run the app: logging and showing your meals, estimating '
          'nutrition from photos, calculating your calorie goal, answering Ask '
          'AI questions, suggesting meals and sending the reminders you turn '
          'on. We do not sell your data, show ads or use it for advertising.',
    ),
    (
      'Health data',
      'Data read from Apple Health or Health Connect is used only to show '
          'your activity, adjust your calorie goal and keep your weight up to '
          'date. Today\'s steps and active calories are stored with your '
          'account so your other devices show the same numbers. If you turn on '
          '"Save meals & water to Health", the app writes your meals and water '
          'to Apple Health or Health Connect. Health data is never used for '
          'advertising, never sold and never shared with anyone except the '
          'service providers below that run the app. You can turn access off '
          'at any time in Settings or in your phone\'s health settings.',
    ),
    (
      'Who processes it',
      '• Supabase stores your account and data.\n'
          '• Google Gemini analyzes meal photos and generates Ask AI answers '
          'and meal suggestions. It receives the photo or question plus the '
          'context needed to answer (such as your goals and today\'s meals).\n'
          '• Sentry receives crash reports.\n'
          '• Open Food Facts receives the barcode when you scan a packaged '
          'product. No account details are sent with it.',
    ),
    (
      'Keeping and deleting your data',
      'Your data is kept while you have an account. Meal photos that are '
          'never saved to a meal are removed automatically. You can delete your '
          'account at any time in Settings → Delete account, which '
          'permanently removes your account and all data linked to it.',
    ),
    ('Children', 'The app is not intended for children under 13.'),
    (
      'Changes',
      'If this policy changes, the updated version will appear here with a '
          'new date.',
    ),
    (
      'Contact',
      'Questions about privacy: use the developer email on the app\'s store '
          'listing.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Privacy policy'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Last updated $_lastUpdated',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            for (final (title, body) in _sections) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(title, style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(body, style: AppTypography.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
