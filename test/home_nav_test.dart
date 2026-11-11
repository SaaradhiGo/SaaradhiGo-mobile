// The map home: the menu reaches the other screens,
// back returns home, and no search results open on their own.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/providers/history_provider.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/providers/remote_config_provider.dart';
import 'package:saaradhigo_rider/screens/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_test_harness.dart';

Future<void> _pumpHome(WidgetTester tester) async {
  usePhoneSurface(tester);
  SharedPreferences.setMockInitialValues({});
  final auth = AuthProvider();
  await auth.initializationFuture;
  tester.view.padding = const FakeViewPadding(top: 40);
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    wrapWithRiderProviders(
      auth: auth,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ChangeNotifierProvider(create: (_) => WalletProvider()),
          ChangeNotifierProvider(create: (_) => RemoteConfigProvider()),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              GoRoute(
                path: '/help-support',
                builder: (_, _) => const Scaffold(body: Text('Help page')),
              ),
              GoRoute(
                path: '/notifications',
                builder: (_, _) => const Scaffold(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubStartupPluginChannels);
  _focusSurvivesOpening();

  const headline = 'Where to?';

  testWidgets('map home: menu, Where to?, the destination field; no tab '
      'bar; nothing opens by itself', (tester) async {
    await _pumpHome(tester);
    expect(find.byKey(const Key('home_menu')), findsOneWidget);
    expect(find.byKey(const Key('home-nav-home')), findsNothing);
    expect(find.text(headline), findsOneWidget);
    expect(find.text('Search a destination'), findsOneWidget);
    expect(find.text('Current Location'), findsNothing);
    // Never a mic: voice search does not exist.
    expect(find.byIcon(Icons.mic), findsNothing);
  });

  testWidgets('the menu reaches Account; Account reaches Trips; back '
      'returns home', (tester) async {
    await _pumpHome(tester);
    await tester.tap(find.byKey(const Key('home_menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('menu_profile')));
    await _settle(tester);
    expect(find.text(headline), findsNothing);
    expect(find.text('Your trips'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.byKey(const Key('account_trips')));
    await _settle(tester);
    expect(find.text('Sign out'), findsNothing);
    await tester.tap(find.byKey(const Key('page_back')));
    await _settle(tester);
    expect(find.text(headline), findsOneWidget);
  });

  testWidgets('Account opens from the menu and system back returns home', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.byKey(const Key('home_menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('menu_profile')));
    await _settle(tester);
    expect(find.text(headline), findsNothing);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text(headline), findsOneWidget);
  });

  testWidgets('tapping the destination field hides the headline and back '
      'brings it back', (tester) async {
    await _pumpHome(tester);
    await tester.tap(find.byType(TextField).last);
    await _settle(tester);
    expect(find.text(headline), findsNothing);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text(headline), findsOneWidget);
  });
}

// Seen on the emulator: opening the search rebuilt the field, so the keyboard
// closed and the typed text was lost.
void _focusSurvivesOpening() {
  testWidgets(
    'the destination field keeps focus and text when the sheet opens',
    (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byType(TextField).last);
      await _settle(tester);
      final field = find.byType(TextField).last;
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      await tester.enterText(field, 'Charminar');
      await _settle(tester);
      expect(find.text('Charminar'), findsWidgets);
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .focusNode!
            .hasFocus,
        isTrue,
      );
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
