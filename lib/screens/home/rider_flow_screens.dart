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
import '../../core/market/market_config_store.dart';
import '../components/market_overlays.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'package:provider/provider.dart' as p;
import '../../utils/money.dart';
import '../../widgets/safety_sheet.dart';
import '../../state/ride_notifier.dart';
import '../../state/ride_state.dart';
import '../../core/vehicle_classes.dart';
import '../../ui/appearance_settings.dart' show sgStrings;
import '../../ui/booking_widgets.dart';
import '../../ui/choose_ride_sheet.dart';
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
  final confirmed = await provider.cancelRideRequest();
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

  String? get vehicleLine {
    final color = (vehicle['color'] ?? '').toString().trim();
    final line = [
      if (_model.isNotEmpty) _model,
      if (color.isNotEmpty) color,
    ].join(' \u00B7 ');
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

/// Whole minutes from "3 mins" / "1 hour 5 mins"; null when there is no number.
int? _minutesOf(String? text) {
  if (text == null) return null;
  var total = 0;
  var found = false;
  for (final m in RegExp(
    r'(\d+)\s*(hour|hr|h|min)',
  ).allMatches(text.toLowerCase())) {
    found = true;
    final n = int.parse(m.group(1)!);
    total += m.group(2) == 'min' ? n : n * 60;
  }
  if (found) return total;
  final plain = int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '');
  return plain;
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

Future<void> _callDriver(BuildContext context, _DriverView d) async {
  void say(String m) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  // Only a tel: link; the number is never shown (privacy posture, Phase-0).
  final raw = (d.info['phone'] ?? d.ride['driver_phone'] ?? '').toString();
  if (raw.isEmpty) {
    return say('Driver phone unavailable. Use in-app chat instead.');
  }
  try {
    if (!await launchUrl(Uri(scheme: 'tel', path: raw))) {
      say('Could not open dialer on this device.');
    }
  } catch (_) {
    say('Could not start a call.');
  }
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
              style: TextStyle(fontWeight: FontWeight.w700),
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
      _startSearch();
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
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          child: _DarkMapScaffold(
            title: failure == null
                ? 'Finding your Saaradhi'
                : 'No Saaradhi nearby right now',
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
        // TODO(data): "Asked N drivers nearby" needs a count; the socket's
        // drivers_notified event carries none the app keeps, so the line is
        // left out.
        ChecklistItem(
          l.waitingAccept,
          ChecklistState.current,
          key: const Key('finding_waiting'),
        ),
      ],
      note: l.closeAppNote,
      cancelLabel: l.cancelRequest,
      // Said only when app-config says cancelling costs nothing
      // (cancel_policy.charges_fee == false). TODO(data): no free-cancel
      // window (free_cancel_seconds) is configured.
      cancelNote: market.freeToCancel ? l.freeToCancel : null,
      onCancel: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _failed(BuildContext context, MapProvider mp, String message) {
    return NoDriverSheet(
      subline: message == kNoDriverMessage
          ? 'Drivers nearby are busy right now. Try again, or choose another ride.'
          : message,
      fare: _lockedFare(mp),
      onTryAgain: _startSearch,
      onChangeRide: () => _leaveFailedSearch(toChooseRide: true),
    );
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: SgColors.bg200,
            title: Text(
              'Cancel Search?',
              style: TextStyle(
                color: SgColors.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel your ride request?',
              style: TextStyle(color: SgColors.inkMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Wait', style: TextStyle(color: SgColors.goldText)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Cancel Anyway',
                  style: TextStyle(color: SgColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);
      _handleStateChange(); // Initial check
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
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
        final mins = mapProvider.driverLocation == null
            ? null
            : _minutesOf(mapProvider.duration);
        final who = d.first.isEmpty ? 'Your driver' : d.first;
        final headline = arrived
            ? (d.first.isEmpty ? 'Your driver has arrived' : '$who has arrived')
            : (mins == null ? '$who is on the way' : '$who is $mins min away');

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
              Navigator.of(context).pop();
            }
          },
          child: _DarkMapScaffold(
            title: headline,
            close: true,
            mapBottom: 470,
            onBack: () async {
              if (mounted && context.mounted) {
                Navigator.of(context).maybePop();
              }
            },
            sheet: ArrivingSheet(
              headline: headline,
              badge: arrived ? 'Arrived' : 'On the way',
              meetLine: d.meetLine,
              driver: d.card,
              photoUrl: d.photo,
              pin: d.pin,
              onCancel: () => Navigator.of(context).maybePop(),
              actions: [
                SgActionData(
                  key: 'arriving_call',
                  label: 'Call',
                  icon: SgIcons.call,
                  onTap: () => _callDriver(context, d),
                ),
                SgActionData(
                  key: 'arriving_message',
                  label: 'Message',
                  icon: SgIcons.message,
                  onTap: () => _openChat(context, d),
                ),
                SgActionData(
                  key: 'arriving_share',
                  label: 'Share trip',
                  icon: SgIcons.share,
                  onTap: () => shareTripDetails(context, d.safety),
                ),
                _safetyAction(
                  const ValueKey('arriving_sos_button'),
                  () => showSafetySheet(context, trip: d.safety),
                ),
              ],
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
          'Ongoing Ride',
          style: TextStyle(color: SgColors.ink, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You have an active ride request. Are you sure you want to cancel?',
          style: TextStyle(color: SgColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Wait', style: TextStyle(color: SgColors.goldText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cancel Anyway',
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
        if (confirmed && context.mounted) context.pop();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);
      _handleStateChange(); // Initial check
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
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
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel your ongoing ride?',
              style: TextStyle(color: SgColors.inkMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Continue Ride',
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
        final mins = _minutesOf(mapProvider.duration);
        final headline = [
          drop.isEmpty ? 'On the way' : 'On the way to $drop',
          if (mins != null) '$mins min',
        ].join(' \u00B7 ');
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
              Navigator.of(context).pop();
            }
          },
          child: _DarkMapScaffold(
            title: headline,
            close: true,
            mapBottom: 330,
            onBack: () async {
              if (mounted && context.mounted) {
                Navigator.of(context).maybePop();
              }
            },
            forceInProgress: true,
            sheet: LiveTripSheet(
              headline: headline,
              driver: d.card,
              extra: ride?['status'] == 'complete'
                  ? SgPrimaryButton(
                      label: 'View summary',
                      onPressed: () => context.push('/ride-summary'),
                    )
                  : null,
              actions: [
                SgActionData(
                  key: 'tracking_share',
                  label: 'Share trip',
                  icon: SgIcons.share,
                  onTap: () =>
                      shareTripDetails(context, _safetyContext(mapProvider)),
                ),
                // The safety sheet POSTs /sos/, offers 112, and shows a failure
                // instead of swallowing it. Always one tap from this screen.
                _safetyAction(
                  const ValueKey('tracking_sos_button'),
                  () => showSafetySheet(
                    context,
                    trip: _safetyContext(mapProvider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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

  /// The trip to rate, captured on open: every payment path clears the local
  /// ride state before the rating screen, which then had nothing to rate.
  String? _rateTripId;
  String? _rateDriverName;

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
      _rateDriverName = raw is Map ? raw['driver_name']?.toString() : null;
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
    });
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
    await _finishCashSelection('Cash payment received. Thank you.');
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
        _showCashError('Please sign in again to pay for this trip.');
        return;
      }

      final tripIdStr =
          context.read<MapProvider>().tripId ??
          rideData?['trip_id']?.toString() ??
          rideData?['id']?.toString();
      if (tripIdStr == null) {
        _showCashError('No active trip found. Please refresh and try again.');
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
        title: const Text('Insufficient Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your wallet balance (${MarketConfigStore.instance.current.currencySymbol}${walletProvider.balance.toStringAsFixed(2)}) is less than the fare (${MarketConfigStore.instance.current.currencySymbol}${fare.toStringAsFixed(2)}).',
            ),
            const SizedBox(height: 16),
            const Text('Would you like to:'),
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
            child: const Text('Add Money'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedPaymentMethod = 'online');
            },
            child: const Text('Pay with UPI/Card'),
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
        final totalFareStr = (endedBySupport && _receipt?['final_fare'] != null)
            ? _receipt!['final_fare']
            : (rideData?['total_fare'] ??
                  rideData?['estimated_fare'] ??
                  '0.00');
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

        _fareText = exactMoney(payTotal, currencyCode);
        final walletShort = walletProvider.balance < payTotal;
        return Scaffold(
          backgroundColor: SgColors.bg000,
          body: SafeArea(
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
                    label: 'Back',
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
                TripChargeCard(
                  fare: totalFareStr.toString(),
                  currencyCode: currencyCode,
                  charge: charge,
                  endedBySupport: endedBySupport,
                  distanceDriven: distanceDriven,
                ),
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
                    title: 'Pay with Cash',
                    subtitle: 'Hand it to your driver',
                    icon: SgIcons.cash,
                    isSelected: _selectedPaymentMethod == 'cash',
                    onTap: () =>
                        setState(() => _selectedPaymentMethod = 'cash'),
                  ),
                  const SizedBox(height: SgSpace.s3),
                  _buildPaymentOption(
                    id: 'wallet',
                    title: 'Pay from Wallet',
                    subtitle: walletShort
                        ? 'Not enough balance'
                        : 'Current Balance: ${MarketConfigStore.instance.current.currencySymbol}${walletProvider.balance.toStringAsFixed(2)}',
                    icon: SgIcons.wallet,
                    isSelected: _selectedPaymentMethod == 'wallet',
                    onTap: () =>
                        setState(() => _selectedPaymentMethod = 'wallet'),
                  ),
                  const SizedBox(height: SgSpace.s3),
                  _buildPaymentOption(
                    id: 'upi_card',
                    title: 'Pay via UPI/Card',
                    icon: SgIcons.cash,
                    isSelected: _selectedPaymentMethod == 'upi_card',
                    onTap: () =>
                        setState(() => _selectedPaymentMethod = 'upi_card'),
                  ),
                  const SizedBox(height: SgSpace.s5),
                  SgPrimaryButton(
                    label: _isProcessing ? 'Processing' : 'Confirm & Pay',
                    onPressed: _isProcessing
                        ? null
                        : () => _selectedPaymentMethod == 'cash'
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
                          'Pay with Cash instead?',
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
        );
      },
    );
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
  });

  final String? tripId;
  final String? driverName;

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
              below: RideRatingPanel(
                tripId: id,
                driverName: driverName,
                onDone: (rated) {
                  if (rated) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text('Thanks for rating your trip.'),
                      ),
                    );
                  }
                  context.go('/home');
                },
              ),
            ),
          ],
        ),
      ),
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
  });

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
                icon: const SgSvgMarker('assets/markers/pickup.svg'),
                label: 'Pickup',
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
                icon: const SgSvgMarker('assets/markers/dropoff.svg'),
                label: 'Drop',
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
                label: 'Your driver',
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
          final polylines = <SgPolyline>[
            if (!widget.searching &&
                mapProvider.polylineCoordinates.isNotEmpty &&
                (isInProgress || mapProvider.driverLocation != null))
              SgPolyline(
                id: 'route',
                points: mapProvider.polylineCoordinates,
                color: isInProgress ? SgColors.gold500 : SgColors.inkMuted,
                width: isInProgress ? 4.5 : 3,
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

          return Stack(
            children: [
              SgMap(
                initialCenter: initialCenter,
                initialZoom: widget.searching ? 15 : 14,
                markers: markers,
                polylines: polylines,
                // The sheet covers the lower part of the map.
                padding: EdgeInsets.only(bottom: widget.mapBottom, top: 96),
                onMapCreated: (c) {
                  _mapController = c;
                  _fitDriverAndTarget();
                },
              ),
              if (widget.pulse)
                Positioned(
                  top: 96,
                  bottom: widget.mapBottom,
                  left: 0,
                  right: 0,
                  child: const PulseRings(),
                ),
              Positioned(
                top: MediaQuery.of(context).padding.top + SgSpace.s2,
                left: SgSpace.s4,
                child: SgMapButton(
                  icon: widget.close ? SgIcons.close : SgIcons.back,
                  label: widget.close ? 'Close' : 'Back',
                  onTap: widget.onBack ?? () => context.pop(),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Semantics(
                  container: true,
                  label: widget.title,
                  child: widget.sheet ?? SgSheetSurface(child: widget.bottom!),
                ),
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
                    fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
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
          fontSize: 16,
          fontWeight: FontWeight.w500,
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
          hintText: 'Search for help',
          hintStyle: TextStyle(
            color: SgColors.inkMuted,
            fontSize: 16,
            fontWeight: FontWeight.w500,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: SgColors.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
      style: TextStyle(
        color: SgColors.inkMuted,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.4,
      ),
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
