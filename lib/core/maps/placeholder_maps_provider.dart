/// The map drawn when there is no Google Maps key: a plain surface in the
/// basemap's land colour, the faint badge, and the app's own route and pins.
/// No streets are drawn: it must never pass for a real map.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../ui/sg_tokens.dart';
import 'sg_map.dart';
import '../../ui/sg_brand.dart';

class PlaceholderMapsProvider extends MapsProvider {
  const PlaceholderMapsProvider();

  @override
  Widget build(SgMap map) => _PlaceholderMap(map: map);
}

class _PlaceholderMap extends StatefulWidget {
  const _PlaceholderMap({required this.map});
  final SgMap map;

  @override
  State<_PlaceholderMap> createState() => _PlaceholderMapState();
}

class _PlaceholderMapState extends State<_PlaceholderMap> {
  Offset _pan = Offset.zero;

  /// Degrees per pixel at the map's zoom (web-mercator, square pixels).
  LatLng _centerFor(Offset pan) {
    final map = widget.map;
    final c = map.initialCenter;
    final metres =
        156543.03392 *
        math.cos(c.latitude * math.pi / 180) /
        math.pow(2, map.initialZoom);
    final dLat = pan.dy * metres / 111320;
    final dLng =
        -pan.dx * metres / (111320 * math.cos(c.latitude * math.pi / 180));
    return LatLng(c.latitude + dLat, c.longitude + dLng);
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.map;
    final canvas = ExcludeSemantics(
      child: Transform.translate(
        offset: _pan,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: const _GroundPainter()),
            Center(
              child: Opacity(
                opacity: 0.05,
                child: SvgPicture.asset(kBadgeFullAsset, width: 190),
              ),
            ),
            CustomPaint(painter: _OverlayPainter(map)),
          ],
        ),
      ),
    );
    if (!map.interactive ||
        (map.onCameraMove == null && map.onCameraIdle == null)) {
      return canvas;
    }
    // Dragging moves the ground under a fixed centre and reports where it is.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) {
        setState(() => _pan += d.delta);
        map.onCameraMove?.call(
          SgCamera(_centerFor(_pan), map.initialZoom, byGesture: true),
        );
      },
      onPanEnd: (_) => map.onCameraIdle?.call(),
      child: ClipRect(child: canvas),
    );
  }
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = SgColors.isDark ? SgColors.bg000 : SgColors.mapLandLight,
    );
  }

  @override
  bool shouldRepaint(_GroundPainter old) => true;
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.map);
  final SgMap map;

  /// Projects lat/lng into the part of the box the sheet leaves free.
  Offset Function(LatLng) _projector(Size size) {
    if (map.onCameraMove != null) {
      // A draggable map is centred on its start point at the real zoom scale.
      final c = map.initialCenter;
      final k = math.cos(c.latitude * math.pi / 180);
      final perDeg = 111320 / (156543.03392 * k / math.pow(2, map.initialZoom));
      return (p) => Offset(
        size.width / 2 + (p.longitude - c.longitude) * k * perDeg,
        size.height / 2 - (p.latitude - c.latitude) * perDeg,
      );
    }
    final pad = map.fitPadding ?? map.padding;
    final area = Rect.fromLTRB(
      pad.left + 24,
      pad.top + 24,
      size.width - pad.right - 24,
      size.height - pad.bottom - 24,
    );
    final pts = <LatLng>[
      for (final l in map.polylines) ...l.points,
      for (final m in map.markers) m.point,
    ];
    if (pts.length < 2) {
      return (_) => area.center;
    }
    final lat0 =
        pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
    final k = math.cos(lat0 * math.pi / 180);
    double xOf(LatLng p) => p.longitude * k;
    final minX = pts.map(xOf).reduce(math.min),
        maxX = pts.map(xOf).reduce(math.max);
    final minY = pts.map((p) => p.latitude).reduce(math.min);
    final maxY = pts.map((p) => p.latitude).reduce(math.max);
    final w = math.max(maxX - minX, 1e-9), h = math.max(maxY - minY, 1e-9);
    final scale = math.min(area.width / w, area.height / h);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    return (p) => Offset(
      area.center.dx + (xOf(p) - cx) * scale,
      area.center.dy - (p.latitude - cy) * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final at = _projector(size);
    for (final line in map.polylines) {
      if (line.points.length < 2) continue;
      final path = Path();
      for (var i = 0; i < line.points.length; i++) {
        final o = at(line.points[i]);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      if (line.dotted) {
        for (final metric in path.computeMetrics()) {
          for (var d = 0.0; d < metric.length; d += 10) {
            final t = metric.getTangentForOffset(d);
            if (t != null) {
              canvas.drawCircle(t.position, 1.8, Paint()..color = line.color);
            }
          }
        }
        continue;
      }
      final w = line.width.clamp(4.0, 5.0);
      final gold = SgColors.isDark && line.color == SgColors.route;
      if (gold) {
        canvas.drawPath(
          path,
          Paint()
            ..color = SgColors.route.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 3
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final m in map.markers) {
      _marker(canvas, at(m.point), m);
    }
  }

  void _marker(Canvas canvas, Offset c, SgMarker m) {
    final icon = m.icon;
    if (icon is SgSvgMarker && icon.asset.contains('pickup')) {
      canvas.drawCircle(
        c,
        22,
        Paint()..color = SgColors.pickup.withValues(alpha: 0.18),
      );
      canvas.drawCircle(c, 9, Paint()..color = SgColors.pickup);
      canvas.drawCircle(
        c,
        9,
        Paint()
          ..color = SgColors.isDark ? SgColors.bg000 : SgColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if (icon is SgSvgMarker && icon.asset.contains('dropoff')) {
      // Dark: a gold square, black centre. Light: an ink square, marigold
      // centre.
      final square = SgColors.isDark ? SgColors.brandGold : SgColors.ink;
      final centre = SgColors.isDark ? SgColors.bg000 : SgColors.gold500;
      canvas.drawCircle(
        c,
        22,
        Paint()..color = square.withValues(alpha: 0.14),
      );
      if (!SgColors.isDark) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 24, height: 24),
            const Radius.circular(6),
          ),
          Paint()..color = SgColors.white,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 20, height: 20),
          const Radius.circular(5),
        ),
        Paint()..color = square,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 7, height: 7),
          const Radius.circular(1.5),
        ),
        Paint()..color = centre,
      );
    } else if (icon is SgCarMarker) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(m.rotation * math.pi / 180);
      paintCarGlyph(canvas, Offset.zero, icon.size);
      canvas.restore();
    } else {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(m.rotation * math.pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 10, height: 18),
          const Radius.circular(3.5),
        ),
        Paint()..color = SgColors.gold500,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
