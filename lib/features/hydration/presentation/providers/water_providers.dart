import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/water_repository_impl.dart';
import '../../domain/repositories/water_repository.dart';

final waterRepositoryProvider = Provider<WaterRepository>(
  (ref) => WaterRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Water (ml) logged on a local calendar day (the family arg, a local
/// midnight — e.g. `HomeScreen`'s selected date).
final waterProvider = FutureProvider.autoDispose.family<int, DateTime>((
  ref,
  day,
) async {
  final userId = ref.watch(authUserIdProvider).valueOrNull;
  if (userId == null) return 0;
  return ref.watch(waterRepositoryProvider).fetchWater(userId, day);
});
