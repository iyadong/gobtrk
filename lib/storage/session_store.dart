// lib/storage/session_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ServerPrefs {
  final String baseUrl;
  final String serverInput;
  ServerPrefs({required this.baseUrl, required this.serverInput});
}

class SessionData extends ServerPrefs {
  final String token;
  final String name;
  final bool isAdmin;

  SessionData({
    required super.baseUrl,
    required super.serverInput,
    required this.token,
    required this.name,
    required this.isAdmin,
  });
}

class SessionStore {
  static const _kBaseUrl = "base_url";
  static const _kServerInput = "server_input";
  static const _kToken = "token";
  static const _kName = "name";
  static const _kIsAdmin = "is_admin";

  static Future<void> saveServer({
    required String baseUrl,
    required String serverInput,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBaseUrl, baseUrl);
    await p.setString(_kServerInput, serverInput);
  }

  static Future<ServerPrefs?> loadServer() async {
    final p = await SharedPreferences.getInstance();
    final baseUrl = p.getString(_kBaseUrl);
    final serverInput = p.getString(_kServerInput) ?? "";
    if (baseUrl == null) return null;
    return ServerPrefs(baseUrl: baseUrl, serverInput: serverInput);
  }

  static Future<void> saveSession({
    required String baseUrl,
    required String serverInput,
    required String token,
    required String name,
    required bool isAdmin,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBaseUrl, baseUrl);
    await p.setString(_kServerInput, serverInput);
    await p.setString(_kToken, token);
    await p.setString(_kName, name);
    await p.setBool(_kIsAdmin, isAdmin);
  }

  static Future<SessionData?> loadSession() async {
    final p = await SharedPreferences.getInstance();
    final baseUrl = p.getString(_kBaseUrl);
    final serverInput = p.getString(_kServerInput) ?? "";
    final token = p.getString(_kToken);
    final name = p.getString(_kName);
    final isAdmin = p.getBool(_kIsAdmin);

    if (baseUrl == null || token == null || name == null || isAdmin == null) {
      return null;
    }

    return SessionData(
      baseUrl: baseUrl,
      serverInput: serverInput,
      token: token,
      name: name,
      isAdmin: isAdmin,
    );
  }

  static Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kName);
    await p.remove(_kIsAdmin);
    // baseUrl & serverInput sengaja tetap disimpan (biar ingat server)
  }

  /// cek expired JWT dari claim `exp` (tanpa verify signature)
  static bool isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = _decodeB64Url(parts[1]);
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! int) return true;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSec >= exp;
    } catch (_) {
      return true;
    }
  }

  static String _decodeB64Url(String input) {
    var s = input.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    return utf8.decode(base64Decode(s));
  }
}
