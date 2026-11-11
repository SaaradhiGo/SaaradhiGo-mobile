/// Share (the trip link) and the masked Call (2026-11-09): the link goes to
/// the share sheet, a live link offers Stop sharing, refusals show the
/// server's sentence, and Call dials only the bridge number.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/services/sharing_service.dart';
import 'package:saaradhigo_rider/widgets/trip_actions.dart';

const _url = 'https://qa.saaradhigo.com/t/abc';

class _Share extends SharingService {
  _Share({this.active = false, this.refuse});
  bool active;
  SharingError? refuse;
  int stops = 0;

  @override
  Future<TripShareLink> tripShare(String tripId) async =>
      TripShareLink(active: active, url: active ? _url : null);

  @override
  Future<TripShareLink> startTripShare(String tripId) async {
    if (refuse != null) throw refuse!;
    active = true;
    return const TripShareLink(active: true, url: _url);
  }

  @override
  Future<TripShareLink> stopTripShare(String tripId) async {
    stops++;
    active = false;
    return const TripShareLink(active: false);
  }
}

class _Calls extends CallService {
  _Calls({this.refuse});
  final CallError? refuse;
  @override
  Future<({String number, String? sessionId})> start(String tripId) async {
    if (refuse != null) throw refuse!;
    return (number: '+914000000000', sessionId: 's1');
  }

  @override
  Future<void> end(String sessionId) async {}
}

void main() {
  Future<BuildContext> pump(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  testWidgets('Share starts the link and hands it to the share sheet', (
    tester,
  ) async {
    final ctx = await pump(tester);
    final shared = <String>[];
    await shareTripLink(
      ctx,
      '7',
      service: _Share(),
      share: (t) async {
        shared.add(t);
      },
    );
    expect(shared.single, contains(_url));
  });

  testWidgets('a live link offers Stop sharing', (tester) async {
    final ctx = await pump(tester);
    final s = _Share(active: true);
    final done = shareTripLink(ctx, '7', service: s, share: (_) async {});
    await tester.pumpAndSettle();
    expect(find.text('Stop sharing'), findsOneWidget);
    await tester.tap(find.byKey(const Key('share_stop')));
    await tester.pumpAndSettle();
    await done;
    expect(s.stops, 1);
    expect(find.text('Sharing stopped'), findsOneWidget);
  });

  testWidgets('before a driver is on the way, the server says so', (
    tester,
  ) async {
    final ctx = await pump(tester);
    await shareTripLink(
      ctx,
      '7',
      service: _Share(
        refuse: const SharingError(
          'TRIP_NOT_ACTIVE',
          status: 409,
          message: 'You can share a trip once a driver is on the way.',
        ),
      ),
      share: (_) async => fail('nothing to share'),
    );
    await tester.pump();
    expect(
      find.text('You can share a trip once a driver is on the way.'),
      findsOneWidget,
    );
  });

  testWidgets('Call dials the bridge number only', (tester) async {
    final ctx = await pump(tester);
    final dialled = <Uri>[];
    await callDriverMasked(
      ctx,
      '7',
      service: _Calls(),
      dial: (u) async {
        dialled.add(u);
        return true;
      },
    );
    expect(dialled.single.toString(), 'tel:+914000000000');
  });

  testWidgets('Call outside the trip shows the server sentence', (
    tester,
  ) async {
    final ctx = await pump(tester);
    await callDriverMasked(
      ctx,
      '7',
      service: _Calls(
        refuse: const CallError(
          'CALL_NOT_AVAILABLE',
          status: 409,
          message: 'Calling is available during the trip.',
        ),
      ),
      dial: (_) async => fail('must not dial'),
    );
    await tester.pump();
    expect(find.text('Calling is available during the trip.'), findsOneWidget);
  });
}
