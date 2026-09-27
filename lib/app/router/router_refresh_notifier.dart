import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';

/// Bridges Riverpod state into a [Listenable] for `GoRouter.refreshListenable`,
/// so the router's `redirect` callback re-runs whenever the signed-in user
/// or their profile changes. `currentUserProfileProvider` watches
/// `authUserIdProvider`, so listening to both here (rather than manually
/// invalidating the profile provider on auth changes) keeps redirect from
/// ever reading a profile cached for the previous user.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authUserIdProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProfileProvider, (_, _) => notifyListeners());
    ref.listen(passwordRecoveryProvider, (_, _) => notifyListeners());
  }
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
