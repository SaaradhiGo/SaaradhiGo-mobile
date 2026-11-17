import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saaradhigo_rider/ui/sg_standard_theme.dart';
import 'package:saaradhigo_rider/ui/sg_tokens.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  for (final p in [SgStandardPalette.light, SgStandardPalette.dark]) {
    test('standard ${p.brightness.name}: every text pair is AA (4.5:1)', () {
      final pairs = <String, List<Color>>{
        'text/bg': [p.text, p.bg], 'text2/bg': [p.text2, p.bg], 'text3/bg': [p.text3, p.bg],
        'text3/band': [p.text3, p.band], 'goldText/bg': [p.goldText, p.bg], 'onGold/gold': [p.onGold, p.gold],
        'onInk/ink': [p.onInk, p.ink], 'ok/okBg': [p.ok, p.okBg], 'warn/warnBg': [p.warn, p.warnBg], 'bad/badBg': [p.bad, p.badBg],
      };
      for (final e in pairs.entries) {
        expect(_ratio(e.value[0], e.value[1]), greaterThanOrEqualTo(4.5), reason: e.key);
      }
    });
  }

  test('the standard theme: 48px buttons, one radius, the type scale', () {
    final t = sgStandardTheme();
    expect(t.filledButtonTheme.style!.minimumSize!.resolve({})!.height, SgStandard.buttonHeight);
    expect(t.textTheme.bodyLarge!.fontSize, 16);
    expect(t.textTheme.titleLarge!.fontSize, 20);
    expect(t.textTheme.headlineSmall!.fontSize, 28);
    expect(t.scaffoldBackgroundColor, SgStandardPalette.light.bg);
    expect(t.brightness, Brightness.light);
  });
}
