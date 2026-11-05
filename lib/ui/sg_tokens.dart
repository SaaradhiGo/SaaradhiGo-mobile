/// Design-system tokens (dark theme), from design-system/tokens.json.
library;

import 'package:flutter/material.dart';

class SgColors {
  SgColors._();
  static const bg000 = Color(0xFF000000);
  static const bg100 = Color(0xFF141414);
  static const bg200 = Color(0xFF18181B);
  static const bg300 = Color(0xFF27272A);
  static const line = Color(0xFF27272A);
  static const lineStrong = Color(0xFF71717A);
  static const ink = Color(0xFFF1F5F9);
  static const inkMuted = Color(0xFF94A3B8);
  static const inkSubtle = Color(0xFF8090A6);
  static const gold500 = Color(0xFFFFD700);
  static const gold300 = Color(0xFFFFE34D);
  static const gold700 = Color(0xFFD4B200);
  static const onGold = Color(0xFF000000);
  static const goldText = Color(0xFFFFD700);
  static const goldSoft = Color(0x1AFFD700);
  static const goldLine = Color(0x33FFD700);
  static const bgGlass = Color(0xCC0A0A0A);
  static const mapGround = Color(0xFF0A0A0A);
  static const mapStreet = Color(0xFF18181B);
  static const mapArterial = Color(0xFF27272A);
  static const mapHighway = Color(0xFF3A3205);
  static const mapWater = Color(0xFF0A1418);
  static const mapPark = Color(0xFF0D140E);
  static const champagne = Color(0xFFFFF4BF);
  static const pickup = Color(0xFF46C98B);
  static const danger = Color(0xFFFF8A6B);
}

class SgRadius {
  SgRadius._();
  static const sm = 8.0;
  static const md = 14.0;
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
