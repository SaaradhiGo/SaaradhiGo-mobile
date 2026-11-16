// The summary after a trip ends: the fare and how it was paid, the driver and
// car, "View receipt" (the same PDF the web opens), the rating, and Done.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/screens/home/rider_flow_screens.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';

void main() {
  late List<Uri> requested;
  late List<Uri> opened;

  setUp(() {
    requested = [];
    opened = [];
  });

  Widget host({int receiptStatus = 200}) {
    final client = MockClient((r) async {
      requested.add(r.url);
      return http.Response(
        jsonEncode({'pdf_url': 'https://files.example/receipt-77.pdf'}),
        receiptStatus,
        headers: {'content-type': 'application/json'},
      );
    });
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => RateReviewDriverScreen(
            tripId: '77',
            driverName: 'Ravi Kumar',
            vehicleLine: 'White Maruti Suzuki Dzire · TS09AB1234',
            fareText: '₹132.00',
            method: 'cash',
            detail: 'Inorbit Mall · 9:41 pm',
            rideService: RideService(client: client),
            accessToken: () async => 'tok',
            openUrl: (u) async {
              opened.add(u);
              return true;
            },
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME SCREEN')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('shows fare, how it was paid, driver and car', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('₹132.00'), findsOneWidget);
    expect(find.text('PAID BY CASH'), findsOneWidget);
    expect(find.byKey(const Key('summary_driver_name')), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(
      find.text('White Maruti Suzuki Dzire · TS09AB1234'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('view_receipt')), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('HOME SCREEN'), findsNothing);
  });

  testWidgets('View receipt opens the PDF the server names', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('view_receipt')));
    await t.pumpAndSettle();
    expect(requested.single.path, endsWith('/ride/trip/77/receipt/pdf/'));
    expect(opened.single.toString(), 'https://files.example/receipt-77.pdf');
  });

  testWidgets('a receipt that is not ready says so, opens nothing', (t) async {
    await t.pumpWidget(host(receiptStatus: 404));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('view_receipt')));
    await t.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('The receipt is not ready yet.'), findsOneWidget);
  });

  testWidgets('Done goes home', (t) async {
    t.view.physicalSize = const Size(1200, 3600);
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.text('HOME SCREEN'), findsOneWidget);
  });
}
