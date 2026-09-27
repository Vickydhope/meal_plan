import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_card.dart';

/// Shown after a password-reset link signs the user in. Saving the new
/// password ends recovery (see `passwordRecoveryProvider`), and the router
/// moves on to the app; cancelling signs out.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);
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
      subtitle: 'Choose a new password.',
      passwordController: _passwordController,
      passwordLabel: 'New password',
      minPasswordLength: AuthFormCard.newPasswordMinLength,
      submitLabel: 'Save password',
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      footer: TextButton(
        onPressed: _submitting
            ? null
            : () => ref.read(authRepositoryProvider).signOut(),
        child: const Text('Cancel'),
      ),
    );
  }
}
