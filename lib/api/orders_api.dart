// lib/api/orders_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';

class Order {
  final int id;
  final int userId;
  final String userName;
  final String title;
  final String note;
  final double lat;
  final double lon;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final double? jarakMobilM;

  Order({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.note,
    required this.lat,
    required this.lon,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.jarakMobilM,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userName: (json['user_name'] ?? '-') as String,
      title: (json['title'] ?? '') as String,
      note: (json['note'] ?? '') as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      status: (json['status'] ?? '') as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      jarakMobilM: json['jarak_mobil_m'] == null
          ? null
          : (json['jarak_mobil_m'] as num).toDouble(),
    );
  }
}

class OrdersApi {
  static Future<List<Order>> fetchOrders(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/orders');
    final res = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Gagal ambil orders: HTTP ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(res.body);
    if (body['ok'] != true) {
      throw Exception('Gagal ambil orders: ${body['error']}');
    }

    final List data = body['data'] as List;
    return data.map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<int?> createOrder(
    String token, {
    required String title,
    required String note,
    required double lat,
    required double lon,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/orders');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'title': title, 'note': note, 'lat': lat, 'lon': lon}),
    );

    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['ok'] != true) {
      throw Exception('Gagal buat order: ${body['error'] ?? 'unknown'}');
    }

    return body['order_id'] as int?;
  }

  /// Approve order (admin): /api/v1/orders/<id>/approve
  static Future<void> approveOrder(String token, int orderId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/orders/$orderId/approve',
    );
    final res = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['ok'] != true) {
      throw Exception('Gagal approve order: ${body['error'] ?? 'unknown'}');
    }
  }

  /// Update status order: "baru", "diproses", "selesai", "batal"
  static Future<void> updateOrderStatus(
    String token,
    int orderId,
    String status,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/orders/$orderId');
    final res = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );

    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['ok'] != true) {
      throw Exception('Gagal update status: ${body['error'] ?? 'unknown'}');
    }
  }

  /// Hapus order
  static Future<void> deleteOrder(String token, int orderId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/orders/$orderId');
    final res = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    final body = jsonDecode(res.body);

    if (res.statusCode != 200 || body['ok'] != true) {
      throw Exception('Gagal hapus order: ${body['error'] ?? 'unknown'}');
    }
  }
}
