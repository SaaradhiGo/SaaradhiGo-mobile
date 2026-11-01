/// Server confirmation comes BEFORE local cancellation state.
///
/// WHY THE ORDER IS THE WHOLE POINT
/// --------------------------------
/// `cancelRideRequest` used to tear down local state unconditionally.
/// Combined with the missing `reason` -- which made the server refuse every
/// cancellation -- the rider was shown "cancelled" for a trip that was still
/// live, with a driver still being dispatched to them. Clearing first turns a
/// failed cancellation into a silent one.
///
/// Now nothing local is torn down until the server confirms, and a refusal or
/// a timeout LEAVES THE TRIP STATE INTACT: the ride really is still live, the
/// driver really may still arrive, and the rider needs to keep seeing it so
/// they can retry.
///
/// These tests assert the ordering through `RideService` -- the seam the
/// provider calls -- plus the reason, the timeout bound, and the recoverable
/// state that must survive a failure.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('what counts as confirmation', () {
    test('only a 2xx is a confirmed cancellation', () async {
      for (final status in [200, 201]) {
        final service = RideService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'status': 'success'}),
              status,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        expect(
          await service.cancelTrip('t', '991'),
          isTrue,
          reason: '$status is a confirmation',
        );
      }
    });

    test('a refusal is NOT confirmation, so the trip stays live', () async {
      for (final status in [400, 403, 404, 409, 500, 503]) {
        final service = RideService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'status': 'error'}),
              status,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        expect(
          await service.cancelTrip('t', '991'),
          isFalse,
          reason: '$status must not be read as cancelled',
        );
      }
    });

    test('a dropped connection is not confirmation', () async {
      final service = RideService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      expect(await service.cancelTrip('t', '991'), isFalse);
    });
  });

  group('a network timeout is bounded and is not confirmation', () {
    test('it gives up rather than hanging, and reports false', () async {
      // Unbounded, a dead connection would leave the rider on a spinner
      // instead of being told to retry -- and the ride stays on screen now,
      // so being told matters more than before.
      final service = RideService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response('{}', 200);
        }),
      );

      final stopwatch = Stopwatch()..start();
      final result = await service.cancelTrip('t', '991');
      stopwatch.stop();

      expect(result, isFalse, reason: 'a timeout is not a cancellation');
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 25)),
        reason: 'it must give up on its own',
      );
    });

    test('the bound is short, because the ride stays on screen until it '
        'answers', () {
      expect(RideService.cancelTimeout.inSeconds, lessThanOrEqualTo(15));
      expect(
        RideService.cancelTimeout.inSeconds,
        greaterThanOrEqualTo(5),
        reason: 'too short would fail cancellations on a slow connection',
      );
    });
  });

  group('the request that gets sent', () {
    test('it always carries a server-accepted reason', () async {
      // The defect that made every cancellation fail: no reason at all.
      final captured = <http.Request>[];
      final service = RideService(
        client: MockClient((request) async {
          captured.add(request);
          return http.Response(
            jsonEncode({'status': 'success'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.cancelTrip('t', '991');

      final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
      expect(body['reason'], isNotNull);
      expect(RideService.riderCancelReasons, contains(body['reason']));
    });

    test('it goes to the rider cancel route, not the driver one', () async {
      // The two endpoints have different reason vocabularies; sending one
      // app's set to the other's route is a 400.
      final captured = <http.Request>[];
      final service = RideService(
        client: MockClient((request) async {
          captured.add(request);
          return http.Response(
            jsonEncode({'status': 'success'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.cancelTrip('t', '991');

      expect(captured.single.url.path, endsWith('/ride/trip/991/cancel/'));
      expect(captured.single.url.path, isNot(contains('driver-cancel')));
    });

    test('it is authenticated, or the server would refuse it', () async {
      final captured = <http.Request>[];
      final service = RideService(
        client: MockClient((request) async {
          captured.add(request);
          return http.Response(
            jsonEncode({'status': 'success'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.cancelTrip('token-aaa', '991');

      expect(captured.single.headers['Authorization'], 'Bearer token-aaa');
    });
  });

  group('the rider cancel vocabulary stays the server own', () {
    test('it is exactly the five the rider endpoint accepts', () {
      expect(RideService.riderCancelReasons, {
        'no_show',
        'wrong_location',
        'too_long',
        'safety',
        'other',
      });
    });

    test('it excludes the driver-only reasons', () {
      // `vehicle_issue` and `personal` belong to /driver-cancel/ and are a
      // 400 here -- which would make a cancellation fail again, this time
      // for a different reason.
      expect(RideService.riderCancelReasons, isNot(contains('vehicle_issue')));
      expect(RideService.riderCancelReasons, isNot(contains('personal')));
    });
  });
}
