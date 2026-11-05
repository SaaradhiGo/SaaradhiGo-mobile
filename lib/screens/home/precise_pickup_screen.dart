import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/maps/sg_map.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/map_provider.dart';
import '../../ui/choose_ride_sheet.dart';
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
  Future<void> _onIdle() async {
    final at = _snappedLocation;
    final provider = _mapProvider;
    if (at == null || provider == null) return;
    final ticket = ++_lookup;
    final found = await provider.addressFor(at);
    if (mounted && ticket == _lookup && found != null) setState(() => _address = found);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, child) {
          final options = RideOption.fromEstimates(mapProvider.fareEstimates);
          RideOption? chosen;
          for (final o in options) {
            if (o.type == mapProvider.selectedVehicleType) chosen = o;
          }
          final address = _address ??
              mapProvider.pickupAddress ??
              mapProvider.pickupLocation?.name ??
              'Your pickup point';
          final eta = chosen?.etaMin;
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SgMap(
                        initialCenter:
                            mapProvider.pickupLocation?.latLng ?? const LatLng(17.385044, 78.4867),
                        initialZoom: 17,
                        onCameraMove: (camera) {
                          if (camera.byGesture) _updateSnapping(camera.center);
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
                      child: Transform.translate(offset: const Offset(0, -44), child: const FixedPickupPin()),
                    ),
                    if (eta != null)
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: const Offset(0, -112),
                          child: MapChip('Pickup in $eta min'),
                        ),
                      ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + SgSpace.s2,
                      left: SgSpace.s4,
                      child: SgMapButton(icon: SgIcons.back, label: 'Back', onTap: () => context.pop()),
                    ),
                  ],
                ),
              ),
              ConfirmPickupSheet(
                address: address,
                lockText: chosen == null
                    ? 'Drivers see your fare before they accept.'
                    : 'Fare locked at ${chosen.fareText}. Drivers see it before they accept.',
                buttonLabel: chosen == null ? 'Request ride' : 'Request ${chosen.shortName}',
                onConfirm: _snappedLocation == null
                    ? null
                    : () {
                        context.read<MapProvider>().setPrecisePickupLocation(
                          _snappedLocation!,
                          address: _address,
                        );
                        context.push('/searching-driver');
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}
