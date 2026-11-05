/// Google Maps behind [SgMap] (owner decision D1).
///
/// Keys are restricted per platform (Android package + signing SHA-1, iOS
/// bundle ID) and supplied at build time, never committed. Place search does
/// not go through this SDK: it goes through the backend's cached proxy
/// (`/ride/maps/geocode`), so a rider typing costs no extra billed calls here.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import 'map_style.dart';
import 'sg_map.dart';

class GoogleMapsProvider extends MapsProvider {
  const GoogleMapsProvider();

  @override
  Widget build(SgMap map) => _GoogleSgMap(map: map);
}

gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);
LatLng _l(gm.LatLng p) => LatLng(p.latitude, p.longitude);

/// Marker bitmaps, drawn once per look for the whole app.
class MarkerBitmaps {
  MarkerBitmaps._();

  static final Map<String, gm.BitmapDescriptor> _cache = {};
  static final Map<String, Future<gm.BitmapDescriptor>> _pending = {};

  static gm.BitmapDescriptor? cached(SgMarkerIcon icon, double dpr) =>
      _cache['${icon.key}x$dpr'];

  static Future<gm.BitmapDescriptor> load(SgMarkerIcon icon, double dpr) {
    final key = '${icon.key}x$dpr';
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    return _pending[key] ??= _draw(icon, dpr).then((b) {
      _cache[key] = b;
      _pending.remove(key);
      return b;
    });
  }

  static Future<gm.BitmapDescriptor> _draw(SgMarkerIcon icon, double dpr) async {
    final px = (icon.size * dpr).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    switch (icon) {
      case SgSvgMarker(:final asset):
        final info = await vg.loadPicture(SvgAssetLoader(asset), null);
        final s = info.size;
        final scale = math.min(px / s.width, px / s.height);
        canvas.scale(scale);
        canvas.drawPicture(info.picture);
        info.picture.dispose();
      case SgIconMarker(:final icon, :final color):
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: px.toDouble(),
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset((px - tp.width) / 2, (px - tp.height) / 2));
    }
    final image = await recorder.endRecording().toImage(px, px);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return gm.BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }
}

class _GoogleController implements SgMapController {
  _GoogleController(this._c, this._onProgrammatic);
  final gm.GoogleMapController _c;
  final VoidCallback _onProgrammatic;

  @override
  Future<void> moveTo(LatLng center, {double? zoom}) {
    _onProgrammatic();
    return _c.animateCamera(
      zoom == null
          ? gm.CameraUpdate.newLatLng(_g(center))
          : gm.CameraUpdate.newLatLngZoom(_g(center), zoom),
    );
  }

  @override
  Future<void> fitPoints(
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) {
    if (points.isEmpty) return Future.value();
    if (points.length == 1) return moveTo(points.first, zoom: 15);
    var s = points.first.latitude, n = s;
    var w = points.first.longitude, e = w;
    for (final p in points) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
    }
    _onProgrammatic();
    // The SDK takes one padding; the map's own `padding` already keeps the
    // sheet clear, so the larger side inset is enough here.
    final inset = [padding.left, padding.right, padding.top, padding.bottom]
        .reduce(math.max);
    return _c.animateCamera(
      gm.CameraUpdate.newLatLngBounds(
        gm.LatLngBounds(southwest: gm.LatLng(s, w), northeast: gm.LatLng(n, e)),
        math.min(inset, 120),
      ),
    );
  }
}

class _GoogleSgMap extends StatefulWidget {
  const _GoogleSgMap({required this.map});
  final SgMap map;

  @override
  State<_GoogleSgMap> createState() => _GoogleSgMapState();
}

class _GoogleSgMapState extends State<_GoogleSgMap> {
  bool _programmatic = false;
  bool _byGesture = false;
  gm.CameraPosition? _last;

  double get _dpr => MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warmIcons();
  }

  @override
  void didUpdateWidget(covariant _GoogleSgMap old) {
    super.didUpdateWidget(old);
    _warmIcons();
  }

  void _warmIcons() {
    for (final m in widget.map.markers) {
      if (MarkerBitmaps.cached(m.icon, _dpr) != null) continue;
      MarkerBitmaps.load(m.icon, _dpr).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Set<gm.Marker> _markers() => {
    for (final m in widget.map.markers)
      if (MarkerBitmaps.cached(m.icon, _dpr) case final bmp?)
        gm.Marker(
          markerId: gm.MarkerId(m.id),
          position: _g(m.point),
          icon: bmp,
          anchor: m.anchor,
          rotation: m.rotation,
          flat: m.rotation != 0,
          infoWindow: m.label == null
              ? gm.InfoWindow.noText
              : gm.InfoWindow(title: m.label),
        ),
  };

  Set<gm.Polyline> _polylines() => {
    for (final p in widget.map.polylines)
      if (p.points.length >= 2)
        gm.Polyline(
          polylineId: gm.PolylineId(p.id),
          points: [for (final pt in p.points) _g(pt)],
          color: p.color,
          width: p.width.round(),
          patterns: p.dotted ? [gm.PatternItem.dot, gm.PatternItem.gap(8)] : const [],
        ),
  };

  @override
  Widget build(BuildContext context) {
    final map = widget.map;
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: _g(map.initialCenter),
        zoom: map.initialZoom,
      ),
      style: kSgMapStyle,
      markers: _markers(),
      polylines: _polylines(),
      padding: map.padding,
      myLocationEnabled: map.showMyLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      buildingsEnabled: false,
      trafficEnabled: false,
      indoorViewEnabled: false,
      rotateGesturesEnabled: map.interactive,
      scrollGesturesEnabled: map.interactive,
      zoomGesturesEnabled: map.interactive,
      tiltGesturesEnabled: false,
      onMapCreated: (c) => map.onMapCreated?.call(
        _GoogleController(c, () => _programmatic = true),
      ),
      onCameraMoveStarted: () {
        _byGesture = !_programmatic;
      },
      onCameraMove: (pos) {
        _last = pos;
        map.onCameraMove?.call(
          SgCamera(_l(pos.target), pos.zoom, byGesture: _byGesture),
        );
      },
      onCameraIdle: () {
        _programmatic = false;
        _byGesture = false;
        if (_last != null) map.onCameraIdle?.call();
      },
    );
  }
}
