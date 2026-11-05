/// The one map every screen uses (owner decision D1, 2026-11-02).
///
/// Screens describe WHAT is on the map -- markers, a route, where the camera
/// should be -- in the app's own types (`latlong2` coordinates). The
/// [MapsProvider] decides how a vendor draws it. Google Maps is the provider
/// today, matching the website; the CARTO/OpenStreetMap tiles the app used
/// before are gone (their usage policy does not allow an app like this, and
/// the rider app's tiles carried an "API KEY REQUIRED" watermark).
///
/// Nothing here imports a vendor SDK, so swapping the provider is one file.
library;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'google_maps_provider.dart';
import 'maps_availability.dart';
import 'placeholder_maps_provider.dart';

/// How a marker looks. Rasterised once per look and cached by the provider.
@immutable
sealed class SgMarkerIcon {
  const SgMarkerIcon(this.size);

  /// Logical pixels, square.
  final double size;

  /// A cache key: two icons with the same key draw the same bitmap.
  String get key;
}

/// An SVG from the app's assets (the pickup and drop markers).
class SgSvgMarker extends SgMarkerIcon {
  const SgSvgMarker(this.asset, {double size = 40}) : super(size);
  final String asset;
  @override
  String get key => 'svg:$asset@$size';
}

/// A Material icon in one colour (the cars).
class SgIconMarker extends SgMarkerIcon {
  const SgIconMarker(this.icon, this.color, {double size = 32}) : super(size);
  final IconData icon;
  final Color color;
  @override
  String get key => 'icon:${icon.codePoint}:${color.toARGB32()}@$size';
}

/// The driver's car seen from above: light body, gold outline.
class SgCarMarker extends SgMarkerIcon {
  const SgCarMarker({double size = 28}) : super(size);
  @override
  String get key => 'car@$size';
}

/// Draws the car glyph centred on [c], nose up.
void paintCarGlyph(Canvas canvas, Offset c, double size) {
  final w = size * 0.5, h = size * 0.92;
  final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: h), Radius.circular(w * 0.38));
  canvas.drawRRect(body, Paint()..color = const Color(0xFFF1F5F9));
  canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
  final glass = Paint()..color = const Color(0xFF18181B);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(0, -h * 0.17), width: w * 0.68, height: h * 0.2),
          const Radius.circular(2)),
      glass);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(0, h * 0.2), width: w * 0.62, height: h * 0.14),
          const Radius.circular(2)),
      glass);
}

@immutable
class SgMarker {
  const SgMarker({
    required this.id,
    required this.point,
    required this.icon,
    this.anchor = const Offset(0.5, 1.0),
    this.rotation = 0,
    this.label,
  });

  final String id;
  final LatLng point;
  final SgMarkerIcon icon;

  /// Which point of the icon sits on [point]: (0.5, 1.0) is the bottom
  /// centre, right for a pin; (0.5, 0.5) for a car seen from above.
  final Offset anchor;
  final double rotation;

  /// Read by screen readers where the provider supports it.
  final String? label;
}

@immutable
class SgPolyline {
  const SgPolyline({
    required this.id,
    required this.points,
    required this.color,
    this.width = 4,
    this.dotted = false,
  });

  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;

  /// Drawn as dots, for a line that is not the route (driver to pickup).
  final bool dotted;
}

/// Moves the camera. Handed to the screen through [SgMap.onMapCreated].
abstract class SgMapController {
  Future<void> moveTo(LatLng center, {double? zoom});

  /// Shows every point, with [padding] kept clear (for a sheet or a header).
  Future<void> fitPoints(List<LatLng> points, {EdgeInsets padding});
}

/// Where the camera is, reported while it moves.
@immutable
class SgCamera {
  const SgCamera(this.center, this.zoom, {this.byGesture = false});
  final LatLng center;
  final double zoom;
  final bool byGesture;
}

/// The vendor seam. One implementation per maps vendor.
abstract class MapsProvider {
  const MapsProvider();

  Widget build(SgMap map);
}

/// The provider the app uses. Google Maps (D1).
const MapsProvider kMapsProvider = GoogleMapsProvider();

/// Google when the build has a key, else the branded placeholder.
MapsProvider mapsProviderFor({required bool hasKey}) =>
    hasKey ? kMapsProvider : const PlaceholderMapsProvider();

class SgMap extends StatelessWidget {
  const SgMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14,
    this.markers = const [],
    this.polylines = const [],
    this.onMapCreated,
    this.onCameraMove,
    this.onCameraIdle,
    this.padding = EdgeInsets.zero,
    this.fitPadding,
    this.interactive = true,
    this.showMyLocation = false,
    this.provider,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final List<SgMarker> markers;
  final List<SgPolyline> polylines;
  final ValueChanged<SgMapController>? onMapCreated;
  final ValueChanged<SgCamera>? onCameraMove;
  final VoidCallback? onCameraIdle;

  /// Map UI (logo, attribution) is kept clear of this, e.g. a bottom sheet.
  final EdgeInsets padding;

  /// Where the route and pins are kept clear of (a back button, a sheet).
  final EdgeInsets? fitPadding;
  final bool interactive;
  final bool showMyLocation;

  /// Test seam; production uses [kMapsProvider].
  final MapsProvider? provider;

  @override
  Widget build(BuildContext context) {
    final fixed = provider;
    if (fixed != null) return fixed.build(this);
    MapsAvailability.ensureResolved();
    return ValueListenableBuilder<bool>(
      valueListenable: MapsAvailability.hasKey,
      builder: (_, hasKey, _) => mapsProviderFor(hasKey: hasKey).build(this),
    );
  }
}
