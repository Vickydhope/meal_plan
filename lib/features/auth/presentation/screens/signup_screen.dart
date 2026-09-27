import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_route.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_card.dart';

/// Account-creation screen. If email confirmation is required, no session
/// is issued on success — the screen stays put and shows [_info] with a
/// link across to [LoginScreen]. Otherwise `app_router.dart`'s auth-state
/// redirect swaps this screen out automatically once the session lands.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    final auth = ref.read(authRepositoryProvider);
    try {
      await auth.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (auth.currentUserId == null) {
        // Email confirmation is required before a session is issued.
        setState(() {
          _info = 'Check your email to confirm your account, then log in.';
        });
      }
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
      subtitle: 'Create an account to get started.',
      emailController: _emailController,
      passwordController: _passwordController,
      submitLabel: 'Sign up',
      // Matches Supabase Auth's minimum password length (config.toml / dashboard).
      minPasswordLength: 8,
      submitting: _submitting,
      error: _error,
      info: _info,
      onSubmit: _submit,
      footer: TextButton(
        onPressed: _submitting
            ? null
            : () => context.goNamed(AppRoute.login.name),
        child: const Text('Already have an account? Log in'),
      ),
    );
  }
}
