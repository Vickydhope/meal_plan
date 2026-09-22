import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/meal_type.dart';
import '../providers/meal_log_providers.dart';
import 'camera_scan/camera_frame.dart';
import 'camera_scan/fade_slide_in.dart';
import 'camera_scan/ingredients_section.dart';
import 'camera_scan/nutrition_overview_card.dart';
import 'camera_scan/phase.dart';

/// Arguments for [ScanResultScreen], carried through go_router's `extra`.
class ScanResultArgs {
  const ScanResultArgs({required this.imagePath, this.mealType});

  /// Local file path of the photo confirmed on [CameraScanScreen].
  final String imagePath;

  /// Overrides the time-of-day default meal type, forwarded from
  /// [CameraScanScreen.initialMealType].
  final MealType? mealType;
}

/// Analysis + review screen: starts analyzing [ScanResultArgs.imagePath] as
/// soon as it's shown, streams in ingredients, and lets the user edit and
/// confirm the result as a meal log. The captured photo arrives via
/// [capturedPhotoHeroTag] from [CameraScanScreen] as a full-bleed parallax
/// header image (a [SliverAppBar.flexibleSpace], not the corner-bracketed
/// frame used on the capture screen) that scrolls away with the rest of
/// the content.
///
/// The visual building blocks (ingredient cards, nutrition metrics,
/// entrance animation) live under `camera_scan/` — this file only holds
/// the analysis lifecycle and phase-driven layout.
class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key, required this.args});

  final ScanResultArgs args;

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Deferred a frame: analyzeCapturedPhoto mutates notifier state
    // synchronously before its first await, which can't happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started || !mounted) return;
      _started = true;
      ref
          .read(mealLogProvider.notifier)
          .analyzeCapturedPhoto(widget.args.imagePath, mealType: widget.args.mealType);
    });
  }

  /// Discards/cancels whatever the analysis pipeline has in flight, without
  /// leaving the screen — used by both "retake" and the back action. Best
  /// effort: this makes a real network call (deleting the orphaned upload),
  /// and a failure there must never block the user from leaving.
  Future<void> _cleanupInFlight() async {
    final notifier = ref.read(mealLogProvider.notifier);
    final current = ref.read(mealLogProvider);
    try {
      if (current.pendingAnalysis != null) {
        await notifier.discardPendingMeal();
      } else if (current.isStreaming) {
        await notifier.cancelAnalysis();
      }
    } catch (_) {
      // Swallow — the pop below must still happen.
    }
  }

  /// Pops immediately — cleanup is best-effort and network-bound (see
  /// [_cleanupInFlight]), so awaiting it here would make every back press
  /// wait on a request the UI doesn't actually depend on.
  void _leave() {
    unawaited(_cleanupInFlight());
    context.pop(false);
  }

  Future<void> _confirm() async {
    await ref.read(mealLogProvider.notifier).confirmMealLog();
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealLogProvider);
    final pending = state.pendingAnalysis;

    final phase = pending != null ? ScanPhase.reviewing : ScanPhase.analyzing;
    final items = phase == ScanPhase.reviewing ? pending!.items : state.streamingItems;
    final mealName = phase == ScanPhase.reviewing
        ? pending!.mealName
        : state.streamingMealName;
    final showScanningRings =
        phase == ScanPhase.analyzing && items.isEmpty && state.isStreaming;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: AppColors.background,
                    elevation: 0,
                    // Full-bleed header spans the screen width, so match
                    // that width to keep the photo at its native 1:1
                    // aspect ratio.
                    expandedHeight: MediaQuery.of(context).size.width,
                    leading: IconButton(
                      icon: const Icon(
                        LucideIcons.arrow_left,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _leave,
                    ),
                    title: mealName == null
                        ? null
                        : Text(
                            mealName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: capturedPhotoHeroTag,
                            child: capturedImage(widget.args.imagePath),
                          ),
                          // Scrim so the back button/title stay legible
                          // against whatever the photo looks like.
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black45, Colors.transparent],
                                stops: [0, 0.35],
                              ),
                            ),
                          ),
                          if (showScanningRings) const ScanningRings(),
                        ],
                      ),
                    ),
                  ),
                  if (state.error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Text(
                          state.error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NutritionOverviewCard(
                            items: items,
                            healthScore: pending?.healthScore,
                          ),
                          const SizedBox(height: 20),
                          FadeSlideIn(
                            child: IngredientsSection(
                              items: items,
                              isStreaming: state.isStreaming,
                              editable: phase == ScanPhase.reviewing,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(phase),
                  child: _bottomBar(phase, state.isProcessing),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(ScanPhase phase, bool isProcessing) {
    switch (phase) {
      case ScanPhase.analyzing:
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => ref.read(mealLogProvider.notifier).stopAnalyzing(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Stop Analyzing'),
          ),
        );
      case ScanPhase.reviewing:
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isProcessing ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: isProcessing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm'),
          ),
        );
    }
  }
}
