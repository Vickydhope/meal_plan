import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'meal_log_provider.dart';
import 'scan_result_screen.dart';

const _accentOrange = Color(0xFFE8823A);

/// Full-screen camera capture flow: live preview while idle, then a
/// frozen-frame "AI is analyzing..." overlay (scanning rings + step
/// checklist) while the captured photo is sent off for analysis.
class CameraScanScreen extends ConsumerStatefulWidget {
  const CameraScanScreen({super.key});

  @override
  ConsumerState<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends ConsumerState<CameraScanScreen> {
  static const _analyzingSteps = [
    'Detecting ingredients',
    'Estimating calories',
    'Checking allergens',
    'Finding healthier alternatives',
  ];

  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;

  bool _flashOn = false;
  bool _analyzing = false;
  int _stepIndex = 0;
  Timer? _stepTimer;
  String? _capturedPhotoPath;
  String? _lastThumbnailPath;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera available on this device');
        return;
      }
      _cameras = cameras;
      await _openCamera(0);
    } catch (err) {
      setState(() => _error = '$err');
    }
  }

  Future<void> _openCamera(int index) async {
    final previous = _controller;
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    await previous?.dispose();
    if (!mounted) return;
    setState(() {
      _cameraIndex = index;
      _controller = controller;
      _flashOn = false;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _analyzing) return;
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
    _stepTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _analyzing) return;

    final photo = await controller.takePicture();

    setState(() {
      _analyzing = true;
      _stepIndex = 0;
      _capturedPhotoPath = photo.path;
    });

    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_stepIndex >= _analyzingSteps.length - 1) {
        timer.cancel();
        return;
      }
      setState(() => _stepIndex++);
    });

    try {
      await ref.read(mealLogProvider.notifier).analyzeCapturedPhoto(photo.path);
      _stepTimer?.cancel();

      final hasPending = ref.read(mealLogProvider).pendingAnalysis != null;
      if (!mounted) return;

      if (hasPending) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScanResultScreen()),
        );
        return;
      }

      setState(() {
        _analyzing = false;
        _lastThumbnailPath = _capturedPhotoPath;
        _capturedPhotoPath = null;
      });
    } catch (_) {
      _stepTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _lastThumbnailPath = _capturedPhotoPath;
        _capturedPhotoPath = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _RoundIconButton(
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _RoundIconButton(
              icon: _flashOn ? Icons.flash_on : Icons.flash_off,
              onTap: _analyzing ? null : _toggleFlash,
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final controller = _controller;
          if (snapshot.connectionState != ConnectionState.done ||
              controller == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final capturedPath = _capturedPhotoPath;
          final squareSize = MediaQuery.of(context).size.width - 32;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (_analyzing && capturedPath != null)
                Image.file(File(capturedPath), fit: BoxFit.cover)
              else
                _CoverCameraPreview(controller: controller),
              // Blur/darken everything outside the centered square viewfinder.
              Positioned.fill(
                child: ClipPath(
                  clipper: _InvertedSquareClipper(squareSize: squareSize),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  height: squareSize,
                  width: squareSize,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              if (_analyzing)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  bottom: 300,
                  child: const _ScanningRings(),
                ),
              if (_analyzing)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _AnalyzingCard(
                    steps: _analyzingSteps,
                    stepIndex: _stepIndex,
                  ),
                ),
              if (!_analyzing)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ThumbnailButton(path: _lastThumbnailPath),
                          GestureDetector(
                            onTap: _capture,
                            child: Container(
                              height: 76,
                              width: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          _RoundIconButton(
                            icon: Icons.cameraswitch,
                            onTap: _flipCamera,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Renders [CameraPreview] cropped to cover its parent box, instead of the
/// texture stretching to fill it. The camera plugin reports the preview
/// size in the sensor's native (landscape) orientation, so width/height are
/// swapped here before handing it to a cover-fit [FittedBox].
class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// Clips to "everywhere except a centered square" so a [BackdropFilter]
/// blurs only the area around the viewfinder, leaving the square sharp.
class _InvertedSquareClipper extends CustomClipper<Path> {
  _InvertedSquareClipper({required this.squareSize});

  final double squareSize;

  @override
  Path getClip(Size size) {
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: squareSize,
            height: squareSize,
          ),
          const Radius.circular(24),
        ),
      );
    return Path.combine(PathOperation.difference, outer, hole);
  }

  @override
  bool shouldReclip(covariant _InvertedSquareClipper oldClipper) =>
      oldClipper.squareSize != squareSize;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onTap,
      ),
    );
  }
}

class _ThumbnailButton extends StatelessWidget {
  const _ThumbnailButton({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        height: 52,
        width: 52,
        color: Colors.white24,
        child: path == null
            ? const Icon(Icons.image, color: Colors.white70, size: 20)
            : Image.file(File(path!), fit: BoxFit.cover),
      ),
    );
  }
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard({required this.steps, required this.stepIndex});

  final List<String> steps;
  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xF2FBF8F3),
        borderRadius: .all(.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI is analyzing...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final isDone = index < stepIndex;
            final isActive = index == stepIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isDone ? Icons.check_circle : Icons.circle_outlined,
                    color: isDone ? _accentOrange : Colors.black26,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 15,
                        color: isDone || isActive
                            ? Colors.black87
                            : Colors.black45,
                      ),
                    ),
                  ),
                  if (isActive && !isDone)
                    const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ScanningRings extends StatefulWidget {
  const _ScanningRings();

  @override
  State<_ScanningRings> createState() => _ScanningRingsState();
}

class _ScanningRingsState extends State<_ScanningRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 260,
        width: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final size in [260.0, 200.0, 150.0])
              Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Transform.rotate(
                  angle: _controller.value * 6.28318,
                  child: CustomPaint(
                    size: const Size(260, 260),
                    painter: _SweepArcPainter(),
                  ),
                );
              },
            ),
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accentOrange, width: 2),
                color: Colors.black26,
              ),
              child: const Icon(
                Icons.center_focus_strong,
                color: _accentOrange,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SweepArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Offset.zero & size;
    canvas.drawArc(rect.deflate(1), 0, 4.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
