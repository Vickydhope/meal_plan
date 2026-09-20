import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shown briefly while the signed-in user's profile is still loading, so
/// [AppRouter]'s redirect has enough information to decide between
/// onboarding and the main app shell.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
