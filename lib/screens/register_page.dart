// lib/screens/register_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _joinUrl(String base, String path) {
    // base: http://x:8080  atau http://x:8080/
    // path: /api/v1/auth/register atau api/v1/auth/register
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final phone = _phone.text.trim();
    final pwd = _password.text;

    setState(() => _loading = true);

    try {
      final url = Uri.parse(
        _joinUrl(ApiConfig.baseUrl, '/api/v1/auth/register'),
      );

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "phone": phone,
          "password": pwd,
        }),
      );

      Map<String, dynamic> body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = {"ok": false, "error": "invalid-json", "raw": res.body};
      }

      if (res.statusCode == 200 && body["ok"] == true) {
        _snack("Registrasi berhasil, silakan login");
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        final err = (body["error"] ?? "unknown-error").toString();
        String msg = "Registrasi gagal: $err";

        if (err == "email-exists") msg = "Email sudah terdaftar";
        if (err == "missing-fields") msg = "Data tidak lengkap";

        // kalau server error / baseUrl salah
        if (res.statusCode >= 500) {
          msg = "Server error (HTTP ${res.statusCode})";
        } else if (res.statusCode == 404) {
          msg = "Endpoint tidak ditemukan (cek baseUrl / ngrok)";
        }

        _snack(msg);
      }
    } catch (e) {
      _snack("Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Akun")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_add_alt_1,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Buat akun baru",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Text(
                          "Server: ${ApiConfig.baseUrl}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: "Nama lengkap",
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Nama wajib diisi";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final s = (v ?? "").trim();
                            if (s.isEmpty) return "Email wajib diisi";
                            if (!s.contains("@"))
                              return "Format email tidak valid";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _phone,
                          decoration: const InputDecoration(
                            labelText: "No. HP (opsional)",
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _password,
                          obscureText: _obscure1,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                              icon: Icon(
                                _obscure1
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Password wajib diisi";
                            }
                            if (v.length < 4) {
                              return "Minimal 4 karakter";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _password2,
                          obscureText: _obscure2,
                          decoration: InputDecoration(
                            labelText: "Ulangi Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                              icon: Icon(
                                _obscure2
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return "Ulangi password";
                            if (v != _password.text)
                              return "Password tidak sama";
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _loading ? null : _register,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("DAFTAR"),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          "Dengan mendaftar, kamu bisa membuat pesanan dan melacak mobil.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
