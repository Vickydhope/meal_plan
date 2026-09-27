import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's id, reactive to sign-in/sign-out/session-restore.
/// Downstream providers (e.g. `currentUserProfileProvider`) should `watch`
/// this instead of reading `authRepositoryProvider.currentUserId` directly —
/// that getter is a plain snapshot, so a provider that only reads it once
/// on build can end up serving a stale cached value to a redirect/rebuild
/// that runs before the provider is explicitly invalidated.
final authUserIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).userIdChanges;
});

/// Whether the user arrived via a password-reset link and still has to
/// choose a new password; the router keeps them on `ResetPasswordScreen`
/// until then.
final passwordRecoveryProvider = StreamProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).passwordRecoveryChanges;
});
