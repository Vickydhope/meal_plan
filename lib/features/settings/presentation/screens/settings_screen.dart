import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authRepositoryProvider).currentUserEmail;
    final syncEnabled = ref.watch(activitySyncEnabledProvider).value ?? false;
    final mealWriteBack =
        ref.watch(mealWriteBackEnabledProvider).value ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsSection(
              title: 'Account',
              children: [
                _SettingsRow(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                  onTap: () {
                    context.pushNamed(AppRoute.profile.name);
                  },
                ),
                _SettingsRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  trailing: Text(
                    email ?? '—',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Activity',
              children: [
                _SettingsRow(
                  icon: Icons.directions_run,
                  label: 'Sync activity & weight from this device',
                  trailing: Switch.adaptive(
                    value: syncEnabled,
                    onChanged: (value) => _setActivitySync(context, value),
                  ),
                ),
                _SettingsRow(
                  icon: Icons.restaurant_outlined,
                  label: 'Save meals to Health',
                  trailing: Switch.adaptive(
                    value: mealWriteBack,
                    onChanged: (value) => _setMealWriteBack(context, value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SettingsSection(
              title: 'About',
              children: [
                _SettingsRow(
                  icon: Icons.info_outline,
                  label: 'App version',
                  trailing: Text('1.0.0', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              children: [
                _SettingsRow(
                  icon: Icons.logout,
                  label: 'Log out',
                  iconColor: AppColors.error,
                  labelColor: AppColors.error,
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setActivitySync(BuildContext context, bool enabled) async {
    // Captured up front: the permission sheet can outlive this screen, and
    // a WidgetRef can't be used once its widget is unmounted.
    final container = ProviderScope.containerOf(context);
    final userId = container.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;
    try {
      await container.read(setActivitySyncUseCaseProvider)(
        enabled,
        userId: userId,
      );
    } catch (err) {
      if (context.mounted) showAppSnackBar(context, userMessageFor(err));
    }
    container
      ..invalidate(activitySyncEnabledProvider)
      ..invalidate(todayActivityProvider)
      ..invalidate(healthWeightSyncProvider);
  }

  /// Only meals confirmed or edited from now on are saved; existing
  /// history isn't backfilled.
  Future<void> _setMealWriteBack(BuildContext context, bool enabled) async {
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(setMealWriteBackUseCaseProvider)(enabled);
    } catch (err) {
      if (context.mounted) showAppSnackBar(context, userMessageFor(err));
    }
    container.invalidate(mealWriteBackEnabledProvider);
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!.toUpperCase(),
              style: AppTypography.label,
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
