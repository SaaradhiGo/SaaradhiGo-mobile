/// "No notifications" and "we could not load your notifications" are
/// different sentences, and the rider used to be told the first one for both.
///
/// THE DEFECT
/// ----------
/// `NotificationService.fetchNotifications` returned
/// `{notifications: [], hasNext: false}` for **every** non-200 response, and
/// `NotificationProvider` had no error state, and
/// `notification_screen.dart` rendered "No notifications yet" whenever the
/// list was empty. So a 401, a 500, a dropped connection and a malformed row
/// all produced the same screen as a genuinely empty inbox.
///
/// An expired access token produced it reliably: tokens live 15 minutes,
/// nothing on this path refreshed them, so a rider who opened notifications a
/// quarter of an hour into a session was told they had none.
///
/// The provider also did `final List<NotificationModel> x = result[...]`,
/// an implicit downcast that throws on an unexpected shape -- caught, logged,
/// and shown as an empty inbox.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/providers/notification_provider.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:saaradhigo_rider/services/notification_service.dart';
import 'package:saaradhigo_rider/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TokenStore.resetSessionRevocationCacheForTests();
    await TokenStore.writeTokens(
      accessToken: 'access-aaa',
      refreshToken: 'refresh-bbb',
    );
  });

  /// A notification row shaped like the server's.
  Map<String, dynamic> row(int id, {bool isRead = false}) => {
    'id': id,
    'title': 'Your driver is arriving',
    'body': 'Toyota Etios, KA01AB1234',
    'is_read': isRead,
    'created_at': '2026-10-17T09:00:00Z',
  };

  NotificationProvider providerFor(
    List<http.Response> responses, {
    http.Client? authClient,
  }) {
    var call = 0;
    final client = MockClient((request) async {
      final response = responses[call.clamp(0, responses.length - 1)];
      call++;
      return response;
    });
    return NotificationProvider(
      notificationService: NotificationService(client: client),
      apiService: ApiService(client: authClient ?? client),
    );
  }

  http.Response ok(List<Map<String, dynamic>> rows, {bool hasNext = false}) =>
      http.Response(
        jsonEncode({
          'status': 'success',
          'data': {'results': rows, 'next': hasNext ? 'page=2' : null},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );

  group('a successful fetch', () {
    test('loads the rows and reports no error', () async {
      final provider = providerFor([
        ok([row(1), row(2)]),
      ]);

      await provider.fetchNotifications();

      expect(provider.notifications, hasLength(2));
      expect(provider.error, isNull);
      expect(provider.isEmpty, isFalse);
    });

    test('an genuinely empty inbox is empty, not an error', () async {
      final provider = providerFor([ok(const [])]);

      await provider.fetchNotifications();

      expect(provider.notifications, isEmpty);
      expect(provider.error, isNull);
      expect(
        provider.isEmpty,
        isTrue,
        reason: 'this is the only case that should say "no notifications"',
      );
    });
  });

  group('a failure is reported as a failure', () {
    test('a 500 sets an error rather than an empty inbox', () async {
      final provider = providerFor([
        http.Response(
          '{"status":"error"}',
          500,
          headers: {'content-type': 'application/json'},
        ),
      ]);

      await provider.fetchNotifications();

      expect(provider.notifications, isEmpty);
      expect(provider.error, isNotNull);
      expect(provider.error, contains('500'));
      expect(
        provider.isEmpty,
        isFalse,
        reason: 'the screen must not say "no notifications" for a failure',
      );
    });

    test(
      'an unreachable server says so, and mentions the connection',
      () async {
        final provider = NotificationProvider(
          notificationService: NotificationService(
            client: MockClient(
              (_) async => throw http.ClientException('offline'),
            ),
          ),
          apiService: ApiService(
            client: MockClient(
              (_) async => throw http.ClientException('offline'),
            ),
          ),
        );

        await provider.fetchNotifications();

        expect(provider.error, contains('connection'));
      },
    );

    test('a malformed row is skipped instead of emptying the list', () async {
      // One bad notification used to throw inside the whole-list map and
      // take every good one with it.
      final provider = providerFor([
        http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'results': [row(1), 'not-an-object', row(2)],
              'next': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ]);

      await provider.fetchNotifications();

      expect(
        provider.notifications,
        hasLength(2),
        reason: 'the two valid rows must survive the invalid one',
      );
      expect(provider.error, isNull);
    });
  });

  group('an expired access token is refreshed, not reported as empty', () {
    test('a 401 refreshes once and retries', () async {
      // The common case, every 15 minutes.
      var notificationCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path.contains('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {'token': 'access-new', 'refresh_token': 'refresh-new'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        notificationCalls++;
        if (notificationCalls == 1) {
          return http.Response(
            '{"status":"error"}',
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return ok([row(1)]);
      });

      final provider = NotificationProvider(
        notificationService: NotificationService(client: client),
        apiService: ApiService(client: client),
      );

      await provider.fetchNotifications();

      expect(notificationCalls, 2, reason: 'it should retry after refreshing');
      expect(provider.notifications, hasLength(1));
      expect(provider.error, isNull);
      expect(await TokenStore.readAccessToken(), 'access-new');
    });

    test(
      'a 401 that survives the refresh is an error, not an empty inbox',
      () async {
        final client = MockClient((request) async {
          if (request.url.path.contains('/auth/refresh')) {
            return http.Response(
              '{"status":"error"}',
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{"status":"error"}',
            401,
            headers: {'content-type': 'application/json'},
          );
        });

        final provider = NotificationProvider(
          notificationService: NotificationService(client: client),
          apiService: ApiService(client: client),
        );

        await provider.fetchNotifications();

        expect(provider.error, isNotNull);
        expect(provider.isEmpty, isFalse);
      },
    );
  });

  group('a logged-out session fetches nothing', () {
    test('no token means no request and no error', () async {
      // Reading the token through TokenStore respects the revocation
      // tombstone; this used to read SharedPreferences directly.
      await TokenStore.clear();
      var calls = 0;
      final provider = NotificationProvider(
        notificationService: NotificationService(
          client: MockClient((_) async {
            calls++;
            return ok(const []);
          }),
        ),
        apiService: ApiService(client: MockClient((_) async => ok(const []))),
      );

      await provider.fetchNotifications();

      expect(calls, 0, reason: 'a logged-out session must not call the API');
      expect(
        provider.error,
        isNull,
        reason: 'being logged out is not an error to show here',
      );
    });
  });
}
