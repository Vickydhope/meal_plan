import 'dart:async';

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

class _WaterCardState extends ConsumerState<WaterCard> {
  /// The total after this visit's taps; `null` shows the stored total.
  int? _local;

  /// Bumped per tap to replay the icon bounce.
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
      _bubbles.add((
        id: _taps,
        text: '${deltaMl > 0 ? '+' : '−'}${deltaMl.abs()} ml',
      ));
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
          // Bounces on every tap: a new key restarts the tween.
          TweenAnimationBuilder<double>(
            key: ValueKey(_taps),
            tween: Tween(begin: _taps == 0 ? 1 : 1.25, end: 1),
            duration: ms(450),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.water.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.glass_water,
                size: 20,
                color: AppColors.water,
              ),
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
                  _FillBar(fraction: value / _goalMl),
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
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
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

/// A rounded bar filled to [fraction] (clamped) with a water gradient.
class _FillBar extends StatelessWidget {
  const _FillBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0, 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              colors: [
                AppColors.water.withValues(alpha: 0.55),
                AppColors.water,
              ],
            ),
          ),
        ),
      ),
    );
  }
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
