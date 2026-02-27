import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../utils/constants.dart';
import 'transaction_history_screen.dart';
import 'qr_scanner_screen.dart';


class SendPaymentScreen extends StatefulWidget {
  final String? scannedData;
  
  const SendPaymentScreen({super.key, this.scannedData});

  @override
  State<SendPaymentScreen> createState() => _SendPaymentScreenState();
}

class _SendPaymentScreenState extends State<SendPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _walletIdController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ຖ້າມີ scannedData ໃຫ້ຕັ້ງຄ່າໃສ່ wallet ID
    if (widget.scannedData != null) {
      _walletIdController.text = widget.scannedData!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _walletIdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ເພີ່ມ function ສຳລັບເປີດ scanner
  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _walletIdController.text = result;
      });
    }
  }

  void _handleSend() async {
  if (_formKey.currentState!.validate()) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final paymentService = Provider.of<PaymentService>(context, listen: false);

    final amount = double.parse(_amountController.text.replaceAll(',', ''));
    final walletId = _walletIdController.text.trim();
    final description = _descriptionController.text.trim();

    try {
      final result = await paymentService.sendPayment(
        accessToken: authService.accessToken!,
        amount: amount,
        toWalletId: walletId,
        description: description,
      );

      if (result != null) {
        // ແຈ້ງສຳເລັດ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ໂອນເງິນສຳເລັດ: $amount LAK'),
            backgroundColor: Colors.green,
          ),
        );

        // ກັບໄປ history ແລະ refresh
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionHistoryScreen(),
          ),
          (route) => false,
        );
      } else {
        // ສະແດງ error ຖ້າລົ້ມ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paymentService.errorMessage ?? 'ໂອນເງິນລົ້ມເຫລວ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ເກີດຂໍ້ຜິດພາດ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final balance = user?.lnbitsWallet?.balance ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Send',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.black),
            onPressed: _openScanner,  // ແກ້ຕົງນີ້
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Available Balance
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppConstants.primaryOrange.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppConstants.primaryOrange.withAlpha(51),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ຍອດເງິນຄົງເຫຼືອ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${balance.toStringAsFixed(0)} LAK',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Amount Input
              const Text(
                'ຈຳນວນເງິນ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.lightGray, width: 2),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryOrange,
                      ),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: 36,
                          color: AppConstants.textGray,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'ກະລຸນາປ້ອນຈຳນວນເງິນ';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'ຈຳນວນເງິນບໍ່ຖືກຕ້ອງ';
                        }
                        if (amount > balance) {
                          return 'ຍອດເງິນບໍ່ພຽງພໍ';
                        }
                        return null;
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'LAK',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.darkGray,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.lightGray,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '≈ \$0.00',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppConstants.darkGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Amount Buttons
              Row(
                children: [
                  Expanded(child: _buildQuickAmountButton('10,000')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAmountButton('50,000')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildQuickAmountButton('100,000')),
                ],
              ),

              const SizedBox(height: 32),

              // Recipient Wallet ID
              const Text(
                'ໂອນເຂົ້າ Wallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _walletIdController,
                decoration: InputDecoration(
                  hintText: 'ປ້ອນ Wallet ID ຜູ້ຮັບ',
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppConstants.textGray,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppConstants.primaryOrange,
                    ),
                    onPressed: _openScanner,  // ແກ້ຕົງນີ້
                  ),
                  filled: true,
                  fillColor: AppConstants.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ກະລຸນາປ້ອນ Wallet ID';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Description (Optional)
              const Text(
                'ໝາຍເຫດ (ທາງເລືອກ)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'ເພີ່ມໝາຍເຫດ...',
                  filled: true,
                  fillColor: AppConstants.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'ສືບຕໍ່',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String amount) {
    return InkWell(
      onTap: () {
        _amountController.text = amount.replaceAll(',', '');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppConstants.primaryOrange),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          amount,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppConstants.primaryOrange,
          ),
        ),
      ),
    );
  }
}