// Round 3: the Android QA build asked Stripe for Apple Pay with no merchant
// id; the assert threw and US booking did nothing. Apple Pay is iOS-only and
// needs STRIPE_MERCHANT_IDENTIFIER.
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/services/card_hold_service.dart';

void main() {
  test('Android never asks for Apple Pay', () {
    expect(
      holdSheetApplePay(isIOS: false, merchantId: 'merchant.com.x'),
      isNull,
    );
  });
  test('iOS without a merchant id leaves Apple Pay out', () {
    expect(holdSheetApplePay(isIOS: true, merchantId: ''), isNull);
  });
  test('iOS with a merchant id offers Apple Pay in the US', () {
    final p = holdSheetApplePay(isIOS: true, merchantId: 'merchant.com.x');
    expect(p, isNotNull);
    expect(p!.merchantCountryCode, 'US');
  });
}
