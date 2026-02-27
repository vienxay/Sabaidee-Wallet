import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class PaymentDetailSheet extends StatelessWidget {
  final Transaction transaction;

  const PaymentDetailSheet({super.key, required this.transaction});

  static void show(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentDetailSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment Detail',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Time',
                  transaction.formattedDate,
                ),
                _buildDetailRow(
                  'Amount (sats)',
                  '${transaction.amount.toInt()}',
                ),
                _buildDetailRow(
                  'Fiat',
                  'about \$${(transaction.amount / 8000).toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  'Type',
                  'LIGHTNING NETWORK PAYMENT',
                ),
                _buildDetailRow(
                  'Status',
                  transaction.status.toUpperCase(),
                  valueColor: transaction.status == 'paid' 
                      ? Colors.green 
                      : AppConstants.primaryOrange,
                ),
                _buildDetailRow(
                  'Total Fees (sats)',
                  '${transaction.fee?.toInt() ?? 0}',
                ),
                _buildDetailRow(
                  'Note',
                  transaction.description ?? 'Pay to Wallet of Sabaidee user: ${transaction.toWallet?.substring(0, 10) ?? "unknown"}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppConstants.primaryOrange,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}