// Fails when lib/ sets a raw font size or a weight outside 400/600 anywhere
// but the theme file: sizes and weights come from SgText (lib/ui/sg_text.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'lib/ has no raw fontSize, no off-scale FontWeight, no stray tracking',
    () {
      final bad = <String>[];
      final rawSize = RegExp(r'fontSize:\s*[\d.]');
      final rawPx = RegExp(r'SgText\.(px|size)\(');
      final weight = RegExp(r'FontWeight\.(?!w400\b|w600\b)\w+|FontWeight\(');
      final spacing = RegExp(r'letterSpacing:\s*(?!0\s*[,)]|0\.0\s*[,)])[^\s]');
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final path = e.path.replaceAll(r'\', '/');
        if (path.endsWith('lib/ui/sg_text.dart')) continue;
        final lines = e.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (l.trimLeft().startsWith('//')) continue;
          if (rawSize.hasMatch(l) ||
              rawPx.hasMatch(l) ||
              weight.hasMatch(l) ||
              spacing.hasMatch(l)) {
            bad.add('$path:${i + 1}: ${l.trim()}');
          }
        }
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
    },
  );
}
