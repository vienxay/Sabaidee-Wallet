// lib/screens/merchant_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/merchant_model.dart';
import '../services/merchant_service.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';

class MerchantPaymentScreen extends StatefulWidget {
  const MerchantPaymentScreen({super.key});

  @override
  State<MerchantPaymentScreen> createState() => _MerchantPaymentScreenState();
}

class _MerchantPaymentScreenState extends State<MerchantPaymentScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _amountController = TextEditingController();

  // States
  bool _isScanning = true;
  bool _isProcessing = false;
  String _statusMessage = '';
  Merchant? _merchant;
  String? _scannedQrCode;

  @override
  void dispose() {
    _scannerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// ເມື່ອ Scan QR ສຳເລັດ
  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String qrCode = barcodes.first.rawValue ?? '';
    if (qrCode.isEmpty) return;

    // ປິດ scanner
    setState(() {
      _isScanning = false;
      _scannedQrCode = qrCode;
      _statusMessage = 'ກຳລັງຫາຂໍ້ມູນຮ້ານຄ້າ...';
    });

    await _loadMerchant(qrCode);
  }

  /// ດຶງຂໍ້ມູນຮ້ານຄ້າ
  Future<void> _loadMerchant(String qrCodeId) async {
    setState(() => _isProcessing = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final merchantService = Provider.of<MerchantService>(context, listen: false);

    final merchant = await merchantService.getMerchantByQR(
      accessToken: authService.accessToken!,
      qrCodeId: qrCodeId,
    );

    setState(() {
      _merchant = merchant;
      _isProcessing = false;
      _statusMessage = '';
    });

    if (merchant == null) {
      _showError(merchantService.errorMessage ?? 'ບໍ່ພົບຮ້ານຄ້າ');
      _resetScanner();
    }
  }

  /// ດຳເນີນການຈ່າຍເງິນ
  Future<void> _processPayment() async {
    if (_merchant == null || _scannedQrCode == null) return;

    // Validate amount
    final amountText = _amountController.text.replaceAll(',', '').trim();
    if (amountText.isEmpty) {
      _showError('ກະລຸນາປ້ອນຈຳນວນເງິນ');
      return;
    }

    final amount = int.tryParse(amountText);
    if (amount == null || amount < 1000) {
      _showError('ຈຳນວນເງິນຕ້ອງຢ່າງໜ້ອຍ 1,000 ກີບ');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'ກຳລັງສ້າງ Invoice...';
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final merchantService = Provider.of<MerchantService>(context, listen: false);
    final paymentService = Provider.of<PaymentService>(context, listen: false);

    try {
      // Step 1: ສ້າງ Invoice (ຈາກ Admin Pool)
      debugPrint('📤 Step 1: Creating payment...');
      final paymentResult = await merchantService.createPayment(
        accessToken: authService.accessToken!,
        qrCodeId: _scannedQrCode!,
        amountLAK: amount,
        memo: 'ຈ່າຍ ${_merchant!.merchantName}',
      );

      if (paymentResult == null) {
        _showError(merchantService.errorMessage ?? 'ສ້າງ Invoice ລົ້ມເຫລວ');
        setState(() => _isProcessing = false);
        return;
      }

      debugPrint('✅ Invoice created: ${paymentResult.paymentHash}');

      // Step 2: ຈ່າຍ Invoice (User → Admin Pool)
      setState(() => _statusMessage = 'ກຳລັງຈ່າຍເງິນ...');
      debugPrint('📤 Step 2: Paying invoice...');

      final payResult = await paymentService.payInvoice(
        accessToken: authService.accessToken!,
        bolt11: paymentResult.paymentRequest,
      );

      if (payResult == null) {
        _showError(paymentService.errorMessage ?? 'ຈ່າຍເງິນລົ້ມເຫລວ');
        setState(() => _isProcessing = false);
        return;
      }

      debugPrint('✅ Invoice paid');

      // Step 3: ກວດສອບ ແລະ ລໍຖ້າ LAK ຖືກຈ່າຍໃຫ້ຮ້ານຄ້າ
      setState(() => _statusMessage = 'ກຳລັງໂອນເງິນໃຫ້ຮ້ານຄ້າ...');
      debugPrint('📤 Step 3: Processing LAK payout...');

      // ລໍຖ້າ 2 ວິນາທີ ໃຫ້ webhook process
      await Future.delayed(const Duration(seconds: 2));

      final result = await merchantService.checkAndProcessPayment(
        accessToken: authService.accessToken!,
        paymentHash: paymentResult.paymentHash,
      );

      setState(() => _isProcessing = false);

      if (result != null && 
          (result['status'] == 'completed' || result['status'] == 'already_completed')) {
        _showSuccess(paymentResult, result);
      } else if (result != null && result['status'] == 'pending') {
        // ຍັງ pending, ສະແດງວ່າ processing
        _showProcessing(paymentResult);
      } else {
        _showError(result?['error'] ?? 'ເກີດຂໍ້ຜິດພາດ');
      }

    } catch (e) {
      debugPrint('❌ Payment error: $e');
      _showError('ເກີດຂໍ້ຜິດພາດ: ${e.toString()}');
      setState(() => _isProcessing = false);
    }
  }

  /// ສະແດງ Success Dialog
  void _showSuccess(MerchantPaymentResult payment, Map<String, dynamic> result) {
    final paymentInfo = result['payment'] ?? {};
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 12),
            const Text('ຈ່າຍເງິນສຳເລັດ!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('ຮ້ານຄ້າ', payment.merchantName),
            _buildInfoRow('ຈຳນວນ', '${_formatNumber(payment.amountLAK)} ກີບ'),
            _buildInfoRow('Sats', '${payment.amountSats} sats'),
            const Divider(),
            _buildInfoRow('ຄ່າທຳນຽມ', '${_formatNumber(payment.feeLAK)} ກີບ'),
            _buildInfoRow('ຮ້ານໄດ້ຮັບ', '${_formatNumber(payment.netAmountLAK)} ກີບ', 
                valueColor: Colors.green),
            if (paymentInfo['bankReference'] != null)
              _buildInfoRow('ອ້າງອີງ', paymentInfo['bankReference']),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // ກັບໄປໜ້າຫຼັກ
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('ຕົກລົງ', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// ສະແດງ Processing (ຍັງ pending)
  void _showProcessing(MerchantPaymentResult payment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('ກຳລັງດຳເນີນການ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ການຈ່າຍ ${_formatNumber(payment.amountLAK)} ກີບ'),
            Text('ໃຫ້ ${payment.merchantName}'),
            const SizedBox(height: 8),
            const Text('ກຳລັງໂອນເງິນໃຫ້ຮ້ານຄ້າ...', 
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('ປິດ'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          )),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _isScanning = true;
      _merchant = null;
      _scannedQrCode = null;
      _amountController.clear();
      _statusMessage = '';
    });
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ຈ່າຍຮ້ານຄ້າ'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _resetScanner,
              tooltip: 'Scan ໃໝ່',
            ),
        ],
      ),
      body: _isScanning ? _buildScanner() : _buildPaymentForm(),
    );
  }

  /// QR Scanner View
  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),
        // Overlay
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
          ),
          child: Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 3),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        // Instructions
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              const Text(
                'ສະແກນ QR Code ຮ້ານຄ້າ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.orange),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Payment Form View
  Widget _buildPaymentForm() {
    if (_isProcessing && _merchant == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 16),
            Text(_statusMessage),
          ],
        ),
      );
    }

    if (_merchant == null) {
      return const Center(child: Text('ບໍ່ພົບຂໍ້ມູນຮ້ານຄ້າ'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Merchant Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, size: 40, color: Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _merchant!.merchantName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${_merchant!.merchantId}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        if (_merchant!.bankName != null)
                          Text(
                            'ທະນາຄານ: ${_merchant!.bankName}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified, color: Colors.green, size: 28),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Amount Input
          const Text(
            'ຈຳນວນເງິນ (ກີບ)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'LAK',
              suffixStyle: const TextStyle(fontSize: 16, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ຄ່າທຳນຽມ: ${_merchant!.feePercent}%',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),

          // Quick Amount Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [10000, 20000, 50000, 100000].map((amount) {
              return OutlinedButton(
                onPressed: () {
                  _amountController.text = amount.toString();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                ),
                child: Text('${_formatNumber(amount)}', 
                    style: const TextStyle(color: Colors.orange)),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Status Message
          if (_statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Text(_statusMessage),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Pay Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                disabledBackgroundColor: Colors.orange.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'ຈ່າຍເງິນ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}