/// The one place trip dates are worded. US trips read month-first with a
/// 12-hour clock ("Sat, Nov 14", "Nov 14, 2026", "7:30 PM"); India keeps its
/// day-first wording ("Sat, 14 Nov", "14 Nov 2026"). Do not scatter
/// `DateFormat` patterns for trips: add a method here.
library;

import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _tzReady = false;

/// [instant] as the wall clock read where the trip happened ([zone], an IANA
/// name such as America/Boise), not on the phone. Unknown zone: the phone's.
DateTime inTripZone(DateTime instant, String? zone) {
  if (zone == null || zone.isEmpty) return instant.toLocal();
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  try {
    final t = tz.TZDateTime.from(instant, tz.getLocation(zone));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  } catch (_) {
    return instant.toLocal();
  }
}

class MarketDates {
  const MarketDates({required this.isUs});

  final bool isUs;

  /// A trip is US when its currency is USD or its timezone is `America/...`.
  factory MarketDates.forTrip({String? currency, String? timezone}) =>
      MarketDates(
        isUs:
            (currency ?? '').toUpperCase() == 'USD' ||
            (timezone ?? '').startsWith('America/'),
      );

  /// "Sat, Nov 14" / "Sat, 14 Nov".
  String weekdayDay(DateTime d) =>
      DateFormat(isUs ? 'EEE, MMM d' : 'EEE, d MMM').format(d);

  /// "Nov 14, 2026" / "14 Nov 2026".
  String date(DateTime d) =>
      DateFormat(isUs ? 'MMM d, yyyy' : 'd MMM yyyy').format(d);

  /// "7:30 PM" in both markets (India's existing `h:mm a`).
  String time(DateTime d) => DateFormat('h:mm a').format(d);

  /// A history row's date line: "Nov 14, 7:30 PM" / "14 Nov, 7:30 PM".
  String shortDateTime(DateTime d) =>
      DateFormat(isUs ? 'MMM d, h:mm a' : 'd MMM, h:mm a').format(d);

  /// The history list's month heading: "November 2026".
  String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
}
