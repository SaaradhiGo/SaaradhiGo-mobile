/// A rider can now actually report a problem.
///
/// THE DEFECT
/// ----------
/// `help_support_screen.dart` rendered tiles labelled "Ride Issues",
/// "Payment & Wallet", "Account & App", "Safety", "Live Chat" and "Email
/// Support". **None of them had a handler.** A rider with a problem could
/// reach a screen called Help & Support and do nothing from it -- the same
/// shape of defect as the decorative SOS button found earlier, and worse
/// than an absent feature, because the rider stops looking for another way
/// to get help.
///
/// `/support/tickets/create/` has been live and tested the whole time, and
/// the DRIVER app has used it since its support work. This is the rider side
/// of the same API.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/screens/profile/report_problem_screen.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:saaradhigo_rider/services/support_service.dart';
import 'package:saaradhigo_rider/services/token_store.dart';
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

  SupportService serviceReturning(Object body, {int status = 201}) {
    final client = MockClient((request) async {
      captured.add(request);
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
    });
    return SupportService(
      apiService: ApiService(client: client),
      client: client,
    );
  }

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  const createdTicket = {
    'status': 'success',
    'data': {
      'id': 4821,
      'issue_type': 'safety',
      'status': 'OPEN',
      'description': 'The driver took a detour and would not stop',
      'created_at': '2026-10-17T09:30:00Z',
    },
  };

  /// Tap Submit and let the real async work finish.
  ///
  /// `pumpAndSettle` cannot be used here: while the request is in flight the
  /// button shows a CircularProgressIndicator, which animates forever, so
  /// settling never happens. `runAsync` is needed because MockClient and
  /// SharedPreferences do real async work that the fake clock does not drive.
  Future<void> submitAndSettle(WidgetTester tester) async {
    // The tap itself goes inside runAsync: the submission walks TokenStore
    // (secure storage and SharedPreferences mocks) before it reaches the
    // MockClient, and none of those hops are driven by the fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Submit'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    await tester.pump();
  }

  group('creating a ticket', () {
    test('posts the issue type and description the server expects', () async {
      final service = serviceReturning(createdTicket);

      final result = await service.createTicket(
        issueType: SupportIssueType.safety,
        description: 'The driver took a detour and would not stop',
      );

      expect(result.isCreated, isTrue);
      expect(result.ticket?.id, 4821);

      final request = captured.single;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/support/tickets/create/'));
      expect(bodyOf(request), {
        'issue_type': 'safety',
        'description': 'The driver took a detour and would not stop',
      });
    });

    test('the issue types are the server own choices, not invented ones', () {
      // A value outside servers/support/models.py::ISSUE_CHOICES is rejected
      // by model validation, so these strings are a contract.
      const serverChoices = {
        'payment',
        'fare_dispute',
        'driver_behaviour',
        'lost_item',
        'safety',
        'account',
        'app_bug',
        'other',
      };

      for (final type in SupportIssueType.values) {
        expect(
          serverChoices,
          contains(type.wireValue),
          reason:
              '${type.name} sends "${type.wireValue}", which the '
              'server does not accept',
        );
      }
    });

    test('a trip id is attached when the rider is reporting a ride', () async {
      final service = serviceReturning(createdTicket);

      await service.createTicket(
        issueType: SupportIssueType.fareDispute,
        description: 'I was charged more than the quote',
        tripId: '991',
      );

      expect(bodyOf(captured.single)['trip_id'], '991');
    });

    test('the key is omitted when there is no trip', () async {
      final service = serviceReturning(createdTicket);

      await service.createTicket(
        issueType: SupportIssueType.other,
        description: 'The app will not open the map',
      );

      expect(bodyOf(captured.single).containsKey('trip_id'), isFalse);
    });

    test('an empty description is refused without a round trip', () async {
      final service = serviceReturning(createdTicket);

      final result = await service.createTicket(
        issueType: SupportIssueType.other,
        description: '   ',
      );

      expect(result.isCreated, isFalse);
      expect(result.error, contains('describe'));
      expect(captured, isEmpty, reason: 'nothing to send, so send nothing');
    });

    test("a server refusal is reported in the server's own words", () async {
      final service = serviceReturning({
        'status': 'error',
        'error': {
          'code': 'MISSING_FIELDS',
          'message': 'description is required',
        },
      }, status: 400);

      final result = await service.createTicket(
        issueType: SupportIssueType.other,
        description: 'something',
      );

      expect(result.isCreated, isFalse);
      expect(result.error, 'description is required');
    });

    test(
      'an unreachable server says so, and mentions the connection',
      () async {
        final client = MockClient(
          (_) async => throw http.ClientException('off'),
        );
        final service = SupportService(
          apiService: ApiService(client: client),
          client: client,
        );

        final result = await service.createTicket(
          issueType: SupportIssueType.other,
          description: 'something went wrong',
        );

        expect(result.isCreated, isFalse);
        expect(result.error, contains('connection'));
      },
    );

    test(
      'a created ticket with an unreadable body still counts as created',
      () async {
        // Telling the rider it failed would make them submit it twice, and
        // support would have two tickets for one problem.
        final service = serviceReturning({'unexpected': true}, status: 201);

        final result = await service.createTicket(
          issueType: SupportIssueType.other,
          description: 'something went wrong',
        );

        expect(result.isCreated, isTrue);
        expect(result.ticket, isNull);
      },
    );
  });

  group('listing tickets', () {
    test('parses the wrapped, paginated shape', () async {
      final service = serviceReturning({
        'status': 'success',
        'data': {
          'count': 2,
          'next': null,
          'results': [
            (createdTicket['data'] as Map),
            {'id': 4822, 'issue_type': 'payment', 'status': 'CLOSED'},
          ],
        },
      }, status: 200);

      final tickets = await service.listTickets();

      expect(tickets, hasLength(2));
      expect(tickets!.first.id, 4821);
      expect(tickets.first.isOpen, isTrue);
      expect(tickets.last.isOpen, isFalse);
    });

    test('a malformed ticket is skipped, not fatal', () async {
      final service = serviceReturning({
        'status': 'success',
        'data': {
          'results': [
            {'issue_type': 'payment'}, // no id
            (createdTicket['data'] as Map),
          ],
        },
      }, status: 200);

      final tickets = await service.listTickets();

      expect(tickets, hasLength(1));
      expect(tickets!.single.id, 4821);
    });

    test(
      'a failure returns null, so the UI can tell it from "no tickets"',
      () async {
        final service = serviceReturning({'status': 'error'}, status: 500);

        expect(await service.listTickets(), isNull);
      },
    );
  });

  group('the report screen', () {
    testWidgets('submits what the rider typed and shows the reference', (
      tester,
    ) async {
      final service = serviceReturning(createdTicket);

      await tester.pumpWidget(
        MaterialApp(
          home: ReportProblemScreen(
            initialIssueType: SupportIssueType.safety,
            supportService: service,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'The driver took a detour and would not stop',
      );
      await submitAndSettle(tester);

      expect(
        find.textContaining('#4821'),
        findsOneWidget,
        reason: 'a reference is what makes this more than a reassurance',
      );
      expect(bodyOf(captured.single)['issue_type'], 'safety');
    });

    testWidgets('refuses an empty description before calling the server', (
      tester,
    ) async {
      final service = serviceReturning(createdTicket);

      await tester.pumpWidget(
        MaterialApp(home: ReportProblemScreen(supportService: service)),
      );

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Please describe the problem.'), findsOneWidget);
      expect(captured, isEmpty);
    });

    testWidgets('asks for more than one word', (tester) async {
      final service = serviceReturning(createdTicket);

      await tester.pumpWidget(
        MaterialApp(home: ReportProblemScreen(supportService: service)),
      );

      await tester.enterText(find.byType(TextFormField), 'broken');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sentence or two'), findsOneWidget);
      expect(captured, isEmpty);
    });

    testWidgets('a failure keeps what the rider typed', (tester) async {
      // Making someone retype a complaint is how a complaint stops being
      // made.
      final service = serviceReturning({
        'status': 'error',
        'error': {'message': 'Support is temporarily unavailable'},
      }, status: 503);

      await tester.pumpWidget(
        MaterialApp(home: ReportProblemScreen(supportService: service)),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'The driver would not stop the car',
      );
      await submitAndSettle(tester);

      expect(find.text('Support is temporarily unavailable'), findsOneWidget);
      expect(
        find.text('The driver would not stop the car'),
        findsOneWidget,
        reason: 'the description must survive a failed submission',
      );
    });

    testWidgets('shows a trip attachment when one was passed', (tester) async {
      final service = serviceReturning(createdTicket);

      await tester.pumpWidget(
        MaterialApp(
          home: ReportProblemScreen(supportService: service, tripId: '991'),
        ),
      );

      expect(find.textContaining('#991'), findsOneWidget);
    });
  });
}
