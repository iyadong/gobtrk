// lib/screens/map_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../mqtt/mqtt_manager.dart';
import '../config.dart';

class MapPage extends StatefulWidget {
  final String token;
  final bool isAdmin;

  const MapPage({super.key, required this.token, required this.isAdmin});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MqttManager mqtt;

  double? mobLat;
  double? mobLon;
  String mobStatus = "-";
  bool mqttConnected = false;

  double? goalLat;
  double? goalLon;
  int? activeOrderId;
  List<LatLng> routePoints = [];
  bool loadingRoute = true;
  String? routeError;
  String? routeWarn;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();

    mqtt = MqttManager(
      broker: 'broker.hivemq.com',
      mobilId: 'ID01',
      onPosisi: (data) {
        setState(() {
          mobLat = (data["lat"] is num)
              ? (data["lat"] as num).toDouble()
              : double.tryParse("${data['lat']}");
          mobLon = (data["lon"] is num)
              ? (data["lon"] as num).toDouble()
              : double.tryParse("${data['lon']}");
          mobStatus = (data["status"] ?? "-").toString();
        });

        if (mobLat != null && mobLon != null) {
          _mapController.move(
            LatLng(mobLat!, mobLon!),
            _mapController.camera.zoom,
          );
        }
      },
    );

    _connectMqtt();
    _loadActiveRoute();
  }

  Future<void> _connectMqtt() async {
    await mqtt.connect();
    if (!mounted) return;
    setState(() => mqttConnected = mqtt.isConnected);
  }

  Future<void> _loadActiveRoute() async {
    setState(() {
      loadingRoute = true;
      routeError = null;
      routeWarn = null;
      activeOrderId = null;
      goalLat = null;
      goalLon = null;
      routePoints = [];
    });

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/active_route/ID01');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      final body = jsonDecode(res.body);

      if (res.statusCode != 200 || body['ok'] != true) {
        routeError =
            body['error']?.toString() ??
            'Gagal ambil route (HTTP ${res.statusCode})';
      } else {
        activeOrderId = body['order_id'] as int?;
        if (body['goal'] is List && (body['goal'] as List).length == 2) {
          final g = body['goal'] as List;
          goalLat = (g[0] as num).toDouble();
          goalLon = (g[1] as num).toDouble();
        }

        if (body['points'] is List) {
          final List pts = body['points'] as List;
          routePoints = pts
              .where(
                (p) =>
                    p is List && p.length == 2 && p[0] != null && p[1] != null,
              )
              .map(
                (p) =>
                    LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
              )
              .toList();
        }

        if (body['warn'] != null) {
          routeWarn = body['warn'].toString();
        }
      }
    } catch (e) {
      routeError = 'Error: $e';
    } finally {
      if (!mounted) return;
      setState(() => loadingRoute = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadActiveRoute();
    await _connectMqtt();
  }

  @override
  void dispose() {
    mqtt.disconnect();
    super.dispose();
  }

  LatLng get _initialCenter {
    if (mobLat != null && mobLon != null) return LatLng(mobLat!, mobLon!);
    if (goalLat != null && goalLon != null) return LatLng(goalLat!, goalLon!);
    if (routePoints.isNotEmpty) return routePoints.first;
    return const LatLng(5.2089, 97.0749);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (mobLat != null && mobLon != null) {
      markers.add(
        Marker(
          point: LatLng(mobLat!, mobLon!),
          width: 40,
          height: 40,
          child: const Icon(Icons.directions_car, size: 32, color: Colors.blue),
        ),
      );
    }

    if (goalLat != null && goalLon != null) {
      markers.add(
        Marker(
          point: LatLng(goalLat!, goalLon!),
          width: 40,
          height: 40,
          child: const Icon(Icons.flag_circle, size: 32, color: Colors.red),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (routePoints.isNotEmpty) {
      return [Polyline(points: routePoints, strokeWidth: 4)];
    }

    if (mobLat != null &&
        mobLon != null &&
        goalLat != null &&
        goalLon != null) {
      return [
        Polyline(
          points: [LatLng(mobLat!, mobLon!), LatLng(goalLat!, goalLon!)],
          strokeWidth: 3,
        ),
      ];
    }

    return [];
  }

  String _fmtLatLon(double? lat, double? lon) {
    if (lat == null || lon == null) return "-";
    return "${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}";
  }

  @override
  Widget build(BuildContext context) {
    final center = _initialCenter;

    final goalTitle = loadingRoute
        ? "Memuat goal..."
        : (routeError != null
              ? "Goal error"
              : (goalLat != null ? "Goal aktif" : "Belum ada goal"));

    final goalDesc = loadingRoute
        ? "Sedang mengambil dari server"
        : (routeError != null
              ? routeError!
              : (goalLat != null
                    ? (activeOrderId != null
                          ? "Order #$activeOrderId • ${_fmtLatLon(goalLat, goalLon)}"
                          : _fmtLatLon(goalLat, goalLon))
                    : "Belum ada pesanan diproses"));

    final routeDesc = (routePoints.isNotEmpty)
        ? "Rute: ${routePoints.length} titik"
        : ((mobLat != null && goalLat != null)
              ? "Garis langsung (fallback)"
              : "Rute belum tersedia");

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 16),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gobotrak',
              ),
              PolylineLayer(polylines: _buildPolylines()),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // ===== Floating Back + Refresh (tanpa AppBar) =====
          Positioned(
            left: 12,
            top: 12,
            child: _FloatingCircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _FloatingCircleButton(
              icon: Icons.refresh,
              onTap: _refreshAll,
            ),
          ),

          // ===== Info Panel bawah: rapi dan tidak berantakan =====
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _InfoPanel(
              mqttConnected: mqttConnected,
              mobText: mobLat == null
                  ? "Belum ada posisi"
                  : "${_fmtLatLon(mobLat, mobLon)} • $mobStatus",
              goalTitle: goalTitle,
              goalDesc: goalDesc,
              routeDesc: routeDesc,
              warn: routeWarn,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.black87),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final bool mqttConnected;
  final String mobText;
  final String goalTitle;
  final String goalDesc;
  final String routeDesc;
  final String? warn;

  const _InfoPanel({
    required this.mqttConnected,
    required this.mobText,
    required this.goalTitle,
    required this.goalDesc,
    required this.routeDesc,
    required this.warn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      color: Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row chip
            Row(
              children: [
                _Chip(
                  ok: mqttConnected,
                  text: mqttConnected ? "MQTT Online" : "MQTT Offline",
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    routeDesc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _Section(icon: Icons.directions_car, title: "Mobil", desc: mobText),
            const SizedBox(height: 8),

            _Section(icon: Icons.flag_circle, title: goalTitle, desc: goalDesc),

            if (warn != null && warn!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _Section(icon: Icons.info_outline, title: "Info", desc: warn!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final bool ok;
  final String text;

  const _Chip({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final bg = ok
        ? Colors.green.withOpacity(0.12)
        : Colors.red.withOpacity(0.12);
    final fg = ok ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _Section({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
