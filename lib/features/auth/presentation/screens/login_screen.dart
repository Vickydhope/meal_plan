import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_route.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_card.dart';

/// Sign-in screen for an existing account. On success, `app_router.dart`'s
/// auth-state redirect swaps this screen out automatically — this screen
/// doesn't navigate itself except across to [SignupScreen].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

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
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
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
      subtitle: 'Log in to your account.',
      emailController: _emailController,
      passwordController: _passwordController,
      submitLabel: 'Log in',
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
      footer: TextButton(
        onPressed: _submitting
            ? null
            : () => context.goNamed(AppRoute.signup.name),
        child: const Text("Don't have an account? Sign up"),
      ),
    );
  }
}
