// lib/services/payment_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class PaymentService extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ==================== Backend API ====================

  // ✅ ສ້າງ Invoice (ຮັບເງິນ)
  Future<Map<String, dynamic>?> createInvoice({
    required String accessToken,
    required int amount,
    String memo = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/invoice'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'amount': amount,
          'memo': memo,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return data['data'];
      } else {
        _errorMessage = data['message'] ?? 'ສ້າງ Invoice ລົ້ມເຫລວ';
        debugPrint('Create Invoice Error: ${response.body}');
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ✅ ຈ່າຍ Invoice (Lightning)
  Future<Map<String, dynamic>?> payInvoice({
    required String accessToken,
    required String bolt11,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/pay'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'bolt11': bolt11,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return data['data'];
      } else {
        _errorMessage = data['message'] ?? 'ຈ່າຍເງິນລົ້ມເຫລວ';
        debugPrint('Pay Invoice Error: ${response.body}');
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ✅ ສົ່ງເງິນ (ໃຊ້ກັບ Wallet ID, Merchant QR, ຫຼື Lightning Invoice)
  Future<Map<String, dynamic>?> sendPayment({
    required String accessToken,
    required String toWalletId,
    required double amount,
    String? description,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('📤 Sending payment...');
      debugPrint('   To: $toWalletId');
      debugPrint('   Amount: $amount LAK');

      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'toWalletId': toWalletId,
          'amount': amount.toInt(),
          'description': description,
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('📥 Response: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return data['data'];
      } else {
        _errorMessage = data['message'] ?? 'ການສົ່ງເງິນລົ້ມເຫລວ';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('❌ Send payment error: $e');
      _errorMessage = 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ✅ ກວດສອບຍອດເງິນ
  Future<Map<String, dynamic>?> getBalance({
    required String accessToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/balance'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting balance: $e');
      return null;
    }
  }

  // ✅ ກວດສອບສະຖານະ Invoice
  Future<Map<String, dynamic>?> checkPaymentStatus({
    required String accessToken,
    required String paymentHash,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/payment/$paymentHash'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('Error checking payment: $e');
      return null;
    }
  }

  // ✅ ດຶງປະຫວັດການເຮັດທຸລະກຳ
  Future<List<Transaction>> getTransactionHistory({
    required String accessToken,
    int? limit,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/transactions'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List<dynamic> transactionsJson = data['data']['transactions'] ?? [];
        
        final allTransactions = transactionsJson
            .map((json) => Transaction.fromJson(json))
            .where((transaction) => !transaction.isPending)
            .toList();
        
        return allTransactions;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      return [];
    }
  }

  // ✅ ດຶງອັດຕາແລກປ່ຽນ
  Future<double?> fetchSatToLakRate(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/rate'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data']['satToLakRate'] as num?)?.toDouble();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching rate: $e');
      return null;
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}