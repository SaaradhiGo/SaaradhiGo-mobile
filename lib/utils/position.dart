/// Where the phone is, without waiting forever.
///
/// `Geolocator.getCurrentPosition` with no time limit waits for a fresh fix
/// as long as it takes. Indoors, or with a weak signal, that is indefinitely:
/// the home screen's pickup field spun on "Enter pickup point" and the rider
/// could not book (seen on the QA emulator, product phase 1). Ten seconds,
/// then the last known position, then null so the caller can ask the rider.
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';

Future<Position?> currentOrLastKnownPosition({
  Duration limit = const Duration(seconds: 10),
}) async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: limit,
      ),
    );
  } on TimeoutException {
    return Geolocator.getLastKnownPosition();
  }
}
