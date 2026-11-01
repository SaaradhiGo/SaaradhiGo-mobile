/// The release build must be signed with a real key, or refuse to build.
///
/// THE DEFECT THIS LOCKS DOWN
/// --------------------------
/// `android/app/build.gradle.kts` had:
///
///     release {
///         // TODO: replace with the real upload key before the pilot.
///         signingConfig = signingConfigs.getByName("debug")
///
/// So every release APK of the driver app was signed with the Android debug
/// key — a key that ships with the SDK and is identical on every developer
/// machine and CI image. Play rejects it, and anything side-loaded from it is
/// signed with a key nobody owns, so it can never be updated by a real build.
///
/// A debug-signed APK installs and runs, which is exactly why this went
/// unnoticed: `flutter test`, `flutter analyze` and even a successful
/// `flutter build apk` all pass with it.
///
/// These are text assertions on the Gradle file. That is crude, and it is the
/// only check that runs without a JDK, an Android SDK and a keystore. CI runs
/// the real thing: an unsigned release build must FAIL.
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts');

  test('the gradle file exists', () {
    expect(gradle.existsSync(), isTrue);
  });

  test('the release build type does not unconditionally use the debug key', () {
    final text = gradle.readAsStringSync();

    // The exact line that shipped.
    expect(
      text,
      isNot(contains(RegExp(
          r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)\s*$',
          multiLine: true))),
      reason: 'the release build type assigns the debug signing config '
          'unconditionally',
    );
    expect(
      text,
      contains('signingConfigs.getByName("release")'),
      reason: 'there is no release signing config to use',
    );
  });

  test('a release build with no signing material is refused', () {
    final text = gradle.readAsStringSync();

    // The guard, not just the config: without it a missing keystore silently
    // falls back to debug again.
    expect(text, contains('Release build refused'),
        reason: 'no guard stops an unsigned release build');
    expect(text, contains('gradle.startParameter.taskNames'),
        reason: 'the guard must fire only for release tasks, so that '
            '`flutter build apk --debug` keeps working with no secrets');
    expect(text, contains('allowDebugSigning'),
        reason: 'there must be an explicit, logged opt-out for '
            '`flutter run --release` on a dev machine');
  });

  test('signing material is read from key.properties or the environment', () {
    final text = gradle.readAsStringSync();

    for (final name in const [
      'ANDROID_KEYSTORE_PATH',
      'ANDROID_KEY_ALIAS',
      'ANDROID_KEY_PASSWORD',
      'ANDROID_STORE_PASSWORD',
    ]) {
      expect(text, contains(name),
          reason: 'CI supplies signing material through $name');
    }
    expect(text, contains('key.properties'));
  });

  test('no keystore password or path literal is committed', () {
    final text = gradle.readAsStringSync();

    // Every credential must arrive from a file or the environment. A literal
    // here would be committed, which is the whole thing being avoided.
    expect(text, isNot(contains(RegExp(r'storePassword\s*=\s*"[^"$]'))),
        reason: 'a literal store password is committed');
    expect(text, isNot(contains(RegExp(r'keyPassword\s*=\s*"[^"$]'))),
        reason: 'a literal key password is committed');
    expect(text, isNot(contains('.jks"')),
        reason: 'a keystore path literal is committed');
  });

  test('the keystore and its properties file are gitignored', () {
    final ignore = File('android/.gitignore').readAsStringSync();
    expect(ignore, contains('key.properties'));
    expect(ignore, contains('*.jks'));
    expect(ignore, contains('*.keystore'));
  });

  test('no keystore is actually present in the working tree', () {
    // Catches the accident this is all guarding against.
    final strays = Directory('android')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.jks') ||
            f.path.endsWith('.keystore') ||
            f.path.endsWith('key.properties'))
        .map((f) => f.path)
        .toList();

    expect(strays, isEmpty,
        reason: 'signing material is in the repo tree: ${strays.join(", ")}');
  });
}
