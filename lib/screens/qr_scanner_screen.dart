import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isScanned = true);
        Navigator.pop(context, barcode.rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Theme.of(context).primaryColor,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          // Close Button
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // Flash Button
          Positioned(
            top: 50,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (context, state, child) {
                    final torchState = state.torchState;
                    switch (torchState) {
                      case TorchState.on:
                        return const Icon(Icons.flash_on, color: Colors.yellow);
                      case TorchState.off:
                      case TorchState.auto:
                      case TorchState.unavailable:
                        return const Icon(Icons.flash_off, color: Colors.grey);
                    }
                  },
                ),
                onPressed: () => _controller.toggleTorch(),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Align QR code within the frame',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom overlay shape helper class
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutSizeVal = cutOutSize != 0.0 ? cutOutSize : width - 40.0;
    final cutOutWidth = cutOutSizeVal < width ? cutOutSizeVal : width - 40.0;
    final cutOutHeight = cutOutSizeVal < height ? cutOutSizeVal : height - 40.0;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromCenter(
      center: rect.center.translate(0, -cutOutBottomOffset),
      width: cutOutWidth,
      height: cutOutHeight,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    final borderOffsetRadius = borderRadius;
    final borderLength = this.borderLength;
    final cutOutLeft = cutOutRect.left;
    final cutOutTop = cutOutRect.top;
    final cutOutRight = cutOutRect.right;
    final cutOutBottom = cutOutRect.bottom;

    // Draw borders
    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(cutOutLeft, cutOutTop + borderLength)
        ..lineTo(cutOutLeft, cutOutTop + borderOffsetRadius)
        ..arcToPoint(
          Offset(cutOutLeft + borderOffsetRadius, cutOutTop),
          radius: Radius.circular(borderOffsetRadius),
          clockwise: true,
        )
        ..lineTo(cutOutLeft + borderLength, cutOutTop),
      borderPaint,
    );
    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRight - borderLength, cutOutTop)
        ..lineTo(cutOutRight - borderOffsetRadius, cutOutTop)
        ..arcToPoint(
          Offset(cutOutRight, cutOutTop + borderOffsetRadius),
          radius: Radius.circular(borderOffsetRadius),
          clockwise: true,
        )
        ..lineTo(cutOutRight, cutOutTop + borderLength),
      borderPaint,
    );
    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRight, cutOutBottom - borderLength)
        ..lineTo(cutOutRight, cutOutBottom - borderOffsetRadius)
        ..arcToPoint(
          Offset(cutOutRight - borderOffsetRadius, cutOutBottom),
          radius: Radius.circular(borderOffsetRadius),
          clockwise: true,
        )
        ..lineTo(cutOutRight - borderLength, cutOutBottom),
      borderPaint,
    );
    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(cutOutLeft + borderLength, cutOutBottom)
        ..lineTo(cutOutLeft + borderOffsetRadius, cutOutBottom)
        ..arcToPoint(
          Offset(cutOutLeft, cutOutBottom - borderOffsetRadius),
          radius: Radius.circular(borderOffsetRadius),
          clockwise: true,
        )
        ..lineTo(cutOutLeft, cutOutBottom - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
