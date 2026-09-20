import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/meal_type.dart';
import '../providers/meal_log_providers.dart';
import 'camera_scan/camera_frame.dart';
import 'camera_scan/empty_plate_message.dart';
import 'camera_scan/fade_slide_in.dart';
import 'camera_scan/ingredients_section.dart';
import 'camera_scan/metrics_section.dart';
import 'camera_scan/phase.dart';

/// Shared [Hero] tag for the flight between the app shell's camera FAB and
/// this screen's shutter button.
const cameraFabHeroTag = 'camera-fab-hero';

/// One continuous screen for the whole capture → confirm → analyze →
/// review flow. There's a single [Scaffold]/[AppBar] for the screen's
/// lifetime — only the photo frame's contents, the section below it, and
/// the bottom action button change as [Phase] advances. Matches
/// `design_references/img.png`.
///
/// The visual building blocks (photo frame/viewfinder, ingredient cards,
/// nutrition metrics, entrance animation) live under `camera_scan/` — this
/// file only holds the screen's camera lifecycle and phase-driven layout.
class CameraScanScreen extends ConsumerStatefulWidget {
  const CameraScanScreen({super.key, this.initialMealType});

  /// Overrides the time-of-day default meal type — set when the capture was
  /// started from a specific section's "+ Log Food" button on the home
  /// screen.
  final MealType? initialMealType;

  @override
  ConsumerState<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends ConsumerState<CameraScanScreen> {
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _cameraError;

  bool _flashOn = false;
  bool _capturing = false;
  String? _capturedPath;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera available on this device');
        return;
      }
      _cameras = cameras;
      await _openCamera(0);
    } catch (err) {
      setState(() => _cameraError = '$err');
    }
  }

  Future<void> _openCamera(int index) async {
    final previous = _controller;
    if (previous != null) {
      // Dispose the previous session and let go of it before opening a new
      // one — on Android (CameraX) two overlapping sessions can leave the
      // new controller's preview surface unbound (a blank/white preview)
      // even though initialize() succeeds and takePicture() still works.
      if (mounted) setState(() => _controller = null);
      await previous.dispose();
    }

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _cameraIndex = index;
      _controller = controller;
      _flashOn = false;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _capturing) return;
    await _openCamera((_cameraIndex + 1) % _cameras.length);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_flashOn;
    await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
    setState(() => _flashOn = next);
  }

  @override
  void dispose() {
    // Best-effort: on some devices/plugin versions, disposing a controller
    // whose preview surface was never attached (e.g. the live camera was
    // never rendered again after a capture) throws a PlatformException.
    // The screen is being torn down either way, so swallow it.
    unawaited(_controller?.dispose().catchError((_) {}));
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;

    setState(() => _capturing = true);
    try {
      final photo = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedPath = photo.path;
        _capturing = false;
      });
    } catch (err) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _cameraError = '$err';
        });
      }
    }
  }

  void _analyze() {
    final path = _capturedPath;
    if (path == null) return;
    ref
        .read(mealLogProvider.notifier)
        .analyzeCapturedPhoto(path, mealType: widget.initialMealType);
  }

  /// Discards/cancels whatever the analysis pipeline has in flight, without
  /// leaving the screen — used by both "retake" and the back action. Best
  /// effort: this makes a real network call (deleting the orphaned upload),
  /// and a failure there must never block the user from retaking/leaving.
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
      // Swallow — the local reset below must still happen.
    }
  }

  Future<void> _retakeAll() async {
    await _cleanupInFlight();
    if (mounted) setState(() => _capturedPath = null);
  }

  Future<void> _leave() async {
    await _cleanupInFlight();
    if (mounted) context.pop();
  }

  Future<void> _confirm() async {
    await ref.read(mealLogProvider.notifier).confirmMealLog();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealLogProvider);
    final pending = state.pendingAnalysis;
    final capturedPath = _capturedPath;

    final phase = capturedPath == null
        ? Phase.idle
        : pending != null
        ? Phase.reviewing
        : state.isStreaming
        ? Phase.analyzing
        : Phase.captured;

    final items = phase == Phase.reviewing ? pending!.items : state.streamingItems;
    final mealName = phase == Phase.reviewing
        ? pending!.mealName
        : state.streamingMealName;
    final showIngredients = phase == Phase.analyzing || phase == Phase.reviewing;
    final showScanningRings =
        phase == Phase.analyzing && items.isEmpty && state.isStreaming;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              LucideIcons.arrow_left,
              color: AppColors.textPrimary,
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
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
          actions: phase == Phase.idle
              ? [
                  IconButton(
                    icon: Icon(
                      _flashOn ? LucideIcons.zap : LucideIcons.zap_off,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                    onPressed: _capturing ? null : _toggleFlash,
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.switch_camera,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                    onPressed: _capturing || _cameras.length < 2 ? null : _flipCamera,
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.rotate_ccw,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                    onPressed: _retakeAll,
                  ),
                ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: PhotoFrame(
                  phase: phase,
                  capturedPath: capturedPath,
                  controller: _controller,
                  initFuture: _initFuture,
                  cameraError: _cameraError,
                  capturing: _capturing,
                  showScanningRings: showScanningRings,
                ),
              ),
              if (phase == Phase.captured && state.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    state.error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              Expanded(
                child: showIngredients
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FadeSlideIn(
                              child: IngredientsSection(
                                items: items,
                                isStreaming: state.isStreaming,
                                editable: phase == Phase.reviewing,
                              ),
                            ),
                            if (phase == Phase.reviewing)
                              FadeSlideIn(child: MetricsSection(pending: pending!)),
                          ],
                        ),
                      )
                    : const EmptyPlateMessage(),
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
      ),
    );
  }

  Widget _bottomBar(Phase phase, bool isProcessing) {
    switch (phase) {
      case Phase.idle:
        return Center(
          child: Hero(
            tag: cameraFabHeroTag,
            child: ShutterButton(capturing: _capturing, onTap: _capture),
          ),
        );
      case Phase.captured:
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _analyze,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Analyze'),
          ),
        );
      case Phase.analyzing:
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
      case Phase.reviewing:
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
