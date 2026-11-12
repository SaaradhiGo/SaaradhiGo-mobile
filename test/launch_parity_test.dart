/// Launch parity with the web: the operator in About, the policy links, the
/// receipt by entity, trip-state cancel reasons and the "not live yet" card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/core/legal/legal_entity.dart';
import 'package:saaradhigo_rider/core/legal/policy_links.dart';
import 'package:saaradhigo_rider/core/market/booking_refusal.dart';
import 'package:saaradhigo_rider/providers/remote_config_provider.dart';
import 'package:saaradhigo_rider/screens/components/market_overlays.dart';
import 'package:saaradhigo_rider/screens/profile/about_screen.dart';
import 'package:saaradhigo_rider/services/models/trip_invoice.dart';
import 'package:saaradhigo_rider/ui/cancel_reasons.dart';
import 'package:saaradhigo_rider/widgets/invoice_card.dart';

class _Config extends RemoteConfigProvider {
  _Config(this.entity);
  final LegalEntity entity;
  @override
  LegalEntity legalFor(String countryCode) => entity;
}

Widget _host(Widget child, {RemoteConfigProvider? config}) => MaterialApp(
  home: config == null
      ? child
      : ChangeNotifierProvider<RemoteConfigProvider>.value(
          value: config,
          child: child,
        ),
);

void main() {
  group('legal entity', () {
    test('falls back to the name for the market only', () {
      final in_ = LegalEntity.fallback('IN');
      expect(in_.legalName, 'DeepTrics Software Solutions Pvt Ltd');
      expect(in_.registeredAddress, isEmpty);
      expect(LegalEntity.fallback('US').legalName, 'DeepTrics LLC');
    });

    test('parses what the server sent and nothing else', () {
      final m = parseLegal({
        'IN': {
          'legal_name': 'DeepTrics Software Solutions Pvt Ltd',
          'gst_registered': false,
          'cin': 'U12345TG2025PTC000000',
        },
        'US': {'legal_name': 'DeepTrics LLC', 'gst_registered': false},
        'XX': 'junk',
      });
      expect(m['IN']!.cin, 'U12345TG2025PTC000000');
      expect(m['IN']!.registeredAddress, isEmpty);
      expect(m.containsKey('XX'), isFalse);
      expect(parseLegal(null), isEmpty);
    });

    test('copyright line', () {
      expect(
        LegalEntity.fallback('US').copyright(2026),
        '© 2026 SaaradhiGo. Operated by DeepTrics LLC.',
      );
    });
  });

  group('policy links', () {
    test('grievance is India only', () {
      expect(policyLinksFor('IN').any((l) => l.path == '/grievance'), isTrue);
      expect(policyLinksFor('US').any((l) => l.path == '/grievance'), isFalse);
    });

    test('hosts', () {
      final terms = kRiderPolicyLinks.firstWhere((l) => l.path == '/terms');
      expect(
        terms.uri(kProductionSite).toString(),
        'https://www.saaradhigo.com/terms',
      );
      expect(
        terms.uri(kQaSite).toString(),
        'https://www.qa.saaradhigo.com/terms',
      );
    });
  });

  group('About', () {
    testWidgets('shows the name only when the config has nothing more', (
      t,
    ) async {
      await t.pumpWidget(
        _host(AboutScreen(year: 2026, versionLoader: () async => '1.0 (1)')),
      );
      await t.pump();
      expect(
        find.text(
          '© 2026 SaaradhiGo. Operated by DeepTrics Software Solutions Pvt Ltd.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('CIN'), findsNothing);
      expect(find.byKey(const Key('about_link_privacy')), findsOneWidget);
      expect(
        find.byKey(const Key('about_link_grievance'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('adds address, CIN, phone and email when present', (t) async {
      final cfg = _Config(
        const LegalEntity(
          legalName: 'DeepTrics Software Solutions Pvt Ltd',
          registeredAddress: '1 Test Road, Hyderabad',
          cin: 'U1',
          supportPhone: '+91 40 0000 0000',
          supportEmail: 'help@example.test',
        ),
      );
      await t.pumpWidget(
        _host(
          AboutScreen(year: 2026, versionLoader: () async => null),
          config: cfg,
        ),
      );
      await t.pump();
      expect(find.text('1 Test Road, Hyderabad'), findsOneWidget);
      expect(find.text('CIN U1'), findsOneWidget);
      expect(find.text('+91 40 0000 0000'), findsOneWidget);
      expect(find.text('help@example.test'), findsOneWidget);
    });
  });

  group('invoice', () {
    Map<String, dynamic> trip({required bool taxShown, String? title}) => {
      'invoice': {
        if (title != null) 'title': title,
        'currency': 'INR',
        'company': {
          'name': 'DeepTrics Software Solutions Pvt Ltd',
          'address': '',
          'gstin': '',
          'cin': '',
        },
        'breakdown': {
          'tax_shown': taxShown,
          'lines': [
            {'label': 'Base fare', 'amount': '60.00'},
          ],
          'taxable': '60.00',
          'tax': {
            'label': 'GST',
            'percent': '5',
            'amount': '3.00',
            'included': true,
          },
          'extras': [],
          'total': '60.00',
        },
      },
    };

    testWidgets('no tax lines while tax is not shown; titled Receipt', (
      t,
    ) async {
      final inv = TripInvoice.fromTrip(
        trip(taxShown: false, title: 'Receipt'),
      )!;
      await t.pumpWidget(_host(Scaffold(body: InvoiceCard(invoice: inv))));
      expect(find.text('Receipt'), findsOneWidget);
      expect(find.text('Taxable value'), findsNothing);
      expect(find.textContaining('GST'), findsNothing);
      expect(find.text('DeepTrics Software Solutions Pvt Ltd'), findsOneWidget);
    });

    testWidgets('tax lines and Tax invoice when shown', (t) async {
      final inv = TripInvoice.fromTrip(
        trip(taxShown: true, title: 'Tax invoice'),
      )!;
      await t.pumpWidget(_host(Scaffold(body: InvoiceCard(invoice: inv))));
      expect(find.text('Tax invoice'), findsOneWidget);
      expect(find.text('Taxable value'), findsOneWidget);
      expect(find.text('GST 5% (included)'), findsOneWidget);
    });

    test('an older server without the fields reads as a Receipt, no tax', () {
      final inv = TripInvoice.fromTrip({
        'invoice': {
          'company': {'name': 'X'},
          'breakdown': {},
        },
      })!;
      expect(inv.title, 'Receipt');
      expect(inv.taxShown, isFalse);
      expect(TripInvoice.fromTrip({}), isNull);
    });
  });

  group('cancel reasons follow the trip state', () {
    test('before a driver: no driver-only reasons', () {
      final v = cancelReasonsFor(driverAssigned: false).map((r) => r.value);
      expect(v, ['changed_plans', 'booked_by_mistake', 'too_long', 'other']);
    });

    test('with a driver: adds no_show, wrong_location, safety', () {
      final v = cancelReasonsFor(driverAssigned: true).map((r) => r.value);
      expect(
        v,
        containsAll(['no_show', 'wrong_location', 'safety', 'changed_plans']),
      );
    });
  });

  group('city not live', () {
    test('the launching notice offers to be told; other refusals do not', () {
      final s = BookingRefusalState();
      s.reportLaunching(
        "We're not in Hyderabad yet.",
        pickup: const LatLng(1, 2),
      );
      expect(s.latest!.canAskToBeTold, isTrue);
      s.reportMessage(kCashNotAvailable, 'x');
      expect(s.latest!.canAskToBeTold, isFalse);
    });

    testWidgets('the card asks the server with the pickup', (t) async {
      LatLng? sent;
      await t.pumpWidget(
        _host(
          Scaffold(
            body: BookingRefusalCard(
              refusal: const BookingRefusal(
                kCityNotLive,
                'Not live yet',
                pickup: LatLng(17.4, 78.4),
              ),
              onNotifyMe: (p) async {
                sent = p;
                return true;
              },
            ),
          ),
        ),
      );
      expect(find.text('Not live yet'), findsOneWidget);
      await t.tap(find.byKey(const Key('launch_interest_button')));
      await t.pump();
      expect(sent, const LatLng(17.4, 78.4));
      expect(find.byKey(const Key('launch_interest_done')), findsOneWidget);
    });
  });
}
