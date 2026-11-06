/// Design-system tokens: the hybrid palette (Direction B layouts, Direction A
/// colours), dark by default with a light twin.
///
/// THIS IS THE ONLY FILE IN lib/ THAT MAY SPELL A COLOUR AS HEX.
/// `test/no_raw_colors_test.dart` fails on a `Color(0x...)` or a
/// `Colors.<name>` (other than `Colors.transparent`) anywhere else, and
/// `test/token_contrast_test.dart` checks every text pair here against WCAG.
///
/// [SgColors] reads the active [SgPalette]. The theme controller
/// (`sg_theme.dart`) swaps it and rebuilds the tree, so a widget must read
/// `SgColors.x` in `build`, never cache it in a `static const` or `initState`.
library;

import 'package:flutter/material.dart';

/// One complete set of colours. [dark] and [light] are the only instances.
@immutable
class SgPalette {
  const SgPalette._({
    required this.brightness,
    required this.bg000,
    required this.bg100,
    required this.bg200,
    required this.bg300,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.goldText,
    required this.goldLine,
    required this.goldSoft,
    required this.bgGlass,
    required this.pickup,
    required this.success,
    required this.danger,
    required this.onDanger,
    required this.shadow,
    required this.classBike,
    required this.classAuto,
    required this.classCar,
    required this.classComfort,
    required this.classSuv,
  });

  final Brightness brightness;

  /// Page.
  final Color bg000;

  /// Panel, sheet.
  final Color bg100;

  /// Row, card.
  final Color bg200;

  /// Input, pressed.
  final Color bg300;

  /// Divider.
  final Color line;

  /// Control edge (3:1 against the surfaces).
  final Color lineStrong;
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;

  /// Gold used as text, icons and selected edges (4.5:1 on every surface).
  final Color goldText;
  final Color goldLine;
  final Color goldSoft;
  final Color bgGlass;
  final Color pickup;
  final Color success;
  final Color danger;

  /// Text on a [danger] or [success] fill.
  final Color onDanger;

  /// Drop shadow under sheets and floating buttons. Never a glow.
  final Color shadow;
  final Color classBike;
  final Color classAuto;
  final Color classCar;
  final Color classComfort;
  final Color classSuv;

  static const dark = SgPalette._(
    brightness: Brightness.dark,
    bg000: Color(0xFF000000),
    bg100: Color(0xFF0F0F0F),
    bg200: Color(0xFF181818),
    bg300: Color(0xFF242424),
    line: Color(0xFF262626),
    lineStrong: Color(0xFF6E6A63),
    ink: Color(0xFFF3EEE6),
    inkMuted: Color(0xFFB4ADA2),
    inkSubtle: Color(0xFF948E84),
    goldText: Color(0xFFFFD700),
    goldLine: Color(0x38FFD700), // rgba(255,215,0,0.22)
    goldSoft: Color(0x1AFFD700), // rgba(255,215,0,0.10)
    bgGlass: Color(0xCC0F0F0F),
    pickup: Color(0xFF46C98B),
    success: Color(0xFF46C98B),
    danger: Color(0xFFFF6B5E),
    onDanger: Color(0xFF000000),
    shadow: Color(0x99000000),
    classBike: Color(0xFF8AB4FF),
    classAuto: Color(0xFF4FD1A5),
    classCar: Color(0xFFF2A65A),
    classComfort: Color(0xFFB9A3FF),
    classSuv: Color(0xFFAAB6C8),
  );

  static const light = SgPalette._(
    brightness: Brightness.light,
    bg000: Color(0xFFFAF7F2),
    bg100: Color(0xFFFFFFFF),
    bg200: Color(0xFFF3EEE6),
    bg300: Color(0xFFE9E3D9),
    line: Color(0xFFE7E1D7),
    lineStrong: Color(0xFF8C8579),
    ink: Color(0xFF1B1A17),
    inkMuted: Color(0xFF57524A),
    inkSubtle: Color(0xFF6B655B),
    goldText: Color(0xFF7A6000),
    goldLine: Color(0x477A6000), // rgba(122,96,0,0.28)
    goldSoft: Color(0x2EFFD700), // rgba(255,215,0,0.18)
    bgGlass: Color(0xCCFFFFFF),
    pickup: Color(0xFF0D7762), // spec #0E7C66 is 4.44:1 on bg-200; matches web
    success: Color(0xFF0B6B57),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    shadow: Color(0x29000000),
    classBike: Color(0xFF1D4ED8),
    classAuto: Color(0xFF0B6B57),
    classCar: Color(0xFF8A5300),
    classComfort: Color(0xFF5B3FA8),
    classSuv: Color(0xFF334155),
  );
}

/// The colours a widget paints with, from the active palette.
class SgColors {
  SgColors._();

  /// The palette in use. Only the theme controller sets it.
  static SgPalette palette = SgPalette.dark;
  static SgPalette get _active => palette;

  static bool get isDark => _active.brightness == Brightness.dark;

  static Color get bg000 => _active.bg000;
  static Color get bg100 => _active.bg100;
  static Color get bg200 => _active.bg200;
  static Color get bg300 => _active.bg300;
  static Color get line => _active.line;
  static Color get lineStrong => _active.lineStrong;
  static Color get ink => _active.ink;
  static Color get inkMuted => _active.inkMuted;
  static Color get inkSubtle => _active.inkSubtle;

  /// Fill: the primary button, the drop marker, the route line. Same in both.
  static const gold500 = Color(0xFFFFD700);
  static const gold300 = Color(0xFFFFE34D);
  static const gold700 = Color(0xFFD4B200);

  /// Text on gold. Same in both.
  static const onGold = Color(0xFF000000);
  static Color get goldText => _active.goldText;
  static Color get goldSoft => _active.goldSoft;
  static Color get goldLine => _active.goldLine;

  /// Print only, never UI.
  static const logoClassic = Color(0xFFD6A83E);
  static Color get bgGlass => _active.bgGlass;

  // The basemap stays dark in both themes (owner decision D2).
  static const mapGround = Color(0xFF0A0A0A);
  static const mapStreet = Color(0xFF18181B);
  static const mapArterial = Color(0xFF27272A);
  static const mapHighway = Color(0xFF3A3205);
  static const mapWater = Color(0xFF0A1418);
  static const mapPark = Color(0xFF0D140E);
  static const mapLabel = Color(0xFF7D8BA1);

  /// The number plate and the premium class.
  static const champagne = Color(0xFFFFF4BF);
  static Color get pickup => _active.pickup;
  static Color get success => _active.success;
  static Color get danger => _active.danger;
  static Color get onDanger => _active.onDanger;
  static Color get shadow => _active.shadow;

  /// Pure black and white, for the few things that are black or white in both
  /// themes (a photo scrim, the white ring on a marker).
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  /// Behind photos and modal barriers, both themes.
  static const scrim = Color(0x99000000);

  /// Icon colour for a vehicle class.
  static Color vehicleClass(SgVehicleClass c) => switch (c) {
    SgVehicleClass.bike => _active.classBike,
    SgVehicleClass.auto => _active.classAuto,
    SgVehicleClass.car => _active.classCar,
    SgVehicleClass.comfort => _active.classComfort,
    SgVehicleClass.suv => _active.classSuv,
    SgVehicleClass.premium => champagne,
  };

  /// The tile behind a vehicle class icon: 14% of its colour over bg-100
  /// (premium: champagne on black, both themes).
  static Color vehicleClassTile(SgVehicleClass c) => c == SgVehicleClass.premium
      ? Color.alphaBlend(champagne.withValues(alpha: 0.14), black)
      : Color.alphaBlend(vehicleClass(c).withValues(alpha: 0.14), bg100);
}

/// `#rrggbb` for an API that takes a colour as a string (the map style, the
/// payment sheets). Alpha is dropped.
String sgHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// The six colour classes a vehicle type can show as.
enum SgVehicleClass { bike, auto, car, comfort, suv, premium }

class SgRadius {
  SgRadius._();
  static const sm = 8.0;

  /// Buttons, inputs, rows.
  static const md = 16.0;

  /// Cards, sheets.
  static const lg = 22.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

class SgSpace {
  SgSpace._();
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
}

/// Minimum touch target on mobile.
const double kSgTouch = 48;

/// Motion: press feedback and sheets, ease-out (spec 1.0).
class SgMotion {
  SgMotion._();
  static const press = Duration(milliseconds: 140);
  static const sheet = Duration(milliseconds: 240);
  static const curve = Curves.easeOut;
}
