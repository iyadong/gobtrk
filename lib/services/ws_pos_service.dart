import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

typedef PosCallback = void Function(Map<String, dynamic> pos);

class PosWebSocketService {
  WebSocketChannel? _channel;
  PosCallback? _onPos;

  void connect(String token, PosCallback onPos) {
    _onPos = onPos;

    final url = "${ApiConfig.wsBaseUrl}/ws/pos?token=$token";
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen(
      (msg) {
        try {
          final data = jsonDecode(msg);
          if (data is Map<String, dynamic>) {
            _onPos?.call(data);
          }
        } catch (_) {}
      },
      onError: (e) {
        // bisa tambahkan log / callback error
      },
      onDone: () {
        // koneksi selesai
      },
    );
  }

  void dispose() {
    _channel?.sink.close();
  }
}
