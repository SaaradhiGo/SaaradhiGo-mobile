/// Address placeholders follow the market, never a hard-coded US sample.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/core/market/market_config.dart';

MarketConfig _market(String code) => MarketConfig.fromData({
  'country': {'code': code, 'name': code},
});

void main() {
  test('India: Hyderabad-style street, 6-digit PIN code', () {
    final c = _market('IN');
    expect(c.streetAddressHint, 'Road No. 12, Banjara Hills');
    expect(c.postalCodeHint, '500034');
    expect(c.postalCodeHint, hasLength(6));
    expect(c.postalCodeLabel, 'PIN code');
  });

  test('built-in default is India', () {
    expect(MarketConfig.builtIn.postalCodeHint, '500034');
  });

  test('United States: 5-digit ZIP code', () {
    final c = _market('US');
    expect(c.streetAddressHint, '123 Main Street');
    expect(c.postalCodeHint, '78701');
    expect(c.postalCodeLabel, 'ZIP code');
  });

  test('any other market gets neutral text, no US sample', () {
    final c = _market('GB');
    expect(c.streetAddressHint, 'Street address');
    expect(c.postalCodeHint, 'Postal code');
    expect(c.postalCodeLabel, 'Postal code');
  });
}
