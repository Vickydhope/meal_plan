import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import 'phase.dart';

/// A classic circular camera shutter button — a white ring with a solid
/// disc inside, matching the physical shutter on a camera app.
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    super.key,
    required this.capturing,
    required this.onTap,
  });

  final bool capturing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: capturing ? null : onTap,
      child: Container(
        height: 76,
        width: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 4),
        ),
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
          child: capturing
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// The single persistent photo frame on [CameraScanScreen]: a live camera
/// preview while idle, the just-captured photo once taken — always the
/// same square, rounded, corner-bracketed container, so capturing never
/// feels like a screen change.
class PhotoFrame extends StatelessWidget {
  const PhotoFrame({
    super.key,
    required this.phase,
    required this.capturedPath,
    required this.controller,
    required this.initFuture,
    required this.cameraError,
    required this.capturing,
  });

  final CapturePhase phase;
  final String? capturedPath;
  final CameraController? controller;
  final Future<void>? initFuture;
  final String? cameraError;
  final bool capturing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(frameOuterRadius),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: AppColors.surfaceMuted,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (phase == CapturePhase.idle)
                _buildCameraContent(context)
              else
                Hero(
                  tag: capturedPhotoHeroTag,
                  child: capturedImage(capturedPath!),
                ),
              const ViewfinderCorners(),
              if (phase == CapturePhase.idle && capturing)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraContent(BuildContext context) {
    if (cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            cameraError!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return FutureBuilder<void>(
      future: initFuture,
      builder: (context, snapshot) {
        final camera = controller;
        if (snapshot.connectionState != ConnectionState.done ||
            camera == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return CoverCameraPreview(controller: camera);
      },
    );
  }
}

/// Renders the still image at [path] — [Image.network] on web (where
/// captured photos live as blob URLs), [Image.file] elsewhere. Also used
/// directly by [ScanResultScreen] for its parallax header image (no
/// corner-bracketed frame there — see [capturedPhotoHeroTag]).
Widget capturedImage(String path) {
  return kIsWeb
      ? Image.network(path, fit: BoxFit.cover)
      : Image.file(File(path), fit: BoxFit.cover);
}

/// Renders [CameraPreview] scaled to cover its square parent edge-to-edge
/// (cropping evenly, like a standard square-camera viewfinder) instead of
/// stretching or letterboxing it. Uses the plugin's own
/// [CameraValue.aspectRatio] — already corrected for sensor orientation —
/// rather than guessing at a width/height swap, which is what caused the
/// preview to look over-zoomed before.
class CoverCameraPreview extends StatelessWidget {
  const CoverCameraPreview({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameAspectRatio = constraints.maxWidth / constraints.maxHeight;
        // CameraPreview wraps itself in its own AspectRatio using
        // `1 / controller.value.aspectRatio` while in portrait (this screen
        // doesn't support landscape) — match that here, or the two nested
        // AspectRatio widgets disagree and the texture gets squished to fit
        // the wrong box instead of just being cropped.
        final previewAspectRatio = 1 / controller.value.aspectRatio;
        // Scale the (aspect-ratio-correct) preview up until it fully
        // covers the frame, then let ClipRect crop the overflow.
        var scale = frameAspectRatio / previewAspectRatio;
        if (scale < 1) scale = 1 / scale;

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: AspectRatio(
                aspectRatio: previewAspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [PhotoFrame]'s own outer corner radius ([ClipRRect]) and how far each
/// bracket is inset from the frame's edge. The bracket's own corner radius
/// is derived from these so its curve lines up with where the frame's
/// rounded corner actually is.
const frameOuterRadius = 24.0;
const _cornerInset = 12.0;

/// Shared [Hero] tag for the captured photo's flight between
/// [CameraScanScreen]'s [PhotoFrame] and [ScanResultScreen]'s parallax
/// header image.
const capturedPhotoHeroTag = 'captured-photo-hero';

class ViewfinderCorners extends StatelessWidget {
  const ViewfinderCorners({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(
          top: _cornerInset,
          left: _cornerInset,
          child: CornerMark(quarterTurns: 0),
        ),
        Positioned(
          top: _cornerInset,
          right: _cornerInset,
          child: CornerMark(quarterTurns: 1),
        ),
        Positioned(
          bottom: _cornerInset,
          right: _cornerInset,
          child: CornerMark(quarterTurns: 2),
        ),
        Positioned(
          bottom: _cornerInset,
          left: _cornerInset,
          child: CornerMark(quarterTurns: 3),
        ),
      ],
    );
  }
}

class CornerMark extends StatelessWidget {
  const CornerMark({super.key, required this.quarterTurns});

  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CustomPaint(painter: CornerPainter()),
      ),
    );
  }
}

class CornerPainter extends CustomPainter {
  const CornerPainter();

  static const _cornerRadius = frameOuterRadius - _cornerInset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, _cornerRadius)
      ..arcToPoint(
        const Offset(_cornerRadius, 0),
        radius: const Radius.circular(_cornerRadius),
      )
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanningRings extends StatefulWidget {
  const ScanningRings({super.key});

  @override
  State<ScanningRings> createState() => ScanningRingsState();
}

class ScanningRingsState extends State<ScanningRings> {
  late final Timer _messageTimer;
  int _messageIndex = 0;

  // Cycled while waiting on the upload + first Gemini tokens, so the
  // screen never reads as frozen even on requests fast/slow enough that
  // no ingredient has streamed in yet.
  static const _messages = [
    'Uploading photo…',
    'Detecting ingredients…',
    'Estimating nutrition…',
  ];

  @override
  void initState() {
    super.initState();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) {
        setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
      }
    });
  }

  @override
  void dispose() {
    _messageTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _messages[_messageIndex],
              key: ValueKey(_messageIndex),
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
