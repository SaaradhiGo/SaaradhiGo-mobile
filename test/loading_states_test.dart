/// Every signed-in data view ends as loaded, empty (zeros), error with Try
/// again, or a clean sign-out to Log in: never a spinner that waits forever.
///
/// Requests go through the real ApiService 401/refresh path into a
/// MockClient, so an expired token here takes the same road as on a phone.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/navigation/session_end.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/providers/history_provider.dart';
import 'package:saaradhigo_rider/providers/map_provider.dart';
import 'package:saaradhigo_rider/providers/notification_provider.dart';
import 'package:saaradhigo_rider/providers/remote_config_provider.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/screens/auth/login_screen.dart';
import 'package:saaradhigo_rider/screens/home/history_screen.dart';
import 'package:saaradhigo_rider/screens/home/wallet_screen.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/services/token_store.dart';
import 'package:saaradhigo_rider/services/wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_test_harness.dart';

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _ok(Object data) => {'status': 'success', 'data': data};

/// A brand-new rider: a zero balance and nothing to list.
Future<http.Response> _newAccount(http.Request r) async {
  final path = r.url.path;
  if (path.endsWith('/rider/wallet/balance/')) {
    return _json(200, _ok({'balance': '0.00', 'currency': 'INR'}));
  }
  if (path.endsWith('/rider/wallet/transactions/') ||
      path.endsWith('/ride/ride-history/')) {
    return _json(200, _ok({'results': <Object>[]}));
  }
  return _json(404, {'status': 'error'});
}

void _expectNoPlaceholders() {
  for (final p in ['–', '—', '…', '•••', '...']) {
    expect(find.text(p), findsNothing, reason: 'placeholder "$p" on screen');
  }
}

class _NoAuthApi implements AuthApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  late Future<http.Response> Function(http.Request) handler;
  late MockClient client;
  late ApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'expired-access',
      'refresh_token': 'used-refresh',
    });
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'expired-access',
      'refresh_token': 'used-refresh',
    });
    handler = _newAccount;
    client = MockClient((r) => handler(r));
    api = ApiService(client: client);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    WalletProvider? wallet,
    HistoryProvider? history,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(
            value:
                wallet ??
                WalletProvider(
                  walletService: WalletService(client: client, api: api),
                ),
          ),
          ChangeNotifierProvider<HistoryProvider>.value(
            value:
                history ??
                HistoryProvider(
                  rideService: RideService(client: client),
                  api: api,
                ),
          ),
          ChangeNotifierProvider<MapProvider>(create: (_) => MapProvider()),
          ChangeNotifierProvider<NotificationProvider>.value(
            value: NotificationProvider(
              notificationService: FakeNotificationService(),
            ),
          ),
          ChangeNotifierProvider<RemoteConfigProvider>.value(
            value: RemoteConfigProvider(),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: screen)),
      ),
    );
    await settle(tester);
  }

  testWidgets('new account: wallet ₹0.00 and the empty message', (
    tester,
  ) async {
    await pumpScreen(tester, const WalletScreen());

    expect(
      tester.widget<Text>(find.byKey(const Key('wallet_balance'))).data,
      '₹0.00',
    );
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.byKey(const Key('wallet_balance_loading')), findsNothing);
    _expectNoPlaceholders();
  });

  testWidgets('new account: trips show "No rides yet", not an error', (
    tester,
  ) async {
    await pumpScreen(tester, const HistoryScreen());

    expect(find.text('No rides yet'), findsOneWidget);
    expect(find.text("We couldn't load your trips."), findsNothing);
    _expectNoPlaceholders();
  });

  testWidgets('expired token: refresh refused with 400 routes to Log in', (
    tester,
  ) async {
    handler = (r) async => r.url.path.endsWith('/auth/refresh/')
        ? _json(400, {
            'status': 'error',
            'error': {'code': 'INVALID_TOKEN', 'message': 'Token is invalid'},
          })
        : _json(401, {'detail': 'Token is expired'});

    final wallet = WalletProvider(
      walletService: WalletService(client: client, api: api),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: WalletScreen()),
        ),
        GoRoute(
          path: '/login',
          builder: (_, state) => LoginScreen(
            sessionExpired: state.uri.queryParameters['expired'] == '1',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final sub = goToLoginOnSessionEnd(router);
    addTearDown(sub.cancel);

    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(apiService: _NoAuthApi()),
          ),
          ChangeNotifierProvider<WalletProvider>.value(value: wallet),
          ChangeNotifierProvider<NotificationProvider>.value(
            value: NotificationProvider(
              notificationService: FakeNotificationService(),
            ),
          ),
          ChangeNotifierProvider<RemoteConfigProvider>.value(
            value: RemoteConfigProvider(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Your session has expired. Please log in again.'),
      findsOneWidget,
    );
    expect(await tester.runAsync(TokenStore.readAccessToken), isNull);
    expect(wallet.isLoading, isFalse);
  });

  testWidgets('API failure: wallet error shows and Try again recovers', (
    tester,
  ) async {
    handler = (r) async => _json(500, {'status': 'error'});
    await pumpScreen(tester, const WalletScreen());

    expect(find.text("We couldn't load your wallet."), findsOneWidget);
    expect(find.text("We couldn't load your transactions."), findsOneWidget);
    _expectNoPlaceholders();

    handler = _newAccount;
    await tester.tap(find.byKey(const Key('wallet_balance_retry')));
    await settle(tester);
    expect(find.text("We couldn't load your wallet."), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('wallet_balance'))).data,
      '₹0.00',
    );
  });

  testWidgets('API timeout: trips error after 10 s, Try again recovers', (
    tester,
  ) async {
    final never = Completer<http.Response>();
    handler = (r) => never.future;
    await pumpScreen(tester, const HistoryScreen());

    await tester.pump(const Duration(seconds: 10));
    await settle(tester);
    expect(find.text("We couldn't load your trips."), findsOneWidget);

    handler = _newAccount;
    await tester.tap(find.byKey(const Key('history_retry')));
    await settle(tester);
    expect(find.text('No rides yet'), findsOneWidget);
  });
}
