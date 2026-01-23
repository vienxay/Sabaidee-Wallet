// lib/screens/transaction_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _error;
  int _balance = 0;
  double? _satToLakRate;

  // ✅ ກັ່ນຕອງສະເພາະທຸລະກຳທີ່ສຳເລັດແລ້ວ
  List<Transaction> get _completedTransactions {
    return _transactions.where((t) => !t.isPending).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authService = context.read<AuthService>();
    final paymentService = context.read<PaymentService>();

    if (authService.accessToken == null) {
      if (mounted) {
        setState(() {
          _error = 'ກະລຸນາເຂົ້າສູ່ລະບົບກ່ອນ';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // ✅ ດຶງ rate ຈາກ backend
      final rate = await paymentService.fetchSatToLakRate(authService.accessToken!);
      if (mounted) {
        setState(() {
          _satToLakRate = rate;
        });
      }

      // ✅ ດຶງ balance
      final balanceResult = await paymentService.getBalance(
        accessToken: authService.accessToken!,
      );

      if (balanceResult != null && mounted) {
        final balanceInMsats = balanceResult['balance'] ?? 0;
        final balanceInSats = balanceInMsats / 1000;

        setState(() {
          _balance = balanceInSats.round();
        });
      }

      // ✅ ດຶງ transactions
      final transactions = await paymentService.getTransactionHistory(
        accessToken: authService.accessToken!,
      );

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'ເກີດຂໍ້ຜິດພາດ: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'History',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    _buildTotalBalance(),
                    Expanded(
                      child: _buildTransactionList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('ລອງໃໝ່'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBalance() {
    final lakAmount = _balance * (_satToLakRate ?? 20.30);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
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
            'ຍອດຄົງເຫຼືອ',
            style: TextStyle(
              fontSize: 16,
              color: AppConstants.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_balance Sats',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryOrange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat('#,##0').format(lakAmount)} ₭',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryOrange,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    // ✅ ໃຊ້ _completedTransactions ແທນ _transactions
    final displayTransactions = _completedTransactions;

    if (displayTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: AppConstants.darkGray.withAlpha(76),
            ),
            const SizedBox(height: 16),
            const Text(
              'ຍັງບໍ່ມີທຸລະກຳ',
              style: TextStyle(
                fontSize: 16,
                color: AppConstants.darkGray,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayTransactions.length,
        itemBuilder: (context, index) {
          return _buildTransactionCard(displayTransactions[index]);
        },
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isReceive = transaction.isReceive;
    final amountColor = isReceive ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.lightGray,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isReceive 
                  ? Colors.green.withAlpha(25)
                  : Colors.red.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReceive ? Icons.arrow_downward : Icons.arrow_upward,
              color: isReceive ? Colors.green : Colors.red,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceive 
                      ? 'ໄດ້ຮັບເງິນໂອນ '
                      : 'ໂອນເງິນອອກ ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),

                Text(
                  transaction.formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.darkGray.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Amount Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.isReceive ? '+' : '-'}${transaction.amount.toInt()} sats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat('#,##0').format(transaction.amount * (_satToLakRate ?? 20.30))} ₭',
                style: TextStyle(
                  fontSize: 12,
                  color: AppConstants.darkGray.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}