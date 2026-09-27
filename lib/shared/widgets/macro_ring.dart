import 'package:flutter/material.dart';

/// A small circular progress indicator with a value/unit label underneath,
/// used for the protein/carbs/fats mini-stats.
class MacroRing extends StatelessWidget {
  const MacroRing({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
    required this.progress,
    required this.color,
    required this.icon,
  });

  final int value;
  final String unit;
  final String label;
  final double progress;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          width: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, _) {
                  return CircularProgressIndicator(
                    value: animatedValue,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  );
                },
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$value$unit',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Just the ring + icon, no text — used when the value/label are laid out
/// separately (e.g. above the ring, as in the home stat cards).
class MiniRingIcon extends StatelessWidget {
  const MiniRingIcon({
    super.key,
    required this.progress,
    required this.color,
    required this.icon,
    this.size = 54,
  });

  final double progress;
  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return CircularProgressIndicator(
                value: animatedValue,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              );
            },
          ),
          Icon(icon, size: size * 0.4, color: color),
        ],
      ),
    );
  }
}
