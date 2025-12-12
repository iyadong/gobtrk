// lib/screens/home_page.dart
import 'package:flutter/material.dart';

import '../storage/session_store.dart';
import 'orders_page.dart';
import 'create_order_page.dart';
import 'map_page.dart';
import 'login_page.dart';
import 'users_page.dart';

class HomePage extends StatefulWidget {
  final String token; // JWT dari Flask
  final String name;
  final bool isAdmin;

  const HomePage({
    super.key,
    required this.token,
    required this.name,
    required this.isAdmin,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

// --------- MODEL MENU INTERNAL ---------
class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _HomePageState extends State<HomePage> {
  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(token: widget.token, isAdmin: widget.isAdmin),
      ),
    );
  }

  void _openOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrdersPage(token: widget.token, isAdmin: widget.isAdmin),
      ),
    );
  }

  void _openUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UsersPage(token: widget.token)),
    );
  }

  Future<void> _openCreateOrder() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateOrderPage(token: widget.token)),
    );

    // admin: selesai buat order -> langsung ke daftar pesanan (opsional)
    if (result == true && widget.isAdmin) {
      _openOrders();
    }
  }

  Future<void> _logout() async {
    await SessionStore.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  List<_MenuItem> _buildMenuItems(BuildContext context) {
    final theme = Theme.of(context);

    return <_MenuItem>[
      _MenuItem(
        icon: Icons.map,
        title: 'Lacak Mobil',
        subtitle: 'Posisi dan Tujuan Mobil',
        color: theme.colorScheme.primary,
        onTap: _openMap,
      ),
      if (widget.isAdmin)
        _MenuItem(
          icon: Icons.list_alt,
          title: 'Daftar Pesanan',
          subtitle: 'Approve / selesai / batal',
          color: Colors.teal,
          onTap: _openOrders,
        ),
      if (widget.isAdmin)
        _MenuItem(
          icon: Icons.people,
          title: 'Daftar User',
          subtitle: 'Data user terdaftar',
          color: Colors.indigo,
          onTap: _openUsers,
        ),
      _MenuItem(
        icon: Icons.add_location_alt,
        title: 'Buat Pesanan',
        subtitle: 'Pilih titik di peta',
        color: Colors.orange,
        onTap: _openCreateOrder,
      ),
      _MenuItem(
        icon: Icons.logout,
        title: 'Logout',
        subtitle: 'Keluar dari akun',
        color: Colors.red,
        onTap: _logout,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildMenuItems(context);

    return Scaffold(
      // ❌ AppBar dihapus
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== Header 1 kontainer: logo + judul + nama =====
              _HomeHeaderCard(name: widget.name),
              const SizedBox(height: 12),

              // ===== Menu ngisi layar (tanpa ruang kosong) =====
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final n = items.length;
                    const gap = 10.0;

                    final perItem =
                        (constraints.maxHeight - (gap * (n - 1))) / n;

                    // kalau terlalu pendek -> gunakan scroll
                    final useScroll = perItem < 84;

                    if (useScroll) {
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: n,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: gap),
                        itemBuilder: (context, index) {
                          return _MenuRowCard(
                            item: items[index],
                            minHeight: 84,
                          );
                        },
                      );
                    }

                    // Mode fill: setiap menu Expanded agar memenuhi layar
                    return Column(
                      children: [
                        for (int i = 0; i < n; i++) ...[
                          Expanded(child: _MenuRowCard(item: items[i])),
                          if (i != n - 1) const SizedBox(height: gap),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== HEADER CARD =====
class _HomeHeaderCard extends StatelessWidget {
  final String name;

  const _HomeHeaderCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg1 = scheme.primary;
    final bg2 = scheme.primaryContainer;
    final on = scheme.onPrimary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg1, bg2],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 5),
            color: Colors.black.withOpacity(0.10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo bubble
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(Icons.local_shipping, size: 28, color: on),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GOBOTRAK",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: on,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Halo, $name",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: on.withOpacity(0.90),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------- MENU CARD (RESPONSIF) ---------
class _MenuRowCard extends StatelessWidget {
  final _MenuItem item;
  final double? minHeight;

  const _MenuRowCard({required this.item, this.minHeight});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: scheme.surface,
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                offset: const Offset(0, 3),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight;
              final big = h >= 110;

              final iconCircle = big ? 54.0 : 46.0;
              final iconSize = big ? 28.0 : 24.0;
              final titleSize = big ? 17.0 : 15.0;
              final subSize = big ? 13.0 : 12.0;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: big ? 14 : 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: iconCircle,
                      height: iconCircle,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: iconSize),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: subSize,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: Colors.grey,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
