// lib/models/merchant_model.dart

class Merchant {
  final String id;
  final String merchantId;
  final String merchantName;
  final String qrCodeId;
  final double feePercent;
  final String? bankName;

  Merchant({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.qrCodeId,
    required this.feePercent,
    this.bankName,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['_id'] ?? '',
      merchantId: json['merchantId'] ?? '',
      merchantName: json['merchantName'] ?? '',
      qrCodeId: json['qrCodeId'] ?? '',
      feePercent: (json['feePercent'] ?? 1.5).toDouble(),
      bankName: json['bankInfo']?['bankName'],
    );
  }
}

class MerchantPaymentResult {
  final bool success;
  final String paymentRequest;
  final String paymentHash;
  final String merchantPaymentId;
  final int amountLAK;
  final int amountSats;
  final int feeLAK;
  final int netAmountLAK;
  final double exchangeRate;
  final String merchantName;
  final String merchantId;

  MerchantPaymentResult({
    required this.success,
    required this.paymentRequest,
    required this.paymentHash,
    required this.merchantPaymentId,
    required this.amountLAK,
    required this.amountSats,
    required this.feeLAK,
    required this.netAmountLAK,
    required this.exchangeRate,
    required this.merchantName,
    required this.merchantId,
  });

  factory MerchantPaymentResult.fromJson(Map<String, dynamic> json) {
    final invoice = json['invoice'] ?? {};
    final amounts = json['amounts'] ?? {};
    final merchant = json['merchant'] ?? {};

    return MerchantPaymentResult(
      success: true,
      paymentRequest: invoice['paymentRequest'] ?? '',
      paymentHash: invoice['paymentHash'] ?? '',
      merchantPaymentId: json['merchantPaymentId'] ?? '',
      amountLAK: amounts['amountLAK'] ?? 0,
      amountSats: amounts['amountSats'] ?? 0,
      feeLAK: amounts['feeLAK'] ?? 0,
      netAmountLAK: amounts['netAmountLAK'] ?? 0,
      exchangeRate: (amounts['exchangeRate'] ?? 20.30).toDouble(),
      merchantName: merchant['name'] ?? '',
      merchantId: merchant['id'] ?? '',
    );
  }
}

class MerchantPaymentHistory {
  final String id;
  final String merchantName;
  final String merchantId;
  final int amountLAK;
  final int amountSats;
  final int feeLAK;
  final int netAmountLAK;
  final String status;
  final String? bankReference;
  final DateTime createdAt;
  final DateTime? completedAt;

  MerchantPaymentHistory({
    required this.id,
    required this.merchantName,
    required this.merchantId,
    required this.amountLAK,
    required this.amountSats,
    required this.feeLAK,
    required this.netAmountLAK,
    required this.status,
    this.bankReference,
    required this.createdAt,
    this.completedAt,
  });

  factory MerchantPaymentHistory.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] ?? {};

    return MerchantPaymentHistory(
      id: json['_id'] ?? '',
      merchantName: merchant['merchantName'] ?? '',
      merchantId: merchant['merchantId'] ?? '',
      amountLAK: json['amountLAK'] ?? 0,
      amountSats: json['amountSats'] ?? 0,
      feeLAK: json['feeLAK'] ?? 0,
      netAmountLAK: json['netAmountLAK'] ?? 0,
      status: json['status'] ?? 'pending',
      bankReference: json['bankTransfer']?['referenceNumber'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'ລໍຖ້າຈ່າຍ';
      case 'sats_received':
        return 'ຮັບ Sats ແລ້ວ';
      case 'processing':
        return 'ກຳລັງດຳເນີນການ';
      case 'completed':
        return 'ສຳເລັດ';
      case 'failed':
        return 'ລົ້ມເຫລວ';
      default:
        return status;
    }
  }
}