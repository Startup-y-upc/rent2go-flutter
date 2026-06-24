import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  static const _tokenKey = 'session_token';
  static const _loggedKey = 'is_logged_in';
  static const _emailKey = 'saved_email';
  static const _rememberKey = 'remember_me';
  static const _userKey = 'user_data';
  static const _typeKey = 'account_type';

  static Future<UserModel> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'rememberMe': rememberMe,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = UserModel.fromJson(data);
      await _saveSession(user: user, email: email, rememberMe: rememberMe);
      return user;
    }

    throw AuthException(_extractMessage(response, 'Correo o contraseña incorrectos'),
        statusCode: response.statusCode);
  }

  // REGISTRO
  /// POST /api/v1/auth/register
  static Future<UserModel> register({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String phone,
    required String accountType,
    String? profileImageUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'fullName': fullName,
        'phone': phone,
        'profileImageUrl': profileImageUrl ?? '',
        'accountType': accountType,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return await login(email: email, password: password, rememberMe: true);
    }

    throw AuthException(_extractMessage(response, 'No se pudo crear la cuenta'),
        statusCode: response.statusCode);
  }

  static String _extractMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  static Future<void> _saveSession({
    required UserModel user,
    required String email,
    required bool rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, user.token);
    await prefs.setBool(_loggedKey, true);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setBool(_rememberKey, rememberMe);
    await prefs.setString(_typeKey, user.accountType);

    if (rememberMe) {
      await prefs.setString(_emailKey, email);
    } else {
      await prefs.remove(_emailKey);
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedKey) ?? false;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return UserModel.fromJson(jsonDecode(raw));
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? false;
  }

  static Future<void> setAccountType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, type);
  }

  static Future<String?> getAccountType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_typeKey);
  }

  static Future<UserModel?> fetchCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    final uri = Uri.parse('$baseUrl/auth/me');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserModel.fromJson(data);
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.setBool(_loggedKey, false);
  }
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}