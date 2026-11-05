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
import 'package:google_fonts/google_fonts.dart';
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
import '../../widgets/rate_trip_sheet.dart';
import '../../state/ride_notifier.dart';
import '../../state/ride_state.dart';

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
      const SnackBar(
        duration: Duration(seconds: 6),
        backgroundColor: Color(0xFFB00020),
        content: Text(
          'We could not cancel your ride. It is still active — please try '
          'again.',
        ),
      ),
    );
  }
  return confirmed;
}

class SetDestinationScreen extends StatelessWidget {
  const SetDestinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DarkMapScaffold(
      title: 'Set Destination',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.place, color: Color(0xFFEEBD2B)),
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
  Future<void> _leaveFailedSearch() async {
    await _mapProvider?.container
        ?.read(rideNotifierProvider.notifier)
        .clearState();
    if (!mounted) return;
    setState(() => _canPop = true);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return riverpod.Consumer(
      builder: (context, ref, _) {
        final failure = ref.watch(
          rideNotifierProvider.select((s) => s.searchFailure),
        );
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
            title: failure == null ? 'Finding your ride…' : 'No ride yet',
            backIcon: Icons.close,
            bottom: failure == null
                ? _searching(context)
                : _failed(context, failure),
          ),
        );
      },
    );
  }

  Widget _searching(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Searching for a driver',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFEEBD2B),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Asking drivers near your pickup.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cancel search'),
        ),
      ],
    );
  }

  Widget _failed(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _startSearch,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEEBD2B),
            foregroundColor: const Color(0xFF12110E),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Try again',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _leaveFailedSearch,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Change ride'),
        ),
      ],
    );
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1C18),
            title: Text(
              'Cancel Search?',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel your ride request?',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Wait',
                  style: GoogleFonts.inter(color: const Color(0xFFEEBD2B)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Cancel Anyway',
                  style: GoogleFonts.inter(color: Colors.redAccent),
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

        // Extracting data with fallbacks
        final driverInfo = rideData?['driver_info'] as Map<String, dynamic>?;
        final driverName =
            driverInfo?['name'] ?? rideData?['driver_name'] ?? 'Searching...';
        final driverStars = driverInfo?['stars']?.toString() ?? '5.0';
        final driverPhoto = driverInfo?['photo_url'];

        final vehicleData = rideData?['vehicle_info'] as Map<String, dynamic>?;
        final vehicleBrand = vehicleData?['brand'] ?? '';
        final vehicleModel = vehicleData?['model'] ?? '';
        final vehicleColor = vehicleData?['color'] ?? '';
        final vehicleNumber =
            vehicleData?['vehicle_number'] ??
            rideData?['vehicle_number'] ??
            '...';

        final vehicleSummary =
            (vehicleBrand.isNotEmpty && vehicleModel.isNotEmpty)
            ? '$vehicleColor $vehicleBrand $vehicleModel'
            : rideData?['vehicle_info_summary'] ?? 'Vehicle Details';

        final otp = rideData?['otp'] ?? '----';

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
            // "Arriving" stayed up after the driver reached the pickup.
            title: mapProvider.container?.read(rideNotifierProvider).status ==
                    RideStatus.driverArrived
                ? 'Your driver is here'
                : 'Your driver is on the way',
            backIcon: Icons.close,
            onBack: () async {
              if (mounted && context.mounted) {
                Navigator.of(context).maybePop();
              }
            },
            bottom: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Driver & Vehicle Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(
                          0xFFEEBD2B,
                        ).withValues(alpha: 0.2),
                        backgroundImage: driverPhoto != null
                            ? NetworkImage(driverPhoto)
                            : null,
                        child: driverPhoto == null
                            ? const Icon(
                                Icons.person,
                                color: Color(0xFFEEBD2B),
                                size: 32,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                driverName,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Color(0xFFEEBD2B),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$driverStars • Professional Driver',
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _ActionButton(
                            icon: Icons.chat_bubble_outline,
                            onTap: () {
                              // Open in-trip chat. tripId is whatever
                              // the rideData payload exposed; fall back
                              // to 0 (skip) when not present.
                              final tripIdRaw =
                                  rideData?['trip_id'] ?? rideData?['id'];
                              final tripId = tripIdRaw is int
                                  ? tripIdRaw
                                  : int.tryParse('$tripIdRaw') ?? 0;
                              if (tripId <= 0) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TripChatScreen(
                                    tripId: tripId,
                                    myRole: 'rider',
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          _ActionButton(
                            key: const Key('arriving_sos_button'),
                            icon: Icons.shield_outlined,
                            label: 'Safety and SOS',
                            color: const Color(0xFFDC2626),
                            onTap: () => showSafetySheet(
                              context,
                              trip: TripSafetyContext(
                                tripId: (rideData?['trip_id'] ??
                                        rideData?['id'])
                                    ?.toString(),
                                driverName: driverName?.toString(),
                                vehicleNumber: vehicleNumber?.toString(),
                                vehicleModel: vehicleModel?.toString(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _ActionButton(
                            icon: Icons.phone_outlined,
                            // Privacy posture (Phase-0): we launch the
                            // OS dialer with a tel: deep link but never
                            // display the driver's number on screen.
                            // When we wire a phone-masking proxy
                            // (Exotel / Knowlarity, Phase-1), the
                            // backend will return a proxy number here
                            // and the UX is unchanged for the rider.
                            onTap: () async {
                              final raw =
                                  (driverInfo?['phone'] ??
                                          rideData?['driver_phone'] ??
                                          '')
                                      .toString();
                              if (raw.isEmpty) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Driver phone unavailable. Use in-app chat instead.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              final uri = Uri(scheme: 'tel', path: raw);
                              try {
                                final ok = await launchUrl(uri);
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not open dialer on this device.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not start a call.'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Vehicle Detail Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_car_filled_outlined,
                        color: Color(0xFFEEBD2B),
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicleSummary,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              vehicleNumber.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: const Color(0xFFEEBD2B),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // OTP Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEEBD2B).withValues(alpha: 0.15),
                        const Color(0xFFEEBD2B).withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFEEBD2B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'PIN TO START THE TRIP',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEEBD2B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        otp.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share this PIN with your driver only',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Primary Action
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => context.push('/tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEBD2B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'LIVE TRACKING',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(
                      'Cancel Ride',
                      style: GoogleFonts.inter(
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
        backgroundColor: const Color(0xFF1E1C18),
        title: Text(
          'Ongoing Ride',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You have an active ride request. Are you sure you want to cancel?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Wait',
              style: GoogleFonts.inter(color: const Color(0xFFEEBD2B)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cancel Anyway',
              style: GoogleFonts.inter(color: Colors.redAccent),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final Color? color;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withValues(alpha: color == null ? 0.1 : 0.2),
            borderRadius: BorderRadius.circular(12),
            border: color == null ? null : Border.all(color: color!),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
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
            backgroundColor: const Color(0xFF1E1C18),
            title: Text(
              'Cancel Ride?',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel your ongoing ride?',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Continue Ride',
                  style: GoogleFonts.inter(color: const Color(0xFFEEBD2B)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Cancel Ride',
                  style: GoogleFonts.inter(color: Colors.red),
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
            title: 'Ride in Progress',
            backIcon: Icons.close,
            onBack: () async {
              if (mounted && context.mounted) {
                Navigator.of(context).maybePop();
              }
            },
            forceInProgress: true,
            bottom: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mapProvider.duration ?? '-- min',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        marketOf(
                              context,
                            ).displayDistance(mapProvider.distance) ??
                            marketOf(context).distancePlaceholder,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // SOS.
                //
                // This button used to open a dialog that said "This will alert
                // the nearest authorities and our support team", and on
                // confirm showed the snackbar "Emergency Alert Sent! Support
                // is on the way." It called no API. Nothing was sent, nobody
                // was alerted, and the rider was told help was coming.
                //
                // It now opens the safety sheet, which POSTs to /sos/ (a
                // durable row server-side, then an ops push and an SMS to the
                // rider's emergency contact), offers 112 directly, and shows
                // the failure if the POST does not succeed.
                GestureDetector(
                  key: const Key('tracking_sos_button'),
                  onTap: () => showSafetySheet(
                    context,
                    trip: _safetyContext(mapProvider),
                  ),
                  child: Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'SOS',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            action: mapProvider.rideRequestResponse?['status'] == 'complete'
                ? ElevatedButton(
                    onPressed: () => context.push('/ride-summary'),
                    child: const Text('View Summary'),
                  )
                : null,
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
  String _selectedPaymentMethod = 'wallet';
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

  void _goRate() {
    context.go(
      '/rate-driver',
      extra: {'trip_id': _rateTripId, 'driver_name': _rateDriverName},
    );
  }

  /// The driver confirming the cash, heard while this screen is open.
  riverpod.ProviderSubscription<RideState>? _cashSub;
  bool _cashHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mp = context.read<MapProvider>();
      final raw = mp.rideRequestResponse;
      _rateTripId = mp.tripId ??
          (raw is Map ? (raw['trip_id'] ?? raw['id'])?.toString() : null);
      _rateDriverName = raw is Map ? raw['driver_name']?.toString() : null;
      _cashSub = mp.container?.listen<RideState>(
        rideNotifierProvider,
        (_, next) {
          if (next.rawResponse?['cash_confirmed'] == true) _onCashConfirmed();
        },
        fireImmediately: true,
      );
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
  Future<void> _finishCashSelection(String message) async {
    final mapProvider = p.Provider.of<MapProvider>(context, listen: false);
    await mapProvider.clearRideStateLocally();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
    _goRate();
  }

  void _showCashError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
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
            if (mounted)
              setState(() => _confirming = kPaymentConfirmingMessage);
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
        if (mounted) _goRate();
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
            content: Text(result.message ?? kPaymentUnavailableMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  Future<void> _continueWhenNotCharged() async {
    final mapProvider = p.Provider.of<MapProvider>(context, listen: false);
    await mapProvider.clearRideStateLocally();
    if (mounted) _goRate();
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

        return Scaffold(
          backgroundColor: const Color(0xFF12110E),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Payment Methods',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                TripChargeCard(
                  fare: totalFareStr.toString(),
                  currencyCode: currencyCode,
                  charge: charge,
                  endedBySupport: endedBySupport,
                  distanceDriven: distanceDriven,
                ),
                if (_confirming != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _confirming!,
                    key: const Key('payment_confirming'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEEBD2B),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                if (charge.notCharged)
                  NotChargedPanel(
                    message: _notChargedMessage,
                    onContinue: _continueWhenNotCharged,
                  )
                else ...[
                  // Payment Options List
                  _buildPaymentOption(
                    id: 'wallet',
                    title: 'Pay from Wallet',
                    subtitle:
                        'Current Balance: ${MarketConfigStore.instance.current.currencySymbol}${walletProvider.balance.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet,
                    isSelected: _selectedPaymentMethod == 'wallet',
                    onTap: () =>
                        setState(() => _selectedPaymentMethod = 'wallet'),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    id: 'upi_card',
                    title: 'Pay via UPI/Card',
                    icon: Icons.credit_card,
                    isSelected: _selectedPaymentMethod == 'upi_card',
                    onTap: () =>
                        setState(() => _selectedPaymentMethod = 'upi_card'),
                  ),

                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _processPayment(
                              payTotal,
                              walletProvider,
                              rideData,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEEBD2B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Confirm & Pay',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () =>
                                _payWithCash(payTotal, currencyCode, rideData),
                      child: Text(
                        'Pay with Cash instead?',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEEBD2B).withValues(alpha: 0.1)
              : const Color(0xFF24211C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEEBD2B)
                : const Color(0x1AFFFFFF),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFEEBD2B) : Colors.white70,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.radio_button_checked, color: Color(0xFFEEBD2B))
            else
              const Icon(Icons.radio_button_unchecked, color: Colors.white30),
          ],
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
  const RateReviewDriverScreen({super.key, this.tripId, this.driverName});

  final String? tripId;
  final String? driverName;

  @override
  Widget build(BuildContext context) {
    final id = tripId;
    if (id == null || id.isEmpty) {
      // Nothing to rate: never show a form that cannot be submitted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return const Scaffold(backgroundColor: Color(0xFF12110E));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF12110E),
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            child: RateTripSheet(
              tripId: id,
              driverName: driverName,
              onDone: (rated) {
                if (rated) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('Thanks for rating your trip.')),
                  );
                }
                context.go('/home');
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkMapScaffold extends StatefulWidget {
  const _DarkMapScaffold({
    required this.title,
    required this.bottom,
    this.action,
    this.onBack,
    this.backIcon,
    this.forceInProgress = false,
  });

  final String title;
  final Widget bottom;
  final Widget? action;
  final VoidCallback? onBack;
  final IconData? backIcon;
  final bool forceInProgress;

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
      _mapController?.fitPoints(
        [mapProvider.driverLocation!, targetLocation],
        padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 180),
      );
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
      backgroundColor: const Color(0xFF12110E),
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
                icon: const SgIconMarker(
                  Icons.directions_car,
                  Color(0xFFEEBD2B),
                  size: 34,
                ),
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
                  icon: const SgIconMarker(
                    Icons.directions_car,
                    Color(0xFFEEBD2B),
                    size: 24,
                  ),
                  anchor: const Offset(0.5, 0.5),
                ),
              );
            }
          }

          final polylines = <SgPolyline>[
            if (mapProvider.polylineCoordinates.isNotEmpty)
              SgPolyline(
                id: 'route',
                points: mapProvider.polylineCoordinates,
                color: const Color(0xFFEEBD2B),
              ),
          ];

          final initialCenter =
              mapProvider.dropLocation?.latLng ??
              mapProvider.pickupLocation?.latLng ??
              const LatLng(17.385044, 78.4867);

          return Stack(
            children: [
              SgMap(
                initialCenter: initialCenter,
                initialZoom: 14,
                markers: markers,
                polylines: polylines,
                // The sheet covers the lower part of the map.
                padding: const EdgeInsets.only(bottom: 260, top: 72),
                onMapCreated: (c) {
                  _mapController = c;
                  _fitDriverAndTarget();
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack ?? () => context.pop(),
                        icon: CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0x77000000),
                          child: Icon(
                            widget.backIcon ?? Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1C18),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 4,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      widget.bottom,
                      if (widget.action != null) ...[
                        const SizedBox(height: 10),
                        widget.action!,
                      ],
                    ],
                  ),
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
        color: active ? const Color(0x33EEBD2B) : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? const Color(0x66EEBD2B) : Colors.white24,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFEEBD2B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(eta, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Text(
            fare,
            style: const TextStyle(
              color: Color(0xFFEEBD2B),
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
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
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
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFEEBD2B)),
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
    this.iconBackground = const Color(0x1AEEBD2B),
  });

  final IconData icon;
  final String label;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
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
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFEEBD2B), size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFF8FAFC),
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
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: TextField(
        cursorColor: const Color(0xFFEEBD2B),
        textAlignVertical: TextAlignVertical.center,
        style: GoogleFonts.inter(
          color: const Color(0xFFF8FAFC),
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
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF94A3B8),
            size: 24,
          ),
          hintText: 'Search for help',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
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
        color: const Color(0x1A8B6508),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x338B6508)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0x338B6508),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFEEBD2B), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF8FAFC),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 24),
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
      style: GoogleFonts.inter(
        color: const Color(0xFF94A3B8),
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
              color: const Color(0xFFEEBD2B).withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
