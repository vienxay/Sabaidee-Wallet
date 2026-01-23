// lib/services/Lnbits_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class WalletService {
  final String accessToken;
  static const Duration _timeout = Duration(seconds: 30);

  WalletService({required this.accessToken});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  // ກວດສອບຍອດເງິນ
  Future<Map<String, dynamic>> getBalance() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/balance'),  //  ປ່ຽນເປັນ apiUrl
        headers: _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'balance': data['data']['balance'],
          'walletId': data['data']['walletId'],
          'walletName': data['data']['walletName'],
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['message'] ?? 'ບໍ່ສາມາດດຶງຂໍ້ມູນໄດ້',
        };
      }
    } on TimeoutException { // ← ຈັບ timeout error
      return {
        'success': false,
        'error': 'ການເຊື່ອມຕໍ່ໝົດອາຍຸ, ກະລຸນາລອງໃໝ່.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}',
      };
    }
  }

  // ສ້າງ Invoice ຮັບເງິນ
  Future<Map<String, dynamic>> createInvoice(int amount, String memo) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/invoice'),  //  ປ່ຽນເປັນ apiUrl
        headers: _headers,
        body: json.encode({
          'amount': amount,
          'memo': memo,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'paymentRequest': data['data']['payment_request'],
          'paymentHash': data['data']['payment_hash'],
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['message'] ?? 'ບໍ່ສາມາດສ້າງ Invoice ໄດ້',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'ການເຊື່ອມຕໍ່ໝົດເວລາ - ກະລຸນາລອງໃໝ່',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}',
      };
    }
  }

  // ຈ່າຍ Invoice
  Future<Map<String, dynamic>> payInvoice(String bolt11) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/pay'),  // ✅ ປ່ຽນເປັນ apiUrl
        headers: _headers,
        body: json.encode({
          'bolt11': bolt11,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['message'] ?? 'ການຈ່າຍເງິນລົ້ມເຫຼວ',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'ການເຊື່ອມຕໍ່ໝົດເວລາ - ກະລຸນາລອງໃໝ່',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}',
      };
    }
  }

  // ປະຫວັດການຈ່າຍ
  Future<Map<String, dynamic>> getPayments() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/payments'),  // ✅ ປ່ຽນເປັນ apiUrl
        headers: _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'payments': data['data']['payments'],
          'count': data['data']['count'],
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['message'] ?? 'ບໍ່ສາມາດດຶງຂໍ້ມູນໄດ້',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'ການເຊື່ອມຕໍ່ໝົດເວລາ - ກະລຸນາລອງໃໝ່',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}',
      };
    }
  }

  // ກວດສອບສະຖານະການຈ່າຍ
  Future<Map<String, dynamic>> checkPayment(String paymentHash) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/wallet/payment/$paymentHash'),  // ✅ ປ່ຽນເປັນ apiUrl
        headers: _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'error': 'ບໍ່ພົບຂໍ້ມູນການຈ່າຍ',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'ການເຊື່ອມຕໍ່ໝົດເວລາ - ກະລຸນາລອງໃໝ່',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'ເກີດຂໍ້ຜິດພາດ: ${e.toString()}',
      };
    }
  }
}