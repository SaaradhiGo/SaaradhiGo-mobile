/// The product standard as a Flutter theme (owner brief, 17 Nov 2026), matching the web's
/// `/design` page. Light unless the person chooses dark: the app passes [ThemeMode.light] by
/// default, never [ThemeMode.system]. Phase 2 moves every screen onto it.
library;

import 'package:flutter/material.dart';

import 'sg_tokens.dart';

ThemeData sgStandardTheme([SgStandardPalette p = SgStandardPalette.light]) {
  final base = ThemeData(brightness: p.brightness, useMaterial3: true);
  final text = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);
  TextStyle s(double size, double height, FontWeight w, Color c) =>
      TextStyle(fontSize: size, height: height / size, fontWeight: w, color: c);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(SgStandard.radius));
  const buttonSize = Size(SgStandard.tapTarget, SgStandard.buttonHeight);
  final buttonText = s(SgStandard.body, 24, FontWeight.w600, p.text);

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme(
      brightness: p.brightness,
      primary: p.gold,
      onPrimary: p.onGold,
      secondary: p.text,
      onSecondary: p.bg,
      error: p.bad,
      onError: p.onInk,
      surface: p.surface,
      onSurface: p.text,
      outline: p.lineStrong,
      outlineVariant: p.line,
    ),
    dividerColor: p.line,
    textTheme: text.copyWith(
      displaySmall: s(SgStandard.display, 48, FontWeight.w600, p.text),
      headlineSmall: s(SgStandard.heading, 36, FontWeight.w600, p.text),
      titleLarge: s(SgStandard.title, 28, FontWeight.w600, p.text),
      bodyLarge: s(SgStandard.body, 24, FontWeight.w400, p.text2),
      bodyMedium: s(SgStandard.body, 24, FontWeight.w400, p.text2),
      bodySmall: s(SgStandard.small, 20, FontWeight.w400, p.text3),
      labelLarge: buttonText,
    ),
    appBarTheme: AppBarTheme(backgroundColor: p.ink, foregroundColor: p.onInk, elevation: 0, centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.gold, foregroundColor: p.onGold, minimumSize: buttonSize, shape: shape,
        textStyle: buttonText, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text, minimumSize: buttonSize, shape: shape, side: BorderSide(color: p.lineStrong),
        textStyle: buttonText, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.goldText, minimumSize: buttonSize, textStyle: buttonText),
    ),
    cardTheme: CardThemeData(
      color: p.surface, elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SgStandard.cardRadius), side: BorderSide(color: p.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      constraints: const BoxConstraints(minHeight: SgStandard.buttonHeight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(color: p.text3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(SgStandard.radius), borderSide: BorderSide(color: p.lineStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SgStandard.radius), borderSide: BorderSide(color: p.lineStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SgStandard.radius), borderSide: BorderSide(color: p.text, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SgStandard.radius), borderSide: BorderSide(color: p.bad)),
    ),
    chipTheme: base.chipTheme.copyWith(backgroundColor: p.band, side: BorderSide(color: p.line), labelStyle: s(SgStandard.small, 20, FontWeight.w600, p.text2)),
    snackBarTheme: SnackBarThemeData(backgroundColor: p.ink, contentTextStyle: s(SgStandard.body, 24, FontWeight.w400, p.onInk), behavior: SnackBarBehavior.floating),
    iconTheme: IconThemeData(color: p.text, size: SgStandard.icon),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
