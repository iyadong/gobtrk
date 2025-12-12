// lib/screens/startup_gate.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../storage/session_store.dart';
import 'home_page.dart';
import 'login_page.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // 1) load server prefs dulu (biar baseUrl keset)
    final server = await SessionStore.loadServer();
    if (server != null) {
      ApiConfig.baseUrl = server.baseUrl;
    }

    // 2) cek health
    final okServer = await _health(ApiConfig.baseUrl);

    // 3) load session
    final session = await SessionStore.loadSession();

    // 4) auto-login jika bisa
    if (session != null &&
        okServer &&
        !SessionStore.isJwtExpired(session.token)) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            token: session.token,
            name: session.name,
            isAdmin: session.isAdmin,
          ),
        ),
      );
      return;
    }

    // token expired -> clear
    if (session != null && SessionStore.isJwtExpired(session.token)) {
      await SessionStore.clearSession();
    }

    // 5) ke login. kalau server nggak ok -> paksa panel server terbuka
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(showServerPanelInitially: !okServer),
      ),
    );
  }

  Future<bool> _health(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body);
      return body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
