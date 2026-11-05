/// The map drawn when there is no Google Maps key: pure black, a faint street
/// grid in the map-* tokens, the emblem, and the app's own route and pins.
/// It makes no claim to be a real map.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../ui/sg_tokens.dart';
import 'sg_map.dart';

class PlaceholderMapsProvider extends MapsProvider {
  const PlaceholderMapsProvider();

  @override
  Widget build(SgMap map) => _PlaceholderMap(map: map);
}

class _PlaceholderMap extends StatelessWidget {
  const _PlaceholderMap({required this.map});
  final SgMap map;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _GroundPainter()),
          Center(
            child: Opacity(
              opacity: 0.05,
              child: SvgPicture.asset('assets/brand/saaradhigo-emblem-gold.svg', width: 190),
            ),
          ),
          CustomPaint(painter: _OverlayPainter(map)),
        ],
      ),
    );
  }
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = SgColors.bg000);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.14);
    canvas.translate(-size.width / 2, -size.height / 2);
    final reach = size.longestSide * 1.4;
    final street = Paint()
      ..color = SgColors.mapStreet
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (var x = -reach; x < reach; x += 44) {
      canvas.drawLine(Offset(x, -reach), Offset(x, reach), street);
    }
    for (var y = -reach; y < reach; y += 52) {
      canvas.drawLine(Offset(-reach, y), Offset(reach, y), street);
    }
    final arterial = Paint()
      ..color = SgColors.mapArterial
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final fy in [0.22, 0.52, 0.8]) {
      final p = Path()
        ..moveTo(-40, size.height * fy)
        ..cubicTo(size.width * .3, size.height * (fy - .05), size.width * .6,
            size.height * (fy + .06), size.width + 40, size.height * fy);
      canvas.drawPath(p, arterial);
    }
    for (final fx in [0.25, 0.7]) {
      final p = Path()
        ..moveTo(size.width * fx, -40)
        ..cubicTo(size.width * (fx + .08), size.height * .3, size.width * (fx - .08),
            size.height * .65, size.width * fx, size.height + 40);
      canvas.drawPath(p, arterial);
    }
    // Roads stay neutral grey: gold is only ever the route.
    final highway = Paint()
      ..color = SgColors.mapArterial
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-40, size.height * .95)
        ..quadraticBezierTo(size.width * .45, size.height * .3, size.width + 40, -20),
      highway,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .55, size.height * .6, size.width * .3, size.height * .09),
        const Radius.circular(14),
      ),
      Paint()..color = SgColors.mapPark,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * .08, size.height * .38, size.width * .26, size.height * .07),
      Paint()..color = SgColors.mapWater,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GroundPainter old) => false;
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.map);
  final SgMap map;

  /// Projects lat/lng into the part of the box the sheet leaves free.
  Offset Function(LatLng) _projector(Size size) {
    final pad = map.fitPadding ?? map.padding;
    final area = Rect.fromLTRB(pad.left + 24, pad.top + 24, size.width - pad.right - 24,
        size.height - pad.bottom - 24);
    final pts = <LatLng>[
      for (final l in map.polylines) ...l.points,
      for (final m in map.markers) m.point,
    ];
    if (pts.length < 2) {
      return (_) => area.center;
    }
    final lat0 = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
    final k = math.cos(lat0 * math.pi / 180);
    double xOf(LatLng p) => p.longitude * k;
    final minX = pts.map(xOf).reduce(math.min), maxX = pts.map(xOf).reduce(math.max);
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
      final w = line.width.clamp(4.0, 5.0);
      canvas.drawPath(
        path,
        Paint()
          ..color = SgColors.gold500.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = SgColors.gold500
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
      canvas.drawCircle(c, 22, Paint()..color = SgColors.pickup.withValues(alpha: 0.18));
      canvas.drawCircle(c, 9, Paint()..color = SgColors.pickup);
      canvas.drawCircle(
          c,
          9,
          Paint()
            ..color = SgColors.bg000
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    } else if (icon is SgSvgMarker && icon.asset.contains('dropoff')) {
      canvas.drawCircle(c, 22, Paint()..color = SgColors.gold500.withValues(alpha: 0.18));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 20, height: 20), const Radius.circular(5)),
        Paint()..color = SgColors.gold500,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 6, height: 6), const Radius.circular(1.5)),
        Paint()..color = SgColors.bg000,
      );
    } else {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(m.rotation * math.pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 10, height: 18),
            const Radius.circular(3.5)),
        Paint()..color = SgColors.gold500,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
