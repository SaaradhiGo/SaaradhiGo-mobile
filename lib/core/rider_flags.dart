/// Parts of the signed-in designs (2026-11-08) that nothing backs yet. Each
/// stays off until the API or flow it names exists; the screens leave the
/// element out rather than show a value the API did not return.
library;

class RiderFlags {
  RiderFlags._();

  /// "Home" / "Work" chips and labels, from the `label` (home|work|other)
  /// that GET /rider/places/ returns on each saved place.
  static const homeWorkLabels = true;

  /// "Add a place" chip on the home sheet (POST /rider/places/, 2026-11-09).
  static const addPlaceChip = true;

  /// Account > Safety > Trusted contacts and the auto-share switch
  /// (/sharing/contacts/ and /sharing/settings/, 2026-11-09).
  static const trustedContacts = true;

  /// "Share trip" on the arriving and on-trip screens and in the Safety
  /// sheet (/sharing/trips/<id>/share/, 2026-11-09).
  static const shareTrip = true;
}
