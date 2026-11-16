/// 16 Nov rulings: the ticket shows the exact amount held, and a socket
/// address never carries the sign-in token.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:saaradhigo_rider/services/ws_ticket.dart';
import 'package:saaradhigo_rider/ui/choose_ride_sheet.dart';

void main() {
  test('a US fare reads with cents, exactly what the card is held for', () {
    final o = RideOption.fromEstimate('sedan', {
      'estimated_fare': '28.20',
      'currency': 'USD',
    });
    expect(o!.fareText, r'$28.20');
  });

  test('the token is swapped for a ticket before the socket opens', () async {
    final asked = <http.Request>[];
    final client = MockClient((req) async {
      asked.add(req);
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': {'ticket': 'tk-1', 'expires_in': 30},
        }),
        201,
      );
    });
    final uri = await ticketedWsUri(
      'wss://qa.example/ws/ride/request/?token=secret-jwt',
      client: client,
    );
    expect(uri.toString(), 'wss://qa.example/ws/ride/request/?ticket=tk-1');
    expect(uri.toString(), isNot(contains('secret-jwt')));
    expect(asked.single.url.path, endsWith('/auth/ws-ticket/'));
    expect(asked.single.headers['Authorization'], 'Bearer secret-jwt');
  });

  test('no ticket: the address still carries no token', () async {
    final client = MockClient((_) async => http.Response('down', 503));
    final uri = await ticketedWsUri(
      'wss://qa.example/ws/ride/trip/7/?token=secret-jwt',
      client: client,
    );
    expect(uri.toString(), 'wss://qa.example/ws/ride/trip/7/');
  });
}
