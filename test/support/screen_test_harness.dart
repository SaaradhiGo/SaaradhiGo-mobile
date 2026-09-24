/// Shared harness for widget tests that pump real rider screens.
///
/// The profile-tab, personal-information and privacy-and-security suites were
/// quarantined with the reason "assert against a redesign whose widget tree
/// differs from what ships. Needs a device to confirm the real layout." That was
/// a guess made when no Flutter toolchain was available to run them, and it was
/// wrong on both counts: they are widget tests and need no device, and the
/// layouts they assert against are the ones that ship.
///
/// What they actually hit was ProviderNotFoundException. HomeScreen's initState
/// reads MapProvider and NotificationProvider in a post-frame callback, and each
/// suite registered only AuthProvider -- so the tree threw before rendering, and
/// the "Found 0 widgets with text ..." failures were the consequence, not the
/// cause.
///
/// Everything a rider screen touches at startup goes through here so the next
/// screen suite does not rediscover this.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/providers/map_provider.dart';
import 'package:saaradhigo_rider/providers/notification_provider.dart';
import 'package:saaradhigo_rider/services/notification_service.dart';

/// A NotificationService that answers instantly and never touches the network.
///
/// HomeScreen fetches notifications on its first frame. Left to the real
/// service, every screen test would depend on an HTTP failure being swallowed at
/// the right moment.
class FakeNotificationService implements NotificationService {
  @override
  Future<Map<String, dynamic>> fetchNotifications(
    String token, {
    int page = 1,
    int pageSize = 20,
  }) async => {
    'status': 'success',
    'data': {'results': <dynamic>[], 'next': null, 'unread_count': 0},
  };

  @override
  Future<bool> markAsRead(String token, int notificationId) async => true;

  @override
  Future<bool> markAllAsRead(String token) async => true;
}

/// Silences the plugin channels a rider screen reaches for at startup.
///
/// Geolocator and friends have no platform implementation under flutter_test, so
/// they raise MissingPluginException. HomeScreen catches it, but the noise buries
/// the failure that matters and a future uncaught one would be invisible.
void stubStartupPluginChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(String channel, Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (call) async => handler(call),
    );
  }

  answer('flutter.baseflow.com/geolocator', (call) {
    switch (call.method) {
      case 'isLocationServiceEnabled':
        return true;
      case 'checkPermission':
      case 'requestPermission':
        // LocationPermission.whileInUse. Index 1 is deniedForever, whose snackbar
        // is rendered over the bottom navigation bar and swallowed every tap on
        // it -- the tab never changed and the tap looked like it had missed.
        // (Worth noting for the product: on a real handset that snackbar blocks
        // the nav for its full duration.)
        return 2;
      case 'getCurrentPosition':
      case 'getLastKnownPosition':
        return <String, dynamic>{
          'latitude': 17.4450,
          'longitude': 78.3800,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'accuracy': 5.0,
          'altitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
        };
    }
    return null;
  });

  // Deliberately NOT stubbed: SharedPreferences.setMockInitialValues() owns
  // that channel. Stubbing it here returned an empty store and silently
  // discarded every suite's seeded profile values.
}

/// Gives the test a phone-shaped viewport.
///
/// flutter_test defaults to 800x600 at devicePixelRatio 3, which is neither a
/// phone nor tall enough for these screens: the content overflowed and pushed
/// the bottom navigation bar outside the viewport, so taps on it silently missed
/// and the tab never changed. Sized to a common Indian mid-range handset.
void usePhoneSurface(WidgetTester tester) {
  // setSurfaceSize, not view.physicalSize: setting physicalSize alone left
  // layout and hit-testing in different coordinate spaces, so tap() computed a
  // centre inside the viewport and still missed ("would not hit test on the
  // specified widget"). setSurfaceSize resizes both consistently.
  tester.view.devicePixelRatio = 1.0;
  tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
}

/// Wraps [child] in every provider a rider screen expects to find.
Widget wrapWithRiderProviders({
  required Widget child,
  required AuthProvider auth,
  MapProvider? map,
  NotificationProvider? notifications,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<MapProvider>.value(value: map ?? MapProvider()),
      ChangeNotifierProvider<NotificationProvider>.value(
        value: notifications ??
            NotificationProvider(
              notificationService: FakeNotificationService(),
            ),
      ),
    ],
    child: child,
  );
}
