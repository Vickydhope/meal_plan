import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/calorie_ring.dart';
import '../../widgets/macro_ring.dart';
import '../../widgets/week_strip.dart';
import 'meal_log_model.dart';
import 'meal_log_provider.dart';

const _pageBackground = Color(0xFFF7FCF1);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealLogProvider);
    final notifier = ref.read(mealLogProvider.notifier);

    ref.listen(mealLogProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    // Standard macro split (protein 30% / carbs 40% / fat 30% of calories)
    // used only to size the mini-rings; not a stored target.
    final proteinTarget = (state.dailyTarget * 0.3 / 4).round();
    final carbsTarget = (state.dailyTarget * 0.4 / 4).round();
    final fatsTarget = (state.dailyTarget * 0.3 / 9).round();

    final proteinLeft = (proteinTarget - state.totalProteinToday).clamp(
      0,
      proteinTarget,
    );
    final carbsLeft = (carbsTarget - state.totalCarbsToday).clamp(
      0,
      carbsTarget,
    );
    final fatsOver = (state.totalFatsToday - fatsTarget).clamp(0, 1 << 30);
    final fatsLeft = (fatsTarget - state.totalFatsToday).clamp(0, fatsTarget);

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        leadingWidth: 64,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.black45),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Good morning!',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            Text(
              state.username ?? 'Guest!',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {},
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: RefreshIndicator(
          onRefresh: notifier.fetchLogsForSelectedDate,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WeekStrip(
                        selectedDate: state.selectedDate ?? DateTime.now(),
                        onDateSelected: notifier.selectDate,
                      ),
                      const SizedBox(height: 16),
                      CalorieRing(
                        consumed: state.totalCaloriesToday,
                        target: state.dailyTarget,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: '${proteinLeft}g',
                              label: 'Protein left',
                              progress:
                                  state.totalProteinToday /
                                  (proteinTarget == 0 ? 1 : proteinTarget),
                              color: Colors.blue,
                              icon: Icons.water_drop,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              value: '${carbsLeft}g',
                              label: 'Carbs left',
                              progress:
                                  state.totalCarbsToday /
                                  (carbsTarget == 0 ? 1 : carbsTarget),
                              color: Colors.orange,
                              icon: Icons.blur_circular,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              value: '${fatsOver > 0 ? fatsOver : fatsLeft}g',
                              label: fatsOver > 0 ? 'Fat over' : 'Fat left',
                              progress:
                                  state.totalFatsToday /
                                  (fatsTarget == 0 ? 1 : fatsTarget),
                              color: Colors.green,
                              icon: Icons.eco,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Activity",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (state.logs.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  sliver: SliverToBoxAdapter(
                    child: Center(child: Text('No meals logged yet')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
                  sliver: SliverList.builder(
                    itemCount: state.logs.length,
                    itemBuilder: (context, index) =>
                        _ActivityTile(log: state.logs[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.progress,
    required this.color,
    required this.icon,
  });

  final String value;
  final String label;
  final double progress;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          MiniRingIcon(progress: progress, color: color, icon: icon),
        ],
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.log});

  final MealLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mealLogProvider.notifier);
    final imageUrl = log.imageUrl;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 72,
              width: 72,
              child: imageUrl == null
                  ? Container(
                      color: const Color(0xFFEDEDED),
                      child: const Icon(Icons.restaurant),
                    )
                  : FutureBuilder<String>(
                      future: notifier.signedImageUrl(imageUrl),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(color: const Color(0xFFEDEDED));
                        }
                        return Image.network(snapshot.data!, fit: BoxFit.cover);
                      },
                    ),
            ),
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
                        log.mealName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${log.createdAt.hour.toString().padLeft(2, '0')}:'
                      '${log.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '+ ${log.totalCalories} Calories',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _MacroPill(
                      icon: Icons.water_drop,
                      color: Colors.blue,
                      text: '${log.totalProtein} g',
                    ),
                    _MacroPill(
                      icon: Icons.blur_circular,
                      color: Colors.orange,
                      text: '${log.totalCarbs} g',
                    ),
                    _MacroPill(
                      icon: Icons.eco,
                      color: Colors.green,
                      text: '${log.totalFats} g',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
