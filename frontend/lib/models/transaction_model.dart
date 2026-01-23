// lib/models/transaction_model.dart

import 'package:intl/intl.dart';

class Transaction {
  final String id;
  final String type;
  final double amount;
  final double? amountLAK;
  final double? amountSats;
  final String currency;
  final String status;
  final String? fromWallet;
  final String? toWallet;
  final String? fromName;
  final String? toName;
  final String? description;
  final String? paymentMethod;
  final String? invoiceUrl;
  final double? fee;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    this.amountLAK,
    this.amountSats,
    this.fromWallet,
    this.toWallet,
    this.fromName,
    this.toName,
    this.description,
    this.paymentMethod,
    this.invoiceUrl,
    this.fee,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // ✅ Parse amountSats
    final sats = _parseAmount(json['amountSats'] ?? json['amount']);
    
    return Transaction(
      id: json['id']?.toString() ??
          json['_id']?.toString() ??
          json['payment_hash']?.toString() ??
          'unknown',

      type: _determineType(json),
      
      amount: sats,
      amountSats: sats,
      amountLAK: json['amountLAK'] != null 
          ? (json['amountLAK'] as num).toDouble() 
          : null,

      currency: json['currency']?.toString() ?? 'sats',

      status: _determineStatus(json),

      fromWallet: json['fromWallet']?.toString(),
      toWallet: json['toWallet']?.toString(),
      fromName: json['fromName']?.toString(),
      toName: json['toName']?.toString(),

      description: json['memo']?.toString() ??
          json['description']?.toString() ??
          '',

      paymentMethod: json['paymentMethod']?.toString() ?? 'lightning',
      invoiceUrl: json['invoiceUrl']?.toString() ?? json['bolt11']?.toString(),
      fee: json['fee'] != null ? (json['fee'] as num).toDouble() : null,

      createdAt: _parseDate(json),
    );
  }

  // ✅ ແກ້ໄຂ: ຮັບ dynamic ແທນ Map
  static double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;

    double finalAmount;
    if (amount is num) {
      finalAmount = amount.abs().toDouble();
    } else if (amount is String) {
      finalAmount = double.tryParse(amount)?.abs() ?? 0.0;
    } else {
      return 0.0;
    }

    // ✅ ບໍ່ຕ້ອງຫານອີກແລ້ວ ເພາະ backend ແປງໃຫ້ແລ້ວ
    // ແຕ່ຖ້າຄ່າໃຫຍ່ກວ່າ 100,000 ອາດເປັນ millisats
    if (finalAmount > 100000) {
      return finalAmount / 1000;
    }

    return finalAmount;
  }

  // ✅ Helper: determine type
  static String _determineType(Map<String, dynamic> json) {
    if (json['type'] != null) return json['type'].toString();

    if (json['out'] == true) return 'send';
    if (json['out'] == false) return 'receive';

    final amount = json['amount'];
    if (amount != null && amount is num && amount < 0) return 'send';

    return 'receive';
  }

  // ✅ Helper: determine status
  static String _determineStatus(Map<String, dynamic> json) {
    if (json['status'] != null) return json['status'].toString();

    if (json['paid'] == true) return 'completed';
    if (json['pending'] == true) return 'pending';
    if (json['pending'] == false) return 'completed';

    return 'pending';
  }

  // ✅ Helper: parse date (Laos time: UTC+7)
  static DateTime _parseDate(Map<String, dynamic> json) {
    final dateValue = json['createdAt'] ?? json['created_at'] ?? json['time'];

    if (dateValue == null) return DateTime.now();

    if (dateValue is DateTime) {
      return dateValue.isUtc
          ? dateValue.add(const Duration(hours: 7))
          : dateValue;
    }

    if (dateValue is int) {
      final utc = DateTime.fromMillisecondsSinceEpoch(dateValue * 1000, isUtc: true);
      return utc.add(const Duration(hours: 7));
    }

    if (dateValue is String) {
      final parsed = DateTime.tryParse(dateValue);
      if (parsed != null) {
        return parsed.isUtc
            ? parsed.add(const Duration(hours: 7))
            : parsed;
      }
    }

    return DateTime.now();
  }

  // --- Other methods ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'currency': currency,
      'status': status,
      'fromWallet': fromWallet,
      'toWallet': toWallet,
      'fromName': fromName,
      'toName': toName,
      'description': description,
      'paymentMethod': paymentMethod,
      'invoiceUrl': invoiceUrl,
      'fee': fee,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get formattedAmount {
    final sign = type == 'send' ? '-' : '+';
    return '$sign${amount.toInt()} sats';
  }

  String get formattedDate {
    final formatter = DateFormat('d MMMM yyyy, HH:mm', 'lo');
    return formatter.format(createdAt);
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isSend => type == 'send';
  bool get isReceive => type == 'receive';
}