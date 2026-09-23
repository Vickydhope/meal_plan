import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.shortestSide * .36,
            child: _CalorieProgressRing(consumed: consumed, target: target),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              spacing: 14,
              children: [for (final stat in macros) _MacroRow(stat: stat)],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.stat});

  final MacroStat stat;

  @override
  Widget build(BuildContext context) {
    final isOverTarget = stat.target > 0 && stat.value > stat.target;
    final barColor = isOverTarget ? AppColors.error : stat.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    stat.label,
                    style: AppTypography.caption12,
                  ),
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${stat.value}',
                          style: AppTypography.valueMedium.copyWith(
                            color: isOverTarget ? AppColors.error : null,
                          ),
                        ),
                        TextSpan(
                          text: '/${stat.target}g',
                          style: AppTypography.caption11.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _MacroProgressBar(
                progress: stat.target <= 0 ? 0 : stat.value / stat.target,
                color: barColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroProgressBar extends StatelessWidget {
  const _MacroProgressBar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        width: double.infinity,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: AppColors.surfaceMuted,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
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
                    style: AppTypography.statValue,
                  ),
                  Text(
                    'kcal',
                    style: AppTypography.caption10,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'of $target kcal',
                    style: AppTypography.caption10.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: AppTypography.caption12Bold.copyWith(
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
