/// The trip's ETA from the server (`GET /ride/trip/<id>/eta/` and the
/// `trip_eta_update` socket frame, 2026-11-09). The screens show only what
/// this holds: no ETA, no line.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_events.dart' show kLoadTimeout;
import 'app_config.dart';

@immutable
class TripEta {
  const TripEta({
    required this.phase,
    this.pickupEtaMin,
    this.pickupDistanceKm,
    this.dropEtaMin,
    this.arriveAt,
  });

  /// to_pickup, at_pickup or to_drop.
  final String phase;
  final int? pickupEtaMin;

  /// As the server sends it ("1.4").
  final String? pickupDistanceKm;
  final int? dropEtaMin;

  /// The arrival time as a wall clock in the trip's own time zone, taken
  /// from `arrive_at` without converting it to the phone's zone.
  final ({int hour, int minute})? arriveAt;

  static int? _int(Object? v) =>
      v is int ? v : (v is num ? v.round() : int.tryParse('${v ?? ''}'));

  /// "2026-11-09T09:41:00+05:30" -> 9:41.
  static ({int hour, int minute})? wallClock(Object? iso) {
    final m = RegExp(r'T(\d{2}):(\d{2})').firstMatch('${iso ?? ''}');
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return (hour: h, minute: min);
  }

  /// Null when the server sent no ETA.
  static TripEta? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final phase = raw['phase']?.toString() ?? '';
    if (phase.isEmpty) return null;
    final km = raw['pickup_distance_km']?.toString().trim() ?? '';
    return TripEta(
      phase: phase,
      pickupEtaMin: _int(raw['pickup_eta_min']),
      pickupDistanceKm: km.isEmpty ? null : km,
      dropEtaMin: _int(raw['drop_eta_min']),
      arriveAt: wallClock(raw['arrive_at']),
    );
  }

  /// Minutes to the pickup while the driver is on the way; null otherwise,
  /// and never 0 or less.
  int? get minutesToPickup {
    final m = pickupEtaMin;
    return phase == 'to_pickup' && m != null && m > 0 ? m : null;
  }

  /// The arrival clock while on trip; null otherwise.
  ({int hour, int minute})? get arrivalClock =>
      phase == 'to_drop' ? arriveAt : null;
}

/// The live trip's ETA. One trip at a time; frames for another trip are
/// ignored.
class TripEtaStore extends ChangeNotifier {
  TripEtaStore._();
  static final instance = TripEtaStore._();

  String? _tripId;
  TripEta? _eta;

  String? get tripId => _tripId;

  /// The ETA for [tripId], or null when there is none (or it is for another
  /// trip).
  TripEta? etaFor(String? tripId) =>
      tripId != null && tripId == _tripId ? _eta : null;

  void set(String tripId, TripEta? eta) {
    _tripId = tripId;
    _eta = eta;
    notifyListeners();
  }

  void clear() {
    if (_tripId == null && _eta == null) return;
    _tripId = null;
    _eta = null;
    notifyListeners();
  }

  /// A `trip_eta_update` frame. Returns true when it was one.
  bool applyFrame(Map<String, dynamic> frame) {
    if (frame['type'] != 'trip_eta_update') return false;
    final id = frame['trip_id']?.toString();
    if (id == null || id.isEmpty) return true;
    set(id, TripEta.fromJson(frame['eta']));
    return true;
  }

  int _loads = 0;

  /// `GET /ride/trip/<id>/eta/`. A failure keeps what is there.
  Future<void> load(String tripId, {ApiService? api}) async {
    final seq = ++_loads;
    try {
      final r = await (api ?? ApiService())
          .authedRequest(
            (h) => http.get(
              Uri.parse('${AppConfig.baseUrl}/ride/trip/$tripId/eta/'),
              headers: h,
            ),
          )
          .timeout(kLoadTimeout);
      if (r == null || r.statusCode != 200 || seq != _loads) return;
      final body = json.decode(r.body);
      final data = body is Map ? body['data'] : null;
      if (data is! Map) return;
      set(tripId, TripEta.fromJson(data['eta']));
    } catch (e) {
      debugPrint('Trip ETA failed: $e');
    }
  }
}

/// Asks for [tripId]'s ETA once (the id can arrive after a screen opens);
/// returns the id asked for, to pass back next time.
String? askTripEta(String? tripId, String? asked) {
  if (tripId == null || tripId.isEmpty || tripId == asked) return asked;
  unawaited(TripEtaStore.instance.load(tripId));
  return tripId;
}
