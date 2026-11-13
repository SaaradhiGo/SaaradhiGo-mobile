// ignore_for_file: unused_element, unused_element_parameter
//
// This file contains nine private widgets that are built but never rendered.
//
// The tenth was _FareBreakdown / _FareLine, the fare-transparency panel. It is
// no longer here: it moved to lib/widgets/fare_breakdown.dart, became public,
// and is now actually shown on the booking screen behind "How is this fare
// calculated?". The old note here said it was "not wired because it needs to be
// seen on a device, not guessed at" -- it turned out to need a Flutter toolchain,
// not a device.
//
//   _VehicleTile, _Card, _DarkCard, _PaymentTile, _MiniTile, _ContactTile,
//   _HelpSearchField, _HelpSectionLabel, _showCancelDialog
//     Presentation helpers from an in-progress refactor of this screen.
//
// Deleting them is a reasonable future change; doing it silently as part of a
// lint cleanup is not, which is why this comment exists instead.
import '../../ui/sg_layout.dart';
import '../../core/pricing/quote_lock.dart';
import '../../core/trip_eta.dart';
import '../../widgets/trip_actions.dart';
import '../../core/rider_flags.dart';
import '../../core/market/market_config_store.dart';
import '../components/market_overlays.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'trip_chat_screen.dart';

import '../../providers/map_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../core/maps/sg_map.dart';

import 'package:latlong2/latlong.dart';

import '../../services/ride_service.dart';
import '../../services/payment_service.dart';
import '../../services/wallet_service.dart' show WalletPayOutcome;
import '../../services/online_payment.dart';
import '../../services/trip_charge.dart';
import '../../widgets/trip_charge_card.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart' as p;

import '../../utils/money.dart';
import '../../widgets/safety_sheet.dart';
import '../../state/ride_notifier.dart';
import '../../state/ride_state.dart';
import '../../core/vehicle_classes.dart';
import '../../ui/appearance_settings.dart' show paymentMethodLabel, sgStrings;
import '../../ui/booking_widgets.dart';
import '../../ui/trip_t2_widgets.dart';
import '../../ui/choose_ride_sheet.dart';
import '../../ui/cancel_reasons.dart';
import '../../services/models/trip_invoice.dart';
import '../../widgets/invoice_card.dart';
import '../../ui/ride_rating_panel.dart';
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';
import '../../ui/trip_widgets.dart';

/// Cancel, and tell the rider when the server did not confirm it.
///
/// `cancelRideRequest` now returns false and KEEPS the ride on screen when
/// the server refuses or the request times out, because in that case the trip
/// really is still live and a driver really may still arrive. Every call site
/// used to ignore the result, which is how a failed cancellation became a
/// silent one.
Future<bool> _cancelRideAndReport(BuildContext context) async {
  final provider = context.read<MapProvider>();
  // Why, by trip state. Nothing booked yet (a local search) needs no reason.
  String? reason;
  if (provider.tripId != null) {
    reason = await showCancelReasonSheet(
      context,
      driverAssigned: !provider.isRequestingRide,
    );
    // Backed out: keep the ride, say nothing.
    if (reason == null) return false;
    if (!context.mounted) return false;
  }
  final confirmed = await provider.cancelRideRequest(reason: reason);
  if (!confirmed && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        duration: Duration(seconds: 6),
        backgroundColor: SgColors.danger,
        content: Text(
          style: TextStyle(color: SgColors.onDanger),
          'We could not cancel your ride. It is still active — please try '
          'again.',
        ),
      ),
    );
  }
  return confirmed;
}

/// Leaves a ride screen once the cancel is confirmed. A ride started from the
/// booking flow replaces the stack (`go`), so there may be nothing to pop: popping
/// the last page left a black screen (found on the QA phone, 12 Nov).
void _leaveAfterCancel(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go('/home');
  }
}

/// Who the rider is riding with, read from the ride payload the screens render.
class _DriverView {
  _DriverView(dynamic raw)
    : ride = raw is Map ? raw : const {},
      info = (raw is Map && raw['driver_info'] is Map)
          ? raw['driver_info'] as Map
          : const {},
      vehicle = (raw is Map && raw['vehicle_info'] is Map)
          ? raw['vehicle_info'] as Map
          : const {};
  final Map ride;
  final Map info;
  final Map vehicle;

  String get name =>
      (info['name'] ?? ride['driver_name'] ?? '').toString().trim();
  String get first => firstNameOf(name);
  String get plate =>
      (vehicle['vehicle_number'] ?? ride['vehicle_number'] ?? '')
          .toString()
          .trim();
  String get pin => (ride['otp'] ?? '').toString().trim();
  String? get photo => info['photo_url']?.toString();
  String? get tripId => (ride['trip_id'] ?? ride['id'])?.toString();

  String get _model {
    final m = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
    return m.isNotEmpty
        ? m
        : (ride['vehicle_model'] ?? ride['vehicle_info_summary'] ?? '')
              .toString()
              .trim();
  }

  /// "White Maruti Suzuki Dzire" (11 Nov, as on the web and the invoice): colour, make, model.
  /// The plate is shown on its own beside it.
  String? get vehicleLine {
    final color = (vehicle['color'] ?? '').toString().trim();
    final line = [
      if (color.isNotEmpty) color,
      if (_model.isNotEmpty) _model,
    ].join(' ');
    return line.isEmpty ? null : line;
  }

  DriverCardData get card => DriverCardData(
    name: name.isEmpty ? 'Your driver' : name,
    rating: ratingText(info['stars'] ?? info['rating']),
    vehicleLine: vehicleLine,
    plate: plate.isEmpty ? null : plate,
  );

  String? get meetLine {
    for (final k in [
      'pickup_note',
      'pickup_notes',
      'meeting_point',
      'meet_point',
    ]) {
      final v = ride[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  TripSafetyContext get safety => TripSafetyContext(
    tripId: tripId,
    driverName: name.isEmpty ? null : name,
    vehicleNumber: plate.isEmpty ? null : plate,
    vehicleModel: _model.isEmpty ? null : _model,
  );
}

/// Drivers the search has asked so far; 0 until the first dispatch wave.
int _askedDrivers(MapProvider mp) {
  final raw = mp.rideRequestResponse;
  final n = raw is Map ? raw['drivers_asked'] : null;
  return n is num ? n.toInt() : 0;
}

/// The quote the rider accepted, shown while we look for a driver.
SgLockedFareCard _lockedFare(MapProvider mp) {
  final type = mp.selectedVehicleType;
  final est = type == null ? null : mp.fareEstimates[type];
  final opt = (type == null || est == null)
      ? null
      : RideOption.fromEstimate(type, est);
  final raw = mp.rideRequestResponse;
  final fallback = raw is Map
      ? (raw['total_fare'] ?? raw['estimated_fare'])
      : null;
  return SgLockedFareCard(
    vehicleType: type,
    className: opt?.name ?? 'Saaradhi ${vehicleClassName(type)}',
    route: routeLine(
      mp.pickupAddress ?? mp.pickupLocation?.name,
      mp.destinationAddress,
    ),
    fareText:
        opt?.fareText ??
        formatMoney(
          fallback,
          raw is Map ? raw['currency'] as String? : null,
          decimals: 0,
        ) ??
        '',
  );
}

void _openChat(BuildContext context, _DriverView d) {
  final tripId = int.tryParse(d.tripId ?? '') ?? 0;
  if (tripId <= 0) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TripChatScreen(tripId: tripId, myRole: 'rider'),
    ),
  );
}

SgActionData _safetyAction(Key key, VoidCallback onTap) => SgActionData(
  key: (key as ValueKey<String>).value,
  label: 'Safety',
  icon: SgIcons.shield,
  danger: true,
  onTap: onTap,
);

class SetDestinationScreen extends StatelessWidget {
  const SetDestinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DarkMapScaffold(
      title: 'Set Destination',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.place, color: SgColors.goldText),
            title: Text(
              '1200 Ocean Drive',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Miami Beach, FL 33139'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.push('/route-map'),
            child: const Text('Confirm Location'),
          ),
        ],
      ),
    );
  }
}

// Redundant RouteMapScreen removed to use screens/home/route_map_screen.dart instead.

class SearchingDriverScreen extends StatefulWidget {
  const SearchingDriverScreen({super.key});

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen> {
  bool _isNavigated = false;
  bool _canPop = false;
  MapProvider? _mapProvider;

  /// Client-side bounds on the search, so the screen can never wait forever.
  /// The server ends a search at 90 s and says so; these cover the frame
  /// being lost. See [RideNotifier.verifySearch].
  static const _ackTimeout = Duration(seconds: 20);
  static const _checkAfter = Duration(seconds: 105);
  static const _giveUpAfter = Duration(seconds: 240);
  Timer? _watchdog;
  final Stopwatch _elapsed = Stopwatch();
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Start ride request when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);
      QuoteLockState.instance.addListener(_onQuoteRefresh);
      _startSearch();
    });
  }

  /// The server refused the ticket's quote and sent a fresh fare: nothing
  /// was booked. Back to the ticket, which shows the new fare and why; the
  /// rider confirms again to book it.
  void _onQuoteRefresh() {
    if (!mounted || _isNavigated || QuoteLockState.instance.pending == null) {
      return;
    }
    _isNavigated = true;
    _watchdog?.cancel();
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _startSearch() {
    _mapProvider?.requestRide(context: context);
    _elapsed
      ..reset()
      ..start();
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  RideState? get _ride => _mapProvider?.container?.read(rideNotifierProvider);

  Future<void> _tick() async {
    final ride = _ride;
    if (!mounted || ride == null || _checking) return;
    if (ride.searchFailure != null ||
        ride.status != RideStatus.searchingDriver) {
      _watchdog?.cancel();
      return;
    }
    final unacknowledged =
        ride.tripId == null && _elapsed.elapsed >= _ackTimeout;
    if (!unacknowledged && _elapsed.elapsed < _checkAfter) return;
    _checking = true;
    try {
      await _mapProvider?.container
          ?.read(rideNotifierProvider.notifier)
          .verifySearch(giveUp: _elapsed.elapsed >= _giveUpAfter);
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _mapProvider?.removeListener(_handleStateChange);
    QuoteLockState.instance.removeListener(_onQuoteRefresh);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted || _isNavigated) return;

    final mapProvider = _mapProvider;
    if (mapProvider == null) return;

    // Check for ride acceptance
    if (mapProvider.rideRequestResponse != null) {
      final response = mapProvider.rideRequestResponse;
      final status = response['status'];
      final type = response['type'];

      // Navigate if ride is accepted
      if (type == 'ride.accepted' ||
          type == 'ride_accepted' ||
          (type == 'trip_update' && status == 'accept')) {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            String currentRoute = '';
            try {
              currentRoute = GoRouter.of(
                context,
              ).routerDelegate.currentConfiguration.last.matchedLocation;
            } catch (e) {
              debugPrint('Guard route check failed: $e');
            }

            if (currentRoute != '/driver-found') {
              context.pushReplacement('/driver-found');
            }
          }
        });
      }
    }
  }

  /// Leave a search that already ended. Nothing is live on the server, so
  /// there is nothing to cancel there.
  Future<void> _leaveFailedSearch({bool toChooseRide = false}) async {
    await _mapProvider?.container
        ?.read(rideNotifierProvider.notifier)
        .clearState();
    if (!mounted) return;
    final router = GoRouter.of(context);
    setState(() => _canPop = true);
    await Navigator.of(context).maybePop();
    // Choose-ride sits under the pickup step, which has nothing left to confirm.
    if (toChooseRide &&
        router.routerDelegate.currentConfiguration.last.matchedLocation ==
            '/precise-pickup' &&
        router.canPop()) {
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return riverpod.Consumer(
      builder: (context, ref, _) {
        final failure = ref.watch(
          rideNotifierProvider.select((s) => s.searchFailure),
        );
        final mp = context.watch<MapProvider>();
        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (failure != null) {
              await _leaveFailedSearch();
              return;
            }
            final shouldPop = await _showCancelConfirmation(context);
            if (shouldPop && mounted && context.mounted) {
              // Only leave the screen if the ride is really cancelled. Popping
              // on a failed cancellation is what showed a rider an empty screen
              // while a driver was still on the way.
              final confirmed = await _cancelRideAndReport(context);
              if (!confirmed || !mounted) return;
              setState(() => _canPop = true);
              if (context.mounted) _leaveAfterCancel(context);
            }
          },
          child: _DarkMapScaffold(
            title: failure == null
                ? sgStrings(context).findingSaaradhi
                : sgStrings(context).noSaaradhiNearby,
            close: true,
            searching: true,
            pulse: failure == null,
            mapBottom: 400,
            sheet: failure == null
                ? _searching(context, mp)
                : _failed(context, mp, failure),
          ),
        );
      },
    );
  }

  Widget _searching(BuildContext context, MapProvider mp) {
    final l = sgStrings(context);
    final fare = _lockedFare(mp);
    final market = MarketConfigStore.instance.current;
    return FindingChecklistSheet(
      heading: l.findingClass(vehicleClassName(mp.selectedVehicleType)),
      items: [
        if (fare.fareText.isNotEmpty)
          ChecklistItem(
            l.fareLockedAt(fare.fareText),
            ChecklistState.done,
            key: const Key('finding_fare_locked'),
          ),
        // From the socket's dispatch_progress frames (drivers_notified,
        // summed over waves). Said only once someone has been asked.
        if (_askedDrivers(mp) > 0)
          ChecklistItem(
            l.askedDriversNearby(_askedDrivers(mp)),
            ChecklistState.done,
            key: const Key('finding_asked_drivers'),
          ),
        ChecklistItem(
          l.waitingAccept,
          ChecklistState.current,
          key: const Key('finding_waiting'),
        ),
      ],
      note: l.closeAppNote,
      cancelLabel: l.cancelRequest,
      // Said only while cancelling really costs nothing: no fee in this
      // market, or no driver has accepted yet (cancel_policy
      // .free_before_accept). After acceptance the arriving screen decides.
      cancelNote: market.freeToCancel || market.freeBeforeAccept
          ? l.freeToCancel
          : null,
      onCancel: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _failed(BuildContext context, MapProvider mp, String message) {
    final l = sgStrings(context);
    final type = mp.selectedVehicleType;
    // Alternatives: the other classes from the same estimate calls this
    // booking already made, minus any the quote said has no driver near.
    final others = [
      for (final o in RideOption.fromEstimates(mp.fareEstimates))
        if (o.type != type && o.driversNearby) o,
    ];
    return SgSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                l.noClassFree(vehicleClassName(type)),
                key: const Key('no_driver_heading'),
                style: SgText.heading,
              ),
            ),
            const SizedBox(height: SgSpace.s2),
            // A search that ended without a driver was never paid for: the
            // fare is charged after the trip.
            Row(
              children: [
                SgIcon(SgIcons.check, size: 18, color: SgColors.success),
                const SizedBox(width: SgSpace.s2),
                Expanded(
                  child: Text(
                    l.notCharged,
                    key: const Key('no_driver_not_charged'),
                    style: SgText.body.copyWith(
                      color: SgColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (message != kNoDriverMessage) ...[
              const SizedBox(height: SgSpace.s2),
              Text(message, style: SgText.caption),
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: SgSpace.s4),
              SgEyebrow(l.tryAnotherRide),
              const SizedBox(height: SgSpace.s2),
              for (final o in others)
                Padding(
                  padding: const EdgeInsets.only(bottom: SgSpace.s2),
                  child: _AlternativeRow(
                    option: o,
                    onTap: () {
                      // Through the normal booking flow for that class:
                      // back to every fare with it chosen.
                      mp.selectVehicleType(o.type);
                      _leaveFailedSearch(toChooseRide: true);
                    },
                  ),
                ),
            ],
            const SizedBox(height: SgSpace.s4),
            SgPrimaryButton(
              key: const Key('no_driver_keep_looking'),
              label: l.keepLooking,
              onPressed: _startSearch,
            ),
            const SizedBox(height: SgSpace.s2),
            SgGhostButton(
              label: l.changeRide,
              onPressed: () => _leaveFailedSearch(toChooseRide: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: SgColors.bg200,
            title: Text(
              sgStrings(context).cancelSearchTitle,
              style: TextStyle(
                color: SgColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              sgStrings(context).cancelSearchBody,
              style: TextStyle(color: SgColors.inkMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  sgStrings(context).wait,
                  style: TextStyle(color: SgColors.goldText),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  sgStrings(context).cancelAnyway,
                  style: TextStyle(color: SgColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Another class on the no-driver sheet: tile, name, ETA, fare.
class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({required this.option, required this.onTap});
  final RideOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: SgColors.bg200,
    borderRadius: BorderRadius.circular(SgRadius.md),
    child: InkWell(
      key: Key('alt_${option.type}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(SgRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(SgSpace.s2),
        child: Row(
          children: [
            SgClassChip(type: option.type, label: option.shortName),
            const SizedBox(width: SgSpace.s3),
            Expanded(
              child: Text(
                option.metaIn(sgStrings(context)),
                style: SgText.caption,
              ),
            ),
            Text(
              option.fareText,
              style: SgText.fare.copyWith(fontSize: SgText.sizeTitle),
            ),
            const SizedBox(width: SgSpace.s2),
          ],
        ),
      ),
    ),
  );
}

class DriverFoundScreen extends StatefulWidget {
  const DriverFoundScreen({super.key});

  @override
  State<DriverFoundScreen> createState() => _DriverFoundScreenState();
}

class _DriverFoundScreenState extends State<DriverFoundScreen> {
  bool _canPop = false;
  bool _isNavigated = false;
  MapProvider? _mapProvider;
  String? _etaAskedFor;

  @override
  void initState() {
    super.initState();
    TripEtaStore.instance.addListener(_onEta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);
      _handleStateChange(); // Initial check
    });
  }

  void _onEta() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TripEtaStore.instance.removeListener(_onEta);
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    _etaAskedFor = askTripEta(_mapProvider?.tripId, _etaAskedFor);
    if (!mounted || _isNavigated) return;

    final mapProvider = _mapProvider;
    if (mapProvider == null) return;

    final response = mapProvider.rideRequestResponse;

    if (response != null) {
      final status = response['status'];

      if (status == 'start' || status == 'active') {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            context.pushReplacement('/tracking');
          }
        });
      } else if (status == 'cancel') {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isOpsCancelled(response)
                      ? kOpsCancelledNotice
                      : 'Ride was cancelled by driver.',
                ),
              ),
            );
            context.go('/home');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        final rideData = mapProvider.rideRequestResponse;
        final d = _DriverView(rideData);
        final arrived =
            mapProvider.container?.read(rideNotifierProvider).status ==
            RideStatus.driverArrived;
        // The server's pickup ETA only; none, no line (never a guess or 0).
        final mins = TripEtaStore.instance
            .etaFor(mapProvider.tripId)
            ?.minutesToPickup;
        final l = sgStrings(context);
        final market = MarketConfigStore.instance.current;
        final who = d.first.isEmpty ? l.yourDriver : d.first;
        final headline = arrived ? l.driverArrived(who) : l.driverOnWay(who);
        void sos() => showSafetySheet(context, trip: d.safety);
        final fare = _lockedFare(mapProvider);
        final type = mapProvider.selectedVehicleType;
        final locked =
            type != null &&
            (mapProvider.fareEstimates[type]?['quote_id']?.toString() ?? '')
                .isNotEmpty;

        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _showCancelConfirmation(context);
            if (shouldPop && mounted && context.mounted) {
              // Leave the screen only if the ride is really cancelled.
              final confirmed = await _cancelRideAndReport(context);
              if (!confirmed || !mounted || !context.mounted) return;
              setState(() => _canPop = true);
              _leaveAfterCancel(context);
            }
          },
          child: _DarkMapScaffold(
            title: headline,
            close: true,
            mapBottom: 520,
            mapLabel: (arrived || mins == null) ? null : l.minutesShort(mins),
            onBack: () async {
              if (mounted && context.mounted) {
                Navigator.of(context).maybePop();
              }
            },
            topRight: SgSosPill(
              key: const ValueKey('arriving_sos_button'),
              label: l.safety,
              onTap: sos,
            ),
            sheet: ArrivingT2Sheet(
              // "Arriving in N min" only when there is a pickup ETA.
              eta: (arrived || mins == null) ? null : l.arrivingInMin(mins),
              headline: headline,
              meetLine: d.meetLine,
              status: arrived ? l.statusArrived : l.statusOnTheWay,
              fareLine: [
                vehicleClassName(mapProvider.selectedVehicleType),
                paymentMethodLabel(l, mapProvider.selectedPaymentMethod),
              ].where((s) => s.isNotEmpty).join(' \u00b7 '),
              fareText: fare.fareText,
              lockedLabel: locked ? l.locked : null,
              driver: SgDriverRow(
                name: d.card.name,
                rating: d.card.rating,
                vehicleLine: d.card.vehicleLine,
                plate: d.card.plate,
                indianPlate: market.countryCode == 'IN',
              ),
              pinPanel: d.pin.isEmpty
                  ? null
                  : SgPinPanel(
                      label: l.yourRideCode,
                      hint: l.tellDriverInPerson,
                      pin: d.pin,
                      showLabel: l.showCode,
                      hideLabel: l.hideCode,
                    ),
              // Call is masked (the server's bridge number, never the
              // driver's own); Share sends the live trip link.
              actions: [
                SgIconButtonWide(
                  key: const Key('arriving_call'),
                  icon: SgIcons.call,
                  label: l.call,
                  onTap: () => callDriverMasked(context, d.tripId),
                ),
                SgIconButtonWide(
                  key: const Key('arriving_message'),
                  icon: SgIcons.message,
                  label: l.message,
                  onTap: () => _openChat(context, d),
                ),
                if (RiderFlags.shareTrip)
                  SgIconButtonWide(
                    key: const Key('arriving_share'),
                    icon: SgIcons.share,
                    label: l.share,
                    onTap: () => shareTripLink(context, d.tripId),
                  ),
              ],
              cancelLabel: l.cancelRide,
              onCancel: () => Navigator.of(context).maybePop(),
              cancelNote: market.freeToCancel ? l.freeToCancel : null,
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: SgColors.bg200,
        title: Text(
          sgStrings(context).ongoingRideTitle,
          style: TextStyle(color: SgColors.ink, fontWeight: FontWeight.w600),
        ),
        content: Text(
          sgStrings(context).cancelActiveRequestBody,
          style: TextStyle(color: SgColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              sgStrings(context).wait,
              style: TextStyle(color: SgColors.goldText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              sgStrings(context).cancelAnyway,
              style: TextStyle(color: SgColors.danger),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showCancelDialog(BuildContext context) {
    // This is no longer used individually, but kept if needed for specific flows
    _showCancelConfirmation(context).then((shouldCancel) async {
      if (shouldCancel && context.mounted) {
        final confirmed = await _cancelRideAndReport(context);
        if (confirmed && context.mounted) _leaveAfterCancel(context);
      }
    });
  }
}

class FullMapTrackingScreen extends StatefulWidget {
  const FullMapTrackingScreen({super.key});

  @override
  State<FullMapTrackingScreen> createState() => _FullMapTrackingScreenState();
}

class _FullMapTrackingScreenState extends State<FullMapTrackingScreen> {
  /// What the safety sheet needs: who the rider is with, and where they are.
  ///
  /// Read from the ride response the tracking screen is already rendering, so
  /// raising an SOS costs no extra request at the moment it matters most.
  TripSafetyContext _safetyContext(MapProvider mapProvider) {
    final ride = mapProvider.rideRequestResponse;
    double? toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

    return TripSafetyContext(
      tripId: mapProvider.tripId ?? ride?['trip_id']?.toString(),
      driverName: ride?['driver_name'] as String?,
      vehicleNumber: ride?['vehicle_number'] as String?,
      vehicleModel: ride?['vehicle_model'] as String?,
      lat: toDouble(ride?['driver_lat'] ?? ride?['pickup_lat']),
      lng: toDouble(ride?['driver_lng'] ?? ride?['pickup_long']),
    );
  }

  bool _canPop = false;
  bool _isNavigated = false;
  MapProvider? _mapProvider;

  /// The trip's planned route (`planned_route_polyline` on the trip detail,
  /// backend #170), drawn as the route on trip. Null until it arrives, and
  /// when the server has none: no line is invented.
  List<LatLng>? _plannedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);
      _handleStateChange(); // Initial check
      _loadPlannedRoute();
    });
    TripEtaStore.instance.addListener(_onEta);
  }

  String? _etaAskedFor;

  void _onEta() {
    if (mounted) setState(() {});
  }

  /// The trip the route was asked for; asked again only for a new trip id
  /// (the id can arrive after this screen opens).
  String? _routeAskedFor;

  Future<void> _loadPlannedRoute() async {
    final tripId = _mapProvider?.tripId;
    if (tripId == null || tripId == _routeAskedFor) return;
    _routeAskedFor = tripId;
    final token = (await SharedPreferences.getInstance()).getString(
      'access_token',
    );
    if (token == null || token.isEmpty) return;
    try {
      final body = await RideService().getTripStatus(token, tripId);
      final data = body?['data'];
      final line = data is Map ? data['planned_route_polyline'] : null;
      final points = decodePlannedRoute(line);
      if (mounted && points != null) setState(() => _plannedRoute = points);
    } catch (_) {}
  }

  @override
  void dispose() {
    TripEtaStore.instance.removeListener(_onEta);
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    _etaAskedFor = askTripEta(_mapProvider?.tripId, _etaAskedFor);
    if (_plannedRoute == null) _loadPlannedRoute();
    if (!mounted || _isNavigated) return;

    final mapProvider = _mapProvider;
    if (mapProvider == null) return;

    final response = mapProvider.rideRequestResponse;

    if (response != null) {
      final status = response['status'];
      if (status == 'complete') {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            context.pushReplacement('/ride-summary');
          }
        });
      } else if (status == 'cancel') {
        _isNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isOpsCancelled(response)
                      ? kOpsCancelledNotice
                      : 'Ride was cancelled.',
                ),
              ),
            );
            context.go('/home');
          }
        });
      }
    }
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: SgColors.bg200,
            title: Text(
              'Cancel Ride?',
              style: TextStyle(
                color: SgColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              sgStrings(context).cancelOngoingRideBody,
              style: TextStyle(color: SgColors.inkMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  sgStrings(context).continueRide,
                  style: TextStyle(color: SgColors.goldText),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Cancel Ride',
                  style: TextStyle(color: SgColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        final ride = mapProvider.rideRequestResponse;
        final d = _DriverView(ride);
        final drop = (mapProvider.destinationAddress ?? '')
            .split(',')
            .first
            .trim();
        final l = sgStrings(context);
        final rideMap = ride is Map ? ride : const {};
        // "Arriving about HH:MM" from started_at + estimated_duration_min.
        // TODO(data): when the trip payload lacks either, there is no live
        // ETA, so the sheet says where the trip is going and nothing more.
        final est = ArrivalEstimate.from(
          startedAt: DateTime.tryParse(
            (rideMap['started_at'] ?? rideMap['start_time'] ?? '').toString(),
          )?.toLocal(),
          estimatedMinutes: num.tryParse(
            (rideMap['estimated_duration_min'] ?? '').toString(),
          ),
          now: DateTime.now(),
        );
        // The server's ETA (to_drop) first: "Arriving about 9:41 am" in the
        // trip's own time zone.
        final eta = TripEtaStore.instance.etaFor(mapProvider.tripId);
        final clock = eta?.arrivalClock;
        final dropMin = eta?.phase == 'to_drop' ? eta?.dropEtaMin : null;
        final headline = clock != null
            ? l.arrivingAbout(
                clockText(DateTime(2000, 1, 1, clock.hour, clock.minute)),
              )
            : est == null
            ? (drop.isEmpty ? l.arrivingSoon : l.onTheWayTo(drop))
            : est.overdue
            ? l.arrivingSoon
            : l.arrivingAbout(clockText(est.at));
        final fare = _lockedFare(mapProvider);
        void sos() =>
            showSafetySheet(context, trip: _safetyContext(mapProvider));
        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _showCancelConfirmation(context);
            if (shouldPop && mounted && context.mounted) {
              // Leave the screen only if the ride is really cancelled.
              final confirmed = await _cancelRideAndReport(context);
              if (!confirmed || !mounted || !context.mounted) return;
              setState(() => _canPop = true);
              _leaveAfterCancel(context);
            }
          },
          child: _DarkMapScaffold(
            title: headline,
            close: true,
            mapBottom: 420,
            onBack: () async {
              if (mounted && context.mounted) {
                Navigator.of(context).maybePop();
              }
            },
            forceInProgress: true,
            plannedRoute: _plannedRoute,
            // Always visible on a live trip.
            topRight: SgSosPill(
              key: const ValueKey('tracking_sos_pill'),
              onTap: sos,
            ),
            sheet: OnTripSheet(
              arrivalLine: headline,
              minutesLeft: clock != null
                  ? (dropMin != null && dropMin > 0
                        ? l.minutesLeft(dropMin)
                        : null)
                  : est?.minutesLeft == null
                  ? null
                  : l.minutesLeft(est!.minutesLeft!),
              progress: est?.progress,
              driver: SgDriverRow(
                name: d.card.name,
                rating: d.card.rating,
                plate: d.card.plate,
                indianPlate:
                    MarketConfigStore.instance.current.countryCode == 'IN',
                trailing: fare.fareText.isEmpty
                    ? null
                    : LockedFare(fareText: fare.fareText, locked: l.locked),
              ),
              extra: ride?['status'] == 'complete'
                  ? SgPrimaryButton(
                      label: l.viewSummary,
                      onPressed: () => context.push('/ride-summary'),
                    )
                  : null,
              // Share (the live link) and a masked Call; the safety sheet
              // POSTs /sos/, offers the emergency number and shares too.
              actions: [
                if (RiderFlags.shareTrip)
                  SgIconButtonWide(
                    key: const ValueKey('tracking_share_button'),
                    icon: SgIcons.share,
                    label: l.share,
                    onTap: () => shareTripLink(context, d.tripId),
                  ),
                SgIconButtonWide(
                  key: const ValueKey('tracking_call_button'),
                  icon: SgIcons.call,
                  label: l.call,
                  onTap: () => callDriverMasked(context, d.tripId),
                ),
                SgIconButtonWide(
                  key: const ValueKey('tracking_sos_button'),
                  icon: SgIcons.shield,
                  label: l.safety,
                  danger: true,
                  onTap: sos,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The fare a receipt shows, by the server's own settlement rule
/// (`trip.final_fare or trip.estimated_fare`): the final fare when there is
/// one, then the completion frame's total, then the estimate. Null when none
/// is there -- never a made-up ₹0.
String? receiptFareRaw(Map<dynamic, dynamic>? ride) {
  if (ride == null) return null;
  for (final k in const ['final_fare', 'total_fare', 'estimated_fare']) {
    final v = ride[k];
    if (v != null && double.tryParse(v.toString()) != null) {
      return v.toString();
    }
  }
  return null;
}

/// Decodes an encoded polyline (Google's format, as the server stores
/// `planned_route_polyline`). Null for nothing usable.
List<LatLng>? decodePlannedRoute(Object? encoded) {
  if (encoded is! String || encoded.isEmpty) return null;
  final out = <LatLng>[];
  var i = 0, lat = 0, lng = 0;
  int next() {
    var shift = 0, result = 0, b = 0;
    do {
      if (i >= encoded.length) throw const FormatException('cut short');
      b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  try {
    while (i < encoded.length) {
      lat += next();
      lng += next();
      out.add(LatLng(lat / 1e5, lng / 1e5));
    }
  } on FormatException {
    return null;
  }
  return out.length >= 2 ? out : null;
}

class RidePaymentSummaryScreen extends StatefulWidget {
  const RidePaymentSummaryScreen({
    super.key,
    this.rideService,
    this.razorpay,
    this.cashfreeStarter,
    this.confirmPollInterval = const Duration(seconds: 3),
  });

  /// Test seams: the HTTP service, the Razorpay and Cashfree launchers and the
  /// poll interval after a PAYMENT_NOT_CAPTURED. Production passes none.
  final RideService? rideService;
  final RazorpayLauncher? razorpay;
  final CashfreeStarter? cashfreeStarter;
  final Duration confirmPollInterval;

  @override
  State<RidePaymentSummaryScreen> createState() =>
      _RidePaymentSummaryScreenState();
}

class _RidePaymentSummaryScreenState extends State<RidePaymentSummaryScreen> {
  String _selectedPaymentMethod = 'cash';
  final PaymentService _paymentService = PaymentService();
  late final RideService _rideService = widget.rideService ?? RideService();
  bool _isProcessing = false;

  /// create-order said 409 NOT_CHARGED: nothing is owed.
  bool _notCharged = false;
  String _notChargedMessage = 'You were not charged for this trip.';

  /// "Payment received, confirming..." while a 409 PAYMENT_NOT_CAPTURED is
  /// being polled.
  String? _confirming;

  /// The trip detail, loaded for a trip support ended (distance driven, the
  /// fare for it, whether anything was charged).
  Map<String, dynamic>? _receipt;
  TripInvoice? _invoice;

  /// The trip to rate, captured on open: every payment path clears the local
  /// ride state before the rating screen, which then had nothing to rate.
  String? _rateTripId;
  String? _rateDriverName;
  String? _vehicleLine;

  /// Kept for the rating screen, for the same reason: the ride state is gone.
  String? _dropName;
  String? _durationText;
  String? _fareText;
  String? _payMethod;
  final DateTime _openedAt = DateTime.now();

  void _goRate({String? method, bool paid = true}) {
    context.go(
      '/rate-driver',
      extra: {
        'trip_id': _rateTripId,
        'driver_name': _rateDriverName,
        'vehicle_line': _vehicleLine,
        'fare_text': _fareText,
        'method': method ?? _payMethod,
        'paid': paid,
        'detail': tripDetailLine(_dropName, _openedAt, _durationText),
      },
    );
  }

  /// The driver confirming the cash, heard while this screen is open.
  riverpod.ProviderSubscription<RideState>? _cashSub;
  bool _cashHandled = false;

  @override
  void initState() {
    super.initState();
    // The method chosen at booking, never a wallet that may be empty.
    _selectedPaymentMethod =
        context.read<MapProvider>().selectedPaymentMethod == 'cash'
        ? 'cash'
        : 'upi_card';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mp = context.read<MapProvider>();
      final raw = mp.rideRequestResponse;
      _rateTripId =
          mp.tripId ??
          (raw is Map ? (raw['trip_id'] ?? raw['id'])?.toString() : null);
      final who = _DriverView(raw);
      _rateDriverName = who.name.isEmpty ? null : who.name;
      _vehicleLine = [
        if (who.vehicleLine != null) who.vehicleLine!,
        if (who.plate.isNotEmpty) who.plate,
      ].join(' · ');
      _dropName = mp.destinationAddress;
      _durationText = mp.duration;
      _payMethod =
          (raw is Map ? raw['payment_method'] : null)?.toString() ??
          mp.selectedPaymentMethod;
      _cashSub = mp.container?.listen<RideState>(rideNotifierProvider, (
        _,
        next,
      ) {
        if (next.rawResponse?['cash_confirmed'] == true) _onCashConfirmed();
      }, fireImmediately: true);
      // The frame is best-effort, and after `complete` the rider's sockets
      // may already be closed (trip 121 on QA: confirmed, never heard). The
      // trip record is the authority, so ask it too.
      _settledPoll = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkSettled(),
      );
      context.read<WalletProvider>().refreshWallet();
      _loadReceiptIfEndedBySupport();
      _loadInvoice();
    });
  }

  // The receipt or tax invoice, issued by the market's entity. Absent until
  // the server has one (and on servers that predate it): nothing shows then.
  Future<void> _loadInvoice() async {
    final id = context.read<MapProvider>().tripId ?? _rateTripId;
    if (id == null) return;
    final token = (await SharedPreferences.getInstance()).getString(
      'access_token',
    );
    if (token == null) return;
    final body = await _rideService.getTripStatus(token, id);
    final data = body?['data'];
    final invoice = TripInvoice.fromTrip(data is Map ? data : body);
    if (mounted && invoice != null && invoice.companyName.isNotEmpty) {
      setState(() => _invoice = invoice);
    }
  }

  Timer? _settledPoll;

  Future<void> _checkSettled() async {
    final id = _rateTripId;
    if (id == null || _cashHandled) return;
    final token = (await SharedPreferences.getInstance()).getString(
      'access_token',
    );
    if (token == null) return;
    final body = await _rideService.getTripStatus(token, id);
    if (isSettledCompletedTrip(body?['data'])) _onCashConfirmed();
  }

  @override
  void dispose() {
    _settledPoll?.cancel();
    _cashSub?.close();
    super.dispose();
  }

  /// Paid in cash and confirmed by the driver: nothing is owed here.
  Future<void> _onCashConfirmed() async {
    if (_cashHandled || !mounted) return;
    _cashHandled = true;
    _settledPoll?.cancel();
    await _finishCashSelection(sgStrings(context).cashReceived);
  }

  Future<void> _loadReceiptIfEndedBySupport() async {
    final mapProvider = context.read<MapProvider>();
    final raw = mapProvider.rideRequestResponse;
    if (raw is! Map || !isOpsEnded(raw)) return;
    final tripId = mapProvider.tripId;
    if (tripId == null) return;
    final token = (await SharedPreferences.getInstance()).getString(
      'access_token',
    );
    if (token == null) return;
    final body = await _rideService.getTripStatus(token, tripId);
    final data = body?['data'];
    final trip = data is Map<String, dynamic> ? data : body;
    if (mounted && trip != null) setState(() => _receipt = trip);
  }

  /// Choosing cash is a SERVER action, not a screen change.
  ///
  /// This used to be `context.push('/rate-driver')` and nothing else. The
  /// trip's payment stayed exactly as it was -- typically an online payment
  /// row in `pending` -- while the rider was moved on to the rating screen
  /// as though the fare were handled. Nobody owed anything on the record,
  /// the driver had no cash payment to confirm, and the trip never settled.
  ///
  /// So: switch the trip on the server, read what the server says the trip's
  /// payment is now, and only then decide where the rider goes. A refusal or
  /// an unanswered request keeps them on this screen, because the fare is
  /// still outstanding and they are the only one who can retry.
  Future<void> _payWithCash(
    double fare,
    String? currencyCode,
    dynamic rideData,
  ) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (!mounted) return;
      if (token == null) {
        _showCashError(sgStrings(context).signInToPay);
        return;
      }

      final tripIdStr =
          context.read<MapProvider>().tripId ??
          rideData?['trip_id']?.toString() ??
          rideData?['id']?.toString();
      if (tripIdStr == null) {
        _showCashError(sgStrings(context).noActiveTrip);
        return;
      }

      final outcome = await _rideService.selectCashPayment(token, tripIdStr);
      if (!mounted) return;

      switch (outcome.status) {
        case CashSwitchStatus.awaitingCollection:
          // The trip now carries a PENDING cash payment. The money has not
          // moved: the driver confirms collection. Say that, rather than
          // anything that reads as "paid".
          final amount =
              formatMoney(fare, currencyCode) ?? fare.toStringAsFixed(2);
          await _finishCashSelection(
            'Pay $amount to your driver in cash. '
            'They will confirm it once collected.',
            paid: false,
          );
          return;

        case CashSwitchStatus.alreadyPaid:
          // The earlier online payment went through, usually moments before
          // this tap. Collecting cash as well would charge the rider twice.
          await _finishCashSelection(
            outcome.message ?? 'This trip is already paid. No cash is due.',
          );
          return;

        case CashSwitchStatus.refused:
          // The server rejected it and the trip is unchanged. Its own
          // message is more specific than anything this screen could invent.
          _showCashError(
            outcome.message ??
                'Cash is not available for this trip. Please contact support.',
          );
          return;

        case CashSwitchStatus.unconfirmed:
          // We do not know what happened, so nothing may be claimed and the
          // rider stays here with the fare still on screen.
          _showCashError(
            'Could not switch to cash. Check your connection and try again '
            '-- this trip has not been paid.',
          );
          return;
      }
    } catch (e) {
      debugPrint('Pay with cash error: $e');
      if (mounted) {
        _showCashError(
          'Could not switch to cash. Please try again -- this trip has not '
          'been paid.',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// The ride is over and the payment question is answered, so the local
  /// ride state goes. `clearRideStateLocally` -- never `cancelRideRequest`,
  /// which would ask the server to cancel a completed trip.
  Future<void> _finishCashSelection(String message, {bool paid = true}) async {
    final mapProvider = p.Provider.of<MapProvider>(context, listen: false);
    await mapProvider.clearRideStateLocally();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
    _goRate(method: 'cash', paid: paid);
  }

  void _showCashError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(style: TextStyle(color: SgColors.onDanger), message),
        backgroundColor: SgColors.danger,
      ),
    );
  }

  void _showInsufficientBalanceDialog(
    double fare,
    WalletProvider walletProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sgStrings(context).insufficientBalance),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your wallet balance (${MarketConfigStore.instance.current.currencySymbol}${walletProvider.balance.toStringAsFixed(2)}) is less than the fare (${MarketConfigStore.instance.current.currencySymbol}${fare.toStringAsFixed(2)}).',
            ),
            const SizedBox(height: 16),
            Text(sgStrings(context).wouldYouLike),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                '/add-money',
                extra: {'returnRoute': '/ride-summary'},
              );
            },
            child: Text(sgStrings(context).addMoney),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedPaymentMethod = 'online');
            },
            child: Text(sgStrings(context).payUpiCard),
          ),
        ],
      ),
    );
  }

  void _processPayment(
    double fare,
    WalletProvider walletProvider,
    dynamic rideData,
  ) async {
    if (_selectedPaymentMethod == 'wallet') {
      if (walletProvider.balance < fare) {
        _showInsufficientBalanceDialog(fare, walletProvider);
      } else {
        setState(() => _isProcessing = true);
        try {
          final tripIdStr =
              context.read<MapProvider>().tripId ??
              rideData?['trip_id']?.toString() ??
              rideData?['id']?.toString();

          if (tripIdStr == null) {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Error: No active trip ID found. Please refresh.',
                ),
              ),
            );
            return;
          }

          final tripId = int.tryParse(tripIdStr);
          if (tripId == null) {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Invalid Trip ID format.')),
            );
            return;
          }

          // The server decides the amount and whether the trip can be paid.
          final result = await walletProvider.payForRide(tripId: tripId);

          if (!mounted) return;

          setState(() => _isProcessing = false);

          if (result.paid) {
            // A 200 duplicate is the same transaction: success.
            context.push(
              '/payment-status',
              extra: {
                'status': 'success',
                // What the server charged; the local fare is display-only
                // fallback when the response lacks an amount.
                'amount': result.serverAmount ?? fare,
                'transaction_id': result.transactionId,
                'new_balance': result.newBalance ?? walletProvider.balance,
              },
            );
          } else if (result.alreadyPaid) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(WalletPayOutcome.alreadyPaidMessage),
              ),
            );
          } else if (result.insufficientBalance) {
            _showInsufficientBalanceDialog(fare, walletProvider);
          } else {
            context.push(
              '/payment-status',
              extra: {
                'status': 'failed',
                // Still to pay: the fare this screen showed.
                'amount': fare,
                'error_message': WalletPayOutcome.neutralFailureMessage,
              },
            );
          }
        } catch (e) {
          setState(() => _isProcessing = false);
          if (mounted) {
            context.push(
              '/payment-status',
              extra: {
                'status': 'failed',
                // Still to pay: the fare this screen showed.
                'amount': fare,
                'error_message': WalletPayOutcome.neutralFailureMessage,
              },
            );
          }
        }
      }
    } else {
      setState(() => _isProcessing = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final token = prefs.getString('access_token');
        if (token == null) return;

        final tripIdStr =
            context.read<MapProvider>().tripId ??
            rideData?['trip_id']?.toString() ??
            rideData?['id']?.toString();

        if (tripIdStr == null) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No active trip ID found. Please refresh.'),
            ),
          );
          return;
        }

        final tripId = int.tryParse(tripIdStr);
        if (tripId == null) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Invalid Trip ID format.')),
          );
          return;
        }

        final flow = OnlinePaymentFlow(
          rides: _rideService,
          razorpay: widget.razorpay ?? RazorpaySdkLauncher(),
          pollInterval: widget.confirmPollInterval,
          cashfree:
              widget.cashfreeStarter ??
              (order) async {
                final r = await _paymentService.startPayment(
                  amount: fare,
                  name: 'SaaradhiGo',
                  description: order.description,
                  orderId: order.orderId,
                  cashfreePaymentSessionId: order.sessionId,
                  prefill: {
                    'name': order.prefill['name'] ?? 'Rider',
                    'contact': order.prefill['contact'] ?? '9876543210',
                    'email': order.prefill['email'] ?? 'rider@saaradhigo.com',
                  },
                  context: context,
                );
                return r?.orderId;
              },
          onConfirming: () {
            if (mounted) {
              setState(() => _confirming = kPaymentConfirmingMessage);
            }
          },
        );
        final result = await flow.pay(token: token, tripId: tripId);
        if (!mounted) return;
        await _handleOnlineResult(result);
      } catch (e) {
        debugPrint(e.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment initiation failed: ${e.toString()}'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  /// What the screen does with each way the online payment can end.
  Future<void> _handleOnlineResult(OnlinePaymentResult result) async {
    if (!mounted) return;
    setState(() => _confirming = null);
    switch (result.outcome) {
      case OnlinePaymentOutcome.paid:
        // The trip is COMPLETE and PAID. Tear down local state; do not ask the
        // server to cancel a ride that just succeeded.
        final mapProvider = p.Provider.of<MapProvider>(context, listen: false);
        await mapProvider.clearRideStateLocally();
        if (mounted) _goRate(method: 'upi');
      case OnlinePaymentOutcome.notCharged:
        // Nothing is owed: say so, never open a checkout.
        setState(() {
          _notCharged = true;
          _notChargedMessage = result.message ?? _notChargedMessage;
        });
      case OnlinePaymentOutcome.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Payment cancelled.')),
        );
      case OnlinePaymentOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Payment verification failed.'),
          ),
        );
      case OnlinePaymentOutcome.confirming:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? kPaymentStillConfirmingMessage),
            duration: const Duration(seconds: 8),
          ),
        );
      case OnlinePaymentOutcome.unavailable:
        // Online payment is not available (no gateway, unknown gateway, or the
        // backend refused): the message the backend gave, as before.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              style: TextStyle(color: SgColors.onDanger),
              result.message ?? kPaymentUnavailableMessage,
            ),
            backgroundColor: SgColors.danger,
          ),
        );
    }
  }

  Future<void> _continueWhenNotCharged() async {
    final mapProvider = p.Provider.of<MapProvider>(context, listen: false);
    await mapProvider.clearRideStateLocally();
    if (mounted) _goRate(paid: false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MapProvider, WalletProvider>(
      builder: (context, mapProvider, walletProvider, child) {
        final rideData = mapProvider.rideRequestResponse;
        final rideMap = rideData is Map ? rideData : null;
        final endedBySupport = isOpsEnded(rideMap);
        // A trip support ended is charged for the distance driven, capped at the
        // quote: its own final fare, from the trip detail, not the quote.
        final Object? totalFareStr =
            (endedBySupport && _receipt?['final_fare'] != null)
            ? _receipt!['final_fare']
            : receiptFareRaw(rideMap);
        // No fare in anything the app holds: the receipt shows no amount
        // rather than ₹0, and only cash is offered.
        final fareKnown = totalFareStr != null;
        final totalFare = double.tryParse(totalFareStr.toString()) ?? 0.0;
        // The server sends an ISO 4217 CODE, not a symbol. Interpolating it
        // directly rendered a rider's fare as "INR169.02" -- verified against
        // deployed QA, which returns `"currency": "INR"` with every quote.
        final currencyCode =
            (rideData?['currency'] ?? _receipt?['currency']) as String?;

        // What the server says the rider is charged: promo (trip_created frame
        // or trip detail) and "not charged". Nothing is computed here.
        final rideCharge = TripCharge.fromRide(rideMap);
        final receiptCharge = TripCharge.fromTripDetail(_receipt);
        final charge = TripCharge(
          promoCode: rideCharge.promoCode,
          discount: rideCharge.discount ?? receiptCharge.discount,
          payable: rideCharge.payable ?? receiptCharge.payable,
          notCharged:
              _notCharged ||
              rideCharge.notCharged ||
              (endedBySupport && receiptCharge.notCharged),
        );
        final km = double.tryParse(
          _receipt?['actual_distance_km']?.toString() ?? '',
        );
        final distanceDriven = (endedBySupport && km != null)
            ? marketOf(context).formatDistanceKm(km)
            : null;
        // With a promo the rider pays the server's `rider_payable`, not the fare.
        final payTotal = (charge.hasPromo && !charge.notCharged)
            ? (double.tryParse(charge.payable ?? '') ?? totalFare)
            : totalFare;

        _fareText = fareKnown ? exactMoney(payTotal, currencyCode) : null;
        final walletShort = walletProvider.balance < payTotal;
        return Scaffold(
          backgroundColor: SgColors.bg000,
          body: SafeArea(
            child: SgReadableWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SgSpace.s4,
                  SgSpace.s2,
                  SgSpace.s4,
                  SgSpace.s5,
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SgMapButton(
                      icon: SgIcons.back,
                      label: sgStrings(context).back,
                      onTap: () => context.pop(),
                    ),
                  ),
                  const SizedBox(height: SgSpace.s3),
                  TripArrivedHeader(
                    detailLine: tripDetailLine(
                      _dropName,
                      _openedAt,
                      _durationText,
                    ),
                  ),
                  const SizedBox(height: SgSpace.s5),
                  if (fareKnown)
                    ..._receiptTop(
                      context,
                      quotedRaw: rideData?['estimated_fare'],
                      cost: payTotal,
                      currencyCode: currencyCode,
                      promo: charge.notCharged
                          ? null
                          : double.tryParse(charge.discount ?? ''),
                      breakdown: TripChargeCard(
                        fare: totalFareStr.toString(),
                        currencyCode: currencyCode,
                        charge: charge,
                        endedBySupport: endedBySupport,
                        distanceDriven: distanceDriven,
                      ),
                      plain: charge.notCharged || endedBySupport,
                    ),
                  if (_invoice != null) ...[
                    const SizedBox(height: SgSpace.s3),
                    InvoiceCard(invoice: _invoice!),
                  ],
                  if (_confirming != null) ...[
                    const SizedBox(height: SgSpace.s3),
                    Text(
                      _confirming!,
                      key: const Key('payment_confirming'),
                      textAlign: TextAlign.center,
                      style: SgText.body.copyWith(
                        color: SgColors.goldText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: SgSpace.s5),
                  if (charge.notCharged)
                    NotChargedPanel(
                      message: _notChargedMessage,
                      onContinue: _continueWhenNotCharged,
                    )
                  else ...[
                    _buildPaymentOption(
                      id: 'cash',
                      title: sgStrings(context).payWithCashTitle,
                      subtitle: sgStrings(context).handToDriver,
                      icon: SgIcons.cash,
                      isSelected: _selectedPaymentMethod == 'cash',
                      onTap: () =>
                          setState(() => _selectedPaymentMethod = 'cash'),
                    ),
                    const SizedBox(height: SgSpace.s3),
                    if (fareKnown) ...[
                      _buildPaymentOption(
                        id: 'wallet',
                        title: sgStrings(context).payFromWallet,
                        subtitle: walletShort
                            ? sgStrings(context).notEnoughBalance
                            : 'Current Balance: ${MarketConfigStore.instance.current.currencySymbol}${walletProvider.balance.toStringAsFixed(2)}',
                        icon: SgIcons.wallet,
                        isSelected: _selectedPaymentMethod == 'wallet',
                        onTap: () =>
                            setState(() => _selectedPaymentMethod = 'wallet'),
                      ),
                      const SizedBox(height: SgSpace.s3),
                      _buildPaymentOption(
                        id: 'upi_card',
                        title: sgStrings(context).payViaUpiCard,
                        icon: SgIcons.cash,
                        isSelected: _selectedPaymentMethod == 'upi_card',
                        onTap: () =>
                            setState(() => _selectedPaymentMethod = 'upi_card'),
                      ),
                    ],
                    const SizedBox(height: SgSpace.s5),
                    if (fareKnown && _selectedPaymentMethod == 'cash')
                      Padding(
                        padding: const EdgeInsets.only(bottom: SgSpace.s3),
                        child: Text(
                          sgStrings(context).payingCash(
                            exactMoney(payTotal, currencyCode),
                            _driverFirst(rideData, context),
                          ),
                          key: const Key('receipt_cash_note'),
                          style: SgText.body.copyWith(color: SgColors.inkMuted),
                        ),
                      ),
                    SgPrimaryButton(
                      key: const Key('pay_button'),
                      label: _isProcessing
                          ? 'Processing'
                          : !fareKnown
                          ? sgStrings(context).payWithCashTitle
                          : sgStrings(context).payBy(
                              exactMoney(payTotal, currencyCode),
                              paymentMethodLabel(
                                sgStrings(context),
                                _selectedPaymentMethod,
                              ),
                            ),
                      onPressed: _isProcessing
                          ? null
                          : () =>
                                (!fareKnown || _selectedPaymentMethod == 'cash')
                                ? _payWithCash(payTotal, currencyCode, rideData)
                                : _processPayment(
                                    payTotal,
                                    walletProvider,
                                    rideData,
                                  ),
                    ),
                    const SizedBox(height: SgSpace.s2),
                    if (_selectedPaymentMethod != 'cash')
                      Center(
                        child: TextButton(
                          onPressed: _isProcessing
                              ? null
                              : () => _payWithCash(
                                  payTotal,
                                  currencyCode,
                                  rideData,
                                ),
                          child: Text(
                            sgStrings(context).payCashInstead,
                            style: SgText.body.copyWith(
                              color: SgColors.inkMuted,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _driverFirst(dynamic rideData, BuildContext context) {
    final first = _DriverView(rideData).first;
    return first.isEmpty ? sgStrings(context).yourDriver : first;
  }

  /// "Your ticket said" next to "Trip cost", the difference lines, and the
  /// existing charge card folded under "How it adds up".
  List<Widget> _receiptTop(
    BuildContext context, {
    required Object? quotedRaw,
    required double cost,
    required String? currencyCode,
    required double? promo,
    required Widget breakdown,
    required bool plain,
  }) {
    final l = sgStrings(context);
    final quoted = double.tryParse(quotedRaw?.toString() ?? '');
    // No quote to compare with, a trip support ended, or no charge: the
    // charge card says it as before.
    if (quoted == null || plain) return [breakdown];
    final lines = receiptLines(
      quoted: quoted,
      cost: cost,
      promoDiscount: promo,
    );
    String signed(double v) =>
        '${v < 0 ? '−' : '+'}${exactMoney(v.abs(), currencyCode)}';
    return [
      ReceiptTiles(
        ticketLabel: l.ticketSaid,
        ticketText: exactMoney(quoted, currencyCode),
        costLabel: l.tripCost,
        costText: exactMoney(cost, currencyCode),
        equal: lines.isEmpty,
      ),
      const SizedBox(height: SgSpace.s3),
      if (lines.isEmpty)
        Row(
          key: const Key('receipt_exact'),
          children: [
            SgIcon(SgIcons.check, size: 18, color: SgColors.success),
            const SizedBox(width: SgSpace.s2),
            Expanded(
              child: Text(
                l.exactlyQuoted,
                style: SgText.body.copyWith(
                  color: SgColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        )
      else
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: SgSpace.s1),
            child: line.kind == ReceiptLineKind.promotion
                ? Row(
                    children: [
                      Expanded(child: Text(l.promotion, style: SgText.body)),
                      Text(signed(line.amount), style: SgText.body),
                    ],
                  )
                : Text(
                    l.differenceUnexplained(signed(line.amount)),
                    key: const Key('receipt_unexplained'),
                    style: SgText.body.copyWith(color: SgColors.inkMuted),
                  ),
          ),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('receipt_how'),
          tilePadding: EdgeInsets.zero,
          title: Text(
            l.howItAddsUp,
            style: SgText.body.copyWith(
              color: SgColors.goldText,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconColor: SgColors.goldText,
          collapsedIconColor: SgColors.goldText,
          children: [breakdown],
        ),
      ),
    ];
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    String? subtitle,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(SgRadius.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(
            horizontal: SgSpace.s4,
            vertical: SgSpace.s3,
          ),
          decoration: BoxDecoration(
            color: isSelected ? SgColors.goldSoft : SgColors.bg200,
            borderRadius: BorderRadius.circular(SgRadius.md),
            border: Border.all(
              color: isSelected ? SgColors.gold500 : SgColors.lineStrong,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              SgIcon(
                icon,
                size: 24,
                color: isSelected ? SgColors.goldText : SgColors.inkMuted,
              ),
              const SizedBox(width: SgSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SgText.body.copyWith(
                        fontSize: SgText.sizeBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) Text(subtitle, style: SgText.caption),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? SgColors.gold500 : SgColors.lineStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rate the trip that just ended. Opened by the payment summary with the
/// trip id and driver name, because the local ride state is gone by then.
///
/// It used to show a hard-coded driver ("Rajesh Kumar", a Toyota Innova) and
/// a Submit button that went home without saving anything.
class RateReviewDriverScreen extends StatelessWidget {
  const RateReviewDriverScreen({
    super.key,
    this.tripId,
    this.driverName,
    this.fareText,
    this.method,
    this.paid = true,
    this.detail = '',
    this.vehicleLine,
    this.rideService,
    this.openUrl,
    this.accessToken,
  });

  final String? tripId;
  final String? driverName;

  /// "White Maruti Suzuki Dzire · TS09AB1234", when the app knows the car.
  final String? vehicleLine;

  /// Test seams: the HTTP service, the URL opener and the sign-in token.
  final RideService? rideService;
  final Future<bool> Function(Uri url)? openUrl;
  final Future<String?> Function()? accessToken;

  /// What the summary knew, so this screen can show what was paid.
  final String? fareText;
  final String? method;
  final bool paid;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final id = tripId;
    if (id == null || id.isEmpty) {
      // Nothing to rate: never show a form that cannot be submitted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return Scaffold(backgroundColor: SgColors.bg000);
    }
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SgSpace.s4,
            SgSpace.s6,
            SgSpace.s4,
            SgSpace.s5,
          ),
          children: [
            TripCompleteView(
              detailLine: detail,
              paidLabel: paidLabelFor(method, paid: paid),
              fareText: fareText,
              paid: paid,
              below: _TripSummaryBelow(
                tripId: id,
                driverName: driverName,
                vehicleLine: vehicleLine,
                rideService: rideService,
                openUrl: openUrl,
                accessToken: accessToken,
                child: RideRatingPanel(
                  tripId: id,
                  driverName: driverName,
                  onDone: (rated) {
                    if (rated) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(
                          content: Text(sgStrings(context).thanksForRating),
                        ),
                      );
                    }
                    context.go('/home');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who drove, a "View receipt" link, then the rating and Done.
class _TripSummaryBelow extends StatefulWidget {
  const _TripSummaryBelow({
    required this.tripId,
    required this.child,
    this.driverName,
    this.vehicleLine,
    this.rideService,
    this.openUrl,
    this.accessToken,
  });

  final String tripId;
  final String? driverName, vehicleLine;
  final RideService? rideService;
  final Future<bool> Function(Uri url)? openUrl;
  final Future<String?> Function()? accessToken;
  final Widget child;

  @override
  State<_TripSummaryBelow> createState() => _TripSummaryBelowState();
}

class _TripSummaryBelowState extends State<_TripSummaryBelow> {
  bool _busy = false;

  Future<void> _viewReceipt() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      final token = widget.accessToken != null
          ? await widget.accessToken!()
          : (await SharedPreferences.getInstance()).getString('access_token');
      final url = token == null
          ? null
          : await (widget.rideService ?? RideService()).getReceiptPdfUrl(
              token,
              widget.tripId,
            );
      if (url != null) {
        final uri = Uri.parse(url);
        opened = widget.openUrl != null
            ? await widget.openUrl!(uri)
            : await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('The receipt is not ready yet.')),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.driverName ?? '').trim();
    final car = (widget.vehicleLine ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (name.isNotEmpty || car.isNotEmpty)
          Container(
            key: const Key('summary_driver'),
            padding: const EdgeInsets.all(SgSpace.s4),
            margin: const EdgeInsets.only(bottom: SgSpace.s3),
            decoration: BoxDecoration(
              color: SgColors.bg100,
              borderRadius: BorderRadius.circular(SgRadius.lg),
              border: Border.all(color: SgColors.goldLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR DRIVER', style: SgText.label),
                if (name.isNotEmpty)
                  Text(
                    name,
                    key: const Key('summary_driver_name'),
                    style: SgText.title,
                  ),
                if (car.isNotEmpty)
                  Text(
                    car,
                    key: const Key('summary_vehicle'),
                    style: SgText.body.copyWith(color: SgColors.inkMuted),
                  ),
              ],
            ),
          ),
        Center(
          child: TextButton(
            key: const Key('view_receipt'),
            onPressed: _busy ? null : _viewReceipt,
            child: Text(
              'View receipt',
              style: SgText.body.copyWith(
                color: SgColors.goldText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: SgSpace.s3),
        widget.child,
      ],
    );
  }
}

class _DarkMapScaffold extends StatefulWidget {
  const _DarkMapScaffold({
    required this.title,
    this.bottom,
    this.sheet,
    this.onBack,
    this.close = false,
    this.forceInProgress = false,
    this.searching = false,
    this.pulse = false,
    this.mapBottom = 300,
    this.topRight,
    this.plannedRoute,
    this.mapLabel,
  });

  /// A small label over the map ("4 min"), top centre; none when null.
  final String? mapLabel;

  /// The server's planned route for the trip, drawn on trip when present.
  final List<LatLng>? plannedRoute;

  /// Top right over the map: the SOS pill on the trip screens.
  final Widget? topRight;

  /// Read by screen readers; the sheet carries the visible words.
  final String title;

  /// Content wrapped in the standard sheet, or a ready-made [sheet].
  final Widget? bottom;
  final Widget? sheet;
  final VoidCallback? onBack;
  final bool close;
  final bool forceInProgress;

  /// Only the pickup (and nearby cars) on the map, no route.
  final bool searching;

  /// Green rings pulse out from the pickup.
  final bool pulse;

  /// How much of the map the sheet covers.
  final double mapBottom;

  @override
  State<_DarkMapScaffold> createState() => _DarkMapScaffoldState();
}

class _DarkMapScaffoldState extends State<_DarkMapScaffold>
    with TickerProviderStateMixin {
  SgMapController? _mapController;
  LatLng? _animatedDriverLocation;
  MapProvider? _mapProvider;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = Provider.of<MapProvider>(context, listen: false);
      _mapProvider?.addListener(_handleMapUpdate);
      _handleMapUpdate(); // Initial sync
    });
  }

  void _handleMapUpdate() {
    if (!mounted) return;
    final mapProvider = _mapProvider;
    if (mapProvider == null) return;

    if (mapProvider.driverLocation != null && _animatedDriverLocation == null) {
      setState(() => _animatedDriverLocation = mapProvider.driverLocation);
      _fitDriverAndTarget();
    } else if (mapProvider.driverLocation != null &&
        _animatedDriverLocation != mapProvider.driverLocation) {
      _animateMarker(mapProvider.driverLocation!);
      _fitDriverAndTarget(); // Re-fit as driver moves
    }

    // Also re-fit if the ride status changes (e.g., from accept to start)
    final currentStatus = mapProvider.rideRequestResponse?['status'];
    if (currentStatus != _lastStatus) {
      _lastStatus = currentStatus;
      _fitDriverAndTarget();

      // Initialize arrival polyline if entering arrival phase
      if (currentStatus == 'accept' || currentStatus == 'arrive') {
        mapProvider.updateArrivingPolyline();
      }
    }
  }

  void _fitDriverAndTarget() {
    final mapProvider = _mapProvider;
    if (mapProvider == null || mapProvider.driverLocation == null) return;

    final bool isInProgress =
        widget.forceInProgress ||
        mapProvider.rideRequestResponse?['status'] == 'start' ||
        mapProvider.rideRequestResponse?['status'] == 'active';

    final targetLocation = isInProgress
        ? mapProvider.dropLocation?.latLng
        : (mapProvider.precisePickupLocation ??
              mapProvider.pickupLocation?.latLng);

    if (targetLocation == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController?.fitPoints([
        mapProvider.driverLocation!,
        targetLocation,
      ], padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 180));
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleMapUpdate);
    super.dispose();
  }

  void _animateMarker(LatLng target) {
    if (_animatedDriverLocation == null) return;

    final start = _animatedDriverLocation!;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    controller.addListener(() {
      if (!mounted) {
        controller.stop();
        return;
      }
      setState(() {
        _animatedDriverLocation = LatLng(
          start.latitude + (target.latitude - start.latitude) * animation.value,
          start.longitude +
              (target.longitude - start.longitude) * animation.value,
        );
      });
    });

    controller.forward().then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, child) {
          final markers = <SgMarker>[];

          final bool isInProgress =
              widget.forceInProgress ||
              mapProvider.rideRequestResponse?['status'] == 'start' ||
              mapProvider.rideRequestResponse?['status'] == 'active';

          if (mapProvider.pickupLocation != null && !isInProgress) {
            markers.add(
              SgMarker(
                id: 'pickup',
                point:
                    mapProvider.precisePickupLocation ??
                    mapProvider.pickupLocation!.latLng,
                icon: sgPickupIcon,
                anchor: sgJourneyAnchor,
                label: sgStrings(context).pickupLabel,
              ),
            );
          }

          if (mapProvider.dropLocation != null &&
              !widget.searching &&
              (!mapProvider.isDriverArriving || isInProgress)) {
            markers.add(
              SgMarker(
                id: 'drop',
                point: mapProvider.dropLocation!.latLng,
                icon: sgDropIcon,
                anchor: sgJourneyAnchor,
                label: sgStrings(context).dropLabel,
              ),
            );
          }

          if (_animatedDriverLocation != null &&
              mapProvider.rideRequestResponse != null) {
            markers.add(
              SgMarker(
                id: 'driver',
                point: _animatedDriverLocation!,
                icon: const SgCarMarker(),
                anchor: const Offset(0.5, 0.5),
                label: sgStrings(context).yourDriver,
              ),
            );
          }

          var n = 0;
          for (var driver in mapProvider.nearbyDrivers) {
            final lat = driver['latitude'] ?? driver['lat'];
            final lng = driver['longitude'] ?? driver['lng'];
            if (lat != null && lng != null) {
              markers.add(
                SgMarker(
                  id: 'nearby-${n++}',
                  point: LatLng(lat.toDouble(), lng.toDouble()),
                  icon: SgIconMarker(
                    Icons.directions_car,
                    SgColors.goldText,
                    size: 24,
                  ),
                  anchor: const Offset(0.5, 0.5),
                ),
              );
            }
          }

          // Gold is the trip; the way to the pickup is a quiet dotted line.
          final planned = widget.plannedRoute;
          final polylines = <SgPolyline>[
            if (isInProgress && planned != null && planned.length >= 2)
              SgPolyline(
                id: 'route',
                points: planned,
                color: SgColors.route,
                width: SgColors.routeWidth,
              )
            else if (!widget.searching &&
                mapProvider.polylineCoordinates.isNotEmpty &&
                (isInProgress || mapProvider.driverLocation != null))
              SgPolyline(
                id: 'route',
                points: mapProvider.polylineCoordinates,
                color: isInProgress ? SgColors.route : SgColors.inkMuted,
                width: isInProgress ? SgColors.routeWidth : 3,
                dotted: !isInProgress,
              ),
          ];

          final pickupPoint =
              mapProvider.precisePickupLocation ??
              mapProvider.pickupLocation?.latLng;
          final initialCenter = widget.searching
              ? (pickupPoint ?? const LatLng(17.385044, 78.4867))
              : (mapProvider.dropLocation?.latLng ??
                    mapProvider.pickupLocation?.latLng ??
                    const LatLng(17.385044, 78.4867));

          // Tablet: the map on the left, the sheet as a 440 panel beside it.
          final tablet = sgIsTablet(context);
          final mapBottom = tablet ? 0.0 : widget.mapBottom;
          final mapStack = Stack(
            children: [
              SgMap(
                initialCenter: initialCenter,
                initialZoom: widget.searching ? 15 : 14,
                markers: markers,
                polylines: polylines,
                // The sheet covers the lower part of the map.
                padding: EdgeInsets.only(bottom: mapBottom, top: 96),
                onMapCreated: (c) {
                  _mapController = c;
                  _fitDriverAndTarget();
                },
              ),
              if (widget.pulse)
                Positioned(
                  top: 96,
                  bottom: mapBottom,
                  left: 0,
                  right: 0,
                  child: const PulseRings(),
                ),
              Positioned(
                top: MediaQuery.of(context).padding.top + SgSpace.s2,
                left: SgSpace.s4,
                child: SgMapButton(
                  icon: widget.close ? SgIcons.close : SgIcons.back,
                  label: widget.close ? 'Close' : sgStrings(context).back,
                  onTap: widget.onBack ?? () => context.pop(),
                ),
              ),
              if (widget.topRight != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + SgSpace.s2,
                  right: SgSpace.s4,
                  child: widget.topRight!,
                ),
              if (widget.mapLabel != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + SgSpace.s2 + 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      key: const Key('map_eta_label'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: SgSpace.s3,
                        vertical: SgSpace.s1,
                      ),
                      decoration: BoxDecoration(
                        color: SgColors.bg100,
                        borderRadius: BorderRadius.circular(SgRadius.pill),
                        border: Border.all(color: SgColors.goldLine),
                      ),
                      child: Text(
                        widget.mapLabel!,
                        style: SgText.caption.copyWith(
                          color: SgColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
          final sheet = Semantics(
            container: true,
            label: widget.title,
            child: widget.sheet ?? SgSheetSurface(child: widget.bottom!),
          );
          if (tablet) return SgMapSplit(map: mapStack, sheet: sheet);
          // Phone: the sheet floats over the map and scrolls when it is
          // taller than the room (landscape, a large text size).
          return Stack(
            children: [
              Positioned.fill(child: mapStack),
              Align(
                alignment: Alignment.bottomCenter,
                child: SgScrollingSheet(child: sheet),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.name,
    required this.eta,
    required this.fare,
    required this.icon,
    this.active = false,
  });

  final String name;
  final String eta;
  final String fare;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? SgColors.goldSoft : SgColors.bg200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? SgColors.goldLine : SgColors.lineStrong,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: SgColors.goldText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: SgColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(eta, style: TextStyle(color: SgColors.inkMuted)),
              ],
            ),
          ),
          Text(
            fare,
            style: TextStyle(
              color: SgColors.goldText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SgColors.bg000,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SgColors.line),
      ),
      child: child,
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SgColors.bg200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SgColors.line),
      ),
      child: child,
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SgColors.bg200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SgColors.line),
      ),
      child: ListTile(
        leading: Icon(icon, color: SgColors.goldText),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.label,
    this.iconBackground,
  });

  final IconData icon;
  final String label;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SgColors.bg300,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SgColors.line),
        boxShadow: [
          BoxShadow(
            color: SgColors.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground ?? SgColors.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SgColors.goldText, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: SgColors.ink,
              fontSize: SgText.sizeTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSearchField extends StatelessWidget {
  const _HelpSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: SgColors.bg300,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SgColors.line),
      ),
      child: TextField(
        cursorColor: SgColors.goldText,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          color: SgColors.ink,
          fontSize: SgText.sizeBody,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 54,
          ),
          prefixIcon: Icon(Icons.search, color: SgColors.inkMuted, size: 24),
          hintText: sgStrings(context).searchForHelp,
          hintStyle: TextStyle(
            color: SgColors.inkMuted,
            fontSize: SgText.sizeBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SgColors.goldSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SgColors.goldLine),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SgColors.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SgColors.goldText, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: SgColors.ink,
                    fontSize: SgText.sizeBody,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: SgColors.inkMuted,
                    fontSize: SgText.sizeSmall,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: SgColors.inkMuted, size: 24),
        ],
      ),
    );
  }
}

class _HelpSectionLabel extends StatelessWidget {
  const _HelpSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: SgText.eyebrow.copyWith(color: SgColors.inkMuted),
    );
  }
}

// _FareBreakdown and _FareLine used to live here, built but never rendered.
// They are now lib/widgets/fare_breakdown.dart, public, and actually shown on
// the booking screen behind "How is this fare calculated?". Kept out of this
// file so there is one implementation rather than a rendered copy and a
// forgotten one.

class SmoothAnimatedMarker extends StatefulWidget {
  const SmoothAnimatedMarker({super.key, required this.child});
  final Widget child;

  @override
  State<SmoothAnimatedMarker> createState() => _SmoothAnimatedMarkerState();
}

class _SmoothAnimatedMarkerState extends State<SmoothAnimatedMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 2.0).animate(_animation),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: SgColors.gold500.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
