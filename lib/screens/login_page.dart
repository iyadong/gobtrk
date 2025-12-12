// lib/screens/login_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../storage/session_store.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final bool showServerPanelInitially;
  const LoginPage({super.key, this.showServerPanelInitially = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final serverInputController =
      TextEditingController(); // kode ngrok / host / url

  bool loading = false;
  bool obscure = true;

  // server test state
  bool testing = false;
  bool serverOk = false;
  String resolvedBaseUrl = ApiConfig.baseUrl;
  String lastTestedBaseUrl = "";
  String testMsg = "";

  @override
  void initState() {
    super.initState();

    // Set awal dari config
    resolvedBaseUrl = _resolveServerUrl(serverInputController.text.trim());

    // Listen input server -> update preview URL
    serverInputController.addListener(() {
      final url = _resolveServerUrl(serverInputController.text.trim());
      setState(() {
        resolvedBaseUrl = url;
        if (lastTestedBaseUrl != resolvedBaseUrl) {
          serverOk = false;
          testMsg = "";
        }
      });
    });

    // Load server terakhir dari storage
    _loadSavedServer();
  }

  Future<void> _loadSavedServer() async {
    final saved = await SessionStore.loadServer();
    if (saved == null) return;

    // apply baseUrl tersimpan
    ApiConfig.baseUrl = saved.baseUrl;

    // isi input server (kode/host/url) tersimpan
    if (saved.serverInput.isNotEmpty) {
      serverInputController.text = saved.serverInput; // trigger listener
    } else {
      // kalau dulu user tidak isi kode, tetap preview pakai baseUrl tersimpan
      setState(() {
        resolvedBaseUrl = ApiConfig.baseUrl;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    serverInputController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Aturan:
  /// - kosong -> pakai ApiConfig.baseUrl (yang terakhir)
  /// - ada scheme http(s) -> pakai itu
  /// - ada "." atau ":" -> dianggap host/ip -> tambah scheme (ngrok => https, selain itu http)
  /// - selain itu -> dianggap KODE NGROK -> https://<kode>.ngrok-free.app
  String _resolveServerUrl(String input) {
    var s = input.trim();

    if (s.isEmpty) {
      var b = ApiConfig.baseUrl;
      if (b.endsWith("/")) b = b.substring(0, b.length - 1);
      return b;
    }

    if (s.contains("://")) {
      if (s.endsWith("/")) s = s.substring(0, s.length - 1);
      return s;
    }

    // kalau user paste host+path, ambil host saja
    if (s.contains("/")) {
      s = s.split("/").first;
    }

    // domain/ip + optional port
    if (s.contains(".") || s.contains(":")) {
      final scheme = s.contains("ngrok") ? "https://" : "http://";
      var url = "$scheme$s";
      if (url.endsWith("/")) url = url.substring(0, url.length - 1);
      return url;
    }

    // kode ngrok
    return ApiConfig.buildNgrokBaseUrl(s);
  }

  Future<bool> _testConnection({bool showSnack = true}) async {
    final urlToTest = _resolveServerUrl(serverInputController.text.trim());

    setState(() {
      testing = true;
      serverOk = false;
      testMsg = "Menguji koneksi...";
      resolvedBaseUrl = urlToTest;
    });

    ApiConfig.baseUrl = urlToTest;

    try {
      final uri = Uri.parse("${ApiConfig.baseUrl}/api/v1/health");
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        setState(() {
          testing = false;
          serverOk = false;
          testMsg = "Gagal (HTTP ${res.statusCode})";
          lastTestedBaseUrl = urlToTest;
        });
        if (showSnack) _snack("Test gagal: HTTP ${res.statusCode}");
        return false;
      }

      final body = jsonDecode(res.body);
      final ok = body["ok"] == true;

      setState(() {
        testing = false;
        serverOk = ok;
        lastTestedBaseUrl = urlToTest;
        testMsg = ok ? "OK" : "Respon tidak valid";
      });

      // simpan server yang dipakai (walaupun belum login)
      await SessionStore.saveServer(
        baseUrl: ApiConfig.baseUrl,
        serverInput: serverInputController.text.trim(),
      );

      if (showSnack) _snack(ok ? "Koneksi OK" : "Koneksi gagal (ok=false)");
      return ok;
    } on TimeoutException {
      setState(() {
        testing = false;
        serverOk = false;
        lastTestedBaseUrl = urlToTest;
        testMsg = "Timeout";
      });
      if (showSnack) _snack("Test gagal: timeout");
      return false;
    } catch (e) {
      setState(() {
        testing = false;
        serverOk = false;
        lastTestedBaseUrl = urlToTest;
        testMsg = "Error";
      });
      if (showSnack) _snack("Test gagal: $e");
      return false;
    }
  }

  Future<void> _login() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final email = emailController.text.trim();
    final pwd = passwordController.text;

    resolvedBaseUrl = _resolveServerUrl(serverInputController.text.trim());
    ApiConfig.baseUrl = resolvedBaseUrl;

    // auto test koneksi jika belum OK untuk baseUrl ini
    if (!(serverOk && lastTestedBaseUrl == resolvedBaseUrl)) {
      final ok = await _testConnection(showSnack: true);
      if (!ok) return;
    }

    setState(() => loading = true);

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api/v1/auth/login");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": pwd}),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body["ok"] == true) {
        final token = body["token"] as String;
        final name = body["name"] as String? ?? email;
        final isAdmin = body["is_admin"] == true;

        // simpan session login + server
        await SessionStore.saveSession(
          baseUrl: ApiConfig.baseUrl,
          serverInput: serverInputController.text.trim(),
          token: token,
          name: name,
          isAdmin: isAdmin,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomePage(token: token, name: name, isAdmin: isAdmin),
          ),
        );
      } else {
        final err = body["error"] ?? "invalid-credentials";
        _snack("Login gagal: $err");
      }
    } catch (e) {
      _snack("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openRegister() async {
    FocusScope.of(context).unfocus();

    // simpan server terbaru sebelum pindah
    ApiConfig.baseUrl = _resolveServerUrl(serverInputController.text.trim());
    await SessionStore.saveServer(
      baseUrl: ApiConfig.baseUrl,
      serverInput: serverInputController.text.trim(),
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header / Branding
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.local_shipping,
                            size: 34,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "GOBOTRAK",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Masuk untuk melanjutkan",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Card form
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // SERVER / NGROK COLLAPSIBLE
                          Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded:
                                  widget.showServerPanelInitially,
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.cloud),
                              title: const Text(
                                "Server / Ngrok",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                "Opsional — isi kode ngrok jika akses dari luar WiFi",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              children: [
                                const SizedBox(height: 8),
                                TextField(
                                  controller: serverInputController,
                                  decoration: InputDecoration(
                                    labelText: "Kode / Host / URL",
                                    hintText:
                                        "contoh: abcd-1234-efgh (ngrok) / 172.27.226.6:8080",
                                    helperText:
                                        "Jika isi kode ngrok, otomatis jadi: https://<kode>.${ApiConfig.ngrokDomain}\n"
                                        "Kalau kosong, pakai server terakhir (default lokal).",
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: testing
                                            ? null
                                            : () => _testConnection(
                                                showSnack: true,
                                              ),
                                        icon: testing
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.wifi_tethering),
                                        label: const Text("Test Koneksi"),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _StatusChip(
                                      ok: serverOk,
                                      text: testing
                                          ? "Testing..."
                                          : (testMsg.isEmpty
                                                ? "Belum dites"
                                                : testMsg),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "URL hasil: $resolvedBaseUrl",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Form login
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: "Email",
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? "").trim();
                                    if (s.isEmpty) return "Email wajib diisi";
                                    if (!s.contains("@")) {
                                      return "Email tidak valid";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: obscure,
                                  decoration: InputDecoration(
                                    labelText: "Password",
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? "");
                                    if (s.isEmpty) {
                                      return "Password wajib diisi";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: FilledButton(
                                    onPressed: loading ? null : _login,
                                    child: loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text("LOGIN"),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("Belum punya akun? "),
                                    TextButton(
                                      onPressed: _openRegister,
                                      child: const Text("Daftar"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Tip: Jika pakai ngrok, jalankan `ngrok http 8080` di laptop lalu isi kodenya saja.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool ok;
  final String text;

  const _StatusChip({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final bg = ok
        ? Colors.green.withOpacity(0.12)
        : Colors.orange.withOpacity(0.12);
    final fg = ok ? Colors.green : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        ok ? "OK" : text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
