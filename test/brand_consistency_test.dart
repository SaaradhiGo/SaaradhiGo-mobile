import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app must present one name, and it is SaaradhiGo.
///
/// This app was branded VahanGo in places a rider actually sees: the Android task
/// switcher title, the wallet label ("VahanGo Credits"), and the iOS home-screen
/// name. The Android launcher label already said SaaradhiGo, so the two disagreed
/// on the same device.
///
/// The Dart package was also named `vahango`, which is why every import in this
/// repository referenced a brand we are not building.
void main() {
  const retired = 'vahango';

  /// Files that can put text in front of a user, or that name the package.
  List<File> brandSurfaces() {
    final files = <File>[];
    for (final dir in ['lib', 'test']) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      files.addAll(d
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          // This file necessarily contains the string it searches for.
          .where((f) => !f.path.endsWith('brand_consistency_test.dart')));
    }
    for (final p in [
      'pubspec.yaml',
      'ios/Runner/Info.plist',
      'android/app/src/main/AndroidManifest.xml',
    ]) {
      final f = File(p);
      if (f.existsSync()) files.add(f);
    }
    return files;
  }

  test('the retired brand appears nowhere outside a comment', () {
    final offenders = <String>[];
    for (final file in brandSurfaces()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        // Comments explaining the migration are fine and useful.
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('///') ||
            trimmed.startsWith('#') ||
            trimmed.startsWith('<!--')) {
          continue;
        }
        if (line.toLowerCase().contains(retired)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'the retired brand is still present:\n${offenders.join('\n')}');
  });

  test('the dart package is named for the product', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('name: saaradhigo_rider'));
    expect(pubspec, isNot(contains('A new Flutter project')),
        reason: 'the scaffold description made this look like a throwaway app');
  });

  test('android and ios agree on the app name', () {
    // They did not. Android said SaaradhiGo, iOS said Vahango, so the same build
    // wore two names depending on the platform.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="SaaradhiGo"'));

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>SaaradhiGo</string>'),
        reason: 'CFBundleDisplayName is the name under the iOS icon');
  });
}
