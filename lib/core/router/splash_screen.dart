import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Shown while the restored session or the signed-in user's profile is
/// still loading, so [AppRouter]'s redirect has enough information to
/// decide between login, onboarding and the main app shell.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mirrors the native launch screen (flutter_native_splash*.yaml) so the
    // handoff doesn't jump: white background (also blends with the logo's
    // own white square), same 160dp logo exactly centered on the full
    // screen — so no SafeArea around it, and the slogan hangs below it
    // without pushing it off-center.
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Image.asset(
                  appFlavor == 'dev'
                      ? 'assets/splash/app_logo_dev.png'
                      : 'assets/splash/app_logo.png',
                  width: 160,
                ),
                Positioned(
                  top: 160 + 16,
                  child: Text(
                    'Eat · Track · Be Healthy',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
