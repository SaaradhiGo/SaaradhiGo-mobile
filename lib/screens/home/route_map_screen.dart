import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/maps/sg_map.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/map_provider.dart';
import '../components/coming_soon_overlay.dart';
import '../components/market_overlays.dart';
import '../../widgets/promo_entry_section.dart';
import '../../ui/appearance_settings.dart' show paymentMethodLabel, sgStrings;
import '../../ui/choose_ride_sheet.dart';
import '../../ui/trip_widgets.dart' show routeLine;
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  SgMapController? _mapController;
  MapProvider? _mapProvider;
  bool _isNavigated = false;
  bool _showTiles = false; // New flag to delay tile loading

  /// Validates if a LatLng coordinate is within reasonable bounds
  bool _isValidCoordinate(LatLng? coordinate) {
    if (coordinate == null) return false;
    // Explicitly check for NaN or infinite values which cause FlutterMap crashes
    if (coordinate.latitude.isNaN || coordinate.latitude.isInfinite) {
      return false;
    }
    if (coordinate.longitude.isNaN || coordinate.longitude.isInfinite) {
      return false;
    }

    // Check for valid latitude (-90 to 90) and longitude (-180 to 180)
    if (coordinate.latitude < -90 || coordinate.latitude > 90) return false;
    if (coordinate.longitude < -180 || coordinate.longitude > 180) return false;

    // Check for obviously invalid coordinates (0,0 might be valid but often indicates no location)
    if (coordinate.latitude == 0 && coordinate.longitude == 0) return false;
    return true;
  }

  /// A marker, or null for a coordinate that is not a real place.
  SgMarker? _buildSafeMarker({
    required String id,
    required LatLng? point,
    required SgMarkerIcon icon,
    Offset anchor = const Offset(0.5, 1.0),
    String? label,
  }) {
    if (point == null || !_isValidCoordinate(point)) return null;
    return SgMarker(
      id: id,
      point: point,
      icon: icon,
      anchor: anchor,
      label: label,
    );
  }

  /// The route, without any invalid coordinate, or null if too little is left.
  SgPolyline? _buildSafePolyline({
    required List<LatLng> points,
    required Color color,
    double strokeWidth = 4,
  }) {
    final validPoints = points.where(_isValidCoordinate).toList();
    if (validPoints.length < 2) return null;
    return SgPolyline(
      id: 'route',
      points: validPoints,
      color: color,
      width: strokeWidth,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapProvider = Provider.of<MapProvider>(context, listen: false);
      _mapProvider?.addListener(_handleStateChange);

      if (_mapProvider?.pickupLocation != null) {
        _mapProvider?.fetchNearbyDrivers(_mapProvider!.pickupLocation!.latLng);
      }

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

    if (_mapProvider!.showComingSoonOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => const ComingSoonOverlay(),
          ).then((_) {
            _mapProvider?.dismissComingSoonOverlay();
            context.pop();
          });
        }
      });
      return;
    }

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

  void _fitBoundsIfNeeded(MapProvider mapProvider) {
    if (!mounted) return;

    try {
      LatLng? pickup;
      LatLng? dropoff;

      if (mapProvider.pickupLocation != null) {
        pickup =
            mapProvider.precisePickupLocation ??
            mapProvider.pickupLocation!.latLng;
        if (pickup.latitude.isNaN || pickup.longitude.isNaN) {
          pickup = null;
        }
      }
      if (mapProvider.dropLocation != null) {
        dropoff = mapProvider.dropLocation!.latLng;
        if (dropoff.latitude.isNaN || dropoff.longitude.isNaN) {
          dropoff = null;
        }
      }

      if (pickup == null || !_isValidCoordinate(pickup)) return;

      // Don't try to fit camera if we are showing the coming soon overlay (outside service area)
      if (mapProvider.showComingSoonOverlay) return;

      final validPolyline = mapProvider.polylineCoordinates
          .where((point) => _isValidCoordinate(point))
          .toList();

      final points =
          (dropoff != null &&
              _isValidCoordinate(dropoff) &&
              validPolyline.isNotEmpty)
          ? validPolyline
          : (dropoff != null && _isValidCoordinate(dropoff))
          ? [pickup, dropoff]
          : [pickup];
      _mapController?.fitPoints(
        points,
        padding: EdgeInsets.fromLTRB(
          32,
          MediaQuery.of(context).padding.top + 72,
          32,
          32,
        ),
      );

      // Delay tile rendering until the camera has fitted its target bounds
      if (!_showTiles && mounted) {
        setState(() {
          _showTiles = true;
        });
      }
    } catch (e) {
      debugPrint('Fit bounds error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, child) {
          final markers = <SgMarker>[];

          // Pickup Marker with safe coordinate validation
          if (mapProvider.pickupLocation != null) {
            final pickupPoint =
                mapProvider.precisePickupLocation ??
                mapProvider.pickupLocation!.latLng;

            final pickupMarker = _buildSafeMarker(
              id: 'pickup',
              point: pickupPoint,
              icon: const SgSvgMarker('assets/markers/pickup.svg'),
              label: 'Pickup',
            );

            if (pickupMarker != null) {
              markers.add(pickupMarker);
            } else {
              debugPrint('Invalid pickup coordinate: $pickupPoint');
            }
          }

          // Dropoff Marker with safe coordinate validation
          if (mapProvider.dropLocation != null) {
            final dropoffMarker = _buildSafeMarker(
              id: 'drop',
              point: mapProvider.dropLocation!.latLng,
              icon: const SgSvgMarker('assets/markers/dropoff.svg'),
              label: 'Drop',
            );

            if (dropoffMarker != null) {
              markers.add(dropoffMarker);
            } else {
              debugPrint(
                'Invalid dropoff coordinate: ${mapProvider.dropLocation!.latLng}',
              );
            }
          }

          // Nearby Driver Markers with safe coordinate validation
          var nearby = 0;
          for (var driver in mapProvider.nearbyDrivers) {
            final lat = driver['latitude'] ?? driver['lat'];
            final lng = driver['longitude'] ?? driver['lng'];
            if (lat != null && lng != null) {
              try {
                final point = LatLng(lat.toDouble(), lng.toDouble());
                final driverMarker = _buildSafeMarker(
                  id: 'nearby-${nearby++}',
                  point: point,
                  icon: SgIconMarker(
                    Icons.directions_car,
                    SgColors.goldText,
                    size: 24,
                  ),
                  anchor: const Offset(0.5, 0.5),
                );

                if (driverMarker != null) {
                  markers.add(driverMarker);
                } else {
                  debugPrint('Invalid driver coordinate: lat=$lat, lng=$lng');
                }
              } catch (e) {
                debugPrint('Error creating driver marker: $e');
              }
            }
          }

          final polylines = <SgPolyline>[];
          // Use safe polyline creation with coordinate validation
          final safePolyline = _buildSafePolyline(
            points: mapProvider.polylineCoordinates,
            color: SgColors.gold500,
            strokeWidth: 4.5,
          );
          if (safePolyline != null) {
            polylines.add(safePolyline);
          } else if (mapProvider.polylineCoordinates.isNotEmpty) {
            debugPrint('Polyline coordinates invalid or insufficient');
          }

          final LatLng? tempCenter =
              _isValidCoordinate(mapProvider.dropLocation?.latLng)
              ? mapProvider.dropLocation?.latLng
              : _isValidCoordinate(mapProvider.pickupLocation?.latLng)
              ? mapProvider.pickupLocation?.latLng
              : null;

          final initialCenter = tempCenter ?? const LatLng(17.385044, 78.4867);
          final initialZoom = (tempCenter != null) ? 14.0 : 2.0;

          final bool hasTripDetails =
              mapProvider.distance != null && mapProvider.duration != null;

          if (mapProvider.isLoadingRoute) {
            return Scaffold(
              backgroundColor: SgColors.bg000,
              body: const Center(
                child: CircularProgressIndicator(color: SgColors.gold500),
              ),
            );
          }

          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              if (hasTripDetails) {
                final shouldPop = await _showCancelConfirmation(context);
                if (!shouldPop && context.mounted) {
                  // User cancelled, prevent navigation
                  return;
                }
              }
              // Allow navigation to proceed
              if (context.mounted) {
                context.pop();
              }
            },
            child: Column(
              children: [
                SizedBox(
                  // A short route strip; the fares are the screen.
                  height: MediaQuery.of(context).size.height * 0.26,
                  child: Stack(
                    children: [
                      // Ensure FlutterMap has explicit constraints to prevent "render box with no size" errors
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Provide fallback if constraints are zero (shouldn't happen but defensive)
                            if (constraints.maxWidth <= 0 ||
                                constraints.maxHeight <= 0) {
                              return Container(
                                color: SgColors.bg000,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: SgColors.gold500,
                                  ),
                                ),
                              );
                            }

                            try {
                              return SgMap(
                                initialCenter: initialCenter,
                                initialZoom: initialZoom,
                                markers: markers,
                                polylines: polylines,
                                fitPadding: EdgeInsets.fromLTRB(
                                  32,
                                  MediaQuery.of(context).padding.top + 72,
                                  32,
                                  32,
                                ),
                                onMapCreated: (c) {
                                  _mapController = c;
                                  _fitBoundsIfNeeded(mapProvider);
                                },
                              );
                            } catch (e, stackTrace) {
                              debugPrint('FlutterMap rendering error: $e');
                              debugPrint('Stack trace: $stackTrace');
                              // Fallback UI when map fails to render
                              return Container(
                                color: SgColors.bg000,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: SgColors.goldText,
                                        size: 64,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        sgStrings(context).mapUnavailable,
                                        style: TextStyle(
                                          color: SgColors.ink,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        sgStrings(context).checkConnection,
                                        style: TextStyle(
                                          color: SgColors.inkMuted,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: () {
                                          // Try to reload the map
                                          if (mounted) {
                                            setState(() {});
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: SgColors.gold500,
                                          foregroundColor: SgColors.onGold,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: Text(sgStrings(context).retry),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + SgSpace.s2,
                        left: SgSpace.s4,
                        child: SgMapButton(
                          icon: SgIcons.back,
                          label: sgStrings(context).back,
                          onTap: () async {
                            if (hasTripDetails) {
                              final shouldPop = await _showCancelConfirmation(
                                context,
                              );
                              if (shouldPop && context.mounted) context.pop();
                            } else {
                              context.pop();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildSheet(mapProvider)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSheet(MapProvider provider) {
    if (provider.isLoadingFares) {
      return const SgSheetSurface(
        child: Padding(
          padding: EdgeInsets.all(SgSpace.s5),
          child: Center(
            child: CircularProgressIndicator(color: SgColors.gold500),
          ),
        ),
      );
    }
    final options = RideOption.fromEstimates(provider.fareEstimates);
    if (options.isEmpty) {
      return SgSheetSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sgStrings(context).faresUnavailable, style: SgText.title),
            const SizedBox(height: SgSpace.s2),
            Text(
              sgStrings(context).checkConnectionRetry,
              style: SgText.caption,
            ),
            const SizedBox(height: SgSpace.s4),
            SgPrimaryButton(
              label: sgStrings(context).retry,
              onPressed: () {
                if (provider.pickupLocation != null &&
                    provider.dropLocation != null) {
                  provider.fetchFareEstimates();
                }
              },
            ),
          ],
        ),
      );
    }

    final types = [for (final o in options) o.type];
    final chosen = provider.selectedVehicleType;
    if (chosen == null || !types.contains(chosen)) {
      final recents = provider.recentLocations;
      final pick = preselectVehicle(
        types,
        recents.isNotEmpty ? recents.first.vehicleType : null,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.selectVehicleType(pick);
      });
    }
    final payment = provider.selectedPaymentMethod;
    final distance = marketOf(context).displayDistance(provider.distance);
    return ChooseRideSheet(
      options: options,
      selectedType: types.contains(chosen) ? chosen : null,
      onSelect: provider.selectVehicleType,
      summary: (distance == null && provider.duration == null)
          ? null
          : '${distance ?? '--'} · ${minLabel(provider.duration ?? '--')}',
      route: routeLine(
        provider.pickupAddress ?? provider.pickupLocation?.name,
        provider.destinationAddress,
      ),
      paymentLabel: paymentMethodLabel(sgStrings(context), payment),
      onChangePayment: () => context.push('/payment-methods'),
      onConfirm: () => context.push('/precise-pickup'),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The breakdown link moved to the fare ticket ("See how ₹X is
          // worked out"). Here, clipped at the bottom of the scrolling list,
          // it showed as a stray gold dash above the payment row.
          // Hidden unless app-config says a promo is available (promos_available).
          PromoEntrySection(
            market: marketOf(context),
            fareData: provider.fareEstimates[chosen],
            vehicleType: chosen,
            pickupLat:
                (provider.precisePickupLocation ??
                        provider.pickupLocation?.latLng)
                    ?.latitude,
            pickupLong:
                (provider.precisePickupLocation ??
                        provider.pickupLocation?.latLng)
                    ?.longitude,
          ),
        ],
      ),
    );
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: SgColors.bg200,
            title: Text(
              'Cancel Trip?',
              style: TextStyle(
                fontSize: 18,
                color: SgColors.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              sgStrings(context).cancelGoBack,
              style: TextStyle(color: SgColors.inkMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Keep Going',
                  style: TextStyle(color: SgColors.goldText),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Cancel', style: TextStyle(color: SgColors.danger)),
              ),
            ],
          ),
        ) ??
        false;
  }
}
