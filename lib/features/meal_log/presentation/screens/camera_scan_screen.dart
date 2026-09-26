import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/meal_type.dart';
import 'camera_scan/camera_frame.dart';
import 'camera_scan/empty_plate_message.dart';
import 'camera_scan/phase.dart';
import 'scan_result_screen.dart';

/// Shared [Hero] tag for the flight between the app shell's camera FAB and
/// this screen's shutter button.
const cameraFabHeroTag = 'camera-fab-hero';

/// Captures a photo and lets the user confirm or retake it. Owns only the
/// camera hardware lifecycle — once the user confirms a photo ("Use
/// Photo"), it hands the path off to [ScanResultScreen], which owns
/// analysis, review, and confirming the meal log. Matches
/// `design_references/img.png`.
///
/// The visual building blocks (photo frame/viewfinder, entrance animation)
/// live under `camera_scan/` — this file only holds the camera lifecycle
/// and the idle/captured layout.
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key, this.initialMealType});

  /// Overrides the time-of-day default meal type — set when the capture was
  /// started from a specific section's "+ Log Food" button on the home
  /// screen. Threaded through to [ScanResultScreen] on confirm.
  final MealType? initialMealType;

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
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

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    setState(() => _capturedPath = picked.path);
  }

  void _retake() {
    setState(() => _capturedPath = null);
  }

  Future<void> _usePhoto() async {
    final path = _capturedPath;
    if (path == null) return;
    final confirmed = await context.pushNamed<bool>(
      AppRoute.scanResult.name,
      extra: ScanResultArgs(imagePath: path, mealType: widget.initialMealType),
    );
    if (!mounted) return;
    if (confirmed == true) {
      // Meal was saved on the scan-result screen — leave the camera too.
      context.pop();
    } else {
      // User backed out (or the scan-result screen discarded the photo) —
      // return to a live viewfinder.
      setState(() => _capturedPath = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capturedPath = _capturedPath;
    final phase = capturedPath == null
        ? CapturePhase.idle
        : CapturePhase.captured;

    return Scaffold(
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
          onPressed: () => context.pop(),
        ),
        actions: phase == CapturePhase.idle
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
                  onPressed: _capturing || _cameras.length < 2
                      ? null
                      : _flipCamera,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(
                    LucideIcons.rotate_ccw,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  onPressed: _retake,
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
              ),
            ),
            const Expanded(child: EmptyPlateMessage()),
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
                  child: _bottomBar(phase),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(CapturePhase phase) {
    switch (phase) {
      case CapturePhase.idle:
        return Stack(
          alignment: Alignment.center,
          children: [
            Hero(
              tag: cameraFabHeroTag,
              child: ShutterButton(capturing: _capturing, onTap: _capture),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Choose from gallery',
                padding: const EdgeInsets.all(14),
                icon: const Icon(
                  LucideIcons.image_plus,
                  color: AppColors.textPrimary,
                  size: 26,
                ),
                onPressed: _capturing ? null : _pickFromGallery,
              ),
            ),
          ],
        );
      case CapturePhase.captured:
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _usePhoto,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Use Photo'),
          ),
        );
    }
  }
}
