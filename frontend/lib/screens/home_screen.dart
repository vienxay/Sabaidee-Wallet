// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../utils/constants.dart';
import 'menu_screen.dart';
import 'send_payment_screen.dart';
import 'transaction_history_screen.dart';
import 'qr_scanner_screen.dart';
import 'receive_payment_screen.dart';
import 'payment_detail_screen.dart';
import 'package:intl/intl.dart';
import 'notifications_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isBalanceVisible = true;
  bool _isLoading = false;
  int _balance = 0;
  bool _showSats = true;

  List<Transaction> _recentTransactions = [];

  double? _satToLakRate = 19;

  Set<String> _readTransactionIds = {};

  // ✅ ກັ່ນຕອງສະເພາະທຸລະກຳທີ່ສຳເລັດແລ້ວ (isPending = false) ແລະ ພາຍໃນ 5 ຊົ່ວໂມງ
  List<Transaction> get _transactionsWithin5Hours {
    final now = DateTime.now();
    final fiveHoursAgo = now.subtract(const Duration(hours: 5));
    
    return _recentTransactions.where((transaction) {
      return !transaction.isPending && transaction.createdAt.isAfter(fiveHoursAgo);
    }).toList();
  }
  
  // ✅ ທຸລະກຳທີ່ສຳເລັດແລ້ວທັງໝົດ (ສຳລັບສະແດງໃນ list)
  List<Transaction> get _completedTransactions {
    return _recentTransactions.where((transaction) => !transaction.isPending).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadReadTransactions();
    _loadData();
  }

  Future<void> _loadReadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList('read_transaction_ids') ?? [];
    setState(() {
      _readTransactionIds = readIds.toSet();
    });
  }

  Future<void> _markAsRead(String transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readTransactionIds.add(transactionId);
    });
    await prefs.setStringList('read_transaction_ids', _readTransactionIds.toList());
  }

  // ✅ ນັບສະເພາະທຸລະກຳທີ່ສຳເລັດແລ້ວ ແລະ ຍັງບໍ່ອ່ານ
  int get _unreadCount {
    return _transactionsWithin5Hours
        .where((t) => !_readTransactionIds.contains(t.id))
        .length;
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final paymentService = context.read<PaymentService>();

    try {
      await authService.getCurrentUser();

      if (authService.accessToken != null) {
        final balanceResult = await paymentService.getBalance(
          accessToken: authService.accessToken!,
        );
        
        if (balanceResult != null && mounted) {
          setState(() {
            _balance = ((balanceResult['balance'] ?? 0) / 1000).round();
          });
        }

        final transactions = await paymentService.getTransactionHistory(
          accessToken: authService.accessToken!,
          limit: 5,
        );

        if (mounted) {
          setState(() {
            _recentTransactions = transactions;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MenuScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadData,
          ),
          
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(
                        transactions: _completedTransactions, // ✅ ສົ່ງສະເພາະທຸລະກຳທີ່ສຳເລັດ
                        readTransactionIds: _readTransactionIds,
                        onMarkAsRead: _markAsRead,
                      ),
                    ),
                  );
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          _buildProfileSection(user),
                          const SizedBox(height: 20),
                          _buildBalanceCard(),
                          const SizedBox(height: 16),
                          _buildActionButtons(context),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRecentTransaction(context),
                    const SizedBox(height: 16),
                    _buildHistoryButton(context),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildProfileSection(user) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[300],
          backgroundImage: user?.profilePhoto != null
              ? NetworkImage(user!.profilePhoto!)
              : null,
          child: user?.profilePhoto == null
              ? const Icon(Icons.person, size: 32, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ສະບາຍດີ,',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                user?.fullName ?? 'User',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final lakAmount = _balance * (_satToLakRate ?? 20.30);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryOrange,
            AppConstants.primaryOrange.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryOrange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSats = !_showSats;
                      });
                    },
                    child: Icon(
                      _showSats ? Icons.change_circle : Icons.change_circle_outlined,
                      color: Colors.white70,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isBalanceVisible = !_isBalanceVisible;
                      });
                    },
                    child: Icon(
                      _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isBalanceVisible
                ? _showSats
                    ? '$_balance sats'
                    : '≈ ${NumberFormat('#,##0').format(lakAmount)} ₭'
                : '••••••••',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isBalanceVisible
                ? _showSats
                    ? '≈ ${NumberFormat('#,##0').format(lakAmount)} ₭'
                    : '$_balance sats'
                : '••••••••',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.arrow_downward,
            label: 'ຮັບ',
            color: Colors.white,
            textColor: AppConstants.primaryOrange,
            borderColor: AppConstants.primaryOrange,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReceivePaymentScreen(),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.arrow_upward,
            label: 'ສົ່ງ',
            color: AppConstants.primaryOrange,
            textColor: Colors.white,
            borderColor: AppConstants.primaryOrange,
            onTap: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const QRScannerScreen(),
                ),
              );
              if (result != null && mounted) {
                final payResult = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SendPaymentScreen(scannedData: result),
                  ),
                );
                if (payResult == true) {
                  _loadData();
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    required String label,
    required Color color,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ແກ້ໄຂ Recent Transaction - ສະແດງສະເພາະທຸລະກຳທີ່ສຳເລັດແລ້ວ
  Widget _buildRecentTransaction(BuildContext context) {
    final recentTxns = _transactionsWithin5Hours; // ✅ ໃຊ້ທຸລະກຳທີ່ສຳເລັດ ພາຍໃນ 5 ຊົ່ວໂມງ

    if (recentTxns.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'ບໍ່ມີທຸລະກຳລ່າສຸດ',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ກົດ "ເບິ່ງປະຫວັດທັງໝົດ" ເພື່ອເບິ່ງທຸລະກຳເກົ່າ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ທຸລະກຳລ່າສຸດ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
                    Text(
                      'ລາຍການ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppConstants.primaryOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          ...recentTxns.map((transaction) => _buildTransactionItem(
            context,
            transaction,
          )),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final isReceive = transaction.isReceive;
    final amountColor = isReceive ? Colors.green : Colors.red;
    final iconBgColor = isReceive 
        ? Colors.green.withOpacity(0.1) 
        : Colors.red.withOpacity(0.1);
    final iconColor = isReceive ? Colors.green : Colors.red;
    
    return InkWell(
      onTap: () {
        PaymentDetailSheet.show(context, transaction);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReceive ? Icons.arrow_downward : Icons.arrow_upward,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
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
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
                  '${NumberFormat('#,##0').format(transaction.amount * (_satToLakRate ?? 20.30))} ₭',  // ✅ ປ່ຽນຈາກ 19 ເປັນ 20.30
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.darkGray.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionHistoryScreen(),
            ),
          );
          _loadData();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, color: Colors.grey[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'ເບິ່ງປະຫວັດທັງໝົດ',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home,
                label: 'Home',
                isActive: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QRScannerScreen(),
                          ),
                        );
                        if (result != null && mounted) {
                          final payResult = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SendPaymentScreen(scannedData: result),
                            ),
                          );
                          if (payResult == true) {
                            _loadData();
                          }
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppConstants.primaryOrange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.primaryOrange.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -16),
                    child: Text(
                      'Scan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              _buildNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Service',
                isActive: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppConstants.primaryOrange : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppConstants.primaryOrange : Colors.grey[600],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}