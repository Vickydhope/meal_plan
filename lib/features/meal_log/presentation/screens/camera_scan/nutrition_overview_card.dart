import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/shimmer_box.dart';
import '../../../domain/entities/meal_analysis_item.dart';

/// The scan-result screen's calorie/macro summary — a segmented ring (one
/// arc per macro, sized by its share of calories) with the total in the
/// center, and a protein/carbs/fats breakdown beside it. Matches
/// `design_references/nutricard.jpg`.
///
/// [items] grows one ingredient at a time as analysis streams in. While
/// it's still empty every value shimmers in place of a placeholder; the
/// moment the first ingredient lands, the ring sweeps in and the macro
/// rows crossfade to their totals — then keep updating live as more
/// ingredients (and the health score) arrive.
class NutritionOverviewCard extends StatelessWidget {
  const NutritionOverviewCard({
    super.key,
    required this.items,
    required this.healthScore,
  });

  final List<MealAnalysisItem> items;

  /// Null until Gemini has emitted the health rating (arrives with the
  /// rest of the settled result, after streaming ends).
  final int? healthScore;

  @override
  Widget build(BuildContext context) {
    final hasData = items.isNotEmpty;
    final calories = items.fold(0.0, (sum, i) => sum + i.adjustedCalories).round();
    final protein = items.fold(0.0, (sum, i) => sum + i.adjustedProteinG).round();
    final carbs = items.fold(0.0, (sum, i) => sum + i.adjustedCarbsG).round();
    final fats = items.fold(0.0, (sum, i) => sum + i.adjustedFatsG).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition',
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Detected from your photo',
                      style: AppTypography.caption12,
                    ),
                  ],
                ),
              ),
              _HealthBadge(score: healthScore),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: _MacroRing(
                  calories: calories,
                  protein: protein,
                  carbs: carbs,
                  fats: fats,
                  hasData: hasData,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  spacing: 14,
                  children: [
                    _MacroRow(
                      icon: LucideIcons.drumstick,
                      color: AppColors.protein,
                      label: 'Protein',
                      value: protein,
                      hasData: hasData,
                    ),
                    _MacroRow(
                      icon: LucideIcons.wheat,
                      color: AppColors.carbs,
                      label: 'Carbs',
                      value: carbs,
                      hasData: hasData,
                    ),
                    _MacroRow(
                      icon: LucideIcons.droplet,
                      color: AppColors.fat,
                      label: 'Fats',
                      value: fats,
                      hasData: hasData,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return const ShimmerBox(width: 52, height: 24, borderRadius: 20);
    }

    final color = score! >= 7
        ? AppColors.success
        : score! >= 4
        ? AppColors.warning
        : AppColors.error;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(LucideIcons.wand_sparkles, size: 12, color: color),
            Text(
              '$score/10',
              style: AppTypography.caption12Bold.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.hasData,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ),
        if (!hasData)
          const ShimmerBox(width: 36)
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              '${value}g',
              key: ValueKey(value),
              style: AppTypography.valueMedium,
            ),
          ),
      ],
    );
  }
}

/// A ring made of one rounded-cap arc per macro, each sized by its share
/// of the meal's calories (protein/carbs at 4 kcal/g, fat at 9 kcal/g) —
/// the same convention nutrition-label rings use, so a fatty item reads as
/// a bigger wedge even at a lower gram count. The total calorie count sits
/// in the center. Flat gray track with a shimmering center while
/// [hasData] is false.
class _MacroRing extends StatelessWidget {
  const _MacroRing({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.hasData,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final segments = [
      _RingSegment(protein * 4, AppColors.protein),
      _RingSegment(carbs * 4, AppColors.carbs),
      _RingSegment(fats * 9, AppColors.fat),
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: hasData ? 1 : 0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, reveal, _) {
            return CustomPaint(
              size: const Size.square(108),
              painter: _MacroRingPainter(
                segments: segments,
                reveal: reveal,
                strokeWidth: 7,
                trackColor: AppColors.surfaceMuted,
              ),
            );
          },
        ),
        if (!hasData)
          const Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              ShimmerBox(width: 34, height: 20, borderRadius: 6),
              ShimmerBox(width: 44, height: 10, borderRadius: 4),
            ],
          )
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey(calories),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$calories',
                  style: AppTypography.statValue,
                ),
                Text(
                  'Calories',
                  style: AppTypography.caption10,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RingSegment {
  const _RingSegment(this.weight, this.color);

  final num weight;
  final Color color;
}

class _MacroRingPainter extends CustomPainter {
  const _MacroRingPainter({
    required this.segments,
    required this.reveal,
    required this.strokeWidth,
    required this.trackColor,
  });

  final List<_RingSegment> segments;

  /// 0..1 sweep-in factor applied to every segment, animated once when
  /// data first arrives.
  final double reveal;
  final double strokeWidth;
  final Color trackColor;

  /// Angular gap left between adjacent segments, in radians.
  static const _gap = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final total = segments.fold<num>(0, (sum, s) => sum + s.weight);
    if (total <= 0 || reveal <= 0) return;

    final sweepBudget = 2 * math.pi - segments.length * _gap;
    var angle = -math.pi / 2;
    for (final segment in segments) {
      final sweep = (segment.weight / total) * sweepBudget * reveal;
      if (sweep > 0) {
        final paint = Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, angle, sweep, false, paint);
      }
      angle += sweep + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.reveal != reveal ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor;
  }
}
