/// Account > Safety > Trusted contacts (`/sharing/contacts/`, backend #191):
/// up to five people who get the trip link, the "Share every trip
/// automatically" switch, and the server's privacy note.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import '../../services/session_events.dart' show kLoadTimeout;
import '../../services/sharing_service.dart';
import '../../ui/appearance_settings.dart' show sgStrings;
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';

/// Picks a name and number from the phone's contacts; null when cancelled.
typedef ContactPicker = Future<({String name, String phone})?> Function();

/// The system contact picker: the rider chooses one number, and the app
/// needs no contacts permission (it never reads the address book).
Future<({String name, String phone})?> pickNativeContact() async {
  final c = await FlutterNativeContactPicker().selectPhoneNumber();
  if (c == null) return null;
  final phone = (c.selectedPhoneNumber ?? c.phoneNumbers?.firstOrNull ?? '')
      .trim();
  if (phone.isEmpty) return null;
  return (name: c.fullName ?? '', phone: phone);
}

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({
    super.key,
    this.service,
    this.pickContact,
    this.onChanged,
  });

  final SharingService? service;

  /// The native picker; null hides "Pick from contacts".
  final ContactPicker? pickContact;

  /// Called with the count after every load (Account's "2 trusted contacts").
  final ValueChanged<int>? onChanged;

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  late final SharingService _service = widget.service ?? SharingService();
  TrustedContacts? _data;
  bool? _autoShare;
  bool _loading = true;
  bool _failed = false;
  bool _savingSwitch = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    TrustedContacts? data;
    bool? auto;
    try {
      final r = await Future.wait([
        _service.fetchContacts(),
        _service.fetchAutoShare(),
      ]).timeout(kLoadTimeout);
      data = r[0] as TrustedContacts;
      auto = r[1] as bool;
    } catch (e) {
      debugPrint('Trusted contacts failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = data == null;
      if (data != null) {
        _data = data;
        _autoShare = auto;
      }
    });
    if (data != null) widget.onChanged?.call(data.contacts.length);
  }

  Future<void> _toggle(bool on) async {
    final l = sgStrings(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingSwitch = true);
    try {
      final now = await _service.setAutoShare(on).timeout(kLoadTimeout);
      if (mounted) setState(() => _autoShare = now);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.autoShareFailed)));
    }
    if (mounted) setState(() => _savingSwitch = false);
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<TrustedContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: AddContactSheet(
          service: _service,
          pickContact: widget.pickContact,
        ),
      ),
    );
    if (added != null && mounted) await _load();
  }

  Future<void> _remove(TrustedContact c) async {
    final l = sgStrings(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: SgColors.bg100,
        title: Text(l.contactRemoveTitle(c.name), style: SgText.title),
        content: Text(l.contactRemoveBody, style: SgText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(l.cancel, style: SgText.body),
          ),
          TextButton(
            key: const Key('contact_remove_confirm'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(
              l.remove,
              style: SgText.body.copyWith(
                color: SgColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await _service.deleteContact(c.id).timeout(kLoadTimeout);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.contactRemoveFailed)));
      return;
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    final data = _data;
    final Widget body;
    if (_loading && data == null) {
      body = Center(
        key: const Key('contacts_loading'),
        child: CircularProgressIndicator(color: SgColors.gold500),
      );
    } else if (_failed && data == null) {
      body = Center(
        key: const Key('contacts_error'),
        child: Padding(
          padding: const EdgeInsets.all(SgSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.contactsLoadErr,
                style: SgText.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SgSpace.s3),
              TextButton(
                key: const Key('contacts_retry'),
                onPressed: _load,
                child: Text(
                  l.tryAgain,
                  style: SgText.body.copyWith(
                    color: SgColors.goldText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final d = data!;
      final max = d.max;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, SgSpace.s6),
        children: [
          if (_autoShare != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: SgSpace.s2),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: SgColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.autoShareTrips,
                      style: SgText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    key: const Key('contacts_auto_share'),
                    value: _autoShare!,
                    activeThumbColor: SgColors.onGold,
                    activeTrackColor: SgColors.gold500,
                    onChanged: _savingSwitch ? null : _toggle,
                  ),
                ],
              ),
            ),
          const SizedBox(height: SgSpace.s3),
          if (d.contacts.isEmpty)
            Padding(
              key: const Key('contacts_empty'),
              padding: const EdgeInsets.symmetric(vertical: SgSpace.s3),
              child: Text(l.trustedContactsNone, style: SgText.caption),
            ),
          for (final c in d.contacts)
            Container(
              key: Key('contact_${c.id}'),
              padding: const EdgeInsets.symmetric(vertical: SgSpace.s2),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: SgColors.divider)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SgColors.bg200,
                      borderRadius: BorderRadius.circular(SgSpace.s3),
                    ),
                    child: Center(
                      child: SgIcon(
                        SgIcons.user,
                        size: 20,
                        color: SgColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: SgSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SgText.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(c.phone, style: SgText.caption),
                        if (c.optedOut)
                          Text(
                            l.contactOptedOut,
                            style: SgText.caption.copyWith(
                              color: SgColors.danger,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l.remove,
                    child: InkWell(
                      key: Key('contact_remove_${c.id}'),
                      customBorder: const CircleBorder(),
                      onTap: () => _remove(c),
                      child: SizedBox(
                        width: kSgTouch,
                        height: kSgTouch,
                        child: Center(
                          child: SgIcon(
                            SgIcons.close,
                            size: 18,
                            color: SgColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (d.note.isNotEmpty) ...[
            const SizedBox(height: SgSpace.s3),
            Text(
              d.note,
              key: const Key('contacts_note'),
              style: SgText.caption,
            ),
          ],
          const SizedBox(height: SgSpace.s5),
          if (max == null || d.contacts.length < max)
            SgPrimaryButton(
              key: const Key('contacts_add'),
              label: l.contactAdd,
              onPressed: _add,
            ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                SgSpace.s4,
                20,
                SgSpace.s3,
              ),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: l.back,
                      child: InkWell(
                        key: const Key('contacts_back'),
                        onTap: () => Navigator.of(context).maybePop(),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 32,
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SgIcon(
                              SgIcons.back,
                              size: 20,
                              color: SgColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(l.trustedContacts, style: SgText.title),
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Name and number, "Pick from contacts", Save. Shows the server's message
/// when it refuses (bad number, already added, five already).
class AddContactSheet extends StatefulWidget {
  const AddContactSheet({super.key, required this.service, this.pickContact});
  final SharingService service;
  final ContactPicker? pickContact;

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final pick = widget.pickContact;
    if (pick == null) return;
    ({String name, String phone})? got;
    try {
      got = await pick();
    } catch (e) {
      debugPrint('Contact picker failed: $e');
    }
    if (!mounted || got == null) return;
    setState(() {
      var n = got!.name.trim();
      if (n.length > 60) n = n.substring(0, 60);
      _name.text = n;
      _phone.text = got.phone.trim();
      _error = null;
    });
  }

  bool get _canSave =>
      !_saving && _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;

  Future<void> _save() async {
    final l = sgStrings(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = await widget.service
          .addContact(name: _name.text.trim(), phone: _phone.text.trim())
          .timeout(kLoadTimeout);
      if (!mounted) return;
      Navigator.of(context).pop(c);
    } on SharingError catch (e) {
      if (!mounted) return;
      final m = e.message?.trim() ?? '';
      setState(() {
        _saving = false;
        _error = (e.status >= 400 && e.status < 500 && m.isNotEmpty)
            ? m
            : l.contactSaveFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l.contactSaveFailed;
      });
    }
  }

  Widget _field(
    Key key,
    TextEditingController c,
    String hint, {
    TextInputType? type,
    int? max,
  }) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: SgColors.bg200,
      borderRadius: BorderRadius.circular(SgSpace.s3),
    ),
    child: TextField(
      key: key,
      controller: c,
      style: SgText.body,
      maxLines: 1,
      maxLength: max,
      keyboardType: type,
      inputFormatters: type == TextInputType.phone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]'))]
          : null,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        counterText: '',
        hintText: hint,
        hintStyle: SgText.body.copyWith(color: SgColors.inkMuted),
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    return SgSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.contactAdd, style: SgText.title),
            const SizedBox(height: SgSpace.s4),
            _field(const Key('contact_name'), _name, l.contactName, max: 60),
            const SizedBox(height: SgSpace.s3),
            _field(
              const Key('contact_phone'),
              _phone,
              l.phoneHint,
              type: TextInputType.phone,
            ),
            if (widget.pickContact != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('contact_pick'),
                  onPressed: _pick,
                  child: Text(
                    l.contactPick,
                    style: SgText.body.copyWith(
                      color: SgColors.goldText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: SgSpace.s2),
              Text(
                _error!,
                key: const Key('contact_error'),
                style: SgText.caption.copyWith(color: SgColors.danger),
              ),
            ],
            const SizedBox(height: SgSpace.s4),
            SgPrimaryButton(
              key: const Key('contact_save'),
              label: l.placeSave,
              onPressed: _canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
