import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

enum _NotificationType { meal, streak, reminder, tip }

class _AppNotification {
  const _AppNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.timeAgo,
    this.read = false,
  });

  final _NotificationType type;
  final String title;
  final String body;
  final String timeAgo;
  final bool read;
}

// Dummy data — no backend/notification feature exists yet, this just
// gives the bell icon on HomeScreen somewhere to go.
const _dummyNotifications = [
  _AppNotification(
    type: _NotificationType.reminder,
    title: 'Log your lunch',
    body: "You haven't logged a meal since breakfast. Snap a photo to keep today on track.",
    timeAgo: '10m ago',
  ),
  _AppNotification(
    type: _NotificationType.streak,
    title: '5-day streak! 🔥',
    body: "You've logged a meal every day this week. Keep it going!",
    timeAgo: '2h ago',
  ),
  _AppNotification(
    type: _NotificationType.meal,
    title: 'Meal analyzed',
    body: '"Grilled chicken bowl" was added to your log — 540 kcal.',
    timeAgo: '5h ago',
    read: true,
  ),
  _AppNotification(
    type: _NotificationType.tip,
    title: 'Tip: portion sizing',
    body: "Adjust the portion slider on a scan if it looks bigger or smaller than what's on Gemini's plate.",
    timeAgo: 'Yesterday',
    read: true,
  ),
  _AppNotification(
    type: _NotificationType.meal,
    title: 'Meal analyzed',
    body: '"Avocado toast" was added to your log — 320 kcal.',
    timeAgo: 'Yesterday',
    read: true,
  ),
  _AppNotification(
    type: _NotificationType.reminder,
    title: "Don't forget to weigh in",
    body: 'Weekly check-ins help keep your calorie target accurate.',
    timeAgo: '2 days ago',
    read: true,
  ),
];

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: SafeArea(
        child: _dummyNotifications.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _dummyNotifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _NotificationCard(notification: _dummyNotifications[index]),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bell_off, size: 40, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text("You're all caught up", style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final _AppNotification notification;

  IconData get _icon => switch (notification.type) {
        _NotificationType.meal => LucideIcons.utensils,
        _NotificationType.streak => LucideIcons.flame,
        _NotificationType.reminder => LucideIcons.clock,
        _NotificationType.tip => LucideIcons.lightbulb,
      };

  Color get _iconColor => switch (notification.type) {
        _NotificationType.meal => AppColors.primary,
        _NotificationType.streak => AppColors.accent,
        _NotificationType.reminder => AppColors.carbs,
        _NotificationType.tip => AppColors.protein,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      notification.timeAgo,
                      style: AppTypography.caption11.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!notification.read) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 8,
              width: 8,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}
