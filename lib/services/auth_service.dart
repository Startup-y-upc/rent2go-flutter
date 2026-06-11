import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey   = 'session_token';
  static const _loggedKey  = 'is_logged_in';
  static const _typeKey    = 'account_type';
  static const _emailKey   = 'saved_email';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedKey) ?? false;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveSession({
    required String token,
    required String email,
    bool remember = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setBool(_loggedKey, true);
    if (remember) {
      await prefs.setString(_emailKey, email);
    } else {
      await prefs.remove(_emailKey);
    }
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<void> setAccountType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, type);
  }

  static Future<String?> getAccountType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_typeKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.setBool(_loggedKey, false);
  }
}
