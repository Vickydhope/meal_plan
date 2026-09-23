import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared email/password form chrome for [LoginScreen]/[SignupScreen] — the
/// logo, title, subtitle, the two fields, error/info banners, submit
/// button, and a footer slot for the "switch screens" link. Each screen
/// owns its own controllers, validation, and submit logic; this widget is
/// purely the visual shell so the two screens can't drift out of sync.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.formKey,
    required this.subtitle,
    required this.emailController,
    required this.passwordController,
    required this.submitLabel,
    required this.submitting,
    required this.onSubmit,
    required this.footer,
    this.error,
    this.info,
  });

  final GlobalKey<FormState> formKey;
  final String subtitle;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String submitLabel;
  final bool submitting;
  final VoidCallback onSubmit;
  final Widget footer;
  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Image.asset(
                  'assets/images/girl_illustration.png',
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  'Cravia',
                  textAlign: TextAlign.center,
                  style: AppTypography.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Enter your email';
                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return 'At least 6 characters';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => onSubmit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                  ),
                ],
                if (info != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    info!,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.success),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: submitting ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onScrim,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onScrim,
                            ),
                          )
                        : Text(submitLabel),
                  ),
                ),
                const SizedBox(height: 16),
                footer,
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
