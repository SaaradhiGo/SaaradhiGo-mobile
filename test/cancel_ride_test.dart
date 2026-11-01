/// A rider could not actually cancel a ride.
///
/// THE DEFECT
/// ----------
/// `POST /ride/trip/<id>/cancel/` **requires** `reason`, validated against
/// `{no_show, wrong_location, too_long, safety, other}`, and answers
/// `INVALID_REASON` 400 for anything else -- including an absent field.
///
/// Every call site in the app invoked `cancelTrip(token, tripId)` with no
/// reason, so the request body was `{}` and **every rider cancellation was
/// refused**. The 400 was caught and `debugPrint`ed, and the app went on to
/// clear its local state regardless -- so the rider was shown "cancelled"
/// while the trip stayed live on the server, a driver could still be
/// dispatched to them, and the trip only ended when `auto_cancel_trip` ran.
///
/// Note the two vocabularies differ: the DRIVER endpoint accepts
/// `vehicle_issue` and `personal`, which the rider endpoint rejects. Sending
/// one app's set to the other's endpoint is a 400.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <http.Request>[];

  setUp(() {
    captured.clear();
    SharedPreferences.setMockInitialValues({});
  });

  RideService serviceReturning(int status, {Object? body}) {
    return RideService(
      client: MockClient((request) async {
        captured.add(request);
        return http.Response(
          jsonEncode(body ?? {'status': 'success', 'data': {}}),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  group('the cancellation request', () {
    test('always carries a reason, even when the caller gives none', () async {
      // This is the defect: the body used to be `{}`.
      final service = serviceReturning(200);

      final ok = await service.cancelTrip('token-aaa', '991');

      expect(ok, isTrue);
      final body = bodyOf(captured.single);
      expect(
        body.containsKey('reason'),
        isTrue,
        reason: 'an absent reason is an INVALID_REASON 400',
      );
      expect(body['reason'], 'other');
    });

    test('the default is a reason the server actually accepts', () {
      expect(RideService.riderCancelReasons, contains('other'));
    });

    test('a caller-supplied valid reason is passed through', () async {
      final service = serviceReturning(200);

      await service.cancelTrip('token-aaa', '991', reason: 'too_long');

      expect(bodyOf(captured.single)['reason'], 'too_long');
    });

    test('a reason the server would reject is replaced, not sent', () async {
      // `vehicle_issue` and `personal` belong to the DRIVER endpoint. Sending
      // either here is a 400, and a rider who cannot cancel is the whole
      // defect repeating.
      final service = serviceReturning(200);

      for (final wrong in ['vehicle_issue', 'personal', 'changed my mind']) {
        captured.clear();
        await service.cancelTrip('token-aaa', '991', reason: wrong);
        expect(
          RideService.riderCancelReasons,
          contains(bodyOf(captured.single)['reason']),
          reason: '"$wrong" would have been refused',
        );
      }
    });

    test('the rider vocabulary is exactly the server own', () {
      // From servers/ride/views.py, the rider branch. The driver branch has a
      // different set on purpose.
      expect(RideService.riderCancelReasons, {
        'no_show',
        'wrong_location',
        'too_long',
        'safety',
        'other',
      });
    });

    test('a note is included only when given', () async {
      final service = serviceReturning(200);

      await service.cancelTrip('token-aaa', '991', note: 'driver never moved');
      expect(bodyOf(captured.single)['note'], 'driver never moved');

      captured.clear();
      await service.cancelTrip('token-aaa', '991');
      expect(bodyOf(captured.single).containsKey('note'), isFalse);
    });
  });

  group('what the caller learns', () {
    test('a refusal is reported as false, not swallowed', () async {
      // The old code could not tell: it caught the failure and carried on
      // clearing local state, so the rider saw "cancelled" for a live trip.
      final service = serviceReturning(
        400,
        body: {
          'status': 'error',
          'error': {
            'code': 'INVALID_REASON',
            'message': 'reason must be one of',
          },
        },
      );

      expect(await service.cancelTrip('token-aaa', '991'), isFalse);
    });

    test('a 403 for somebody else trip is reported as false', () async {
      final service = serviceReturning(
        403,
        body: {
          'status': 'error',
          'error': {
            'code': 'FORBIDDEN',
            'message': 'Only the rider who booked',
          },
        },
      );

      expect(await service.cancelTrip('token-aaa', '991'), isFalse);
    });

    test('an unreachable server is reported as false', () async {
      final service = RideService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      expect(await service.cancelTrip('token-aaa', '991'), isFalse);
    });

    test('a success is reported as true', () async {
      expect(
        await serviceReturning(200).cancelTrip('token-aaa', '991'),
        isTrue,
      );
    });
  });
}
