import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../fitness/presentation/providers/fitness_providers.dart';
import '../providers/water_providers.dart';

// ponytail: fixed goal; make it a profile setting (or ~35 ml/kg) if asked.
const _goalMl = 2500;
const _glassMl = 250;

/// Matches the `daily_water.ml` check constraint.
const _maxMl = 10000;

/// [day]'s water intake: tap + to add a glass, − to take one back.
/// Keyed per day by the caller, so local state never leaks across days.
class WaterCard extends ConsumerStatefulWidget {
  const WaterCard({super.key, required this.day, required this.editable});

  /// Local midnight of the day shown.
  final DateTime day;

  /// `false` hides the +/− buttons — past days are read-only, like meals —
  /// and hides the whole card when nothing was logged.
  final bool editable;

  @override
  ConsumerState<WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends ConsumerState<WaterCard>
    with TickerProviderStateMixin {
  /// Replayed per tap to bounce the glass. A controller rather than a keyed
  /// tween, so the glass (and its fill animation) isn't rebuilt each tap.
  late final _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );

  /// One wave cycle, shared by the glass and the bar so they move together.
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  /// Runs the wave whenever there's water to show and motion is allowed,
  /// so an empty card (or reduce motion) costs no frames.
  void _syncWave(double fraction, bool still) {
    final moving = !still && fraction > 0;
    if (moving && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!moving && _wave.isAnimating) {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    _wave.dispose();
    super.dispose();
  }

  /// The total after this visit's taps; `null` shows the stored total.
  int? _local;

  /// Tap count, used to give each floating label a distinct id.
  int _taps = 0;

  /// In-flight "+250 ml" labels; ids keep each one's animation distinct.
  final _bubbles = <({int id, String text})>[];

  /// Saves run one after another, each sending the latest total, so rapid
  /// taps can't land out of order and leave an older total stored.
  Future<void> _saving = Future.value();

  void _change(int stored, int deltaMl) {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;
    // Read up front: the queued saves may outlive this widget.
    final repository = ref.read(waterRepositoryProvider);
    final writeToHealth = ref.read(writeWaterToHealthUseCaseProvider);
    setState(() {
      _local = ((_local ?? stored) + deltaMl).clamp(0, _maxMl);
      _taps++;
      // No bounce or floating label under reduce motion: they're pure
      // motion, and a zero-length label would remove itself during the
      // build adding it.
      if (!MediaQuery.of(context).disableAnimations) {
        _bounce.forward(from: 0);
        _bubbles.add((
          id: _taps,
          text: '${deltaMl > 0 ? '+' : '−'}${deltaMl.abs()} ml',
        ));
      }
    });

    _saving = _saving.then((_) async {
      final ml = _local ?? stored;
      try {
        await repository.saveWater(userId, widget.day, ml);
      } catch (err) {
        if (!mounted) return;
        showAppSnackBar(context, userMessageFor(err));
        setState(() => _local = null);
        ref.invalidate(waterProvider(widget.day));
        return;
      }
      // Health is only a mirror: a failure there is reported, and the
      // saved total stands. Queued too, since each write replaces the last.
      try {
        await writeToHealth(widget.day, ml);
      } catch (err, stack) {
        unawaited(Sentry.captureException(err, stackTrace: stack));
        if (mounted) showAppSnackBar(context, userMessageFor(err));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(waterProvider(widget.day)).value;
    final ml = _local ?? stored ?? 0;
    final reached = ml >= _goalMl;
    final still = MediaQuery.of(context).disableAnimations;
    Duration ms(int n) => still ? Duration.zero : Duration(milliseconds: n);

    // A past day with nothing logged has nothing to show or do. Also hidden
    // while loading, so it never flashes in and back out.
    if (!widget.editable && ml == 0) return const SizedBox.shrink();
    _syncWave(ml / _goalMl, still);

    return Container(
      // The gap lives here, not in the parent, so a hidden card leaves none.
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _bounce.drive(
              Tween<double>(
                begin: 1.25,
                end: 1,
              ).chain(CurveTween(curve: Curves.elasticOut)),
            ),
            // The circle fills to the day's progress, rising after each tap.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (ml / _goalMl).clamp(0, 1)),
              duration: ms(600),
              curve: Curves.easeOutCubic,
              builder: (context, fraction, _) =>
                  _GlassFill(fraction: fraction, wave: _wave),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            // Number and bar glide to each new total together.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ml.toDouble()),
              duration: ms(600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Water', style: AppTypography.valueLarge),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: ms(300),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: reached
                            ? const Padding(
                                key: ValueKey('reached'),
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  LucideIcons.circle_check,
                                  size: 14,
                                  color: AppColors.water,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: ms(300),
                        style: AppTypography.bodySmallMedium.copyWith(
                          color: reached
                              ? AppColors.water
                              : AppColors.textSecondary,
                        ),
                        child: Text('${value.round()} / $_goalMl ml'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FillBar(fraction: value / _goalMl, wave: _wave),
                ],
              ),
            ),
          ),
          if (widget.editable) ...[
            const SizedBox(width: 4),
            // Disabled until the stored total loads, so a tap can't be based
            // on (and then overwrite) a total that isn't known yet.
            IconButton(
              tooltip: 'Remove a glass',
              icon: const Icon(LucideIcons.minus, size: 18),
              onPressed: stored == null || ml == 0
                  ? null
                  : () => _change(stored, -_glassMl),
            ),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton.filled(
                  tooltip: 'Add a glass ($_glassMl ml)',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: stored == null
                      ? null
                      : () => _change(stored, _glassMl),
                ),
                for (final bubble in _bubbles)
                  _FloatingLabel(
                    key: ValueKey(bubble.id),
                    text: bubble.text,
                    duration: ms(700),
                    onDone: () => setState(() => _bubbles.remove(bubble)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The glass icon on a circle filled from the bottom to [fraction], with a
/// moving wave on the water line (driven by [wave]).
class _GlassFill extends StatelessWidget {
  const _GlassFill({required this.fraction, required this.wave});

  final double fraction;
  final Animation<double> wave;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.square(
        dimension: 40,
        child: CustomPaint(
          painter: _GlassPainter(fraction: fraction, wave: wave),
          child: const Icon(
            LucideIcons.glass_water,
            size: 20,
            color: AppColors.water,
          ),
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({required this.fraction, required this.wave})
    : super(repaint: wave);

  final double fraction;

  /// 0..1 through one wave cycle.
  final Animation<double> wave;

  static const _amplitude = 2.0;

  /// A full glass fills to just below the rim, so its wave stays visible.
  static const _maxFill = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.water.withValues(alpha: 0.12),
    );
    if (fraction <= 0) return;

    final level = size.height * (1 - fraction * _maxFill);
    final shift = wave.value * 2 * math.pi;
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x++) {
      path.lineTo(
        x,
        level + _amplitude * math.sin(x / size.width * 2 * math.pi + shift),
      );
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = AppColors.water.withValues(alpha: 0.32),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => old.fraction != fraction;
}

/// A thin rounded bar filled to [fraction] (clamped) with a water gradient,
/// whose surface ripples and leading edge sways with [wave].
class _FillBar extends StatelessWidget {
  const _FillBar({required this.fraction, required this.wave});

  final double fraction;
  final Animation<double> wave;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      // heightFactor: the aligned parent loosens constraints, and the fill
      // would otherwise collapse to 0 px tall.
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0, 1),
        heightFactor: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: CustomPaint(painter: _BarPainter(wave: wave)),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.wave}) : super(repaint: wave);

  /// 0..1 through one wave cycle.
  final Animation<double> wave;

  /// Pixels per ripple along the bar.
  static const _wavelength = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final shift = wave.value * 2 * math.pi;
    // Kept small: the bar is only a few px tall.
    final amp = size.height * 0.2;
    // The leading edge sways back and forth within the fill's width.
    final edgeSway = math.min(2.0, size.width / 2);

    final path = Path()..moveTo(0, size.height);
    // Surface: a ripple travelling toward the leading edge.
    final surfaceEnd = size.width - edgeSway;
    for (var x = 0.0; x <= surfaceEnd; x++) {
      path.lineTo(
        x,
        amp + amp * math.sin(x / _wavelength * 2 * math.pi - shift),
      );
    }
    // Leading edge, top to bottom.
    for (var y = 0.0; y <= size.height; y += 0.5) {
      path.lineTo(
        surfaceEnd + edgeSway * math.sin(y / size.height * math.pi + shift),
        y,
      );
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [AppColors.water.withValues(alpha: 0.55), AppColors.water],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) => false;
}

/// "+250 ml" that drifts up from the + button and fades, then removes
/// itself via [onDone].
class _FloatingLabel extends StatelessWidget {
  const _FloatingLabel({
    super.key,
    required this.text,
    required this.duration,
    required this.onDone,
  });

  final String text;
  final Duration duration;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOut,
        onEnd: onDone,
        builder: (context, t, child) => Transform.translate(
          offset: Offset(0, -28 * t),
          child: Opacity(opacity: 1 - t, child: child),
        ),
        child: Text(
          text,
          style: AppTypography.caption12Bold.copyWith(color: AppColors.water),
        ),
      ),
    );
  }
}
