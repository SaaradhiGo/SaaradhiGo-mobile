/// The rider login screen's Mobile | Email tabs.
///
/// Two properties matter more than the layout:
///
///   1. **Mobile stays the default.** It is what a pilot rider has, it needs
///      no password, and it is the only route that can create an account. A
///      change that quietly made Email the landing tab would strand every
///      rider who has never set a password.
///   2. **The refusal is generic.** The server answers every credential
///      failure with one message by design; the screen must not add a more
///      specific one of its own on top.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/screens/auth/login_screen.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthApiClient implements AuthApiClient {
  String? emailLoginEmail;
  String? emailLoginPassword;
  String? emailLoginMfaCode;
  Map<String, dynamic>? emailLoginResponse;
  String? passwordResetEmail;
  bool passwordResetResult = true;
  String? requestedOtpPhone;

  @override
  Future<Map<String, dynamic>?> emailLogin({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    emailLoginEmail = email;
    emailLoginPassword = password;
    emailLoginMfaCode = mfaCode;
    return emailLoginResponse;
  }

  @override
  Future<bool> requestPasswordReset(String email) async {
    passwordResetEmail = email;
    return passwordResetResult;
  }

  @override
  Future<Map<String, dynamic>?> requestOtp(String phoneNumber, String role) async {
    requestedOtpPhone = phoneNumber;
    return {'status': 'success', 'data': {}};
  }

  @override
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String? deviceToken,
  ) async =>
      null;

  @override
  Future<bool> registerPushToken(String token) async {
    registeredPushTokens.add(token);
    return true;
  }

  /// Tokens the app asked the server to store after an FCM rotation.
  final List<String> registeredPushTokens = <String>[];

  @override
  Future<Map<String, dynamic>?> updateProfile({
    String? profilePicPath,
    String? fullName,
    String? email,
    String? gender,
    String? dob,
    String? emergencyContact,
    String? houseNo,
    String? street,
    String? city,
    String? zipCode,
  }) async =>
      null;

  @override
  Future<Map<String, dynamic>?> getProfile() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _FakeAuthApiClient api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _FakeAuthApiClient();
  });

  Future<void> pump(WidgetTester tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 3000);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    // A real GoRouter, because a successful sign-in calls context.go('/home')
    // and `GoRouter.of` throws without one -- which reads as a login failure
    // rather than as a missing test harness.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '/otp',
          builder: (_, _) => const Scaffold(body: Text('OTP')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(apiService: api),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Mobile is the default tab and the phone field is shown',
      (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('login_tab_mobile')), findsOneWidget);
    expect(find.byKey(const Key('login_tab_email')), findsOneWidget);
    // The email form is not built until the tab is chosen.
    expect(find.byKey(const Key('login_email_field')), findsNothing);
    expect(find.text('PHONE NUMBER'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('choosing Email shows the email and password fields',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_forgot_password')), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // And the phone field is gone, so there is no ambiguity about which
    // credential the button will use.
    expect(find.text('PHONE NUMBER'), findsNothing);
  });

  testWidgets('the password is obscured until the eye is tapped',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    TextField field() => tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('login_password_field')),
            matching: find.byType(TextField),
          ),
        );

    expect(field().obscureText, isTrue);

    await tester.tap(find.byKey(const Key('login_password_visibility')));
    await tester.pumpAndSettle();

    expect(field().obscureText, isFalse);
  });

  testWidgets('signing in sends the email and password to the API',
      (tester) async {
    api.emailLoginResponse = {
      'status': 'success',
      'data': {'token': 't', 'refresh_token': 'r', 'user': {}},
    };
    await pump(tester);
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login_email_field')), '  Rider@Example.test ');
    await tester.enterText(
        find.byKey(const Key('login_password_field')), 'Cadence-Harbour-74');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    // Trimmed before sending. The server lower-cases too, but sending
    // leading whitespace would make a mistyped address fail for a reason the
    // rider cannot see.
    expect(api.emailLoginEmail, 'Rider@Example.test');
    expect(api.emailLoginPassword, 'Cadence-Harbour-74');
    // No MFA code for a rider: the field is not even shown.
    expect(api.emailLoginMfaCode, isNull);
  });

  testWidgets('an operator is asked for a second factor only after the '
      'password is accepted', (tester) async {
    api.emailLoginResponse = {
      '_error': {'code': 'AUTH_MFA_REQUIRED', 'message': 'Enter the code.'},
    };
    await pump(tester);
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_mfa_field')), findsNothing);

    await tester.enterText(
        find.byKey(const Key('login_email_field')), 'ops@example.test');
    await tester.enterText(
        find.byKey(const Key('login_password_field')), 'Cadence-Harbour-74');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_mfa_field')), findsOneWidget);
  });

  testWidgets('a credential failure shows one generic message',
      (tester) async {
    api.emailLoginResponse = {
      '_error': {'code': 'AUTH_INVALID_CREDENTIALS',
                 'message': 'Invalid email or password.'},
    };
    await pump(tester);
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login_email_field')), 'nobody@example.test');
    await tester.enterText(
        find.byKey(const Key('login_password_field')), 'whatever');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    // The screen must not help an attacker by saying which part was wrong.
    expect(find.textContaining('No account'), findsNothing);
    expect(find.textContaining('not found'), findsNothing);
  });

  testWidgets('forgot password with no address asks for one', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_forgot_password')));
    await tester.pump();

    expect(find.textContaining('Enter your email address first'),
        findsOneWidget);
    // Nothing was sent, so this cannot be used to probe addresses by
    // leaving the field blank.
    expect(api.passwordResetEmail, isNull);
  });

  testWidgets('forgot password says the same thing whatever the server found',
      (tester) async {
    // Its own test rather than a second tap in the one above: SnackBars
    // queue, so the second message is not on screen until the first has
    // timed out, and asserting on it immediately fails for the wrong reason.
    await pump(tester);
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login_email_field')), 'rider@example.test');
    await tester.tap(find.byKey(const Key('login_forgot_password')));
    await tester.pump();

    expect(api.passwordResetEmail, 'rider@example.test');
    expect(find.textContaining('If that address belongs to an account'),
        findsOneWidget);
  });

  testWidgets('switching back to Mobile restores the OTP flow',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login_tab_mobile')));
    await tester.pumpAndSettle();

    expect(find.text('PHONE NUMBER'), findsOneWidget);
    expect(find.byKey(const Key('login_email_field')), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });
}
