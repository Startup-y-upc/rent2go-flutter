import 'dart:convert';
import 'dart:typed_data';
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
      return await login(email: email, password: password, rememberMe: true);
    }

    throw AuthException(_extractMessage(response, 'No se pudo crear la cuenta'),
        statusCode: response.statusCode);
  }

  // RECUPERAR CONTRASEÑA
  // POST /api/v1/auth/password/request
  // Envía un token de recuperación al correo del usuario
  static Future<void> requestPasswordReset({required String email}) async {
    final uri = Uri.parse('$baseUrl/auth/password/request');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw AuthException(_extractMessage(response, 'No se pudo enviar el correo de recuperación'),
          statusCode: response.statusCode);
    }
  }

  /// POST /api/v1/auth/password/reset
  /// Completa el cambio usando el token recibido por correo + la nueva contraseña
  static Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/password/reset');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );

    if (response.statusCode != 200) {
      throw AuthException(_extractMessage(response, 'No se pudo cambiar la contraseña. Verifica el código.'),
          statusCode: response.statusCode);
    }
  }

  static Future<UserModel> updateProfile({
    required String fullName,
    required String phone,
    Uint8List? profileImageBytes,
    String? imageFilename,
  }) async {
    final token = await getToken();
    if (token == null) throw AuthException('No hay sesión activa');

    final uri = Uri.parse('$baseUrl/auth/me');
    final request = http.MultipartRequest('PATCH', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['fullName'] = fullName;
    request.fields['phone'] = phone;

    if (profileImageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'profileImage',
        profileImageBytes,
        filename: imageFilename ?? 'profile.jpg',
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = await getCurrentUser();
      final updated = UserModel.fromJson({...data, 'token': current?.token ?? ''});
      await _saveUserOnly(updated);
      return updated;
    }

    throw AuthException(_extractMessage(response, 'No se pudo actualizar el perfil'),
        statusCode: response.statusCode);
  }

  static String _extractMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        if (body['message'] != null) return _humanize(body['message'].toString());
        if (body['error'] != null) return _humanize(body['error'].toString());
      }
    } catch (_) {}
    return fallback;
  }

  static String _humanize(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('email already registered') || lower.contains('already exists')) {
      return 'Ese correo ya está registrado. Intenta iniciar sesión o usa otro correo.';
    }
    if (lower.contains('invalid credentials') || lower.contains('incorrect password')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('user not found')) {
      return 'No encontramos una cuenta con ese correo.';
    }
    if (lower.contains('invalid token') || lower.contains('expired')) {
      return 'El código ha expirado o es inválido. Solicita uno nuevo.';
    }
    return raw;
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

  static Future<void> _saveUserOnly(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
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
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = UserModel.fromJson({...data, 'token': token});
      await _saveUserOnly(user);
      return user;
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