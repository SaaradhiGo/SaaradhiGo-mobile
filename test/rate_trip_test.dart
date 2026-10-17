/// A completed trip can now be rated.
///
/// THE GAP
/// -------
/// `/ride/rate-trip/` has been live the whole time: riders rate drivers,
/// drivers rate riders, one rating per user per trip, and the server
/// recomputes the rated user's average. **Neither app had any way to submit
/// one.** The driver profile shows a `ratings` figure and the rider is shown
/// `driver_rating`, so both apps displayed an average that nothing could
/// ever change -- every driver sat at the default for ever.
///
/// For a pilot whose point is to measure driver quality, that was the
/// measurement missing.
///
/// These tests mirror the server's own refusals, which are specific and must
/// not be replaced with a generic message:
///   TRIP_NOT_COMPLETED (400), FORBIDDEN (403), ALREADY_RATED (409),
///   INVALID_SCORE (400).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:saaradhigo_rider/services/rating_service.dart';
import 'package:saaradhigo_rider/services/token_store.dart';
import 'package:saaradhigo_rider/widgets/rate_trip_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <http.Request>[];

  setUp(() async {
    captured.clear();
    SharedPreferences.setMockInitialValues({});
    TokenStore.resetSessionRevocationCacheForTests();
    await TokenStore.writeTokens(
      accessToken: 'access-aaa',
      refreshToken: 'refresh-bbb',
    );
  });

  RatingService serviceReturning(Object body, {int status = 201}) {
    final client = MockClient((request) async {
      captured.add(request);
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
    });
    return RatingService(
      apiService: ApiService(client: client),
      client: client,
    );
  }

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  const created = {
    'status': 'success',
    'data': {'rating_id': 77, 'trip_id': 991, 'score': 5, 'comments': ''},
  };

  Object refusal(String code, String message) => {
    'status': 'error',
    'error': {'code': code, 'message': message},
  };

  group('submitting a rating', () {
    test('posts the trip and score the server expects', () async {
      final service = serviceReturning(created);

      final result = await service.rateTrip(tripId: '991', score: 5);

      expect(result.isSubmitted, isTrue);
      expect(result.ratingId, 77);
      final request = captured.single;
      expect(request.url.path, endsWith('/ride/rate-trip/'));
      expect(bodyOf(request), {'trip_id': '991', 'score': 5});
    });

    test('an optional comment is included only when there is one', () async {
      final service = serviceReturning(created);

      await service.rateTrip(tripId: '991', score: 4, comments: '  Great  ');
      expect(bodyOf(captured.single)['comments'], 'Great');

      captured.clear();
      await service.rateTrip(tripId: '991', score: 4, comments: '   ');
      expect(bodyOf(captured.single).containsKey('comments'), isFalse);
    });

    test('a score outside 1-5 is refused without a round trip', () async {
      final service = serviceReturning(created);

      for (final score in [0, 6, -1, 99]) {
        final result = await service.rateTrip(tripId: '991', score: score);
        expect(
          result.isSubmitted,
          isFalse,
          reason: '$score is not a rating the server accepts',
        );
      }
      expect(captured, isEmpty);
    });
  });

  group("the server's refusals keep their meaning", () {
    test('ALREADY_RATED is settled, not an error to nag about', () async {
      // The rating exists, which is what the rider wanted. Treating a 409 as
      // a failure teaches them the prompt is broken.
      final service = serviceReturning(
        refusal('ALREADY_RATED', 'You have already rated this trip'),
        status: 409,
      );

      final result = await service.rateTrip(tripId: '991', score: 5);

      expect(result.outcome, RatingOutcome.alreadyRated);
      expect(result.isSettled, isTrue);
      expect(result.isSubmitted, isFalse);
    });

    test('TRIP_NOT_COMPLETED is reported in the server own words', () async {
      final service = serviceReturning(
        refusal('TRIP_NOT_COMPLETED', 'You can only rate a completed trip'),
        status: 400,
      );

      final result = await service.rateTrip(tripId: '991', score: 5);

      expect(result.outcome, RatingOutcome.notEligible);
      expect(result.message, 'You can only rate a completed trip');
      expect(result.isSettled, isFalse);
    });

    test('FORBIDDEN is not eligible, not a transport failure', () async {
      final service = serviceReturning(
        refusal('FORBIDDEN', 'You were not on this trip'),
        status: 403,
      );

      final result = await service.rateTrip(tripId: '991', score: 5);

      expect(result.outcome, RatingOutcome.notEligible);
    });

    test('an unreachable server says the rating was not saved', () async {
      final client = MockClient((_) async => throw http.ClientException('off'));
      final service = RatingService(
        apiService: ApiService(client: client),
        client: client,
      );

      final result = await service.rateTrip(tripId: '991', score: 5);

      expect(result.outcome, RatingOutcome.failed);
      expect(
        result.message,
        contains('not saved'),
        reason:
            'a rider must not believe a rating was recorded when it '
            'was not',
      );
    });

    test('an unexpected status is a failure with its code', () async {
      final service = serviceReturning({'status': 'error'}, status: 500);

      final result = await service.rateTrip(tripId: '991', score: 5);

      expect(result.outcome, RatingOutcome.failed);
      expect(result.message, contains('500'));
    });
  });

  group('the rating sheet', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      RatingService service, {
      String? driverName,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RateTripSheet(
              tripId: '991',
              driverName: driverName,
              service: service,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Submit rating'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
      await tester.pump();
    }

    testWidgets('five stars are offered, each separately labelled', (
      tester,
    ) async {
      // Five identical "star" buttons are unusable with a screen reader.
      await pumpSheet(tester, serviceReturning(created));

      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      expect(find.byTooltip('1 star'), findsOneWidget);
      expect(find.byTooltip('5 stars'), findsOneWidget);
    });

    testWidgets('it names the driver when the app knows it', (tester) async {
      await pumpSheet(
        tester,
        serviceReturning(created),
        driverName: 'Ramesh K',
      );

      expect(find.textContaining('Ramesh K'), findsOneWidget);
    });

    testWidgets('submitting with no stars asks for one, and sends nothing', (
      tester,
    ) async {
      await pumpSheet(tester, serviceReturning(created));

      await tester.tap(find.text('Submit rating'));
      await tester.pump();

      expect(find.textContaining('Tap a star'), findsOneWidget);
      expect(captured, isEmpty);
    });

    testWidgets('tapping a star then submitting sends that score', (
      tester,
    ) async {
      final service = serviceReturning(created);
      await pumpSheet(tester, service);

      await tester.tap(find.byTooltip('4 stars'));
      await tester.pump();
      await submit(tester);

      expect(bodyOf(captured.single)['score'], 4);
    });

    testWidgets('a failure is shown and the sheet stays open', (tester) async {
      final service = serviceReturning(
        refusal('TRIP_NOT_COMPLETED', 'You can only rate a completed trip'),
        status: 400,
      );
      await pumpSheet(tester, service);

      await tester.tap(find.byTooltip('5 stars'));
      await tester.pump();
      await submit(tester);

      expect(find.text('You can only rate a completed trip'), findsOneWidget);
      expect(
        find.text('Submit rating'),
        findsOneWidget,
        reason: 'the rider should be able to retry or dismiss',
      );
    });

    testWidgets('Not now dismisses without sending anything', (tester) async {
      // Skippable on purpose: a prompt a rider cannot dismiss is one they
      // learn to tap through without reading.
      await pumpSheet(tester, serviceReturning(created));

      await tester.tap(find.text('Not now'));
      await tester.pump();

      expect(captured, isEmpty);
    });
  });
}
