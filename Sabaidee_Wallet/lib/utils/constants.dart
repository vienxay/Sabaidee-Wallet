import 'package:flutter/material.dart';

class AppConstants {
  // Colors
  static const Color primaryOrange = Color(0xFFFF9800);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF757575);
  static const Color textGray = Color(0xFF9E9E9E);
  
  // API Endpoints
  static const String apiUrl  = 'https://unpluralized-membranophonic-saniya.ngrok-free.dev';        // ✅ Backend Node.js
  static const String lnbitsUrl = 'https://lnbits.sabaideeln.com'; // ✅ LNbits (ບໍ່ໃຊ້ໃນ Flutter)
  
  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  // Border Radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusLarge = 24.0;
}



class AppStyles {
  static InputDecoration inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppConstants.textGray,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: AppConstants.textGray,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppConstants.lightGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppConstants.primaryOrange,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }

  static ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppConstants.primaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}