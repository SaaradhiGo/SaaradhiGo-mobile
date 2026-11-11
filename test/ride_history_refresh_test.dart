// A cold start used to show no recent places: the stored access token had
// expired, the history call got 401 and returned nothing.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';

void main() {
  test('an expired token is refreshed once and the history call retried', () async {
    final seen = <String?>[];
    final client = MockClient((req) async {
      seen.add(req.headers['Authorization']);
      if (req.headers['Authorization'] == 'Bearer old') {
        return http.Response('{"detail":"expired"}', 401);
      }
      return http.Response(jsonEncode({'results': []}), 200);
    });
    var refreshed = 0;
    final trips = await RideService(client: client).fetchRideHistory(
      'old',
      onUnauthorized: () async {
        refreshed++;
        return 'new';
      },
    );
    expect(trips, isEmpty);
    expect(refreshed, 1);
    expect(seen, ['Bearer old', 'Bearer new']);
  });

  test('without a refresher a 401 still returns an empty list', () async {
    final client = MockClient((_) async => http.Response('', 401));
    expect(await RideService(client: client).fetchRideHistory('old'), isEmpty);
  });
}
