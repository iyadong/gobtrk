import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class CommandService {
  static Future<Map<String, dynamic>> sendStop({
    required String token,
    String mobilId = "ID01",
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/v1/cmd/$mobilId");

    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"command": "stop"}),
    );

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
