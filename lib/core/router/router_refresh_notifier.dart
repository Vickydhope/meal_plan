import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/providers/profile_providers.dart';
import '../providers/core_providers.dart';

/// Bridges Riverpod state into a [Listenable] for `GoRouter.refreshListenable`,
/// so the router's `redirect` callback re-runs whenever the signed-in user
/// or their profile changes — replacing what `_AuthGate`'s reactive
/// `StreamBuilder`/`ref.watch` used to do implicitly.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _authSubscription = _ref
        .read(authRepositoryProvider)
        .userIdChanges
        .listen((_) {
          // currentUserProfileProvider reads currentUserId as a plain
          // getter, so it isn't reactive to the auth stream on its own —
          // invalidate it here so redirect sees fresh data for the
          // new/no user before re-evaluating.
          _ref.invalidate(currentUserProfileProvider);
          notifyListeners();
        });
    _ref.listen(currentUserProfileProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
  late final StreamSubscription<String?> _authSubscription;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
