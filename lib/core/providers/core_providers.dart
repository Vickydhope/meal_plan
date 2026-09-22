import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';
import '../auth/supabase_auth_repository.dart';

/// The single Supabase client instance, exposed so every data source
/// depends on this provider rather than the `Supabase.instance` singleton
/// directly — makes it possible to override in tests.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

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
