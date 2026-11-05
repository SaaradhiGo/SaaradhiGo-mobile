import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saaradhigo_rider/core/route_follow.dart';

void main() {
  // ~1.1 km due east along lat 17.0 (0.01 deg lng ~ 1063 m).
  final line = [
    const LatLng(17.0, 78.00),
    const LatLng(17.0, 78.005),
    const LatLng(17.0, 78.01),
  ];
  final t0 = DateTime(2026, 1, 1, 12);

  test('on-line point is ~0 m, 0.001 deg north is ~111 m', () {
    expect(
      RouteFollow.distanceToLine(const LatLng(17.0, 78.004), line),
      lessThan(1),
    );
    expect(
      RouteFollow.distanceToLine(const LatLng(17.001, 78.004), line),
      closeTo(111, 3),
    );
  });

  test('refetch needs both >150 m off and >=60 s since last fetch', () {
    const far = LatLng(17.002, 78.004); // ~222 m off
    const near = LatLng(17.001, 78.004); // ~111 m off
    bool go(LatLng p, int secs) => RouteFollow.shouldRefetch(
      driver: p,
      line: line,
      lastFetch: t0,
      now: t0.add(Duration(seconds: secs)),
    );
    expect(go(far, 30), isFalse);
    expect(go(far, 60), isTrue);
    expect(go(near, 120), isFalse);
  });

  test('never fetched or empty line allows an immediate fetch', () {
    expect(
      RouteFollow.shouldRefetch(
        driver: const LatLng(17.002, 78.0),
        line: line,
        lastFetch: null,
        now: t0,
      ),
      isTrue,
    );
    expect(
      RouteFollow.shouldRefetch(
        driver: const LatLng(17, 78),
        line: const [],
        lastFetch: null,
        now: t0,
      ),
      isTrue,
    );
  });

  test('trim drops points behind the driver', () {
    final out = RouteFollow.trim(const LatLng(17.0, 78.007), line);
    expect(out.length, 2);
    expect(out.first.longitude, closeTo(78.007, 1e-6));
    expect(out.last, line.last);
  });

  test('trim keeps a short line and handles empty', () {
    expect(RouteFollow.trim(const LatLng(17, 78), const []), isEmpty);
    expect(RouteFollow.trim(const LatLng(17, 78), [line.first]).length, 1);
  });
}
