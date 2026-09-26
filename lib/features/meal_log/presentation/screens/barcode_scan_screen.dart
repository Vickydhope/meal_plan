import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Full-screen barcode scanner for packaged food. Pops with the first
/// product barcode read, or nothing if the user backs out.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    // Product codes only: ignores QR codes and other barcodes on packaging.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Detection can fire again before the pop lands.
  bool _closing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        _close(code);
        return;
      }
    }
  }

  /// Stops the camera before popping (with [code], if scanned), so it's
  /// free the moment the camera screen reopens its own — dispose() alone
  /// only runs after the exit animation, too late.
  Future<void> _close([String? code]) async {
    if (_closing) return;
    _closing = true;
    await _controller.stop().catchError((_) {});
    if (mounted) context.pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System back goes through _close too, to release the camera first.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.scrim,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              LucideIcons.arrow_left,
              color: AppColors.onScrim,
              size: 18,
            ),
            onPressed: _close,
          ),
          actions: [
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, _) => IconButton(
                tooltip: 'Flashlight',
                icon: Icon(
                  state.torchState == TorchState.on
                      ? LucideIcons.zap
                      : LucideIcons.zap_off,
                  color: AppColors.onScrim,
                  size: 18,
                ),
                onPressed: state.torchState == TorchState.unavailable
                    ? null
                    : _controller.toggleTorch,
              ),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Allow camera access in Settings to scan barcodes.'
                        : "The camera couldn't start. Try again.",
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onScrim,
                    ),
                  ),
                ),
              ),
            ),
            // Aiming frame and hint; purely visual, scanning uses the whole
            // preview.
            IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 280,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.onScrim, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Point at the barcode on the package',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onScrim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
