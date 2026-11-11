/// Shapes of `GET/PUT /api/v1/notifications/preferences/`, copied from
/// servers/notifications/app_views.py (`_payload`) and
/// tests/test_notifications_console.py::TestPreferencesApi in the backend.
///
/// `data.effective` is `{channel: {category: bool}}` for every channel the
/// platform sends on (sms, whatsapp, email, push, in_app) and both categories
/// (transactional, promotional). `data.locked` lists the rows nobody can
/// switch off (in-app transactional). The API carries no consent wording of
/// its own, so the screen uses neutral text.
library;

import 'package:flutter/foundation.dart';

const String kTransactional = 'transactional';
const String kPromotional = 'promotional';

@immutable
class PrefKey {
  const PrefKey(this.channel, this.category);
  final String channel;
  final String category;

  @override
  bool operator ==(Object other) =>
      other is PrefKey && other.channel == channel && other.category == category;

  @override
  int get hashCode => Object.hash(channel, category);
}

@immutable
class NotificationPrefs {
  const NotificationPrefs({required this.effective, required this.locked});

  /// `{channel: {category: opted in}}` exactly as the dispatcher reads it.
  final Map<String, Map<String, bool>> effective;

  /// Rows that cannot be switched off.
  final Set<PrefKey> locked;

  /// Whether the API lists [channel] at all.
  bool hasChannel(String channel) => effective.containsKey(channel);

  /// Whether the API lists this row.
  bool has(String channel, String category) =>
      effective[channel]?.containsKey(category) ?? false;

  /// The current value. A row the API did not list reads as off, never on.
  bool value(String channel, String category) =>
      effective[channel]?[category] ?? false;

  bool isLocked(String channel, String category) =>
      locked.contains(PrefKey(channel, category));

  NotificationPrefs withValue(String channel, String category, bool v) {
    final next = <String, Map<String, bool>>{
      for (final e in effective.entries) e.key: Map<String, bool>.of(e.value),
    };
    (next[channel] ??= <String, bool>{})[category] = v;
    return NotificationPrefs(effective: next, locked: locked);
  }

  static NotificationPrefs? fromData(Object? data) {
    if (data is! Map) return null;
    final eff = data['effective'];
    if (eff is! Map) return null;
    final effective = <String, Map<String, bool>>{};
    eff.forEach((channel, cats) {
      if (cats is! Map) return;
      final row = <String, bool>{};
      cats.forEach((category, v) {
        if (v is bool) row['$category'] = v;
      });
      effective['$channel'] = row;
    });
    final locked = <PrefKey>{};
    final raw = data['locked'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['channel'] != null && item['category'] != null) {
          locked.add(PrefKey('${item['channel']}', '${item['category']}'));
        }
      }
    }
    return NotificationPrefs(effective: effective, locked: locked);
  }
}
