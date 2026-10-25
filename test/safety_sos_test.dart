/// Rider safety: the SOS must actually send, and must admit it when it did not.
///
/// THE DEFECT THESE TESTS LOCK DOWN
/// -------------------------------
/// The tracking screen had an SOS button. It opened a dialog saying "This will
/// alert the nearest authorities and our support team", and on confirm it
/// showed a red snackbar:
///
///     Emergency Alert Sent! Support is on the way.
///
/// It called no API. Nothing was persisted, no ops alert was raised, and the
/// rider's nominated emergency contact was never messaged. A rider in trouble
/// was told help was coming when nobody had been told anything.
///
/// So these tests assert the two things that matter: a real request goes to
/// `/sos/` with the trip and the coordinates, and a failure surfaces to the
/// rider with the dialler rather than a reassuring message.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/services/sos_service.dart';
import 'package:saaradhigo_rider/widgets/safety_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // TokenStore reads secure storage first and falls back to prefs. In a test
    // binding secure storage is unavailable, so the prefs value is what the
    // service will find.
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
  });

  group('SosService', () {
    test('posts the category, trip and coordinates the server expects',
        () async {
      http.Request? seen;
      final service = SosService(
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({'status': 'success', 'data': {'sos_id': 77}}),
            201,
          );
        }),
      );

      final result = await service.raise(
        category: SosCategory.harassment,
        tripId: '45',
        lat: 17.4450,
        lng: 78.3800,
      );

      expect(result.ok, isTrue);
      expect(result.sosId, 77);

      expect(seen, isNotNull);
      expect(seen!.method, 'POST');
      expect(seen!.url.path, endsWith('/sos/'));
      expect(seen!.headers['Authorization'], 'Bearer test-token');

      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      // `harassment`, not `SosCategory.harassment` and not `Harassment`.
      expect(body['event_type'], 'harassment');
      // An int, because the server looks the trip up by id.
      expect(body['trip_id'], 45);
      expect(body['lat'], 17.4450);
      expect(body['lng'], 78.3800);
      // Deliberately absent: the server derives it from the authenticated role
      // and ignores a client-sent value.
      expect(body.containsKey('initiated_by'), isFalse);
    });

    test('sends the underscored wire value for every category', () {
      // A mis-spelled category is a mis-categorised emergency in the ops queue.
      expect(SosCategory.vehicleBreakdown.wireValue, 'vehicle_breakdown');
      expect(SosCategory.panic.wireValue, 'panic');
      expect(SosCategory.medical.wireValue, 'medical');
      expect(SosCategory.accident.wireValue, 'accident');
      expect(SosCategory.harassment.wireValue, 'harassment');
    });

    test('omits a trip id when there is no live trip', () async {
      http.Request? seen;
      final service = SosService(
        client: MockClient((request) async {
          seen = request;
          return http.Response('{}', 200);
        }),
      );

      await service.raise(category: SosCategory.panic);

      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      expect(body.containsKey('trip_id'), isFalse);
      expect(body['event_type'], 'panic');
    });

    test('a 500 is reported as a failure that names 112', () async {
      final service = SosService(
        client: MockClient((_) async => http.Response('boom', 500)),
      );

      final result = await service.raise(category: SosCategory.panic);

      expect(result.ok, isFalse);
      expect(result.message, contains('112'));
    });

    test('a network error is reported, not swallowed', () async {
      final service = SosService(
        client: MockClient((_) async => throw const SocketishError()),
      );

      final result = await service.raise(category: SosCategory.panic);

      expect(result.ok, isFalse);
      expect(result.message, contains('112'));
    });

    test('a signed-out rider is told to sign in, and still told to call 112',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = SosService(
        client: MockClient((_) async {
          fail('no request should be made without a token');
        }),
      );

      final result = await service.raise(category: SosCategory.panic);

      expect(result.ok, isFalse);
      expect(result.message, contains('112'));
    });

    test('a 2xx with an unreadable body is still a success', () async {
      // The row exists server-side. Failing the UI over a parse error would
      // tell the rider nothing was sent when something was.
      final service = SosService(
        client: MockClient((_) async => http.Response('not json', 200)),
      );

      final result = await service.raise(category: SosCategory.panic);

      expect(result.ok, isTrue);
      expect(result.sosId, isNull);
    });
  });

  group('trip sharing', () {
    test('shares the facts the server gave us, and no invented link', () {
      const trip = TripSafetyContext(
        tripId: '45',
        driverName: 'A Driver',
        vehicleNumber: 'TS09AB1234',
        vehicleModel: 'Swift Dzire',
        lat: 17.4450,
        lng: 78.3800,
      );

      final message = trip.shareMessage();

      expect(message, contains('A Driver'));
      expect(message, contains('TS09AB1234'));
      expect(message, contains('Swift Dzire'));
      expect(message, contains('#45'));
      expect(message, contains('17.445000,78.380000'));
      // No public live-tracking endpoint exists. A link that 404s during an
      // emergency is worse than no link.
      expect(message, isNot(contains('saaradhigo.com/track')));
    });

    test('omits what it does not know rather than printing null', () {
      const trip = TripSafetyContext(tripId: '9');
      final message = trip.shareMessage();

      expect(message, contains('#9'));
      expect(message.toLowerCase(), isNot(contains('null')));
      expect(message.toLowerCase(), isNot(contains('unknown')));
      expect(message, isNot(contains('My location')));
    });
  });

  group('the safety sheet', () {
    Future<void> pump(WidgetTester tester, SosService service) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetySheet(
              trip: const TripSafetyContext(tripId: '45'),
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers 112 before anything else happens', (tester) async {
      await pump(
        tester,
        SosService(client: MockClient((_) async => http.Response('{}', 200))),
      );

      expect(find.byKey(const Key('safety_call_112')), findsOneWidget);
      expect(find.byKey(const Key('safety_share_trip')), findsOneWidget);
    });

    testWidgets('a successful SOS shows a reference, not a bare reassurance',
        (tester) async {
      await pump(
        tester,
        SosService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'data': {'sos_id': 12}}),
              201,
            ),
          ),
        ),
      );

      await _raiseAndSettle(tester, const Key('sos_panic'));

      expect(find.byKey(const Key('sos_success')), findsOneWidget);
      expect(find.textContaining('#12'), findsOneWidget);
    });

    testWidgets('a failed SOS shows the failure AND a 112 button',
        (tester) async {
      // The whole point. The old screen showed "Emergency Alert Sent!" here.
      await pump(
        tester,
        SosService(client: MockClient((_) async => http.Response('no', 503))),
      );

      await _raiseAndSettle(tester, const Key('sos_panic'));

      expect(find.byKey(const Key('sos_failure')), findsOneWidget);
      expect(find.byKey(const Key('sos_failure_call_112')), findsOneWidget);
      expect(find.byKey(const Key('sos_success')), findsNothing);
      expect(find.textContaining('on the way'), findsNothing);
    });
  });
}


/// Taps a category and waits for the request to produce its banner.
///
/// `runAsync` is required, not stylistic: the token read goes through the
/// SharedPreferences platform channel and `MockClient` completes on a real
/// Future, neither of which the fake-async test zone advances with `pump`
/// alone. And `pumpAndSettle` cannot be used at all here, because the sheet
/// shows a progress indicator whose animation never settles.
Future<void> _raiseAndSettle(WidgetTester tester, Key category) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(category));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

/// A stand-in for a transport failure. `MockClient` wants a thrown object and
/// the service catches broadly on purpose.
class SocketishError implements Exception {
  const SocketishError();
  @override
  String toString() => 'connection failed';
}
