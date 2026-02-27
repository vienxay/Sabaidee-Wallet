import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;
  bool _isProcessingImage = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _isScanned = true;
        final String code = barcode.rawValue!;
        Navigator.pop(context, code);
        break;
      }
    }
  }

  /// ເລືອກຮູບພາບຈາກ Gallery ແລ້ວ scan QR Code
  Future<void> _pickImageFromGallery() async {
    if (_isProcessingImage) return;

    setState(() => _isProcessingImage = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        setState(() => _isProcessingImage = false);
        return;
      }

      // ໃຊ້ MobileScanner ເພື່ອ analyze ຮູບ
      final BarcodeCapture? result =
          await cameraController.analyzeImage(image.path);

      if (!mounted) return;

      if (result != null && result.barcodes.isNotEmpty) {
        final String? code = result.barcodes.first.rawValue;
        if (code != null) {
          Navigator.pop(context, code);
          return;
        }
      }

      // ບໍ່ພົບ QR Code ໃນຮູບ
      _showNoQRFoundDialog();
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _showNoQRFoundDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.orange),
            SizedBox(width: 8),
            Text('ບໍ່ພົບ QR Code'),
          ],
        ),
        content: const Text('ບໍ່ພົບ QR Code ໃນຮູບທີ່ເລືອກ\nກະລຸນາເລືອກຮູບໃໝ່'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ຕົກລົງ', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('ເກີດຂໍ້ຜິດພາດ'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ຕົກລົງ', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ສະແກນ QR Code',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QRScannerOverlayShape(
                borderColor: AppConstants.primaryOrange,
                borderRadius: 12,
                borderLength: 30,
                borderWidth: 4,
                cutOutSize: 280,
              ),
            ),
          ),

          // ຂໍ້ຄວາມລຸ່ມ
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'ວາງ QR Code ໃນກອບ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'ລະບົບຈະສະແກນອັດຕະໂນມັດ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ✅ ປຸ່ມເລືອກຮູບພາບຈາກ Gallery
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isProcessingImage ? null : _pickImageFromGallery,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: _isProcessingImage
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'ເລືອກຮູບພາບ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom overlay shape
class QRScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QRScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.5),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
        Radius.circular(borderRadius),
      ));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
        Radius.circular(borderRadius),
      ))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Paint paint = Paint()..color = overlayColor;
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.drawPath(getOuterPath(rect), paint);

    final double cornerLength = borderLength;
    final double r = borderRadius;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.top + cornerLength)
        ..lineTo(cutOutRect.left, cutOutRect.top + r)
        ..quadraticBezierTo(cutOutRect.left, cutOutRect.top, cutOutRect.left + r, cutOutRect.top)
        ..lineTo(cutOutRect.left + cornerLength, cutOutRect.top),
      borderPaint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - cornerLength, cutOutRect.top)
        ..lineTo(cutOutRect.right - r, cutOutRect.top)
        ..quadraticBezierTo(cutOutRect.right, cutOutRect.top, cutOutRect.right, cutOutRect.top + r)
        ..lineTo(cutOutRect.right, cutOutRect.top + cornerLength),
      borderPaint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right, cutOutRect.bottom - cornerLength)
        ..lineTo(cutOutRect.right, cutOutRect.bottom - r)
        ..quadraticBezierTo(cutOutRect.right, cutOutRect.bottom, cutOutRect.right - r, cutOutRect.bottom)
        ..lineTo(cutOutRect.right - cornerLength, cutOutRect.bottom),
      borderPaint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left + cornerLength, cutOutRect.bottom)
        ..lineTo(cutOutRect.left + r, cutOutRect.bottom)
        ..quadraticBezierTo(cutOutRect.left, cutOutRect.bottom, cutOutRect.left, cutOutRect.bottom - r)
        ..lineTo(cutOutRect.left, cutOutRect.bottom - cornerLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QRScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}