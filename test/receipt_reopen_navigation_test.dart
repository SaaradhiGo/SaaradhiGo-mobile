// Round 3 (emulator, trip 231): a US trip charged at drop while the rider app
// was closed. Reopened, the app recovered the trip and then went Home: the
// navigation decision treats a completed trip as "no active trip". It now
// opens the receipt and tip.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/navigation/ride_navigation_handler.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';

class _NoRideService implements RideService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a paid trip recovered at launch opens the receipt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'access_token': 't'});
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/ride-summary',
          builder: (_, _) => const Text('receipt'),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [rideServiceProvider.overrideWithValue(_NoRideService())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RideNavigationHandler(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    expect(find.text('home'), findsOneWidget);

    await tester.runAsync(
      () => container
          .read(rideNotifierProvider.notifier)
          .syncStateFromActiveTripResponse({
            'status': 'success',
            'data': {
              'id': 231,
              'status': 'completed',
              'payment_status': 'completed',
              'payment_method': 'card',
              'card_held': true,
              'currency': 'USD',
              'final_fare': '29.45',
              'is_active': false,
              'recovery': 'recently_completed',
            },
          }),
    );
    await tester.pumpAndSettle();
    expect(find.text('receipt'), findsOneWidget);
  });
}
