/// Parts of the signed-in designs (2026-11-08) that nothing backs yet. Each
/// stays off until the API or flow it names exists; the screens leave the
/// element out rather than show a value the API did not return.
library;

class RiderFlags {
  RiderFlags._();

  /// "Home" / "Work" chips and labels. Needs a label on each saved place from
  /// GET /rider/locations/all/.
  static const homeWorkLabels = false;

  /// "Add a place" chip on the home sheet. Needs an add-a-saved-place flow.
  static const addPlaceChip = false;

  /// Account > Safety ("2 trusted contacts"). Needs a trusted-contacts API.
  static const trustedContacts = false;

  /// "Share trip" on the arriving and on-trip screens. Needs a trip-share
  /// link API.
  static const shareTrip = false;
}
