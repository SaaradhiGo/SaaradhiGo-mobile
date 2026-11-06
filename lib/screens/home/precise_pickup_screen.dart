import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/maps/sg_map.dart';
import '../../core/pricing/quote_lock.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/map_provider.dart';
import '../../core/vehicle_classes.dart';
import '../../ui/appearance_settings.dart' show sgStrings;
import '../../ui/booking_widgets.dart';
import '../../ui/choose_ride_sheet.dart';
import '../../widgets/fare_breakdown.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';
import '../../ui/trip_widgets.dart';
import '../../utils/geometry_utils.dart';

class PrecisePickupScreen extends StatefulWidget {
  const PrecisePickupScreen({super.key});

  @override
  State<PrecisePickupScreen> createState() => _PrecisePickupScreenState();
}

class _PrecisePickupScreenState extends State<PrecisePickupScreen> {
  LatLng? _snappedLocation;
  LatLng? _centerLocation;
  MapProvider? _mapProvider;
  bool _isNavigated = false;

  /// Where the pin is now, once the map has stopped after a drag.
  String? _address;
  int _lookup = 0;

  /// The rider has moved the pin. From then on the ticket's fare is the one
  /// quoted for the pin, re-quoted each time the map stops.
  bool _dragged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = context.read<MapProvider>();
      _mapProvider?.addListener(_handleStateChange);

      _centerLocation = _mapProvider?.pickupLocation?.latLng;
      _updateSnapping(_centerLocation);

      _handleStateChange(); // Initial check
    });
  }

  @override
  void dispose() {
    _mapProvider?.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted || _isNavigated || _mapProvider == null) return;

    final status = _mapProvider?.rideRequestResponse?['status'];

    if (status == 'start' || status == 'accept' || status == 'active') {
      _isNavigated = true;
      String target = (status == 'start') ? '/tracking' : '/driver-found';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          context.pushReplacement(target);
        }
      });
    }
  }

  void _updateSnapping(LatLng? center) {
    if (center == null) return;
    final mapProvider = context.read<MapProvider>();
    final nearest = GeometryUtils.findNearestPointOnPolyline(
      center,
      mapProvider.polylineCoordinates,
    );
    setState(() {
      _snappedLocation = nearest;
      _centerLocation = center;
    });
  }

  /// The new spot's address, if the geocoder answers; else the old one stays.
  ///
  /// A moved pin is re-quoted at once, before the rider can book: the quote
  /// the booking carries is for exactly this pickup, so the ticket always
  /// shows the fare that will be booked.
  Future<void> _onIdle() async {
    final at = _snappedLocation;
    final provider = _mapProvider;
    if (at == null || provider == null) return;
    if (_dragged) provider.setPrecisePickupLocation(at, address: _address);
    final ticket = ++_lookup;
    final found = await provider.addressFor(at);
    if (mounted && ticket == _lookup && found != null) {
      setState(() => _address = found);
      // Same spot, so no new quote: only the booking's address text.
      if (_dragged) provider.setPrecisePickupLocation(at, address: found);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, child) => ListenableBuilder(
          listenable: QuoteLockState.instance,
          builder: (context, _) => _body(context, mapProvider),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, MapProvider mapProvider) {
    final options = RideOption.fromEstimates(mapProvider.fareEstimates);
    RideOption? chosen;
    for (final o in options) {
      if (o.type == mapProvider.selectedVehicleType) chosen = o;
    }
    final l = sgStrings(context);
    final address =
        _address ??
        mapProvider.pickupAddress ??
        mapProvider.pickupLocation?.name ??
        l.pickupLabel;
    final type = mapProvider.selectedVehicleType;
    final estimate = type == null ? null : mapProvider.fareEstimates[type];
    final requoting =
        mapProvider.isLoadingRoute ||
        mapProvider.isLoadingFares ||
        (_dragged && _snappedLocation != mapProvider.precisePickupLocation);
    final refresh = QuoteLockState.instance.pending;
    final String? notice;
    if (requoting) {
      notice = l.fareUpdating;
    } else if (refresh != null &&
        chosen != null &&
        (refresh.vehicleType == null || refresh.vehicleType == type)) {
      notice = refresh.reason == QuoteChangeReason.moved
          ? l.fareUpdatedPickupChanged(chosen.fareText)
          : l.fareUpdatedTimePassed(chosen.fareText);
    } else {
      notice = null;
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SgMap(
                  initialCenter:
                      mapProvider.pickupLocation?.latLng ??
                      const LatLng(17.385044, 78.4867),
                  initialZoom: 17,
                  onCameraMove: (camera) {
                    if (!camera.byGesture) return;
                    _dragged = true;
                    _updateSnapping(camera.center);
                  },
                  onCameraIdle: _onIdle,
                  polylines: [
                    SgPolyline(
                      id: 'route',
                      points: mapProvider.polylineCoordinates,
                      width: 5,
                      color: SgColors.gold500.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
              // The pin never moves; the map slides under it.
              Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(0, -44),
                  child: const FixedPickupPin(),
                ),
              ),
              // The pickup point's name, over the pin.
              Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(0, -112),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: MapChip(address.split(',').first.trim()),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + SgSpace.s2,
                left: SgSpace.s4,
                child: SgMapButton(
                  icon: SgIcons.back,
                  label: 'Back',
                  onTap: () => context.pop(),
                ),
              ),
            ],
          ),
        ),
        FareTicketSheet(
          buttonLabel: l.confirmAndBook,
          notice: notice,
          ticket: FareTicket(
            eyebrow: l.fareTicket,
            vehicleType: mapProvider.selectedVehicleType,
            className: vehicleClassName(mapProvider.selectedVehicleType),
            fareText: chosen?.fareText ?? '',
            lockText: l.fareLocked,
            pickupLabel: l.pickupLabel,
            pickup: address,
            dropLabel: l.dropLabel,
            drop: mapProvider.destinationAddress,
            editLabel: l.edit,
            // The pin is already draggable: Edit says so.
            onEditPickup: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l.dragToMove))),
            breakdownLabel: (chosen == null || estimate == null)
                ? null
                : l.seeHowWorkedOut(chosen.fareText),
            onBreakdown: estimate == null
                ? null
                : () => showFareBreakdownSheet(context, estimate),
          ),
          // Only the fare on the ticket can be booked: nothing while
          // it is being re-quoted, or when there is no fare to show.
          onConfirm: (_snappedLocation == null || requoting || chosen == null)
              ? null
              : () => context.push('/searching-driver'),
        ),
      ],
    );
  }
}
