// lib/screens/users_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class UsersPage extends StatefulWidget {
  final String token;

  const UsersPage({super.key, required this.token});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<List<_AppUser>> _future;

  final _search = TextEditingController();
  String _q = "";

  @override
  void initState() {
    super.initState();
    _future = _fetchUsers();
    _search.addListener(() {
      setState(() => _q = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchUsers());
  }

  Future<List<_AppUser>> _fetchUsers() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/users');
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body);
    if (body['ok'] != true) {
      throw Exception('Error: ${body['error'] ?? 'unknown'}');
    }

    final List data = body['data'] as List;
    return data
        .map((j) => _AppUser.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  bool _match(_AppUser u) {
    if (_q.isEmpty) return true;
    final hay = [
      u.id.toString(),
      u.name,
      u.email,
      u.phone,
      u.isAdmin ? "admin" : "user",
      u.createdAt ?? "",
    ].join(" ").toLowerCase();
    return hay.contains(_q);
  }

  Color _roleColor(bool isAdmin) =>
      isAdmin ? Colors.deepPurple : Colors.blueGrey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER (tanpa AppBar) =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.primaryContainer],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    color: Colors.black.withOpacity(0.10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Daftar User",
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _CircleIconButton(icon: Icons.refresh, onTap: _refresh),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: "Cari user (nama / email / hp / role)...",
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.trim().isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _search.clear();
                                    _q = "";
                                  });
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== LIST =====
            Expanded(
              child: FutureBuilder<List<_AppUser>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: ${snap.error}'),
                      ),
                    );
                  }

                  final usersAll = snap.data ?? [];
                  final users = usersAll.where(_match).toList();

                  if (usersAll.isEmpty) {
                    return const Center(child: Text('Belum ada user.'));
                  }
                  if (users.isEmpty) {
                    return const Center(
                      child: Text('Tidak ada hasil pencarian.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      final roleColor = _roleColor(u.isAdmin);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          title: Text(
                            u.name.isEmpty ? '(tanpa nama)' : u.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(u.email),
                              if (u.phone.isNotEmpty)
                                Text(
                                  'HP: ${u.phone}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (u.createdAt != null)
                                Text(
                                  'Dibuat: ${u.createdAt}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: roleColor.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              u.isAdmin ? 'ADMIN' : 'USER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: roleColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white.withOpacity(0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: scheme.onPrimary),
        ),
      ),
    );
  }
}

class _AppUser {
  final int id;
  final String name;
  final String email;
  final String phone;
  final bool isAdmin;
  final String? createdAt;

  _AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.isAdmin,
    this.createdAt,
  });

  factory _AppUser.fromJson(Map<String, dynamic> json) {
    return _AppUser(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      isAdmin: json['is_admin'] == true,
      createdAt: json['created_at'] as String?,
    );
  }
}
