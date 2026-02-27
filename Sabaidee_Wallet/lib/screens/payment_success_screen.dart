import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'transaction_history_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final double amount;
  final String toWalletId;
  final String? toName;
  final String transactionId;
  final String? paymentMethod;
  final String? invoiceUrl;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.toWalletId,
    this.toName,
    required this.transactionId,
    this.paymentMethod,
    this.invoiceUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox(), // ບໍ່ໃຫ້ກົດກັບ
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Success Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 60,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Success Title
                  const Text(
                    'Payment success',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'ການໂອນເງິນສຳເລັດແລ້ວ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppConstants.darkGray.withAlpha(179),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Transaction ID
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.lightGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRANSACTION',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppConstants.darkGray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          transactionId,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Details
                  _buildDetailCard(
                    icon: Icons.account_circle_outlined,
                    title: 'Sender',
                    subtitle: toName ?? 'Sabaidee wallet',
                    detail: '(Payyadebit)',
                  ),

                  const SizedBox(height: 12),

                  _buildDetailCard(
                    icon: Icons.restaurant_outlined,
                    title: 'Recipient',
                    subtitle: toName ?? 'Viengsay Restaurant',
                    detail: null,
                  ),

                  const SizedBox(height: 24),

                  // Amount
                  Container(
                    padding: const EdgeInsets.all(24),
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
                          'Amount',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppConstants.darkGray,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${amount.toStringAsFixed(0)} LAK',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Additional Info
                  if (paymentMethod != null)
                    _buildInfoRow('Payment Method', paymentMethod!),
                  
                  _buildInfoRow(
                    'Date',
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  ),
                  
                  _buildInfoRow(
                    'Time',
                    '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  ),

                  if (invoiceUrl != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConstants.lightGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            color: AppConstants.primaryOrange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              invoiceUrl!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppConstants.darkGray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            color: AppConstants.primaryOrange,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: invoiceUrl!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ຄັດລອກແລ້ວ')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
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
                      'ກັບໄປໜ້າຫຼັກ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const TransactionHistoryScreen(),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(
                        color: AppConstants.primaryOrange,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ເບິ່ງປະຫວັດ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.primaryOrange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.lightGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.lightGray,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppConstants.primaryOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppConstants.darkGray,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppConstants.darkGray,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}