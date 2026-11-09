/// Saved places (GET/POST/PATCH/DELETE /rider/places/, 2026-11-09): the
/// service reads the contract, Account > Saved places ends loaded, empty or
/// error with Try again, and the place sheet saves or shows the refusal.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:saaradhigo_rider/screens/profile/place_sheet.dart';
import 'package:saaradhigo_rider/screens/profile/saved_places_screen.dart';
import 'package:saaradhigo_rider/services/favorite_location_service.dart';
import 'package:saaradhigo_rider/services/models/location_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _place(
  int id,
  String label, {
  String name = '',
  bool inside = true,
}) => {
  'id': id,
  'label': label,
  'name': name,
  'address_text': 'Mindspace, Hitech City',
  'latitude': '17.441000',
  'longitude': '78.381000',
  'in_service_area': inside,
  'notice': inside ? null : 'Outside our service area for now',
};

class _FakeService extends FavoriteLocationService {
  _FakeService({this.list, this.fail = false, this.hang = false});
  SavedPlaces? list;
  bool fail;
  bool hang;
  final created = <Map<String, Object?>>[];
  final deleted = <int>[];
  PlaceError? refuse;

  @override
  Future<SavedPlaces?> fetchPlaces() async {
    if (hang) return Completer<SavedPlaces?>().future;
    if (fail) throw const PlaceError('HTTP_500', status: 500);
    return list;
  }

  @override
  Future<FavoriteLocation> createPlace({
    required String label,
    required String addressText,
    required double latitude,
    required double longitude,
    String name = '',
  }) async {
    if (refuse != null) throw refuse!;
    created.add({'label': label, 'name': name, 'address': addressText});
    return FavoriteLocation.fromJson(_place(99, label, name: name));
  }

  @override
  Future<void> deletePlace(int id) async {
    deleted.add(id);
    list = SavedPlaces(
      places: list!.places.where((p) => p.id != id).toList(),
      limits: list!.limits,
    );
  }
}

class _NoSearch implements PlaceSearch {
  @override
  Future<String?> addressAt(LatLng at) async => null;
  @override
  Future<PlaceDetails?> details(String placeId) async => null;
  @override
  Future<List<PlaceSuggestion>> suggest(String query, {LatLng? near}) async =>
      const [];
}

SavedPlaces _places(List<Map<String, Object?>> raw) => SavedPlaces(
  places: [for (final p in raw) FavoriteLocation.fromJson(p)],
  limits: const {'home': 1, 'work': 1, 'other': 10},
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'a'});
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'a',
      'refresh_token': 'r',
    });
  });

  group('FavoriteLocationService', () {
    test('reads places, limits and the notice', () async {
      final r = await http.runWithClient(
        () => FavoriteLocationService().fetchPlaces(),
        () => MockClient(
          (req) async => http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'places': [
                  _place(1, 'home'),
                  _place(2, 'other', name: 'Gym', inside: false),
                ],
                'limits': {'home': 1, 'work': 1, 'other': 10},
              },
            }),
            200,
          ),
        ),
      );
      expect(r!.byLabel('home')!.id, 1);
      expect(r.others.single.name, 'Gym');
      expect(r.others.single.inServiceArea, isFalse);
      expect(r.others.single.notice, 'Outside our service area for now');
      expect(r.limits['other'], 10);
    });

    test('a 409 becomes PLACE_LIMIT with its field', () async {
      final call = http.runWithClient(
        () => FavoriteLocationService().createPlace(
          label: 'home',
          addressText: 'X',
          latitude: 17.4,
          longitude: 78.4,
        ),
        () => MockClient(
          (req) async => http.Response(
            jsonEncode({
              'status': 'error',
              'error': {
                'code': 'PLACE_LIMIT',
                'message': 'You already have a Home. Edit it instead.',
                'details': {'field': 'label', 'issue': 'limit reached'},
              },
            }),
            409,
          ),
        ),
      );
      await expectLater(
        call,
        throwsA(
          isA<PlaceError>()
              .having((e) => e.code, 'code', 'PLACE_LIMIT')
              .having((e) => e.field, 'field', 'label'),
        ),
      );
    });

    test('a server without /rider/places/ gives null (fallback)', () async {
      final r = await http.runWithClient(
        () => FavoriteLocationService().fetchPlaces(),
        () => MockClient((req) async => http.Response('{}', 404)),
      );
      expect(r, isNull);
    });
  });

  Future<void> pump(WidgetTester tester, _FakeService s) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SavedPlacesScreen(service: s, search: _NoSearch()),
      ),
    );
    await tester.pump();
  }

  testWidgets('loaded: Home, Set work, an other with its notice', (
    tester,
  ) async {
    final s = _FakeService(
      list: _places([
        _place(1, 'home'),
        _place(2, 'other', name: 'Gym', inside: false),
      ]),
    );
    await pump(tester, s);
    expect(find.byKey(const Key('places_home')), findsOneWidget);
    expect(find.byKey(const Key('places_set_work')), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.byKey(const Key('place_notice_2')), findsOneWidget);
    expect(find.text('Outside our service area for now'), findsOneWidget);
  });

  testWidgets('empty: the message, Set home and Set work', (tester) async {
    await pump(tester, _FakeService(list: _places([])));
    expect(find.byKey(const Key('places_empty')), findsOneWidget);
    expect(find.text('Set home'), findsOneWidget);
    expect(find.text('Set work'), findsOneWidget);
    expect(find.byKey(const Key('places_add')), findsOneWidget);
  });

  testWidgets('error, then Try again loads', (tester) async {
    final s = _FakeService(list: _places([_place(1, 'home')]), fail: true);
    await pump(tester, s);
    expect(find.byKey(const Key('places_error')), findsOneWidget);
    s.fail = false;
    await tester.tap(find.byKey(const Key('places_retry')));
    await tester.pump();
    expect(find.byKey(const Key('places_home')), findsOneWidget);
  });

  testWidgets('a load that never answers ends in the error at 10 s', (
    tester,
  ) async {
    await pump(tester, _FakeService(hang: true));
    expect(find.byKey(const Key('places_loading')), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(const Key('places_error')), findsOneWidget);
  });

  testWidgets('delete asks first, then removes', (tester) async {
    final s = _FakeService(
      list: _places([_place(1, 'home'), _place(2, 'other', name: 'Gym')]),
    );
    await pump(tester, s);
    await tester.tap(find.byKey(const Key('place_delete_2')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this place?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('place_delete_confirm')));
    await tester.pumpAndSettle();
    expect(s.deleted, [2]);
    expect(find.text('Gym'), findsNothing);
  });

  Future<void> pumpSheet(WidgetTester tester, _FakeService s) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceSheet(
            service: s,
            search: _NoSearch(),
            address: 'Inorbit Mall, Madhapur',
            at: const LatLng(17.43, 78.38),
            name: 'Inorbit Mall',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sheet: Other needs a name; Save posts it', (tester) async {
    final s = _FakeService(list: _places([]));
    await pumpSheet(tester, s);
    await tester.enterText(find.byKey(const Key('place_name')), '');
    await tester.pump();
    final save = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('place_save')),
        matching: find.byType(InkWell),
      ),
    );
    expect(save.onTap, isNull);
    await tester.enterText(find.byKey(const Key('place_name')), 'Mall');
    await tester.pump();
    await tester.tap(find.byKey(const Key('place_save')));
    await tester.pump();
    expect(s.created.single, {
      'label': 'other',
      'name': 'Mall',
      'address': 'Inorbit Mall, Madhapur',
    });
  });

  testWidgets('sheet: a second Home shows the limit line', (tester) async {
    final s = _FakeService(list: _places([]))
      ..refuse = const PlaceError('PLACE_LIMIT', status: 409, field: 'label');
    await pumpSheet(tester, s);
    await tester.tap(find.byKey(const Key('place_label_home')));
    await tester.pump();
    expect(find.byKey(const Key('place_name')), findsNothing);
    await tester.tap(find.byKey(const Key('place_save')));
    await tester.pump();
    expect(
      find.text('You already have a Home. Edit it instead.'),
      findsOneWidget,
    );
  });
}
