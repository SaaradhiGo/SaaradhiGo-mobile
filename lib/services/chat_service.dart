import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../core/app_config.dart';

/// Connects to /ws/ride/trip/<id>/chat/?token=<jwt> and streams messages.
///
/// Companion to the backend ChatMessage model. Two surfaces:
///   * WebSocket for live messages (send + receive)
///   * REST history endpoint for paginated backfill on screen-open or
///     after a reconnect.
class ChatService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _intentionalDisconnect = false;
  Timer? _reconnectTimer;
  int _attempts = 0;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void connect({required int tripId, required String token}) {
    _intentionalDisconnect = false;
    final uri = Uri.parse(
      '${AppConfig.wsBaseUrl}/ride/trip/$tripId/chat/?token=$token',
    );
    try {
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (event) {
          try {
            final parsed = jsonDecode(event as String) as Map<String, dynamic>;
            _controller.add(parsed);
          } catch (e) {
            debugPrint('chat parse error: $e');
          }
        },
        onError: (err) {
          debugPrint('chat ws error: $err');
          _scheduleReconnect(tripId: tripId, token: token);
        },
        onDone: () {
          if (!_intentionalDisconnect) {
            _scheduleReconnect(tripId: tripId, token: token);
          }
        },
        cancelOnError: false,
      );
      _attempts = 0;
    } catch (e) {
      debugPrint('chat ws connect failed: $e');
      _scheduleReconnect(tripId: tripId, token: token);
    }
  }

  void _scheduleReconnect({required int tripId, required String token}) {
    _reconnectTimer?.cancel();
    _attempts += 1;
    final delay = Duration(seconds: _attempts.clamp(1, 8));
    _reconnectTimer = Timer(delay, () {
      if (!_intentionalDisconnect) {
        connect(tripId: tripId, token: token);
      }
    });
  }

  void send(String body) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'action': 'send', 'body': body}));
  }

  void markRead() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'action': 'read_all'}));
  }

  Future<List<Map<String, dynamic>>> fetchHistory({
    required int tripId,
    required String token,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/ride/trip/$tripId/chat/');
    final resp = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return const [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = body['results'] ?? body['data'] ?? [];
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
