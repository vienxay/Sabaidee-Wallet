// lib/services/merchant_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/merchant_model.dart';
import '../utils/constants.dart';

class MerchantService extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// ດຶງຂໍ້ມູນຮ້ານຄ້າຈາກ QR Code
  Future<Merchant?> getMerchantByQR({
    required String accessToken,
    required String qrCodeId,
  }) async {
    try {
      debugPrint('🔍 Getting merchant info: $qrCodeId');

      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/merchant/info/$qrCodeId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return Merchant.fromJson(data['data']);
      } else {
        _errorMessage = data['message'] ?? 'ບໍ່ພົບຮ້ານຄ້າ';
        return null;
      }
    } catch (e) {
      _errorMessage = 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}';
      debugPrint('❌ getMerchantByQR error: $e');
      return null;
    }
  }

  /// ສ້າງການຈ່າຍເງິນໃຫ້ຮ້ານຄ້າ (Step 1)
  Future<MerchantPaymentResult?> createPayment({
    required String accessToken,
    required String qrCodeId,
    required int amountLAK,
    String? memo,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('📤 Creating merchant payment...');
      debugPrint('   QR: $qrCodeId');
      debugPrint('   Amount: $amountLAK LAK');

      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/merchant/pay'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'qrCodeId': qrCodeId,
          'amountLAK': amountLAK,
          'memo': memo,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      debugPrint('📥 Response: ${response.statusCode}');

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201 && data['success'] == true) {
        return MerchantPaymentResult.fromJson(data['data']);
      } else {
        _errorMessage = data['message'] ?? 'ສ້າງການຈ່າຍເງິນລົ້ມເຫລວ';
        return null;
      }
    } catch (e) {
      _errorMessage = 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ createPayment error: $e');
      return null;
    }
  }

  /// ກວດສອບ ແລະ ດຳເນີນການຈ່າຍເງິນ (Step 2)
  /// ເອີ້ນຫຼັງຈາກ User ຈ່າຍ Invoice ແລ້ວ
  Future<Map<String, dynamic>?> checkAndProcessPayment({
    required String accessToken,
    required String paymentHash,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔄 Checking payment: $paymentHash');

      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/merchant/pay/check'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'paymentHash': paymentHash,
        }),
      ).timeout(const Duration(seconds: 60));

      final data = json.decode(response.body);
      debugPrint('📥 Check Response: ${response.statusCode}');
      debugPrint('   Data: ${json.encode(data)}');

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      } else {
        _errorMessage = data['message'] ?? 'ກວດສອບລົ້ມເຫລວ';
        return null;
      }
    } catch (e) {
      _errorMessage = 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ checkAndProcessPayment error: $e');
      return null;
    }
  }

  /// ດຶງປະຫວັດການຈ່າຍເງິນ
  Future<List<MerchantPaymentHistory>> getPaymentHistory({
    required String accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/merchant/history?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List<dynamic> paymentsJson = data['data']['payments'] ?? [];
        return paymentsJson
            .map((json) => MerchantPaymentHistory.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ getPaymentHistory error: $e');
      return [];
    }
  }

  /// Polling ກວດສອບສະຖານະ (ໃຊ້ສຳລັບ UI)
  Future<Map<String, dynamic>?> pollPaymentStatus({
    required String accessToken,
    required String paymentHash,
    int maxAttempts = 30,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      debugPrint('🔄 Polling attempt ${i + 1}/$maxAttempts');

      final result = await checkAndProcessPayment(
        accessToken: accessToken,
        paymentHash: paymentHash,
      );

      if (result != null) {
        final status = result['status'];
        
        if (status == 'completed' || status == 'already_completed') {
          return result;
        } else if (status == 'failed' || status == 'lak_payout_failed') {
          return result;
        }
      }

      // ລໍຖ້າກ່ອນ poll ໃໝ່
      await Future.delayed(interval);
    }

    _errorMessage = 'ໝົດເວລາລໍຖ້າ';
    return null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}