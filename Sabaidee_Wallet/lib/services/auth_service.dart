import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null && _accessToken != null;
  bool get hasWallet => _currentUser?.lnbitsWallet != null;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ✅ Headers ສຳລັບ Ngrok
  Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };

  Future<void> getCurrentUser() async {
    if (_accessToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/auth/me'),
        headers: _authHeaders(_accessToken!),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _currentUser = User.fromJson(data['data']);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Get current user error: $e');
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/auth/forgot-password'),
        headers: _defaultHeaders,
        body: json.encode({
          'email': email,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Failed to send reset email';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/auth/register'),
        headers: _defaultHeaders,
        body: json.encode({
          'fullName': fullName,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        _currentUser = User.fromJson(data['data']['user']);
        _accessToken = data['data']['accessToken'];
        _refreshToken = data['data']['refreshToken'];

        await _saveTokens();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/auth/login'),
        headers: _defaultHeaders,
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _currentUser = User.fromJson(data['data']['user']);
        _accessToken = data['data']['accessToken'];
        _refreshToken = data['data']['refreshToken'];

        await _saveTokens();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _errorMessage = 'Google sign in cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/auth/google-mobile'),
        headers: _defaultHeaders,
        body: json.encode({
          'idToken': googleAuth.idToken,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _currentUser = User.fromJson(data['data']['user']);
        _accessToken = data['data']['accessToken'];
        _refreshToken = data['data']['refreshToken'];

        await _saveTokens();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Google sign in failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Google sign in error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/api/auth/reset-password'),
        headers: _defaultHeaders,
        body: json.encode({
          'token': token,
          'password': newPassword,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Failed to reset password';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    
    await _googleSignIn.signOut();
    
    notifyListeners();
  }

  Future<bool> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/api/auth/me'),
        headers: _authHeaders(token),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _currentUser = User.fromJson(data['data']);
        _accessToken = token;
        _refreshToken = prefs.getString('refreshToken');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('accessToken', _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('refreshToken', _refreshToken!);
    }
  }
}