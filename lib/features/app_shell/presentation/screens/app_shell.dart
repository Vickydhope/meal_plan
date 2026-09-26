import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
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

  /// One per shell branch, in branch order. Plan uses a target: a
  /// calorie/nutrition plan is fundamentally a personal target.
  static const _tabIcons = [
    LucideIcons.house,
    LucideIcons.message_circle_more,
    LucideIcons.target,
  ];

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
    final isToday =
        selectedDate == null ||
        DateUtils.isSameDay(selectedDate, DateTime.now());

    // The camera FAB is only meaningful on the Home tab — it always logs
    // against "now" (see MealLogRepositoryImpl), which doesn't map onto
    // Ask AI or Plan, and it doesn't belong docked over the chat input
    // (see ask_ai_screen.dart) either. Hidden entirely rather than merely
    // padded around, so it can't overlap anything on those tabs.
    final showFab = navigationShell.currentIndex == 0;

    return PopScope(
      // Never let a system/back-gesture pop close the app directly: on any
      // tab but Home it should land on Home first, and only from Home does
      // back mean "exit" (and even then, only after the user confirms).
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          _goBranch(0);
        } else {
          _confirmExit(context);
        }
      },
      child: Scaffold(
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
            // Leaves clear space on the right for the now end-docked FAB
            // (its notch) when it's showing, so the tab row sits entirely
            // to its left instead of the last tab landing underneath it —
            // animated (rather than a plain BottomAppBar.padding, which
            // can't animate) so the tabs visibly glide into the freed
            // space when the FAB hides instead of jumping.
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(right: showFab ? 88 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final (i, icon) in _tabIcons.indexed)
                    _NavIcon(
                      icon: icon,
                      selected: navigationShell.currentIndex == i,
                      onTap: () => _goBranch(i),
                    ),
                ],
              ),
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

  /// Shows a themed confirm dialog before letting a Home-tab back-press
  /// exit the app, matching the app's own rounded/pill button styling
  /// (see the onboarding "Continue" button) rather than the stock
  /// [AlertDialog] look.
  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Exit app?', style: AppTypography.headlineMedium),
        content: Text(
          'Are you sure you want to exit Cravia?',
          style: AppTypography.bodyMedium,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onScrim,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (shouldExit ?? false) {
      await SystemNavigator.pop();
    }
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

/// Mounts every branch [Navigator] exactly once (they carry GlobalKeys, so
/// a switcher holding two copies of the shell mid-transition throws
/// "Duplicate GlobalKey") and slides/fades between them, direction
/// following tab order: branches left of [currentIndex] sit off to the
/// left, those right of it off to the right.
class AnimatedBranchContainer extends StatelessWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < children.length; i++) _branch(i, children[i]),
      ],
    );
  }

  Widget _branch(int i, Widget child) {
    final active = i == currentIndex;
    // TickerMode sits inside the fade/slide: wrapping them would freeze the
    // outgoing branch's own fade-out, leaving it painted over the new one.
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedSlide(
          duration: _duration,
          curve: Curves.easeInOut,
          offset: Offset(active ? 0 : (i < currentIndex ? -0.08 : 0.08), 0),
          child: AnimatedOpacity(
            duration: _duration,
            curve: Curves.easeInOut,
            opacity: active ? 1 : 0,
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}
