import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/ui/sg_text.dart';
import 'package:saaradhigo_rider/ui/sg_tokens.dart';
import 'package:saaradhigo_rider/ui/sg_widgets.dart';

/// Night 2, step 1: plain eyebrows, a plain splash, shared appearance words.
void main() {
  test('the splash shows no invented progress', () {
    final src = File(
      'lib/screens/splash/splash_screen.dart',
    ).readAsStringSync();
    expect(src, isNot(contains('INITIALIZING')));
    expect(src, isNot(contains('64%')));
    expect(src, isNot(contains('value: 0.64')));
  });

  test('appearance options use the loanwords phone settings use', () {
    Map<String, dynamic> arb(String l) =>
        jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
            as Map<String, dynamic>;
    final te = arb('te');
    final hi = arb('hi');
    expect([te['themeDark'], te['themeLight'], te['themeAutomatic']], [
      'డార్క్ (నలుపు, బంగారు)',
      'లైట్',
      'ఆటోమేటిక్',
    ]);
    expect([hi['themeDark'], hi['themeLight'], hi['themeAutomatic']], [
      'डार्क (काला और सुनहरा)',
      'लाइट',
      'ऑटोमैटिक',
    ]);
    for (final k in ['themeDark', 'themeLight', 'themeAutomatic']) {
      expect(te['@$k']['description'], 'needs native review');
      expect(hi['@$k']['description'], 'needs native review');
    }
  });

  testWidgets('an eyebrow is only uppercase gold-text label text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SgEyebrow('Your fare ticket'))),
    );
    final text = tester.widget<Text>(find.text('YOUR FARE TICKET'));
    expect(text.style!.color, SgColors.goldText);
    expect(text.style!.fontSize, SgText.label.fontSize);
    // Nothing is drawn beside it.
    expect(find.byType(Container), findsNothing);
    expect(find.byType(Row), findsNothing);
  });
}
