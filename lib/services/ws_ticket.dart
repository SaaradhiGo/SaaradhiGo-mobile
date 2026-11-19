/// 16 Nov ruling: a socket never carries the sign-in token in its address.
/// The token stays in the app; each connect trades it for a single-use ticket
/// that expires after 30 seconds (POST /auth/ws-ticket/).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// A fresh ticket for [token], or null when the server cannot issue one.
Future<String?> fetchWsTicket(String token, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final r = await c
        .post(
          Uri.parse('${AppConfig.baseUrl}/auth/ws-ticket/'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    final body = jsonDecode(r.body);
    final data = body is Map ? body['data'] : null;
    final ticket = data is Map ? data['ticket']?.toString() : null;
    return (ticket == null || ticket.isEmpty) ? null : ticket;
  } catch (e) {
    debugPrint('ws ticket failed (${e.runtimeType})');
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// [url] as it is opened: its `token` removed and a ticket added in its place.
/// Without a ticket the address carries no credential (the server refuses it
/// and the caller's reconnect refreshes the token and tries again).
Future<Uri> ticketedWsUri(String url, {http.Client? client}) async {
  final uri = Uri.parse(url);
  final params = Map<String, String>.from(uri.queryParameters);
  final token = params.remove('token');
  if (token != null && token.isNotEmpty) {
    final ticket = await fetchWsTicket(token, client: client);
    if (ticket != null) params['ticket'] = ticket;
  }
  final base = url.split('?').first;
  return Uri.parse(
    params.isEmpty ? base : '$base?${Uri(queryParameters: params).query}',
  );
}
