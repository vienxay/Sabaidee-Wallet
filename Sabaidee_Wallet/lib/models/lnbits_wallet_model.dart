class LnbitsWallet {
  final String walletId;
  final String walletName;
  final double balance;
  final String invoiceKey;
  final DateTime createdAt;

  LnbitsWallet({
    required this.walletId,
    required this.walletName,
    required this.balance,
    required this.invoiceKey,
    required this.createdAt,
  });

  factory LnbitsWallet.fromJson(Map<String, dynamic> json) {
    return LnbitsWallet(
      walletId: json['walletId'] ?? '',
      walletName: json['walletName'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      invoiceKey: json['invoiceKey'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'walletName': walletName,
      'balance': balance,
      'invoiceKey': invoiceKey,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}