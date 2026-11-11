// Signed-in designs (2026-11-08): what the new rows show comes only from
// the API's own fields.
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/ui/account_widgets.dart';
import 'package:saaradhigo_rider/ui/choose_ride_sheet.dart';

void main() {
  test('Locked only when the quote carries a quote_id', () {
    final locked = RideOption.fromEstimate('mini', {
      'estimated_fare': '118.00',
      'currency': 'INR',
      'quote_id': 'q1',
      'quote_expires_at': '2026-11-08T10:05:00Z',
    })!;
    final plain = RideOption.fromEstimate('mini', {
      'estimated_fare': '118.00',
      'currency': 'INR',
    })!;
    expect(locked.locked, isTrue);
    expect(locked.quoteExpiresAt, DateTime.utc(2026, 11, 8, 10, 5));
    expect(plain.locked, isFalse);
    expect(plain.quoteExpiresAt, isNull);
  });

  test('Fare held: whole minutes left, nothing once expired or unknown', () {
    final now = DateTime.utc(2026, 11, 8, 10);
    expect(heldMinutes(DateTime.utc(2026, 11, 8, 10, 4, 30), now: now), 5);
    expect(heldMinutes(DateTime.utc(2026, 11, 8, 9, 59), now: now), isNull);
    expect(heldMinutes(null, now: now), isNull);
  });

  test('the phone shows the country code and the last three digits', () {
    expect(maskedPhone('+91', '9876543210'), '+91 ••••• ••210');
    expect(maskedPhone(null, '9876543210'), '••••• ••210');
    expect(maskedPhone('+91', null), '');
  });
}
