// lib/screens/orders_page.dart
import 'package:flutter/material.dart';
import '../api/orders_api.dart';

class OrdersPage extends StatefulWidget {
  final String token;
  final bool isAdmin;

  const OrdersPage({super.key, required this.token, required this.isAdmin});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<List<Order>> _future;

  final _search = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    _future = OrdersApi.fetchOrders(widget.token);
    _search.addListener(() {
      setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'baru':
        return Colors.orange;
      case 'diproses':
        return Colors.blue;
      case 'selesai':
        return Colors.green;
      case 'batal':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDistance(double? m) {
    if (m == null) return '-';
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
    return '${m.toStringAsFixed(0)} m';
  }

  Future<void> _refresh() async {
    setState(() {
      _future = OrdersApi.fetchOrders(widget.token);
    });
  }

  Future<void> _approve(Order o) async {
    try {
      await OrdersApi.approveOrder(widget.token, o.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #${o.id} di-approve & goal dikirim')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal approve: $e')));
    }
  }

  Future<void> _setStatus(Order o, String newStatus) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) {
        String label = '';
        if (newStatus == 'selesai') {
          label = 'tandai selesai';
        } else if (newStatus == 'batal') {
          label = 'batalkan';
        } else {
          label = 'ubah status menjadi $newStatus';
        }
        return AlertDialog(
          title: const Text('Konfirmasi'),
          content: Text('Yakin ingin $label pesanan #${o.id}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya'),
            ),
          ],
        );
      },
    );

    if (konfirmasi != true) return;

    try {
      await OrdersApi.updateOrderStatus(widget.token, o.id, newStatus);
      if (!mounted) return;

      String msg;
      if (newStatus == 'selesai') {
        msg = 'Pesanan #${o.id} ditandai SELESAI';
      } else if (newStatus == 'batal') {
        msg = 'Pesanan #${o.id} dibatalkan';
      } else {
        msg = 'Status pesanan #${o.id} diubah ke $newStatus';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal ubah status: $e')));
    }
  }

  Future<void> _delete(Order o) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pesanan'),
        content: Text(
          'Yakin ingin MENGHAPUS pesanan #${o.id}? Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    try {
      await OrdersApi.deleteOrder(widget.token, o.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pesanan #${o.id} dihapus')));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
    }
  }

  bool _matches(Order o) {
    if (_query.isEmpty) return true;

    final hay = [
      o.id.toString(),
      o.title,
      o.userName,
      o.status,
      o.note,
      o.lat.toString(),
      o.lon.toString(),
    ].join(" ").toLowerCase();

    return hay.contains(_query);
  }

  Widget _buildActionButtons(Order o) {
    if (!widget.isAdmin) return const SizedBox.shrink();

    final List<Widget> buttons = [];

    if (o.status == 'baru') {
      buttons.add(
        FilledButton(
          onPressed: () => _approve(o),
          child: const Text('APPROVE'),
        ),
      );
      buttons.add(
        OutlinedButton(
          onPressed: () => _setStatus(o, 'batal'),
          child: const Text('BATALKAN'),
        ),
      );
      buttons.add(
        TextButton(
          onPressed: () => _delete(o),
          child: const Text('HAPUS', style: TextStyle(color: Colors.red)),
        ),
      );
    } else if (o.status == 'diproses') {
      buttons.add(
        FilledButton(
          onPressed: () => _setStatus(o, 'selesai'),
          child: const Text('SELESAI'),
        ),
      );
      buttons.add(
        OutlinedButton(
          onPressed: () => _setStatus(o, 'batal'),
          child: const Text('BATALKAN'),
        ),
      );
    } else {
      buttons.add(
        TextButton(
          onPressed: () => _delete(o),
          child: const Text('HAPUS', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(spacing: 8, runSpacing: 6, children: buttons),
    );
  }

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
                          "Daftar Pesanan",
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

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText:
                            "Cari pesanan (id / judul / user / status)...",
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.trim().isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _search.clear();
                                    _query = "";
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

            // ===== LIST CONTENT =====
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Order>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          SizedBox(height: 200),
                          Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [Text('Error: ${snapshot.error}')],
                      );
                    }

                    final ordersAll = snapshot.data ?? [];
                    final orders = ordersAll.where(_matches).toList();

                    if (ordersAll.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [Text('Belum ada pesanan.')],
                      );
                    }

                    if (orders.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          Text('Tidak ada hasil untuk pencarian ini.'),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final o = orders[index];
                        final created = o.createdAt ?? '';

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        o.title.isEmpty
                                            ? 'Pesanan #${o.id}'
                                            : o.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          o.status,
                                        ).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: _statusColor(
                                            o.status,
                                          ).withOpacity(0.25),
                                        ),
                                      ),
                                      child: Text(
                                        o.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: _statusColor(o.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                _kvRow("ID", "#${o.id}"),
                                _kvRow("User", o.userName),
                                if (o.note.isNotEmpty)
                                  _kvRow("Catatan", o.note),
                                _kvRow(
                                  "Koordinat",
                                  "${o.lat.toStringAsFixed(6)}, ${o.lon.toStringAsFixed(6)}",
                                ),
                                _kvRow(
                                  "Jarak mobil",
                                  _formatDistance(o.jarakMobilM),
                                ),
                                if (created.isNotEmpty)
                                  _kvRow("Dibuat", created),

                                const SizedBox(height: 10),
                                _buildActionButtons(o),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
