import '../../ui/appearance_settings.dart' show sgStrings;
import 'package:flutter/material.dart';

import '../../core/notifications/notification_prefs.dart';
import '../../services/notification_preferences_service.dart';
import '../../services/token_store.dart';
import '../../ui/sg_text.dart';

const String kPrefsSaveFailed =
    "We couldn't save that change. Your setting has not changed.";

const Map<String, String> _channelNames = {
  'in_app': 'In the app',
  'push': 'Push notifications',
  'sms': 'SMS',
  'email': 'Email',
};

/// Notification preferences (R4): GET and PUT /notifications/preferences/.
///
/// Consent rules, all enforced here as well as by the API:
/// * nothing is saved on opening the screen; a row is written only when the
///   rider flips its switch;
/// * offers (promotional) and WhatsApp are never pre-ticked: the switch shows
///   what the API says, and the API's default for both is off;
/// * ride and account updates in the app and by push are shown fixed on, with
///   a disabled switch and a one-line reason.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({
    super.key,
    this.service,
    this.tokenReader,
  });

  final NotificationPreferencesService? service;
  final Future<String?> Function()? tokenReader;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  NotificationPrefs? _prefs;
  bool _loading = true;
  bool _failed = false;
  String? _error;
  final Set<PrefKey> _saving = {};

  NotificationPreferencesService get _service =>
      widget.service ?? NotificationPreferencesService();

  Future<String?> _token() =>
      (widget.tokenReader ?? TokenStore.readAccessToken)();

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
    final token = await _token();
    NotificationPrefs? prefs;
    if (token != null && token.isNotEmpty) {
      prefs = await _service.fetch(token);
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _failed = prefs == null;
      _loading = false;
    });
  }

  /// Optimistic: the switch moves at once, the PUT follows, and a failure puts
  /// the switch back and says so.
  Future<void> _toggle(String channel, String category, bool value) async {
    final before = _prefs;
    if (before == null) return;
    final key = PrefKey(channel, category);
    if (_saving.contains(key)) return;
    setState(() {
      _error = null;
      _saving.add(key);
      _prefs = before.withValue(channel, category, value);
    });
    final token = await _token();
    NotificationPrefs? saved;
    if (token != null && token.isNotEmpty) {
      saved = await _service.save(
        token,
        channel: channel,
        category: category,
        optedIn: value,
      );
    }
    if (!mounted) return;
    setState(() {
      _saving.remove(key);
      if (saved != null) {
        _prefs = saved;
      } else {
        _prefs = _prefs?.withValue(
          channel,
          category,
          before.value(channel, category),
        );
        _error = kPrefsSaveFailed;
      }
    });
  }

  Widget _row({
    required String channel,
    required String category,
    required String title,
    required String subtitle,
    required bool fixed,
  }) {
    final prefs = _prefs!;
    final saving = _saving.contains(PrefKey(channel, category));
    return SwitchListTile(
      key: Key('pref_${channel}_$category'),
      title: Text(title),
      subtitle: Text(subtitle),
      value: prefs.value(channel, category),
      onChanged: fixed || saving ? null : (v) => _toggle(channel, category, v),
    );
  }

  Widget _section(String heading, String? note, List<Widget> rows) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              heading,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                note,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: SgText.sizeSmall,
                ),
              ),
            ),
          ...rows,
        ],
      ),
    );
  }

  List<Widget> _body(NotificationPrefs prefs) {
    final transactional = <Widget>[
      for (final channel in const ['in_app', 'push'])
        if (prefs.has(channel, kTransactional))
          _row(
            channel: channel,
            category: kTransactional,
            title: _channelNames[channel]!,
            subtitle: sgStrings(context).alwaysOnRides,
            fixed: true,
          ),
    ];
    final promotional = <Widget>[
      for (final channel in const ['push', 'sms', 'email', 'in_app'])
        if (prefs.has(channel, kPromotional))
          _row(
            channel: channel,
            category: kPromotional,
            title: _channelNames[channel]!,
            subtitle: sgStrings(context).offUnlessOn,
            fixed: prefs.isLocked(channel, kPromotional),
          ),
    ];
    final whatsapp = <Widget>[
      if (prefs.has('whatsapp', kTransactional))
        _row(
          channel: 'whatsapp',
          category: kTransactional,
          title: sgStrings(context).rideUpdatesWhatsapp,
          subtitle: sgStrings(context).offUnlessOn,
          fixed: prefs.isLocked('whatsapp', kTransactional),
        ),
      if (prefs.has('whatsapp', kPromotional))
        _row(
          channel: 'whatsapp',
          category: kPromotional,
          title: sgStrings(context).offersWhatsapp,
          subtitle: sgStrings(context).offUnlessOn,
          fixed: prefs.isLocked('whatsapp', kPromotional),
        ),
    ];
    return [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            _error!,
            key: const Key('prefs_error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (transactional.isNotEmpty)
        _section('Ride and account updates', null, transactional),
      if (promotional.isNotEmpty)
        _section(
          'Offers and news',
          'Choose where you would like to hear about offers. '
              'You can change this at any time.',
          promotional,
        ),
      if (whatsapp.isNotEmpty) _section('WhatsApp', null, whatsapp),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification preferences',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "We couldn't load your notification preferences.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('prefs_retry'),
                      onPressed: _load,
                      child: Text(sgStrings(context).tryAgain),
                    ),
                  ],
                ),
              ),
            )
          : ListView(children: _body(_prefs!)),
    );
  }
}
