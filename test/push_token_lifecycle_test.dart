/// The rider's device token: obtained, sent, rotated.
///
/// TWO DEFECTS THIS COVERS
/// -----------------------
/// 1. **`'dummy_token'` at login.** `otp_verification_screen.dart` declared
///    `String deviceToken = 'dummy_token';` and only overwrote it when FCM
///    produced something. Every login from a device without push -- no Play
///    Services, permission declined, no network at launch -- therefore sent
///    that literal, and the backend stored it. The row then held a token that
///    could never receive anything, while dispatch's filter
///    (`if getattr(r.user_id, 'fcm_token', None)`) counted the rider as
///    push-capable and queued a message for them.
///
///    Omitting the key is strictly better: `servers/auth_user/views.py` only
///    writes `fcm_token` when the key is present, so an absent key preserves
///    whatever good token the server already had.
///
/// 2. **Rotations were never registered.** `PushNotificationService` listened
///    to `onTokenRefresh` and only `debugPrint`ed the new value. FCM replaces
///    a token on reinstall, on device restore and after a long idle period,
///    so the server kept a dead token until the rider's next login and every
///    push in between went nowhere, silently.
///
/// These drive the real `ApiService`, so they assert the bytes that would go
/// over the wire rather than a re-description of them.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/core/app_config.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:saaradhigo_rider/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <http.Request>[];

  setUp(() async {
    captured.clear();
    SharedPreferences.setMockInitialValues({});
    TokenStore.resetSessionRevocationCacheForTests();
  });

  ApiService serviceReturning(Map<String, dynamic> body, {int status = 200}) {
    final client = MockClient((request) async {
      captured.add(request);
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
    });
    return ApiService(client: client);
  }

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  const loginSuccess = {
    'status': 'success',
    'data': {'token': 'access-aaa', 'refresh_token': 'refresh-bbb'},
  };

  group('login sends a real token, or omits the key', () {
    test('a real token is sent as device_token', () async {
      final api = serviceReturning(loginSuccess);

      await api.verifyOtpAndLogin('+919999000001', '100001', 'real-fcm-token');

      expect(bodyOf(captured.single)['device_token'], 'real-fcm-token');
    });

    test('null OMITS the key entirely', () async {
      // Not null-valued, not a placeholder: absent. That is what preserves a
      // previously good token server-side.
      final api = serviceReturning(loginSuccess);

      await api.verifyOtpAndLogin('+919999000001', '100001', null);

      expect(bodyOf(captured.single).containsKey('device_token'), isFalse);
      expect(
        bodyOf(captured.single).keys,
        containsAll(['phone_number', 'otp']),
      );
    });

    test('an empty string omits the key too', () async {
      final api = serviceReturning(loginSuccess);

      await api.verifyOtpAndLogin('+919999000001', '100001', '');

      expect(bodyOf(captured.single).containsKey('device_token'), isFalse);
    });

    test('no login ever sends the old placeholder', () async {
      final api = serviceReturning(loginSuccess);

      await api.verifyOtpAndLogin('+919999000001', '100001', null);

      expect(captured.single.body, isNot(contains('dummy_token')));
    });

    test('the session is still stored when the key is omitted', () async {
      // The whole point: omitting push registration must not cost the login.
      final api = serviceReturning(loginSuccess);

      final result = await api.verifyOtpAndLogin(
        '+919999000001',
        '100001',
        null,
      );

      expect(result, isNotNull);
      expect(await TokenStore.readAccessToken(), 'access-aaa');
      expect(await TokenStore.readRefreshToken(), 'refresh-bbb');
    });
  });

  group('registering a rotated token', () {
    test('it is PATCHed to /auth/update/ as fcm_token', () async {
      final api = serviceReturning({'status': 'success', 'data': {}});
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );

      final ok = await api.registerPushToken('rotated-token-ccc');

      expect(ok, isTrue);
      final request = captured.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, endsWith(AppConfig.authUpdate));
      expect(bodyOf(request), {'fcm_token': 'rotated-token-ccc'});
    });

    test(
      'it is sent with the bearer token, or the server would refuse it',
      () async {
        final api = serviceReturning({'status': 'success', 'data': {}});
        await TokenStore.writeTokens(
          accessToken: 'access-aaa',
          refreshToken: 'refresh-bbb',
        );

        await api.registerPushToken('rotated-token-ccc');

        expect(captured.single.headers['Authorization'], 'Bearer access-aaa');
      },
    );

    test('an empty token is not sent at all', () async {
      final api = serviceReturning({'status': 'success', 'data': {}});

      expect(await api.registerPushToken(''), isFalse);
      expect(captured, isEmpty);
    });

    test('a server failure is reported, not thrown', () async {
      // It costs push until the next login, which also sends the current
      // token. It must never surface to a rider who did not ask for
      // anything.
      final api = serviceReturning({'status': 'error'}, status: 500);
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );

      expect(await api.registerPushToken('rotated-token-ccc'), isFalse);
    });

    test('a network failure is reported, not thrown', () async {
      final api = ApiService(
        client: MockClient((_) async {
          throw http.ClientException('no network');
        }),
      );
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );

      expect(await api.registerPushToken('rotated-token-ccc'), isFalse);
    });

    test('the token never appears in a log line', () async {
      // A device token is a credential: anyone holding one can push to that
      // device. Asserted by capturing print output.
      final api = serviceReturning({'status': 'success', 'data': {}});
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );

      final printed = <String>[];
      await runZonedPrint(printed, () => api.registerPushToken('secret-tok'));

      expect(printed.join('\n'), isNot(contains('secret-tok')));
    });
  });

  group('logout ends the session on the server too', () {
    test('it blacklists the refresh token before clearing locally', () async {
      // clearSession() used to be TokenStore.clear() alone, so a rider's
      // logout was local only: the refresh token kept minting access tokens
      // for its full 14-day life, and POST /auth/logout/ -- which is what
      // clears fcm_token server-side -- was never called.
      final api = serviceReturning({
        'status': 'success',
        'data': {'message': 'Logged out'},
      });
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );

      await api.clearSession();

      final logout = captured.singleWhere(
        (r) => r.url.path.endsWith(AppConfig.authLogout),
      );
      expect(logout.method, 'POST');
      expect(bodyOf(logout)['refresh_token'], 'refresh-bbb');
      expect(
        logout.headers['Authorization'],
        'Bearer access-aaa',
        reason:
            'the endpoint is authenticated, so it must be called while '
            'the access token is still valid',
      );
    });

    test('the local session is cleared afterwards', () async {
      final api = serviceReturning({'status': 'success', 'data': {}});
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );

      await api.clearSession();

      expect(await TokenStore.readAccessToken(), isNull);
      expect(await TokenStore.readRefreshToken(), isNull);
    });

    test('a rider with no signal can still log out', () async {
      // The local clear is what the UI depends on; the server call is best
      // effort and must not be able to strand someone signed in.
      final api = ApiService(
        client: MockClient((_) async {
          throw http.ClientException('no network');
        }),
      );
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );

      await expectLater(api.clearSession(), completes);
      expect(await TokenStore.readAccessToken(), isNull);
    });

    test('a server refusal does not strand the session either', () async {
      final api = serviceReturning({'status': 'error'}, status: 503);
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );

      await api.clearSession();

      expect(await TokenStore.readAccessToken(), isNull);
    });

    test('with no refresh token it clears locally and calls nothing', () async {
      final api = serviceReturning({'status': 'success', 'data': {}});

      await api.clearSession();

      expect(
        captured.where((r) => r.url.path.endsWith(AppConfig.authLogout)),
        isEmpty,
      );
      expect(await TokenStore.readAccessToken(), isNull);
    });
  });

  group('no placeholder token survives anywhere in the app', () {
    test('lib/ contains no device-token placeholder', () {
      // A structural guard, because the defect was not one bad call site --
      // it was a default value that looked harmless. Both apps had one.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        for (final entry in text.split('\n').asMap().entries) {
          final line = entry.value;
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (line.contains("'dummy_token'") ||
              line.contains("'dummy_device_token'") ||
              line.contains('"dummy_token"')) {
            offenders.add('\${entity.path}:\${entry.key + 1}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'a placeholder device token overwrites a real one '
            'server-side and makes dispatch treat this rider as '
            'push-capable: \$offenders',
      );
    });
  });

  group('a revoked session cannot register a token', () {
    test('after logout the PATCH carries no bearer token', () async {
      // TokenStore gates reads behind the revocation tombstone, so a token
      // rotation arriving after a logout cannot authenticate as the rider
      // who just left.
      final api = serviceReturning({'status': 'success', 'data': {}});
      await TokenStore.writeTokens(
        accessToken: 'access-aaa',
        refreshToken: 'refresh-bbb',
      );
      await TokenStore.clear();

      await api.registerPushToken('rotated-after-logout');

      if (captured.isNotEmpty) {
        expect(
          captured.single.headers.containsKey('Authorization'),
          isFalse,
          reason: 'a logged-out session must not present a bearer token',
        );
      }
    });
  });
}

/// Runs [body] capturing anything printed through the Dart print hook.
Future<void> runZonedPrint(
  List<String> sink,
  Future<void> Function() body,
) async {
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => sink.add(line),
    ),
  );
}
