/// Type: Anek for the interface (the Latin, Telugu or Devanagari family by the
/// active locale, the other two as fallbacks), Cinzel 600 for the
/// "Saaradhi Go" lettering beside the badge and nothing else. Every font is
/// bundled (assets/fonts); nothing is fetched at runtime.
library;

import 'package:flutter/material.dart';

import 'sg_tokens.dart';

class SgText {
  SgText._();

  static const latin = 'AnekLatin';
  static const telugu = 'AnekTelugu';
  static const devanagari = 'AnekDevanagari';

  /// Brand lettering only. Never a heading or body text.
  static const brand = 'Cinzel';

  /// The active locale's language code. Only the appearance controller sets it.
  static String language = 'en';

  /// The UI family for the active locale.
  static String get sans => switch (language) {
    'te' => telugu,
    'hi' => devanagari,
    _ => latin,
  };

  /// The other two Anek families, so a mixed string (a Telugu place name in an
  /// English UI) still renders.
  static List<String> get fallback => [
    latin,
    telugu,
    devanagari,
  ].where((f) => f != sans).toList(growable: false);

  static TextStyle _style(
    double size,
    double height,
    double weight, {
    Color? color,
    double spacingEm = 0,
    bool figures = false,
  }) => TextStyle(
    fontFamily: sans,
    fontFamilyFallback: fallback,
    fontSize: size,
    height: height / size,
    fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation('wght', weight)],
    letterSpacing: spacingEm * size,
    color: color ?? SgColors.ink,
    fontFeatures: figures ? const [FontFeature.tabularFigures()] : null,
  );

  /// "Where to?" -- one per screen. Phone size.
  static TextStyle get display => _style(34, 36, 800, spacingEm: -0.03);
  static TextStyle get heading => _style(26, 30, 800);
  static TextStyle get title => _style(17, 22, 800);
  static TextStyle get body => _style(16, 22, 500);
  static TextStyle get caption => _style(14, 20, 500, color: SgColors.inkMuted);

  /// Uppercase the string where it is used; a TextStyle cannot.
  static TextStyle get label =>
      _style(13, 18, 700, color: SgColors.inkSubtle, spacingEm: 0.14);
  static TextStyle get fareXl => _style(56, 56, 800, figures: true);
  static TextStyle get fare => _style(22, 24, 800, figures: true);
  static TextStyle get driverEarning => _style(96, 92, 800, figures: true);

  /// The label on a button.
  static TextStyle get button => _style(16, 22, 700, color: SgColors.onGold);

  /// "Saaradhi Go" beside the badge in headers.
  static TextStyle brandLockup(double size) => TextStyle(
    fontFamily: brand,
    fontSize: size,
    height: 1.1,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation('wght', 600)],
    color: SgColors.goldText,
  );
}

/// The app theme for one palette.
ThemeData sgTheme(SgPalette p) {
  final dark = p.brightness == Brightness.dark;
  final base = ThemeData(brightness: p.brightness, useMaterial3: true);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: SgColors.gold500,
        brightness: p.brightness,
      ).copyWith(
        primary: dark ? SgColors.gold500 : p.goldText,
        onPrimary: dark ? SgColors.onGold : p.bg100,
        secondary: p.goldText,
        surface: p.bg100,
        onSurface: p.ink,
        onSurfaceVariant: p.inkMuted,
        outline: p.lineStrong,
        outlineVariant: p.line,
        error: p.danger,
        onError: p.onDanger,
      );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg000,
    canvasColor: p.bg100,
    dividerColor: p.line,
    colorScheme: scheme,
    textTheme: base.textTheme.apply(
      fontFamily: SgText.sans,
      fontFamilyFallback: SgText.fallback,
      bodyColor: p.ink,
      displayColor: p.ink,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: SgText.sans,
      fontFamilyFallback: SgText.fallback,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.bg300,
      contentTextStyle: TextStyle(color: p.ink, fontFamily: SgText.sans),
      actionTextColor: p.goldText,
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.bg100),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.bg100),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg000,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

/// The dark theme. Kept for the tests that build a bare MaterialApp.
ThemeData sgDarkTheme() => sgTheme(SgPalette.dark);
