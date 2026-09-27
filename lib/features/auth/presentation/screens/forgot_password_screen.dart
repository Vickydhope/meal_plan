import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_route.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_card.dart';

/// Emails a password-reset link. Opening it on this phone signs the user in
/// and the router sends them to [ResetPasswordScreen]. The link carries a
/// PKCE code whose verifier is stored on this device, so it only works here.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Prefilled from whatever was typed on [LoginScreen].
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );

  bool _submitting = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    final email = _emailController.text.trim();
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      // Same message whether or not the account exists, so this screen
      // can't be used to find out which emails are registered.
      setState(
        () => _info =
            'If an account exists for $email, we sent it a link to reset '
            'your password. Open it on this phone.',
      );
    } on AuthFailureException catch (err) {
      setState(() => _error = err.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormCard(
      formKey: _formKey,
      subtitle: "Enter your email and we'll send you a reset link.",
      emailController: _emailController,
      submitLabel: 'Send reset link',
      submitting: _submitting,
      error: _error,
      info: _info,
      onSubmit: _submit,
      footer: TextButton(
        onPressed: _submitting
            ? null
            : () => context.goNamed(AppRoute.login.name),
        child: const Text('Back to log in'),
      ),
    );
  }
}
