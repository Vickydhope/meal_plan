import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'ring_painter.dart';

/// The centered "729 of 1512 kcal" donut ring, matching the reference
/// design — no surrounding card, just the ring floating on the scaffold
/// background with the totals inside it.
class CalorieRing extends StatelessWidget {
  const CalorieRing({super.key, required this.consumed, required this.target});

  final int consumed;
  final int target;

  @override
  Widget build(BuildContext context) {
    final safeTarget = target <= 0 ? 1 : target;
    final progress = (consumed / safeTarget).clamp(0.0, 1.0);

    return Center(
      child: SizedBox(
        height: 180,
        width: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  size: const Size.square(180),
                  painter: RingPainter(
                    progress: value,
                    strokeWidth: 10,
                    trackColor: AppColors.surfaceMuted,
                    progressColor: AppColors.primary,
                  ),
                );
              },
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$consumed', style: AppTypography.statValueXLarge),
                const SizedBox(height: 4),
                Text('of $target kcal', style: AppTypography.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
