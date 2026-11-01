/// The rider app's Android manifest must parse, declare no secrets, and keep
/// its Gradle placeholders supplied.
///
/// WHY THIS FILE EXISTS
/// --------------------
/// The manifest shipped a literal Google Maps key:
///
///     <meta-data android:name="com.google.android.geo.API_KEY"
///         android:value="AIzaSy..."/>
///
/// committed in the initial commit, so it is in git history and has to be
/// treated as compromised regardless of what HEAD says. It was also unused —
/// this app renders maps with flutter_map over OSM tiles and has no
/// google_maps_flutter dependency — so nothing noticed for the life of the
/// repo.
///
/// Neither `flutter analyze` nor `flutter test` reads this file, and an APK
/// builds fine with a secret in it. Hence a crude text check that runs in a
/// second.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('the manifest exists and is well-formed XML', () {
    expect(manifest.existsSync(), isTrue);
    expect(
      () => XmlDocument.parse(manifest.readAsStringSync()),
      returnsNormally,
      reason: 'the manifest does not parse, so no APK can be built',
    );
  });

  test('no comment contains a double hyphen', () {
    // XML forbids `--` inside a comment, and it is easy to reintroduce by
    // pasting a `--dart-define` command line into an explanation. The driver
    // app shipped exactly that and was unbuildable for weeks.
    final comments = RegExp(r'<!--(.*?)-->', dotAll: true)
        .allMatches(manifest.readAsStringSync());
    for (final c in comments) {
      expect(c.group(1)!.contains('--'), isFalse,
          reason: 'a double hyphen in an XML comment breaks every APK build');
    }
  });

  test('no API key is committed', () {
    expect(manifest.readAsStringSync(), isNot(contains('AIza')),
        reason: 'a Google API key literal is committed in the manifest');
  });

  test('every Gradle placeholder the manifest uses is actually supplied', () {
    // An unsupplied placeholder is a build failure, so the two files have to
    // agree. This is what makes removing the hardcoded key safe.
    final text = manifest.readAsStringSync();
    final placeholders = RegExp(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((n) => n != 'applicationName') // supplied by the Flutter plugin
        .toSet();

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    for (final name in placeholders) {
      expect(gradle.contains('manifestPlaceholders["$name"]'), isTrue,
          reason: 'the manifest uses \${$name} and build.gradle.kts does not '
              'define it; the build fails');
    }
  });

  test('the background location service declares its Android 14 type', () {
    // The rider app runs a foreground location service while a ride is in
    // progress. From API 34 a location service with no declared
    // foregroundServiceType throws MissingForegroundServiceTypeException.
    final doc = XmlDocument.parse(manifest.readAsStringSync());
    final background = doc.findAllElements('service').where(
          (e) => (e.getAttribute('android:name') ?? '')
              .endsWith('flutter_background_service.BackgroundService'),
        );

    expect(background, isNotEmpty);
    expect(background.first.getAttribute('android:foregroundServiceType'),
        'location');
  });

  test('the rider app does NOT request background location', () {
    // A rider's location is only needed while the app is in use. Requesting
    // ACCESS_BACKGROUND_LOCATION would also trigger a Play Console
    // declaration and review that this app has no justification for.
    final doc = XmlDocument.parse(manifest.readAsStringSync());
    final declared = doc
        .findAllElements('uses-permission')
        .map((e) => e.getAttribute('android:name'))
        .whereType<String>()
        .toSet();

    expect(declared, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(declared,
        isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')));
  });
}
