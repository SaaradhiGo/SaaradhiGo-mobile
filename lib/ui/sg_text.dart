/// Type: Inter 400 and 600 for the interface (Noto Sans Telugu and Devanagari
/// as fallbacks), Cinzel 600 for the "Saaradhi Go" lettering beside the badge
/// and nothing else. Every font is bundled (assets/fonts); nothing is fetched
/// at runtime.
///
/// Five sizes only (display 40/48, heading 28/36, title 20/28, body 16/24,
/// small 14/20; the compact class takes display 32/40 and heading 22/28) and
/// two weights (400 body, 600 headings, buttons, labels, nav). Screens use
/// the styles and the `size*` tokens here, never a raw font size or weight
/// (test/type_tokens_test.dart enforces it).
library;

import 'package:flutter/material.dart';

import 'sg_tokens.dart';

class SgText {
  SgText._();

  static const latin = 'Inter';
  static const telugu = 'NotoSansTelugu';
  static const devanagari = 'NotoSansDevanagari';

  /// Brand lettering only. Never a heading or body text.
  static const brand = 'Cinzel';

  /// The active locale's language code. Only the appearance controller sets it.
  static String language = 'en';

  /// Inter for every locale; the Indic families come after it as fallbacks.
  static String get sans => latin;

  /// Telugu and Devanagari, so a Telugu place name in an English UI (or the
  /// reverse) still renders. The active language's script comes first.
  static List<String> get fallback => language == 'hi'
      ? const [devanagari, telugu]
      : const [telugu, devanagari];

  /// The size class's factor: only the tablet class (1.12) enlarges text. The
  /// compact class (0.92) is flagged by [compact] and changes only display
  /// and heading; nothing shrinks below 14.
  static double scale = 1.0;

  /// True on a phone narrower than 360 (the compact class).
  static bool get compact => scale < 1.0;

  /// The size class for a window's shortest side, in logical pixels.
  static double scaleFor(double shortestSide) => shortestSide < 360
      ? 0.92
      : shortestSide >= 600
      ? 1.12
      : 1.0;

  static double _sz(double regular, [double? compactSize]) =>
      compact ? (compactSize ?? regular) : regular * scale;

  /// The five sizes, in logical pixels for the active size class.
  static double get sizeDisplay => _sz(40, 32);
  static double get sizeHeading => _sz(28, 22);
  static double get sizeTitle => _sz(20);
  static double get sizeBody => _sz(16);
  static double get sizeSmall => _sz(14);

  static TextStyle _style(
    double size,
    double line,
    FontWeight weight, {
    double? compactSize,
    double? compactLine,
    Color? color,
    bool figures = false,
    double? letterSpacing,
  }) {
    final s = _sz(size, compactSize);
    final l = _sz(line, compactLine);
    return TextStyle(
      fontFamily: sans,
      fontFamilyFallback: fallback,
      fontSize: s,
      height: l / s,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color ?? SgColors.ink,
      fontFeatures: figures ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// 40/48 (compact 32/40), 600: the big fare and other display figures.
  static TextStyle get display => _style(
    40,
    48,
    FontWeight.w600,
    compactSize: 32,
    compactLine: 40,
    figures: true,
  );

  /// 28/36 (compact 22/28), 600: the screen title ("Where to?"), one per screen.
  static TextStyle get heading =>
      _style(28, 36, FontWeight.w600, compactSize: 22, compactLine: 28);

  /// 20/28, 600: a section title, a sheet title, a row's main line when it leads.
  static TextStyle get title => _style(20, 28, FontWeight.w600);

  /// 16/24, 400.
  static TextStyle get body => _style(16, 24, FontWeight.w400);

  /// 14/20, 400, muted.
  static TextStyle get small =>
      _style(14, 20, FontWeight.w400, color: SgColors.inkMuted);

  static TextStyle get screenTitle => heading;
  static TextStyle get sectionTitle => title;
  static TextStyle get caption => small;

  /// 14/20, 600, subtle. Sentence-case labels and eyebrows.
  static TextStyle get label =>
      _style(14, 20, FontWeight.w600, color: SgColors.inkSubtle);

  /// An UPPERCASE small label: [label] with 0.04em (0.56 at 14px) tracking.
  /// The only letter-spaced style; use it only on text that is upper-cased.
  static TextStyle get eyebrow =>
      label.copyWith(letterSpacing: 0.04 * sizeSmall);

  /// The big fare: [display].
  static TextStyle get fareXl => display;

  /// A fare in a row: 20/28, 600, tabular.
  static TextStyle get fare => _style(20, 28, FontWeight.w600, figures: true);

  /// The label on a button: 16/24, 600.
  static TextStyle get button =>
      _style(16, 24, FontWeight.w600, color: SgColors.onGold);

  /// "Saaradhi Go" beside the badge in headers.
  static TextStyle brandLockup(double size) => TextStyle(
    fontFamily: brand,
    fontSize: size,
    height: 1.1,
    fontWeight: FontWeight.w600,
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

/// Every Material text slot on one of the five sizes: display slots take
/// display, headline slots heading, titleLarge title, the body slots body,
/// and the small slots small. Weights are 400 (body) or 600 (titles, labels).
TextTheme sgTextTheme(TextTheme base, Color? color) {
  TextStyle on(TextStyle s) =>
      s.copyWith(color: color ?? s.color, letterSpacing: 0);
  TextStyle slot(TextStyle s) => on(s.copyWith(fontFamily: SgText.sans));
  final display = slot(SgText.display);
  final heading = slot(SgText.heading);
  final title = slot(SgText.title);
  final body = slot(SgText.body);
  final small = slot(
    SgText.body.copyWith(fontSize: SgText.sizeSmall, height: 20 / 14),
  );
  final strong = FontWeight.w600;
  return base.copyWith(
    displayLarge: display,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: heading,
    headlineMedium: heading,
    headlineSmall: heading,
    titleLarge: title,
    titleMedium: body.copyWith(fontWeight: strong),
    titleSmall: small.copyWith(fontWeight: strong),
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: small,
    labelLarge: body.copyWith(fontWeight: strong),
    labelMedium: small.copyWith(fontWeight: strong),
    labelSmall: small.copyWith(fontWeight: strong),
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
    textTheme: sgTextTheme(base.textTheme, p.ink),
    primaryTextTheme: sgTextTheme(base.primaryTextTheme, null),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.bg300,
      contentTextStyle: SgText.body.copyWith(color: p.ink),
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
