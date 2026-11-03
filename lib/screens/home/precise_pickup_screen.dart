import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/maps/sg_map.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/map_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12110E),
      body: Stack(
        children: [
          // Map Background
          Consumer<MapProvider>(
            builder: (context, mapProvider, child) {
              return SgMap(
                initialCenter:
                    mapProvider.pickupLocation?.latLng ??
                    const LatLng(17.385044, 78.4867),
                initialZoom: 17,
                onCameraMove: (camera) {
                  if (camera.byGesture) _updateSnapping(camera.center);
                },
                polylines: [
                  SgPolyline(
                    id: 'route',
                    points: mapProvider.polylineCoordinates,
                    width: 5,
                    color: const Color(0xFFEEBD2B).withValues(alpha: 0.5),
                  ),
                  // The snap cue: from where the rider pointed to the road.
                  if (_centerLocation != null && _snappedLocation != null)
                    SgPolyline(
                      id: 'snap',
                      points: [_centerLocation!, _snappedLocation!],
                      width: 2,
                      color: const Color(0xFFEEBD2B).withValues(alpha: 0.3),
                    ),
                ],
                markers: [
                  if (_snappedLocation != null)
                    SgMarker(
                      id: 'pickup',
                      point: _snappedLocation!,
                      icon: const SgSvgMarker('assets/markers/pickup.svg'),
                      label: 'Pickup',
                    ),
                ],
              );
            },
          ),

          // Header
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Select precise pickup point',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1C18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFEEBD2B),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Move the map to align the center icon with your location. We will snap the pickup to the nearest road.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_snappedLocation != null) {
                        context.read<MapProvider>().setPrecisePickupLocation(
                          _snappedLocation!,
                        );
                        context.push('/searching-driver');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEBD2B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'CONFIRM PICKUP',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
