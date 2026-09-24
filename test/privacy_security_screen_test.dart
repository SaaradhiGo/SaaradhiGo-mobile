import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/screens/profile/privacy_security_screen.dart';
import 'package:saaradhigo_rider/services/api_service.dart';

import 'support/screen_test_harness.dart';

class _FakeAuthApiClient implements AuthApiClient {
  @override
  Future<void> clearSession() async {}

  @override
  Future<Map<String, dynamic>?> requestOtp(String phoneNumber, String role) async => {'status': 'success'};

  @override
  Future<Map<String, dynamic>?> getProfile() async => null;

  @override
  Future<Map<String, dynamic>?> updateProfile({
    required String fullName,
    required String email,
    required String gender,
    required String dob,
    required String emergencyContact,
    required String houseNo,
    String? profilePicPath,
    required String street,
    required String city,
    required String zipCode,
  }) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String deviceToken,
  ) async {
    return null;
  }
}

GoRouter _buildRouter({String initialLocation = '/privacy-security'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/privacy-security',
        builder: (context, state) => const PrivacySecurityScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'] ?? 'none';
          return Scaffold(body: Center(child: Text('Home Tab $tab')));
        },
      ),
    ],
  );
}

Future<AuthProvider> _buildProvider(Map<String, Object> prefsData) async {
  SharedPreferences.setMockInitialValues(prefsData);
  final provider = AuthProvider(apiService: _FakeAuthApiClient());
  await provider.initializationFuture;
  return provider;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  AuthProvider provider, {
  String initialLocation = '/privacy-security',
}) async {
  await tester.pumpWidget(
    wrapWithRiderProviders(
      auth: provider,
      child: MaterialApp.router(
        routerConfig: _buildRouter(initialLocation: initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubStartupPluginChannels);

  group('PrivacySecurityScreen redesign', () {
    testWidgets('renders sections, rows, toggles, and bottom nav', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final provider = await _buildProvider({});
      await _pumpScreen(tester, provider);

      expect(find.text('Privacy & Security'), findsOneWidget);
      expect(find.text('ACCOUNT SECURITY'), findsOneWidget);
      expect(find.text('DATA PRIVACY'), findsOneWidget);
      expect(find.text('Two-Factor Authentication'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Location Permissions'), findsOneWidget);
      expect(find.text('Marketing Preferences'), findsOneWidget);
      expect(find.text('Manage My Data'), findsOneWidget);

      expect(find.byKey(const Key('privacy-back')), findsOneWidget);
      expect(find.byKey(const Key('privacy-nav-home')), findsOneWidget);
      expect(find.byKey(const Key('privacy-nav-history')), findsOneWidget);
      expect(find.byKey(const Key('privacy-nav-wallet')), findsOneWidget);
      expect(find.byKey(const Key('privacy-nav-profile')), findsOneWidget);

      final twoFactorSwitch = tester.widget<Switch>(find.descendant(
        of: find.byKey(const Key('privacy-toggle-two-factor')),
        matching: find.byType(Switch),
      ));
      final marketingSwitch = tester.widget<Switch>(find.descendant(
        of: find.byKey(const Key('privacy-toggle-marketing')),
        matching: find.byType(Switch),
      ));
      expect(twoFactorSwitch.value, isTrue);
      expect(marketingSwitch.value, isFalse);
    });

    testWidgets('back button routes to /home?tab=3 when no back stack', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final provider = await _buildProvider({});
      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('privacy-back')));
      await tester.pumpAndSettle();

      expect(find.text('Home Tab 3'), findsOneWidget);
    });

    testWidgets('row taps show temporary snackbar feedback', (tester) async {
      usePhoneSurface(tester);
      final provider = await _buildProvider({});
      await _pumpScreen(tester, provider);

      await tester.tap(find.byKey(const Key('privacy-row-change-password')));
      await tester.pump();
      expect(
        find.text('Change Password will be available soon.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('privacy-row-location-permissions')),
      );
      await tester.pump();
      expect(
        find.text('Location Permissions will be available soon.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('privacy-row-manage-data')));
      await tester.pump();
      expect(
        find.text('Manage My Data will be available soon.'),
        findsOneWidget,
      );
    });

    testWidgets('bottom nav routes to /home?tab=0..3', (tester) async {
      usePhoneSurface(tester);
      final targets = <String, int>{
        'privacy-nav-home': 0,
        'privacy-nav-history': 1,
        'privacy-nav-wallet': 2,
        'privacy-nav-profile': 3,
      };

      for (final entry in targets.entries) {
        final provider = await _buildProvider({});
        await _pumpScreen(tester, provider);

        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();

        expect(find.text('Home Tab ${entry.value}'), findsOneWidget);
      }
    });

    testWidgets('toggle updates persist across provider rebuild', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final provider = await _buildProvider({});
      await _pumpScreen(tester, provider);

      // Scrolled into view before tapping. On a phone-sized surface these rows
      // are below the fold, so tap() computed a centre outside the viewport and
      // silently missed -- "the widget is actually off-screen, or another widget
      // is obscuring it". The toggle never changed, and the failure looked like a
      // persistence bug.
      Future<void> toggle(String key) async {
        // Tap the Switch, not the row that carries the key. The key identifies
        // _PrivacyToggleRow, whose centre is in its title text -- getCenter()
        // resolved to a point the Switch does not occupy, so the tap missed with
        // "the widget is actually off-screen, or another widget is obscuring it"
        // and the toggle never changed. The failure then looked like a
        // persistence bug rather than a mis-aimed tap.
        final row = find.byKey(Key(key));
        final control = find.descendant(of: row, matching: find.byType(Switch));
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        await tester.tap(control);
        await tester.pumpAndSettle();
      }

      await toggle('privacy-toggle-two-factor');
      await toggle('privacy-toggle-marketing');

      expect(provider.twoFactorEnabled, isFalse);
      expect(provider.marketingOptIn, isTrue);

      final rehydratedProvider = AuthProvider(apiService: _FakeAuthApiClient());
      await rehydratedProvider.initializationFuture;
      await _pumpScreen(tester, rehydratedProvider);

      final twoFactorSwitch = tester.widget<Switch>(find.descendant(
        of: find.byKey(const Key('privacy-toggle-two-factor')),
        matching: find.byType(Switch),
      ));
      final marketingSwitch = tester.widget<Switch>(find.descendant(
        of: find.byKey(const Key('privacy-toggle-marketing')),
        matching: find.byType(Switch),
      ));
      expect(twoFactorSwitch.value, isFalse);
      expect(marketingSwitch.value, isTrue);
    });
  });
}
