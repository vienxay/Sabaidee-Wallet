import 'lnbits_wallet_model.dart'; // ⭐ ເພີ່ມ import ນີ້

class User {
  final String id;
  final String email;
  final String fullName;
  final String? profilePhoto;
  final String authProvider;
  final String? googleId;
  final bool isVerified;
  final bool isActive;
  final String role;
  final bool isAdmin;
  final DateTime? lastLogin;
  final LnbitsWallet? lnbitsWallet; // ⭐ ຕອນນີ້ຈະ recognize ແລ້ວ
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.profilePhoto,
    required this.authProvider,
    this.googleId,
    required this.isVerified,
    required this.isActive,
    required this.role,
    required this.isAdmin,
    this.lastLogin,
    this.lnbitsWallet,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      email: json['email'],
      fullName: json['fullName'],
      profilePhoto: json['profilePhoto'],
      authProvider: json['authProvider'] ?? 'local',
      googleId: json['googleId'],
      isVerified: json['isVerified'] ?? false,
      isActive: json['isActive'] ?? true,
      role: json['role'] ?? 'user',
      isAdmin: json['isAdmin'] ?? false,
      lastLogin: json['lastLogin'] != null 
          ? DateTime.parse(json['lastLogin'])
          : null,
      lnbitsWallet: json['lnbitsWallet'] != null
          ? LnbitsWallet.fromJson(json['lnbitsWallet'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'profilePhoto': profilePhoto,
      'authProvider': authProvider,
      'googleId': googleId,
      'isVerified': isVerified,
      'isActive': isActive,
      'role': role,
      'isAdmin': isAdmin,
      'lastLogin': lastLogin?.toIso8601String(),
      'lnbitsWallet': lnbitsWallet?.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}