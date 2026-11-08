import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/services/websocket_service.dart';

void main() {
  test('a refreshed token replaces the old one in the socket URL', () {
    const url = 'wss://host/ws/ride/trip/12/?token=old.jwt.value';
    final out = replaceWsToken(url, 'new.jwt.value');
    expect(Uri.parse(out).queryParameters['token'], 'new.jwt.value');
    expect(out, startsWith('wss://host/ws/ride/trip/12/'));
  });

  test('logs never carry the token', () {
    expect(redactWsToken('wss://h/ws/ride/request/?token=abc.def&x=1'),
        'wss://h/ws/ride/request/?token=***&x=1');
  });
}
