/// Type: Noto Sans for the interface (the Latin, Telugu or Devanagari family by the
/// active locale, the other two as fallbacks), Cinzel 600 for the
/// "Saaradhi Go" lettering beside the badge and nothing else. Every font is
/// bundled (assets/fonts); nothing is fetched at runtime.
library;

import 'package:flutter/material.dart';

import 'sg_tokens.dart';

class SgText {
  SgText._();

  static const latin = 'NotoSans';
  static const telugu = 'NotoSansTelugu';
  static const devanagari = 'NotoSansDevanagari';

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

  /// The other two Noto Sans families, so a mixed string (a Telugu place name in an
  /// English UI) still renders.
  static List<String> get fallback => [
    latin,
    telugu,
    devanagari,
  ].where((f) => f != sans).toList(growable: false);

  /// The size class's factor (Tier 1): every style is multiplied by it.
  /// Only [SgSizeScope] sets it, from the shortest side of the window.
  static double scale = 1.0;

  /// True on a phone narrower than 360 (the compact class).
  static bool get compact => scale < 1.0;

  /// The size class for a window's shortest side, in logical pixels.
  static double scaleFor(double shortestSide) => shortestSide < 360
      ? 0.92
      : shortestSide >= 600
      ? 1.12
      : 1.0;

  /// A size off the type scale, for the few styles built by hand. [n] snaps
  /// to the nearest role (nothing under 13) and is multiplied by [scale].
  static double px(double n) {
    final double base;
    if (n <= 13) {
      base = 13;
    } else if (n < 15) {
      base = 14;
    } else if (n < 17) {
      base = 16;
    } else if (n < 18) {
      base = 17;
    } else if (n < 22) {
      base = 18;
    } else if (n <= 30) {
      base = 24;
    } else if (n < 40) {
      base = n; // Display figures (the PIN, a total) keep their size.
    } else {
      return compact ? 40 : 44 * scale; // The big-fare role.
    }
    return base * scale;
  }

  static TextStyle _style(
    double size,
    double height,
    double weight, {
    Color? color,
    bool figures = false,
  }) {
    final s = size * scale;
    return TextStyle(
      fontFamily: sans,
      fontFamilyFallback: fallback,
      fontSize: s,
      height: height / size,
      fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
      fontVariations: [FontVariation('wght', weight)],
      color: color ?? SgColors.ink,
      fontFeatures: figures ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// The screen title ("Where to?"): one per screen.
  static TextStyle get screenTitle => _style(24, 30, 600);

  /// A section title, a sheet title, a row's main line when it leads.
  static TextStyle get sectionTitle => _style(18, 24, 600);

  static TextStyle get display => screenTitle;
  static TextStyle get heading => screenTitle;
  static TextStyle get title => sectionTitle;
  static TextStyle get body => _style(16, 22, 400);
  static TextStyle get caption => _style(14, 20, 400, color: SgColors.inkMuted);

  /// Short labels and eyebrows. Never letter-spaced (it pulled Telugu and
  /// Devanagari conjuncts apart and read as heavy caps).
  static TextStyle get label => _style(13, 18, 600, color: SgColors.inkSubtle);

  /// The big fare: 44, or 40 in the compact class.
  static TextStyle get fareXl => compact
      ? _style(40 / scale, 44 / scale, 700, figures: true)
      : _style(44, 48, 700, figures: true);

  /// A fare in a row.
  static TextStyle get fare => _style(18, 22, 600, figures: true);

  /// The label on a button.
  static TextStyle get button => _style(17, 22, 600, color: SgColors.onGold);

  /// "Saaradhi Go" beside the badge in headers.
  static TextStyle brandLockup(double size) => TextStyle(
    fontFamily: brand,
    fontSize: size,
    height: 1.1,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation('wght', 600)],
    color: SgColors.logo,
  );
}

/// Sets [SgText.scale] from the window's shortest side and rebuilds the
/// subtree when the size class changes (a resize, a fold, a tablet window).
class SgSizeScope extends StatefulWidget {
  const SgSizeScope({super.key, required this.child});
  final Widget child;

  @override
  State<SgSizeScope> createState() => _SgSizeScopeState();
}

class _SgSizeScopeState extends State<SgSizeScope> {
  double? _last;

  @override
  Widget build(BuildContext context) {
    final scale = SgText.scaleFor(MediaQuery.sizeOf(context).shortestSide);
    SgText.scale = scale;
    if (_last != null && _last != scale) {
      void dirty(Element e) {
        e.markNeedsBuild();
        e.visitChildren(dirty);
      }

      (context as Element).visitChildren(dirty);
    }
    _last = scale;
    return widget.child;
  }
}

/// Phone or tablet, by the shortest side (the tablet size class).
bool sgIsTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;

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
