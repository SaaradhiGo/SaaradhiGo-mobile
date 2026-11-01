/// Rider-side emergency.
///
/// WHY THIS EXISTS
/// ---------------
/// The backend has had `POST /sos/` since the safety work: it persists an
/// SOSEvent row, returns the id in about a second, and then fans out
/// asynchronously to the ops topic, an ops push, and an SMS to the caller's
/// emergency contact. The driver app has used it from day one.
///
/// The rider app did not call it at all. The only trace of safety on the rider
/// side was an `emergency_contact` string in `SharedPreferences` — a value the
/// rider typed into their profile that nothing ever read. So a rider in trouble
/// had no button, and the contact they nominated would never have been told.
///
/// WHAT "GENUINE" MEANS HERE
/// -------------------------
/// This is not a button that shows a toast. Raising an SOS:
///   * persists a durable row server-side before returning,
///   * carries the live trip id and the rider's coordinates, so ops can see
///     where the person is rather than asking,
///   * reports failure honestly — if the POST fails, the UI says so and offers
///     the phone dialler, because a silent failure here is the worst outcome
///     in the app.
///
/// It deliberately does NOT replace calling the emergency services. The sheet
/// that uses this service offers 112 (India's single emergency number) as a
/// direct dial alongside it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'token_store.dart';

/// What the rider says is wrong. Mirrors `SOSEvent.EVENT_TYPE_CHOICES`.
enum SosCategory {
  panic('panic', 'I feel unsafe'),
  medical('medical', 'Medical emergency'),
  accident('accident', 'Accident'),
  harassment('harassment', 'Harassment'),
  vehicleBreakdown('vehicle_breakdown', 'Vehicle breakdown');

  const SosCategory(this.wireValue, this.label);

  /// The exact string the server accepts. Not derived from the enum name:
  /// `vehicle_breakdown` is not `vehicleBreakdown`, and a mismatch here would
  /// be a silently mis-categorised emergency.
  final String wireValue;
  final String label;
}

@immutable
class SosResult {
  const SosResult({required this.ok, this.sosId, this.message});

  final bool ok;
  final int? sosId;

  /// Operator-readable reason when [ok] is false. Shown to the rider, so it
  /// never contains a stack trace or a URL.
  final String? message;

  static const SosResult _noToken = SosResult(
    ok: false,
    message: 'You are signed out. Please sign in again, or call 112 directly.',
  );
}

class SosService {
  SosService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// How long to wait before telling the rider it did not go through.
  ///
  /// Short. The server's own contract is "200 within about a second" because
  /// the fan-out is asynchronous, and a rider holding a phone in an emergency
  /// must not watch a spinner for 30 seconds before being offered the dialler.
  static const Duration _timeout = Duration(seconds: 8);

  /// Raise an SOS. Never throws.
  ///
  /// Returns [SosResult.ok] only on a 2xx. Everything else — no token, a
  /// timeout, a 500, an unparseable body — comes back as a failure with
  /// something the rider can act on.
  Future<SosResult> raise({
    required SosCategory category,
    String? tripId,
    double? lat,
    double? lng,
    double? accuracyM,
    String? note,
  }) async {
    final token = await TokenStore.readAccessToken();
    if (token == null || token.isEmpty) return SosResult._noToken;

    final body = <String, dynamic>{
      'event_type': category.wireValue,
      // `initiated_by` is deliberately omitted: the server derives it from the
      // authenticated user's role and ignores whatever a client sends.
      if (tripId != null && tripId.isNotEmpty) 'trip_id': int.tryParse(tripId),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (note != null && note.isNotEmpty) 'note': note,
    }..removeWhere((_, value) => value == null);

    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}${AppConfig.sos}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SosResult(ok: true, sosId: _sosIdFrom(response.body));
      }

      return SosResult(
        ok: false,
        message: 'We could not alert our team (error '
            '${response.statusCode}). Please call 112.',
      );
    } on TimeoutException {
      return const SosResult(
        ok: false,
        message: 'No response from our team. Please call 112 now.',
      );
    } on Object catch (error) {
      // Deliberately broad: in an emergency any failure must still produce the
      // dialler, not an unhandled exception.
      if (kDebugMode) debugPrint('SOS failed: $error');
      return const SosResult(
        ok: false,
        message: 'We could not reach our team. Please call 112 now.',
      );
    }
  }

  /// Pulls the id out of either response shape the API uses.
  int? _sosIdFrom(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final data = decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;
      final value = data['sos_id'] ?? data['id'];
      return value is num ? value.toInt() : int.tryParse('$value');
    } on Object {
      return null;
    }
  }

  void dispose() => _client.close();
}
