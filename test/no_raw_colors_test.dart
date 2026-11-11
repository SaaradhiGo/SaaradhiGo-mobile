import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Colours come from lib/ui/sg_tokens.dart and nowhere else, and every font is
/// bundled (spec 1.1, 1.2). The legacy gold and slate greys must not return.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  String rel(File f) => f.path.replaceAll(r'\', '/');

  test(
    'no Color(0x...), Colors.<name> or hex string outside sg_tokens.dart',
    () {
      final raw = RegExp(
        r'Color\(\s*0x|(?<![A-Za-z0-9_])Colors\.(?!transparent\b)[a-zA-Z]|'
        r"""['"]#[0-9a-fA-F]{6}\b""",
      );
      final offenders = <String>[];
      for (final f in files) {
        if (rel(f).endsWith('lib/ui/sg_tokens.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (raw.hasMatch(lines[i])) {
            offenders.add('${rel(f)}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );

  test('no runtime font fetching', () {
    final offenders = [
      for (final f in files)
        if (f.readAsStringSync().contains('package:google_fonts/')) rel(f),
    ];
    expect(offenders, isEmpty);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('google_fonts:')),
    );
  });

  test('the old emblem and icon source are gone', () {
    final offenders = [
      for (final f in [...files, File('pubspec.yaml')])
        if (RegExp(
          r'saaradhigo-emblem|assets/icon/',
        ).hasMatch(f.readAsStringSync()))
          rel(f),
    ];
    expect(offenders, isEmpty);
  });
}
