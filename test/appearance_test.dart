import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/ui/sg_appearance.dart';
import 'package:saaradhigo_rider/ui/sg_text.dart';
import 'package:saaradhigo_rider/ui/sg_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final a = SgAppearance.instance;

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await a.restore();
  });

  test('light and English by default (never chose)', () async {
    SharedPreferences.setMockInitialValues({});
    await a.restore();
    expect(a.theme, SgThemeChoice.light);
    expect(a.hasSavedTheme, isFalse);
    expect(a.themeMode, ThemeMode.light);
    expect(SgColors.palette, same(SgPalette.light));
    expect(a.language, 'en');
    expect(SgText.sans, SgText.latin);
  });

  test('a chosen theme and language are applied and kept', () async {
    SharedPreferences.setMockInitialValues({});
    await a.restore();
    await a.setTheme(SgThemeChoice.light);
    await a.setLanguage('te');
    expect(SgColors.palette, same(SgPalette.light));
    expect(SgColors.bg000, SgPalette.light.bg000);
    expect(SgText.sans, SgText.latin);
    expect(
      SgText.body.fontFamilyFallback,
      containsAll([SgText.telugu, SgText.devanagari]),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SgAppearance.themeKey), 'light');
    expect(prefs.getString(SgAppearance.localeKey), 'te');

    // A fresh start reads them back.
    await a.restore(prefs);
    expect(a.theme, SgThemeChoice.light);
    expect(a.language, 'te');
  });

  test('automatic follows the device', () async {
    SharedPreferences.setMockInitialValues({
      SgAppearance.themeKey: 'automatic',
    });
    await a.restore();
    expect(a.themeMode, ThemeMode.system);
  });

  test('an unknown saved language falls back to English', () async {
    SharedPreferences.setMockInitialValues({SgAppearance.localeKey: 'fr'});
    await a.restore();
    expect(a.language, 'en');
  });

  test(
    'every Telugu and Hindi string exists and is marked for native review',
    () {
      Map<String, dynamic> arb(String code) =>
          jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
              as Map<String, dynamic>;
      final keys = arb('en').keys.where((k) => !k.startsWith('@')).toSet();
      for (final code in ['te', 'hi']) {
        final m = arb(code);
        for (final k in keys) {
          expect(m[k], isA<String>(), reason: '$code is missing $k');
          expect(
            (m['@$k'] as Map?)?['description'],
            'needs native review',
            reason: '$code:$k',
          );
        }
      }
    },
  );
}
