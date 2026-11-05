// Home without a tab bar: the menu and the profile button reach the other
// screens, back returns home, and no search results open on their own.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/providers/history_provider.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/providers/remote_config_provider.dart';
import 'package:saaradhigo_rider/screens/home/home_screen.dart';
import 'package:saaradhigo_rider/ui/home_sheet.dart';
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

  testWidgets('no tab bar, and no pickup suggestions open by themselves', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.byKey(const Key('home-nav-home')), findsNothing);
    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Current Location'), findsNothing);
  });

  testWidgets(
    'the menu reaches History, Wallet, Profile and Help; back returns home',
    (tester) async {
      await _pumpHome(tester);
      for (final label in ['Your rides', 'Wallet', 'Profile']) {
        await tester.tap(find.bySemanticsLabel('Menu'));
        await _settle(tester);
        expect(find.text(label), findsOneWidget);
        await tester.tap(find.text(label));
        await _settle(tester);
        expect(find.text('Where to?'), findsNothing);
        await tester.tap(find.byTooltip('Back'));
        await _settle(tester);
        expect(find.text('Where to?'), findsOneWidget);
      }
      await tester.tap(find.bySemanticsLabel('Menu'));
      await _settle(tester);
      expect(find.text('Help and support'), findsOneWidget);
    },
  );

  testWidgets('the profile button opens Profile and system back returns home', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.bySemanticsLabel('Account'));
    await _settle(tester);
    expect(find.text('Where to?'), findsNothing);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Where to?'), findsOneWidget);
  });

  testWidgets(
    'tapping the destination field expands the sheet and back closes it',
    (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byType(TextField).last);
      await _settle(tester);
      expect(find.text('Where to?'), findsNothing);
      final top = tester.getTopLeft(find.byType(HomeSheet)).dy;
      expect(top, greaterThanOrEqualTo(40));
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Where to?'), findsOneWidget);
    },
  );
}

// Seen on the emulator: opening the search rebuilt the field, so the keyboard
// closed and the typed text was lost.
void _focusSurvivesOpening() {
  testWidgets('the destination field keeps focus and text when the sheet opens', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.byType(TextField).last);
    await _settle(tester);
    final field = find.byType(TextField).last;
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    await tester.enterText(field, 'Charminar');
    await _settle(tester);
    expect(find.text('Charminar'), findsWidgets);
    expect(tester.widget<TextField>(find.byType(TextField).last).focusNode!.hasFocus, isTrue);
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
