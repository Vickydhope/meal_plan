import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../meal_log/presentation/providers/meal_log_providers.dart';
import '../../../meal_log/presentation/screens/camera_scan_screen.dart'
    show cameraFabHeroTag;

/// Height of [AppShell]'s `bottomNavigationBar` (Material 3's default
/// `BottomAppBar` height, since no explicit `height` is set below).
///
/// Because the shell's `Scaffold` uses `extendBody: true`, each tab's own
/// body renders full-height underneath this bar — any fixed (non-scrolling)
/// content pinned to a tab's bottom edge must pad itself by this much to
/// avoid being hidden behind it.
const kAppBottomBarHeight = 80.0;

/// Bottom-nav shell with a raised center camera button, matching the
/// reference design's tab bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The camera FAB always logs against "now", not whichever day is
    // being browsed (see MealLogRepositoryImpl) — showing it while
    // viewing a past day would misleadingly suggest it logs food for
    // that day, so it's disabled (kept visible, but non-interactive and
    // muted) whenever the selected day isn't today.
    final selectedDate = ref.watch(
      mealLogProvider.select((state) => state.selectedDate),
    );
    final now = DateTime.now();
    final isToday =
        selectedDate == null ||
        (selectedDate.year == now.year &&
            selectedDate.month == now.month &&
            selectedDate.day == now.day);

    // The camera FAB is only meaningful on the Home tab — it always logs
    // against "now" (see MealLogRepositoryImpl), which doesn't map onto
    // Ask AI or Plan, and it doesn't belong docked over the chat input
    // (see ask_ai_screen.dart) either. Hidden entirely rather than merely
    // padded around, so it can't overlap anything on those tabs.
    final showFab = navigationShell.currentIndex == 0;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      floatingActionButton: showFab
          ? FloatingActionButton(
              heroTag: cameraFabHeroTag,
              backgroundColor: isToday
                  ? AppColors.primary
                  : AppColors.surfaceMuted,
              disabledElevation: 0,
              shape: const CircleBorder(),
              onPressed: isToday
                  ? () => context.pushNamed(AppRoute.cameraScan.name)
                  : null,
              child: Icon(
                LucideIcons.camera,
                color: isToday ? AppColors.onScrim : AppColors.textDisabled,
                size: 20,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 48,
          // Leaves clear space on the right for the now end-docked FAB (its
          // notch) when it's showing, so the tab row sits entirely to its
          // left instead of the last tab landing underneath it — animated
          // (rather than a plain BottomAppBar.padding, which can't
          // animate) so the tabs visibly glide into the freed space when
          // the FAB hides instead of jumping.
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.only(right: showFab ? 88 : 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavIcon(
                  icon: LucideIcons.house,
                  selected: navigationShell.currentIndex == 0,
                  onTap: () => _goBranch(0),
                ),
                _NavIcon(
                  icon: LucideIcons.message_circle_more,
                  selected: navigationShell.currentIndex == 1,
                  onTap: () => _goBranch(1),
                ),
                _NavIcon(
                  // A calorie/nutrition plan is fundamentally a personal
                  // target — more meaningful here than a generic book icon.
                  icon: LucideIcons.target,
                  selected: navigationShell.currentIndex == 2,
                  onTap: () => _goBranch(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// A bottom-nav icon with a circular background that fades in/out as
/// [selected] changes, plus a matching icon-color crossfade.
class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const _fadeDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: _fadeDuration,
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected
                ? AppColors.onScrim
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
