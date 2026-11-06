import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/ui/sg_tokens.dart';

/// WCAG 2.x contrast, computed from the token values (spec 1.1): every text
/// pair 4.5:1, control edges 3:1, in BOTH palettes.
double _lum(Color c) {
  double ch(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final p in [SgPalette.dark, SgPalette.light]) {
    group('${p.brightness.name} palette', () {
      setUp(() => SgColors.palette = p);
      tearDown(() => SgColors.palette = SgPalette.dark);

      final surfaces = {
        'bg-000': p.bg000,
        'bg-100': p.bg100,
        'bg-200': p.bg200,
      };
      final text = {
        'gold-text': p.goldText,
        'ink': p.ink,
        'ink-muted': p.inkMuted,
        'ink-subtle': p.inkSubtle,
        'pickup': p.pickup,
        'success': p.success,
        'danger': p.danger,
      };

      for (final t in text.entries) {
        for (final s in surfaces.entries) {
          test('${t.key} on ${s.key} >= 4.5', () {
            expect(contrast(t.value, s.value), greaterThanOrEqualTo(4.5));
          });
        }
      }

      for (final s in surfaces.entries) {
        test('line-strong on ${s.key} >= 3 (control edge)', () {
          expect(contrast(p.lineStrong, s.value), greaterThanOrEqualTo(3));
        });
      }

      test('on-gold on gold-500 >= 4.5', () {
        expect(
          contrast(SgColors.onGold, SgColors.gold500),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('on-danger on danger >= 4.5', () {
        expect(contrast(p.onDanger, p.danger), greaterThanOrEqualTo(4.5));
      });

      for (final c in SgVehicleClass.values) {
        test('${c.name} class colour on its 14% tile >= 4.5', () {
          SgColors.palette = p;
          final tile = SgColors.vehicleClassTile(c);
          expect(
            contrast(SgColors.vehicleClass(c), tile),
            greaterThanOrEqualTo(4.5),
          );
          if (c != SgVehicleClass.premium) {
            expect(
              contrast(p.ink, tile),
              greaterThanOrEqualTo(4.5),
              reason: 'the class name sits on the same tile colour',
            );
          }
        });
      }
    });
  }
}
