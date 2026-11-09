/// Trusted contacts (`/sharing/contacts/` and `/sharing/settings/`,
/// 2026-11-09): loaded with the note and the switch, empty, error with Try
/// again, a 10 s timeout, remove with a confirm, and the server's refusal.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/screens/profile/trusted_contacts_screen.dart';
import 'package:saaradhigo_rider/services/sharing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _note =
    'Your contacts only see this trip, and only until 30 minutes after it ends.';

class _Fake extends SharingService {
  _Fake(this.contacts);
  List<TrustedContact> contacts;
  bool fail = false;
  bool hang = false;
  bool auto = false;
  final removed = <int>[];
  SharingError? refuse;

  @override
  Future<TrustedContacts> fetchContacts() async {
    if (hang) return Completer<TrustedContacts>().future;
    if (fail) throw const SharingError('HTTP_500', status: 500);
    return TrustedContacts(contacts: contacts, max: 5, note: _note);
  }

  @override
  Future<bool> fetchAutoShare() async => auto;

  @override
  Future<bool> setAutoShare(bool on) async => auto = on;

  @override
  Future<void> deleteContact(int id) async {
    removed.add(id);
    contacts = contacts.where((c) => c.id != id).toList();
  }

  @override
  Future<TrustedContact> addContact({
    required String name,
    required String phone,
  }) async {
    if (refuse != null) throw refuse!;
    final c = TrustedContact(id: 9, name: name, phone: phone);
    contacts = [...contacts, c];
    return c;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _Fake s, {ContactPicker? pick}) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TrustedContactsScreen(service: s, pickContact: pick),
      ),
    );
    await tester.pump();
  }

  const asha = TrustedContact(id: 1, name: 'Asha', phone: '+919800000001');

  testWidgets('loaded: contact, opted-out line, note, switch', (tester) async {
    final s = _Fake([
      asha,
      const TrustedContact(
        id: 2,
        name: 'Ravi',
        phone: '+919800000002',
        optedOut: true,
      ),
    ]);
    await pump(tester, s);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Stopped getting messages'), findsOneWidget);
    expect(find.text(_note), findsOneWidget);
    await tester.tap(find.byKey(const Key('contacts_auto_share')));
    await tester.pump();
    expect(s.auto, isTrue);
  });

  testWidgets('empty shows the message and Add', (tester) async {
    await pump(tester, _Fake([]));
    expect(find.byKey(const Key('contacts_empty')), findsOneWidget);
    expect(find.byKey(const Key('contacts_add')), findsOneWidget);
  });

  testWidgets('error, then Try again', (tester) async {
    final s = _Fake([asha])..fail = true;
    await pump(tester, s);
    expect(find.byKey(const Key('contacts_error')), findsOneWidget);
    s.fail = false;
    await tester.tap(find.byKey(const Key('contacts_retry')));
    await tester.pump();
    expect(find.text('Asha'), findsOneWidget);
  });

  testWidgets('a load that never answers ends in the error at 10 s', (
    tester,
  ) async {
    await pump(tester, _Fake([])..hang = true);
    expect(find.byKey(const Key('contacts_loading')), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(const Key('contacts_error')), findsOneWidget);
  });

  testWidgets('remove asks first', (tester) async {
    final s = _Fake([asha]);
    await pump(tester, s);
    await tester.tap(find.byKey(const Key('contact_remove_1')));
    await tester.pumpAndSettle();
    expect(find.text('Remove Asha?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact_remove_confirm')));
    await tester.pumpAndSettle();
    expect(s.removed, [1]);
    expect(find.text('Asha'), findsNothing);
  });

  testWidgets('add: picker fills the fields; the server message shows', (
    tester,
  ) async {
    final s = _Fake([])
      ..refuse = const SharingError(
        'VALIDATION_ERROR',
        status: 400,
        field: 'phone',
        message: 'Enter a valid mobile number for your country.',
      );
    await pump(
      tester,
      s,
      pick: () async => (name: 'Mum', phone: '98000 00003'),
    );
    await tester.tap(find.byKey(const Key('contacts_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact_pick')));
    await tester.pump();
    expect(find.text('Mum'), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact_save')));
    await tester.pump();
    expect(
      find.text('Enter a valid mobile number for your country.'),
      findsOneWidget,
    );
    s.refuse = null;
    await tester.tap(find.byKey(const Key('contact_save')));
    await tester.pumpAndSettle();
    expect(find.text('Mum'), findsOneWidget); // now on the list
    expect(find.byKey(const Key('contact_save')), findsNothing);
  });

  test('service reads contacts, max and note', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'a'});
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'a',
      'refresh_token': 'r',
    });
    final r = await http.runWithClient(
      () => SharingService().fetchContacts(),
      () => MockClient(
        (req) async => http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'contacts': [
                {
                  'id': 3,
                  'name': 'Asha',
                  'phone': '+919800000001',
                  'opted_out': false,
                  'last_message': null,
                },
              ],
              'max': 5,
              'note': _note,
            },
          }),
          200,
        ),
      ),
    );
    expect(r.contacts.single.name, 'Asha');
    expect(r.max, 5);
    expect(r.note, _note);
  });
}
