/// Trip ETA (`GET /ride/trip/<id>/eta/` and `trip_eta_update`, 2026-11-09):
/// shown only as the server sends it; null, 0 or another trip shows nothing.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/core/trip_eta.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TripEtaStore.instance.clear();
    SharedPreferences.setMockInitialValues({'access_token': 'a'});
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'a',
      'refresh_token': 'r',
    });
  });

  test('to_pickup: minutes; to_drop: the trip-local clock', () {
    final p = TripEta.fromJson({
      'phase': 'to_pickup',
      'pickup_eta_min': 4,
      'pickup_distance_km': '1.4',
      'drop_eta_min': null,
      'arrive_at': null,
      'estimated': true,
      'source': 'straight_line',
    })!;
    expect(p.minutesToPickup, 4);
    expect(p.pickupDistanceKm, '1.4');
    expect(p.arrivalClock, isNull);

    final d = TripEta.fromJson({
      'phase': 'to_drop',
      'pickup_eta_min': null,
      'drop_eta_min': 12,
      'arrive_at': '2026-11-09T21:41:00+05:30',
    })!;
    expect(d.minutesToPickup, isNull);
    expect(d.arrivalClock, (hour: 21, minute: 41));
  });

  test('null, 0 and at_pickup show no minutes', () {
    expect(TripEta.fromJson(null), isNull);
    expect(
      TripEta.fromJson({'phase': 'to_pickup', 'pickup_eta_min': 0})!
          .minutesToPickup,
      isNull,
    );
    expect(
      TripEta.fromJson({'phase': 'at_pickup', 'pickup_eta_min': 2})!
          .minutesToPickup,
      isNull,
    );
  });

  test('a socket frame updates its own trip only', () {
    final s = TripEtaStore.instance;
    expect(
      s.applyFrame({
        'type': 'trip_eta_update',
        'trip_id': 7,
        'eta': {'phase': 'to_pickup', 'pickup_eta_min': 3},
      }),
      isTrue,
    );
    expect(s.etaFor('7')!.minutesToPickup, 3);
    expect(s.etaFor('8'), isNull);
    s.applyFrame({'type': 'trip_eta_update', 'trip_id': 7, 'eta': null});
    expect(s.etaFor('7'), isNull);
    expect(s.applyFrame({'type': 'location_update'}), isFalse);
  });

  test(
    'load reads GET /ride/trip/<id>/eta/; a failure keeps the last',
    () async {
      final s = TripEtaStore.instance;
      await http.runWithClient(
        () => s.load('7'),
        () => MockClient(
          (r) async => http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'trip_id': 7,
                'eta': {'phase': 'to_pickup', 'pickup_eta_min': 5},
              },
            }),
            200,
          ),
        ),
      );
      expect(s.etaFor('7')!.minutesToPickup, 5);
      await http.runWithClient(
        () => s.load('7'),
        () => MockClient((r) async => http.Response('{}', 500)),
      );
      expect(s.etaFor('7')!.minutesToPickup, 5);
    },
  );
}
