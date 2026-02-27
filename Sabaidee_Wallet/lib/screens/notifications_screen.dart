// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import 'payment_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final List<Transaction> transactions;
  final Set<String> readTransactionIds; // ✅ ເພີ່ມ
  final Function(String) onMarkAsRead;  // ✅ ເພີ່ມ

  const NotificationsScreen({
    super.key,
    required this.transactions,
    required this.readTransactionIds,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ແຈ້ງເຕືອນ',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: transactions.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final isRead = readTransactionIds.contains(transaction.id);
                return _buildNotificationItem(context, transaction, isRead);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'ບໍ່ມີການແຈ້ງເຕືອນ',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, Transaction transaction, bool isRead) {
    final isReceive = transaction.isReceive;
    final iconColor = isReceive ? Colors.green : Colors.red;
    final iconBgColor = iconColor.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.grey[100] : Colors.white, // ✅ ສີຕ່າງກັນ
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          onMarkAsRead(transaction.id); // ✅ Mark as read ເມື່ອກົດ
          PaymentDetailSheet.show(context, transaction);
        },
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReceive ? Icons.arrow_downward : Icons.arrow_upward,
                color: iconColor,
                size: 24,
              ),
            ),
            // ✅ ຈຸດສີຟ້າສຳລັບຍັງບໍ່ອ່ານ
            if (!isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          isReceive ? 'ຮັບເງິນສຳເລັດ' : 'ສົ່ງເງິນສຳເລັດ',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold, // ✅ ໜາຖ້າຍັງບໍ່ອ່ານ
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${isReceive ? '+' : '-'}${transaction.amount.toInt()} sats',
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTimeAgo(transaction.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'ລ່າສຸດ';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ນາທີກ່ອນ';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ຊົ່ວໂມງກ່ອນ';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ມື້ກ່ອນ';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }
}