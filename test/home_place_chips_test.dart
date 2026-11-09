// Home's saved-place chips (2026-11-09 smoke): "Add a place" is there even
// when the places did not load; after Try again loads them, Home and
// "Set work" appear; and the chips stay while the search is open.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/providers/history_provider.dart';
import 'package:saaradhigo_rider/providers/map_provider.dart';
import 'package:saaradhigo_rider/providers/remote_config_provider.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/screens/home/home_screen.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:saaradhigo_rider/services/favorite_location_service.dart';
import 'package:saaradhigo_rider/services/models/location_model.dart';
import 'package:saaradhigo_rider/services/models/trip_model.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_test_harness.dart';

class _Places extends FavoriteLocationService {
  bool fail = true;
  @override
  Future<List<FavoriteLocation>> fetchFavoriteLocations() async {
    if (fail) throw const PlaceError('HTTP_504', status: 504);
    return [
      FavoriteLocation(
        id: 1,
        addressText: 'Mindspace, Hitech City',
        latitude: 17.44,
        longitude: 78.38,
        label: 'home',
      ),
    ];
  }
}

class _Rides extends RideService {
  @override
  Future<List<Trip>> loadRideHistory({ApiService? api}) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubStartupPluginChannels);

  testWidgets('chips after a failed load, after Try again, and while '
      'searching', (tester) async {
    usePhoneSurface(tester);
    SharedPreferences.setMockInitialValues({'access_token': 'a'});
    final auth = AuthProvider();
    await auth.initializationFuture;
    final places = _Places();
    final map = MapProvider(
      favoriteLocationService: places,
      rideService: _Rides(),
    );
    await tester.pumpWidget(
      wrapWithRiderProviders(
        auth: auth,
        map: map,
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
                  path: '/notifications',
                  builder: (_, _) => const Scaffold(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Places failed: no Home or Set home (it might exist), but Add a place.
    expect(map.savedPlacesLoaded, isFalse);
    expect(find.text('Add a place'), findsOneWidget);
    expect(find.text('Set home'), findsNothing);

    // Try again refetches the places.
    places.fail = false;
    await map.fetchDynamicHomeData();
    await tester.pump();
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Set work'), findsOneWidget);
    expect(find.text('Add a place'), findsOneWidget);

    // Opening the search keeps the chips.
    await tester.tap(find.byType(TextField).last);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('home_place_chips')), findsOneWidget);
    expect(find.text('Set work'), findsOneWidget);
  });
}
