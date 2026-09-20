import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'ring_painter.dart';

/// A single macro's stat: current total, its share of [dailyTarget], an
/// icon and the color used for that icon/ring.
class MacroStat {
  const MacroStat({
    required this.label,
    required this.value,
    required this.target,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final int target;
  final IconData icon;
  final Color color;
}

/// The "Calories · Today's Intake" overview card — title/goal pill and the
/// protein/carbs/fat breakdown on the left, a big progress ring with the
/// consumed/target/percentage on the right. Matches
/// `design_references/Gemini_Generated_Image_i1pe43i1pe43i1pe.png`.
class CalorieOverviewCard extends StatelessWidget {
  const CalorieOverviewCard({
    super.key,
    required this.consumed,
    required this.target,
    required this.macros,
  });

  final int consumed;
  final int target;
  final List<MacroStat> macros;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.shortestSide * .45,
              child: _CalorieProgressRing(consumed: consumed, target: target),
            ),
          ),

          Row(
            children: [
              for (var i = 0; i < macros.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      height: 56,
                      child: VerticalDivider(
                        width: 1,
                        color: AppColors.divider,
                      ),
                    ),
                  ),
                Expanded(child: _MacroColumn(stat: macros[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroColumn extends StatelessWidget {
  const _MacroColumn({required this.stat});

  final MacroStat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 40,
          width: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(stat.icon, size: 18, color: stat.color),
        ),
        const SizedBox(height: 8),
        Text(
          stat.label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${stat.value} g',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: ' / ${stat.target} g',
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalorieProgressRing extends StatelessWidget {
  const _CalorieProgressRing({required this.consumed, required this.target});

  final int consumed;
  final int target;

  @override
  Widget build(BuildContext context) {
    final safeTarget = target <= 0 ? 1 : target;
    final progress = (consumed / safeTarget).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          return Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return CustomPaint(
                    size: Size.square(size),
                    painter: RingPainter(
                      progress: value,
                      strokeWidth: size * 0.05,
                      trackColor: AppColors.surfaceMuted,
                      progressColor: AppColors.primary,
                    ),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$consumed',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'kcal',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'of $target kcal',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
