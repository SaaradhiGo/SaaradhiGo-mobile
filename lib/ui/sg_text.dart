/// Type styles from tokens.json: Manrope for the interface, Cormorant
/// Garamond for the one display headline per screen.
library;

import 'package:flutter/material.dart';

import 'sg_tokens.dart';

class SgText {
  SgText._();

  static const sans = 'Manrope';
  static const display = 'CormorantGaramond';

  static TextStyle _sans(double size, double height, double weight,
          {Color color = SgColors.ink, double spacing = 0, bool figures = false}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        height: height / size,
        fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
        fontVariations: [FontVariation('wght', weight)],
        letterSpacing: spacing,
        color: color,
        fontFeatures: figures ? const [FontFeature.tabularFigures()] : null,
      );

  /// "Where to?" -- one per screen. Mobile size.
  static const displayLg = TextStyle(
    fontFamily: display,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: -0.16,
    color: SgColors.ink,
  );

  static final heading = _sans(26, 32, 700, spacing: -0.26);
  static final title = _sans(18, 24, 700);
  static final bodyLg = _sans(17, 26, 500);
  static final body = _sans(15, 22, 500);
  static final caption = _sans(13, 18, 500, color: SgColors.inkMuted);
  static final label = _sans(11, 16, 700, color: SgColors.inkSubtle, spacing: 1.32);
  static final fare = _sans(18, 24, 800, spacing: 0, figures: true);
  static final button = _sans(16, 22, 700, color: SgColors.onGold);
}

/// App theme: dark on pure black, Manrope throughout.
ThemeData sgDarkTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: SgColors.bg000,
    colorScheme: ColorScheme.fromSeed(
      seedColor: SgColors.gold500,
      brightness: Brightness.dark,
    ).copyWith(
      primary: SgColors.gold500,
      onPrimary: SgColors.onGold,
      surface: SgColors.bg100,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: SgText.sans,
      bodyColor: SgColors.ink,
      displayColor: SgColors.ink,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: SgText.sans),
  );
}
