import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A single shimmering placeholder rectangle — a muted base with a soft
/// highlight band sweeping across it on a loop, used wherever a value is
/// still loading (e.g. streamed-in nutrition numbers). Purely decorative;
/// carries no size opinion beyond what's passed in, so it drops into any
/// layout the way a `Text`/icon placeholder would.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Sweeps a highlight band left-to-right, looping every cycle.
        final dx = -1.5 + 3.0 * _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                AppColors.surfaceMuted,
                AppColors.shimmerHighlight,
                AppColors.surfaceMuted,
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(dx - 0.6, 0),
              end: Alignment(dx + 0.6, 0),
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
