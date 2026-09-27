import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared form chrome for the auth screens — the logo, title, subtitle, the
/// email and/or password field (whichever controller is given), error/info
/// banners, submit button, and a footer slot for links. Each screen owns
/// its own controllers and submit logic; this widget is purely the visual
/// shell so the screens can't drift out of sync.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.formKey,
    required this.subtitle,
    this.emailController,
    this.passwordController,
    this.passwordLabel = 'Password',
    required this.submitLabel,
    required this.submitting,
    required this.onSubmit,
    required this.footer,
    this.minPasswordLength,
    this.error,
    this.info,
  });

  /// Minimum for a new password (sign up, reset). Keep in sync with Supabase
  /// Auth's `minimum_password_length` (config.toml / prod dashboard).
  static const newPasswordMinLength = 8;

  final GlobalKey<FormState> formKey;
  final String subtitle;
  final TextEditingController? emailController;
  final TextEditingController? passwordController;
  final String passwordLabel;
  final String submitLabel;
  final bool submitting;
  final VoidCallback onSubmit;
  final Widget footer;

  /// Enforced when setting a password (sign up). `null` on log in, so
  /// accounts created under an older, shorter minimum can still sign in.
  final int? minPasswordLength;
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
                if (emailController case final emailController?)
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
                    onFieldSubmitted: passwordController == null
                        ? (_) => onSubmit()
                        : null,
                  ),
                if (emailController != null && passwordController != null)
                  const SizedBox(height: 12),
                if (passwordController case final passwordController?)
                  _PasswordField(
                    controller: passwordController,
                    label: passwordLabel,
                    minLength: minPasswordLength,
                    onSubmitted: onSubmit,
                  ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                if (info != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    info!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.success,
                    ),
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

/// Password input with a show/hide toggle.
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.minLength,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final int? minLength;
  final VoidCallback onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: widget.label,
        filled: true,
        fillColor: AppColors.surface,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          tooltip: _obscured ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) return 'Enter your password';
        final min = widget.minLength;
        if (min != null && password.length < min) {
          return 'At least $min characters';
        }
        return null;
      },
      onFieldSubmitted: (_) => widget.onSubmitted(),
    );
  }
}
