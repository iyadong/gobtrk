import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../api/orders_api.dart';

class CreateOrderPage extends StatefulWidget {
  final String token;

  const CreateOrderPage({super.key, required this.token});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final _mapController = MapController();

  final _searchCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Timer? _debounce;
  bool _loadingSearch = false;
  bool _submitting = false;
  bool _gpsLoading = false;

  // ===== DUA TITIK =====
  LatLng? _pickedManual; // tap peta / search
  LatLng? _pickedGps; // dari GPS

  String _manualAddress = "";
  String _gpsAddress = "";

  // default center
  LatLng _center = LatLng(5.556, 95.317);
  double _zoom = 13;

  List<_Place> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    _debounce?.cancel();

    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _loadingSearch = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await _searchPlaces(q);
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _loadingSearch = true);

    try {
      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/search"
        "?q=${Uri.encodeComponent(query)}"
        "&format=json"
        "&addressdetails=1"
        "&limit=7",
      );

      final res = await http.get(
        uri,
        headers: {
          "User-Agent": "gobtrk/1.0 (flutter; contact: you@example.com)",
        },
      );

      if (res.statusCode != 200) {
        throw "HTTP ${res.statusCode}";
      }

      final data = jsonDecode(res.body) as List<dynamic>;
      final places = data
          .map((e) => _Place.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _suggestions = places;
        _loadingSearch = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSearch = false;
        _suggestions = [];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal cari lokasi: $e")));
    }
  }

  Future<String> _reverseGeocode(LatLng p) async {
    try {
      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse"
        "?lat=${p.latitude}"
        "&lon=${p.longitude}"
        "&format=json",
      );

      final res = await http.get(
        uri,
        headers: {
          "User-Agent": "gobtrk/1.0 (flutter; contact: you@example.com)",
        },
      );

      if (res.statusCode != 200) return "";
      final obj = jsonDecode(res.body) as Map<String, dynamic>;
      return (obj["display_name"] ?? "").toString();
    } catch (_) {
      return "";
    }
  }

  void _moveTo(LatLng p, {double zoom = 16}) {
    setState(() {
      _center = p;
      _zoom = zoom;
    });
    _mapController.move(p, zoom);
  }

  // ===== PILIH MANUAL =====
  Future<void> _pickManualPoint(LatLng p, {bool alsoMove = true}) async {
    setState(() {
      _pickedManual = p;
      _manualAddress = "";
      _suggestions = [];
    });

    if (alsoMove) _moveTo(p, zoom: 16);

    final addr = await _reverseGeocode(p);
    if (!mounted) return;
    setState(() => _manualAddress = addr);
  }

  // ===== PILIH GPS =====
  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("GPS/Location Service belum aktif.")),
      );
      return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Izin lokasi ditolak.")));
      return false;
    }

    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Izin lokasi permanen ditolak. Buka Settings dulu."),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _useMyLocation() async {
    if (_gpsLoading) return;

    final ok = await _ensureLocationPermission();
    if (!ok) return;

    setState(() => _gpsLoading = true);

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final p = LatLng(pos.latitude, pos.longitude);

      // set GPS point (JANGAN hapus manual)
      setState(() {
        _pickedGps = p;
        _gpsAddress = "";
        _suggestions = [];
      });

      // center ke GPS biar langsung terlihat
      _mapController.move(p, 16);

      final addr = await _reverseGeocode(p);
      if (!mounted) return;
      setState(() => _gpsAddress = addr);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Titik GPS disimpan & ditampilkan.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal ambil GPS: $e")));
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ===== SUBMIT =====
  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    // Prioritas: manual > gps
    final p = _pickedManual ?? _pickedGps;

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Judul wajib diisi.")));
      return;
    }
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih titik lokasi dulu (tap peta / GPS)."),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await OrdersApi.createOrder(
        widget.token,
        title: title,
        note: note,
        lat: p.latitude,
        lon: p.longitude,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pesanan berhasil dibuat.")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal buat pesanan: $e")));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final markers = <Marker>[];

    // Manual marker (PIN merah)
    if (_pickedManual != null) {
      markers.add(
        Marker(
          point: _pickedManual!,
          width: 48,
          height: 48,
          child: const Icon(Icons.location_pin, size: 48, color: Colors.red),
        ),
      );
    }

    // GPS marker (target biru)
    if (_pickedGps != null) {
      markers.add(
        Marker(
          point: _pickedGps!,
          width: 42,
          height: 42,
          child: const Icon(Icons.gps_fixed, size: 36, color: Colors.blue),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER =====
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

                      // tombol GPS dengan loading
                      _gpsLoading
                          ? const SizedBox(
                              width: 42,
                              height: 42,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : _CircleIconButton(
                              icon: Icons.my_location,
                              onTap: _useMyLocation,
                            ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText:
                            "Cari lokasi (contoh: masjid, jalan, kota...)",
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _loadingSearch
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : (_searchCtrl.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          _searchCtrl.clear();
                                          _suggestions = [];
                                        });
                                        FocusScope.of(context).unfocus();
                                      },
                                    )),
                      ),
                    ),
                  ),

                  // Suggestion dropdown
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              s.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () async {
                              FocusScope.of(context).unfocus();
                              await _pickManualPoint(
                                LatLng(s.lat, s.lon),
                                alsoMove: true,
                              );
                              setState(() => _suggestions = []);
                            },
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                children: [
                  // Form card
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
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.title),
                              hintText: "Judul",
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.notes),
                              hintText: "Catatan (opsional)",
                              border: UnderlineInputBorder(),
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Map card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: _zoom,
                          onTap: (tapPos, latLng) =>
                              _pickManualPoint(latLng, alsoMove: false),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName: "com.example.gobtrk",
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Legend + info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Legend
                        Row(
                          children: const [
                            Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Manual",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 14),
                            Icon(Icons.gps_fixed, color: Colors.blue, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "GPS",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_pickedManual == null && _pickedGps == null)
                          const Text(
                            "Belum ada titik dipilih. Tap di peta / cari lokasi (Manual) atau tekan GPS.",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                        if (_pickedManual != null) ...[
                          Text(
                            _manualAddress.isNotEmpty
                                ? "Manual: $_manualAddress"
                                : "Manual: ${_pickedManual!.latitude.toStringAsFixed(6)}, ${_pickedManual!.longitude.toStringAsFixed(6)}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],

                        if (_pickedGps != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _gpsAddress.isNotEmpty
                                ? "GPS: $_gpsAddress"
                                : "GPS: ${_pickedGps!.latitude.toStringAsFixed(6)}, ${_pickedGps!.longitude.toStringAsFixed(6)}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            if (_pickedManual != null)
                              TextButton(
                                onPressed: () => setState(() {
                                  _pickedManual = null;
                                  _manualAddress = "";
                                }),
                                child: const Text("Reset Manual"),
                              ),
                            if (_pickedGps != null)
                              TextButton(
                                onPressed: () => setState(() {
                                  _pickedGps = null;
                                  _gpsAddress = "";
                                }),
                                child: const Text("Reset GPS"),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "BUAT PESANAN",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                ],
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

class _Place {
  final String displayName;
  final double lat;
  final double lon;

  _Place({required this.displayName, required this.lat, required this.lon});

  factory _Place.fromJson(Map<String, dynamic> j) {
    return _Place(
      displayName: (j["display_name"] ?? "").toString(),
      lat: double.tryParse((j["lat"] ?? "0").toString()) ?? 0,
      lon: double.tryParse((j["lon"] ?? "0").toString()) ?? 0,
    );
  }
}
