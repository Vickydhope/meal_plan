import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

/// "10m ago", "2h ago", "Yesterday", "3 days ago".
String timeAgo(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} days ago';
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    // Captured up front: ref can't be used in dispose.
    _container = ProviderScope.containerOf(context, listen: false);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    // Unread dots stay visible for this visit; the badge clears on leaving.
    if (userId != null) {
      unawaited(
        ref
            .read(notificationRepositoryProvider)
            .markAllRead(userId)
            .catchError((_) {}),
      );
    }
  }

  @override
  void dispose() {
    _container.invalidate(notificationsProvider);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsProvider.future),
          child: notifications.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) =>
                _Message(icon: LucideIcons.wifi_off, text: userMessageFor(err)),
            data: (items) => items.isEmpty
                ? const _Message(
                    icon: LucideIcons.bell_off,
                    text: "You're all caught up",
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _NotificationCard(
                      notification: items[index],
                      timeAgo: timeAgo(items[index].createdAt, now),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable so pull-to-refresh still works on an empty/error state.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.timeAgo});

  final AppNotification notification;
  final String timeAgo;

  IconData get _icon => switch (notification.type) {
    AppNotificationType.meal => LucideIcons.utensils,
    AppNotificationType.streak => LucideIcons.flame,
    AppNotificationType.weekly => LucideIcons.chart_column,
  };

  Color get _iconColor => switch (notification.type) {
    AppNotificationType.meal => AppColors.primary,
    AppNotificationType.streak => AppColors.accent,
    AppNotificationType.weekly => AppColors.water,
  };

  @override
  Widget build(BuildContext context) {
    final isWeekly = notification.type == AppNotificationType.weekly;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 18, color: _iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: AppTypography.caption11.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isWeekly) ...[
                  const SizedBox(height: 6),
                  Text(
                    'See trends',
                    style: AppTypography.caption12Medium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!notification.isRead) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 8,
              width: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
    // The weekly summary opens the Trends screen with the full picture.
    return isWeekly
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.pushNamed(AppRoute.trends.name),
            child: card,
          )
        : card;
  }
}
