// lib/mqtt/mqtt_manager.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

typedef PosisiCallback = void Function(Map<String, dynamic> data);

class MqttManager {
  final String broker;
  final int port;
  final String mobilId;
  final PosisiCallback onPosisi;

  MqttServerClient? _client;
  bool _connected = false;

  String get topicPosisi => 'mobil/$mobilId/posisi';
  String get topicCommand => 'mobil/$mobilId/command';
  String get topicStatus => 'mobil/$mobilId/status';

  MqttManager({
    required this.broker,
    this.port = 1883,
    required this.mobilId,
    required this.onPosisi,
  });

  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) {
      debugPrint('[MQTT] Already connected');
      return;
    }

    final clientId =
        'flutter-app-$mobilId-${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient(broker, clientId);
    _client!.port = port;
    _client!.logging(on: true); // sementara: hidupkan log untuk debug
    _client!.keepAlivePeriod = 20;

    // Callbacks
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = (topic) => debugPrint('[MQTT] Subscribed: $topic');
    _client!.onSubscribeFail = (topic) =>
        debugPrint('[MQTT] Failed to subscribe: $topic');
    _client!.onUnsubscribed = (topic) =>
        debugPrint('[MQTT] Unsubscribed: $topic');

    // Last Will (status offline)
    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic(topicStatus)
        .withWillMessage('offline')
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMsg;

    try {
      debugPrint('[MQTT] Connecting to $broker:$port ...');
      final connStatus = await _client!.connect();
      debugPrint('[MQTT] connect() returned: ${connStatus?.state}');
      debugPrint(
        '[MQTT] connectionStatus: ${_client!.connectionStatus.toString()}',
      );

      final state = connStatus?.state ?? _client!.connectionStatus?.state;
      if (state == MqttConnectionState.connected) {
        debugPrint('[MQTT] Connected OK');
        _connected = true;

        // Publish status online (retained)
        final online = MqttClientPayloadBuilder()..addString('online');
        _client!.publishMessage(
          topicStatus,
          MqttQos.atLeastOnce,
          online.payload!,
          retain: true,
        );

        // Subscribe posisi & start listener
        _subscribePosisi();

        _client!.updates?.listen(
          _onMessage,
          onError: (e) => debugPrint('[MQTT] updates error: $e'),
        );
      } else {
        debugPrint(
          '[MQTT] Connection failed, status: ${_client!.connectionStatus}',
        );
        disconnect();
      }
    } catch (e) {
      debugPrint('[MQTT] Exception during connect: $e');
      disconnect();
    }
  }

  void _onConnected() {
    debugPrint('[MQTT] onConnected callback dipanggil');
  }

  void _onDisconnected() {
    debugPrint('[MQTT] Disconnected');
    _connected = false;
  }

  void _subscribePosisi() {
    if (_client == null || !_connected) {
      debugPrint('[MQTT] _subscribePosisi tapi belum connected');
      return;
    }
    debugPrint('[MQTT] Subscribing $topicPosisi');
    _client!.subscribe(topicPosisi, MqttQos.atMostOnce);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final msg = event.payload as MqttPublishMessage;
      final payloadStr = MqttPublishPayload.bytesToStringAsString(
        msg.payload.message,
      );

      // Debug semua pesan
      debugPrint('[MQTT] RX topic=${event.topic} payload=$payloadStr');

      if (event.topic == topicPosisi) {
        try {
          final data = json.decode(payloadStr) as Map<String, dynamic>;
          onPosisi(data);
        } catch (e) {
          debugPrint('[MQTT] Parse posisi JSON failed: $e | $payloadStr');
        }
      }
    }
  }

  void sendStopCommand() {
    sendCommand({
      'command': 'stop',
      'source': 'app',
      'command_id': 'stop_${DateTime.now().millisecondsSinceEpoch}',
    });
  }

  void sendTestGoal() {
    // contoh goal dekat koordinat default
    final lat = 5.2089 + 0.0005;
    final lon = 97.0749 + 0.0005;
    sendCommand({
      'command': 'set_goal',
      'goal': [lat, lon],
      'source': 'app',
      'command_id': 'goal_${DateTime.now().millisecondsSinceEpoch}',
    });
  }

  void sendCommand(Map<String, dynamic> cmd) {
    if (_client == null || !_connected) {
      debugPrint('[MQTT] Not connected, cannot send command');
      return;
    }
    try {
      final builder = MqttClientPayloadBuilder()..addString(json.encode(cmd));
      debugPrint('[MQTT] Publish -> $topicCommand : ${json.encode(cmd)}');
      _client!.publishMessage(
        topicCommand,
        MqttQos.atLeastOnce,
        builder.payload!,
      );
    } catch (e) {
      debugPrint('[MQTT] Publish command error: $e');
    }
  }

  void disconnect() {
    try {
      if (_client != null) {
        debugPrint('[MQTT] Disconnecting client');
        _client!.disconnect();
      }
    } catch (_) {}
    _connected = false;
  }
}
