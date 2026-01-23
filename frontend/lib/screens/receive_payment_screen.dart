// lib/screens/receive_payment_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../utils/constants.dart';

class ReceivePaymentScreen extends StatefulWidget {
  const ReceivePaymentScreen({super.key});

  @override
  State<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends State<ReceivePaymentScreen> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  String? _qrData;
  String? _paymentHash;
  bool _isPaid = false;
  bool _isLoading = false;
  Timer? _checkPaymentTimer;
  late AuthService _authService; //  ເກັບໄວ້ໃນ variable

  @override
  void initState() {
    super.initState();
    //  ເອົາ Provider ຈາກ context ທີ່ເຂົ້າມາກ່ອນ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authService = context.read<AuthService>();
        _loadWalletInfo();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //  ຮັບປະກັນວ່າ _authService ຖືກຕັ້ງຄ່າ
    _authService = context.read<AuthService>();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    _checkPaymentTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWalletInfo() async {
    if (!mounted) return;
    
    await _authService.getCurrentUser();
  }

  Future<void> _generateInvoiceQR() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ກະລຸນາປ້ອນຈຳນວນເງິນ'),
          backgroundColor: Color(0xFFFF9800), //  ໃຊ້ Color ໂດຍກົງ
        ),
      );
      return;
    }

    final amountLAK = int.tryParse(_amountController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
    
    if (amountLAK <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ຈຳນວນເງິນຕ້ອງມີຄ່າຫຼາຍກວ່າ 0'),
          backgroundColor: Color(0xFFFF9800),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isPaid = false;
    });

    final paymentService = context.read<PaymentService>();

    if (_authService.accessToken == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ກະລຸນາເຂົ້າສູ່ລະບົບໃໝ່'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final invoice = await paymentService.createInvoice(
        accessToken: _authService.accessToken!,
        amount: amountLAK,
        memo: _memoController.text.isNotEmpty 
            ? _memoController.text 
            : 'Payment to ${_authService.currentUser?.fullName ?? "User"}',
      );

      if (invoice != null && mounted) {
        setState(() {
          _qrData = invoice['payment_request'];
          _paymentHash = invoice['payment_hash'];
          _isLoading = false;
        });
        _startPaymentChecker();
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paymentService.errorMessage ?? 'ສ້າງ Invoice ລົ້ມເຫລວ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ເກີດຂໍ້ຜິດພາດ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startPaymentChecker() {
    if (_paymentHash == null) return;
    
    _checkPaymentTimer?.cancel();
    _checkPaymentTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final paymentService = context.read<PaymentService>();
      
      if (_authService.accessToken == null || !mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final status = await paymentService.checkPaymentStatus(
          accessToken: _authService.accessToken!,
          paymentHash: _paymentHash!,
        );
        
        if (status != null && status['paid'] == true && mounted) {
          timer.cancel();
          
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            
            setState(() {
              _isPaid = true;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ໄດ້ຮັບເງິນສຳເລັດ! 🎉'),
                backgroundColor: Color(0xFF4CAF50),
                duration: Duration(milliseconds: 600),
              ),
            );
            
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              Navigator.pop(context);
            }
            
            _authService.getCurrentUser().catchError((e) {
              debugPrint('ອັບເດດຍອດເງິນບໍ່ສຳເລັດ: $e');
            });
          });
        }
      } catch (e) {
        debugPrint('Error checking payment status: $e');
      }
    });
  }

  void _resetForm() {
    _checkPaymentTimer?.cancel();
    if (!mounted) return;
    
    setState(() {
      _qrData = null; // ✅ ຣີເຊັດເປັນ null ແທນ walletId
      _paymentHash = null;
      _isPaid = false;
      _isLoading = false;
    });
    _amountController.clear();
    _memoController.clear();
  }

  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _primaryOrange10 = Color(0x19FF9800);
  static const Color _primaryOrange30 = Color(0x4DFF9800);
  static const Color _successGreen = Color(0xFF4CAF50);
  static const Color _successGreen95 = Color(0xF24CAF50);

  // ✅ ສ່ວນ QR Code ທີ່ສະແດງສະເພາະເມື່ອ generate ແລ້ວ
  Widget _buildQRCodeSection(BuildContext context, AuthService authService) {
    final user = authService.currentUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile
          CircleAvatar(
            radius: 32,
            backgroundColor: _primaryOrange10,
            backgroundImage: user?.profilePhoto != null
                ? NetworkImage(user!.profilePhoto!)
                : null,
            child: user?.profilePhoto == null
                ? Icon(
                    Icons.person,
                    size: 36,
                    color: _primaryOrange,
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            user?.fullName ?? 'User',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lightning Invoice',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code with Paid Overlay
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPaid 
                        ? _successGreen 
                        : _primaryOrange30,
                    width: 2,
                  ),
                ),
                child: QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: _isPaid ? _successGreen : _primaryOrange,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: _isPaid ? Color(0xFF388E3C) : Colors.black87,
                  ),
                ),
              ),

              // Paid Overlay
              if (_isPaid)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _successGreen95,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'ຈ່າຍເງິນສຳເລັດ!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ໄດ້ຮັບເງິນແລ້ວ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ສະແດງຈຳນວນເງິນ
          if (_amountController.text.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ຈຳນວນ:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppConstants.textGray,
                    ),
                  ),
                  Text(
                    '${_amountController.text} LAK',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✅ ສ່ວນ placeholder ເວລາຍັງບໍ່ທັນ generate
  Widget _buildPlaceholderSection(BuildContext context, AuthService authService) {
    final user = authService.currentUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile
          CircleAvatar(
            radius: 32,
            backgroundColor: _primaryOrange10,
            backgroundImage: user?.profilePhoto != null
                ? NetworkImage(user!.profilePhoto!)
                : null,
            child: user?.profilePhoto == null
                ? Icon(
                    Icons.person,
                    size: 36,
                    color: _primaryOrange,
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            user?.fullName ?? 'User',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Placeholder Icon
          // Container(
          //   width: 220,
          //   height: 220,
          //   decoration: BoxDecoration(
          //     color: Colors.grey[100],
          //     borderRadius: BorderRadius.circular(16),
          //     border: Border.all(
          //       color: Colors.grey[300]!,
          //       width: 2,
          //       style: BorderStyle.solid,
          //     ),
          //   ),
          //   // child: Column(
          //   //   // mainAxisAlignment: MainAxisAlignment.center,
          //   //   // children: [
          //   //   //   Icon(
          //   //   //     Icons.qr_code_2,
          //   //   //     size: 80,
          //   //   //     color: Colors.grey[400],
          //   //   //   ),
          //   //   //   const SizedBox(height: 16),
          //   //   //   Text(
          //   //   //     'QR Code ຈະສະແດງຢູ່ນີ້',
          //   //   //     style: TextStyle(
          //   //   //       fontSize: 14,
          //   //   //       color: Colors.grey[500],
          //   //   //     ),
          //   //   //   ),
          //   //   //   const SizedBox(height: 8),
          //   //   //   Text(
          //   //   //     'ກະລຸນາປ້ອນຈຳນວນເງິນ\nແລ້ວກົດ "ສ້າງ Invoice"',
          //   //   //     textAlign: TextAlign.center,
          //   //   //     style: TextStyle(
          //   //   //       fontSize: 12,
          //   //   //       color: Colors.grey[400],
          //   //   //     ),
          //   //   //   ),
          //   //   // ],
          //   // ),
          // ),

          // Loading Overlay
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ກຳລັງສ້າງ Invoice...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        final hasInvoiceKey = user?.lnbitsWallet?.invoiceKey != null;
        final hasQrData = _qrData != null && _qrData!.isNotEmpty; // ✅ ກວດວ່າມີ QR ແລ້ວບໍ່

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'ຮັບເງິນ',
              style: TextStyle(color: Colors.black),
            ),
            centerTitle: true,
            actions: [
              // ✅ ສະແດງປຸ່ມ refresh ສະເພາະເມື່ອມີ QR ແລ້ວ
              if (hasQrData)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: _resetForm,
                  tooltip: 'ລົງໃໝ່',
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ✅ ສະແດງ QR ຫຼື Placeholder ຕາມສະຖານະ
                if (hasQrData)
                  _buildQRCodeSection(context, authService)
                else
                  _buildPlaceholderSection(context, authService),

                const SizedBox(height: 24),

                // Amount Input Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppConstants.lightGray),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ສ້າງ Invoice ຮັບເງິນ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ປ້ອນຈຳນວນເງິນທີ່ຕ້ອງການຮັບ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount Input
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        enabled: !hasQrData, // ✅ ປິດການແກ້ໄຂເມື່ອມີ QR ແລ້ວ
                        decoration: InputDecoration(
                          hintText: 'ປ້ອນຈຳນວນເງິນ',
                          prefixIcon: const Icon(Icons.money, color: Color(0xFFFF9800)),
                          suffixText: 'LAK',
                          filled: true,
                          fillColor: hasQrData ? Colors.grey[200] : AppConstants.lightGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Memo Input (Optional)
                      TextField(
                        controller: _memoController,
                        enabled: !hasQrData, // ✅ ປິດການແກ້ໄຂເມື່ອມີ QR ແລ້ວ
                        decoration: InputDecoration(
                          hintText: 'ໝາຍເຫດ (ທາງເລືອກ)',
                          prefixIcon: const Icon(Icons.note, color: Color(0xFFFF9800)),
                          filled: true,
                          fillColor: hasQrData ? Colors.grey[200] : AppConstants.lightGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Create Invoice Button ຫຼື Reset Button
                      SizedBox(
                        width: double.infinity,
                        child: hasQrData
                            ? OutlinedButton.icon(
                                onPressed: _resetForm,
                                icon: const Icon(Icons.refresh),
                                label: const Text('ສ້າງ Invoice ໃໝ່'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF9800),
                                  side: const BorderSide(color: Color(0xFFFF9800)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: hasInvoiceKey && !_isLoading && !_isPaid
                                    ? _generateInvoiceQR
                                    : null,
                                icon: const Icon(Icons.qr_code_2),
                                label: _isLoading
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('ກຳລັງສ້າງ...'),
                                        ],
                                      )
                                    : const Text('ສ້າງ Invoice'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF9800),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                      ),

                      if (!hasInvoiceKey)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            '❌ ບໍ່ສາມາດສ້າງ Invoice ໄດ້',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'ຄຳແນະນຳ:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• ປ້ອນຈຳນວນເງິນແລ້ວກົດ "ສ້າງ Invoice"\n'
                        '• QR Code ຈະສ້າງຂຶ້ນມາໃຫ້ຜູ້ຈ່າຍສະແກນ\n'
                        '• Invoice ຈະຫມົດອາຍຸໃນ 1 ຊົ່ວໂມງ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0D47A1),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
