// lib/screens/create_order_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../api/orders_api.dart';

class CreateOrderPage extends StatefulWidget {
  final String token;

  final double? initialLat;
  final double? initialLon;

  const CreateOrderPage({
    super.key,
    required this.token,
    this.initialLat,
    this.initialLon,
  });

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _search = TextEditingController();

  bool _loading = false;
  bool _searching = false;

  Timer? _debounce;
  List<_SearchPlace> _results = [];

  final MapController _mapController = MapController();
  LatLng? _selected;

  LatLng get _initialCenter {
    if (widget.initialLat != null && widget.initialLon != null) {
      return LatLng(widget.initialLat!, widget.initialLon!);
    }
    return const LatLng(5.2089, 97.0749);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  // ==== SEARCH (OSM NOMINATIM) ====
  Future<void> _searchPlaces(String q) async {
    final query = q.trim();
    if (query.length < 3) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      // Nominatim public endpoint (cukup untuk testing)
      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/search"
        "?format=json&limit=6&q=${Uri.encodeComponent(query)}",
      );

      final res = await http.get(
        uri,
        headers: {
          // Nominatim minta ada User-Agent, set agar tidak ditolak
          "User-Agent": "gobotrak_flutter_app/1.0",
        },
      );

      if (res.statusCode != 200) {
        setState(() {
          _results = [];
          _searching = false;
        });
        return;
      }

      final List data = jsonDecode(res.body) as List;
      final items = data
          .map((e) {
            final m = e as Map<String, dynamic>;
            final lat = double.tryParse(m["lat"]?.toString() ?? "");
            final lon = double.tryParse(m["lon"]?.toString() ?? "");
            return _SearchPlace(
              displayName: (m["display_name"] ?? "").toString(),
              lat: lat,
              lon: lon,
            );
          })
          .where((p) => p.lat != null && p.lon != null)
          .toList();

      if (!mounted) return;
      setState(() {
        _results = items;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _searchPlaces(v);
    });
  }

  void _pickSearchResult(_SearchPlace p) {
    final latLng = LatLng(p.lat!, p.lon!);
    setState(() {
      _selected = latLng;
      _results = [];
    });

    _mapController.move(latLng, 16.5);
    FocusScope.of(context).unfocus();
  }

  // ==== SUBMIT ORDER ====
  Future<void> _submit() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih titik di peta dulu')),
      );
      return;
    }

    final title = _title.text.trim().isEmpty ? 'Pesanan' : _title.text.trim();
    final note = _note.text.trim();
    final lat = _selected!.latitude;
    final lon = _selected!.longitude;

    setState(() => _loading = true);

    try {
      final id = await OrdersApi.createOrder(
        widget.token,
        title: title,
        note: note,
        lat: lat,
        lon: lon,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pesanan dibuat dengan id #$id')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuat pesanan: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Marker> _buildMarkers() {
    if (_selected == null) return [];
    return [
      Marker(
        point: _selected!,
        width: 44,
        height: 44,
        child: const Icon(Icons.location_on, size: 36, color: Colors.red),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initialCenter = _initialCenter;

    final selectedText = _selected == null
        ? "Belum ada titik dipilih. Tap di peta atau cari lokasi."
        : "Lat: ${_selected!.latitude.toStringAsFixed(6)} • "
              "Lon: ${_selected!.longitude.toStringAsFixed(6)}";

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER (warna berbeda) + search bar =====
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
                          "Buat Pesanan",
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _CircleIconButton(
                        icon: Icons.my_location,
                        onTap: () => _mapController.move(initialCenter, 16.5),
                      ),
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
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText:
                            "Cari lokasi (contoh: masjid, jalan, kota...)",
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : (_search.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          _search.clear();
                                          _results = [];
                                        });
                                        FocusScope.of(context).unfocus();
                                      },
                                    )),
                      ),
                    ),
                  ),

                  // Results dropdown
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              r.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () => _pickSearchResult(r),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ===== CONTENT =====
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: [
                    // Form (ringkas)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextField(
                              controller: _title,
                              decoration: const InputDecoration(
                                labelText: 'Judul',
                                hintText: 'Contoh: Antar paket',
                                prefixIcon: Icon(Icons.title),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _note,
                              decoration: const InputDecoration(
                                labelText: 'Catatan (opsional)',
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Map
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 360,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: initialCenter,
                              initialZoom: 16.5,
                              onTap: (tapPosition, latLng) {
                                setState(() {
                                  _selected = latLng;
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.gobotrak',
                              ),
                              MarkerLayer(markers: _buildMarkers()),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Selected info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.black.withOpacity(0.04),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_selected != null)
                            TextButton(
                              onPressed: () => setState(() => _selected = null),
                              child: const Text("Reset"),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('BUAT PESANAN'),
                      ),
                    ),
                  ],
                ),
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

class _SearchPlace {
  final String displayName;
  final double? lat;
  final double? lon;

  _SearchPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}
