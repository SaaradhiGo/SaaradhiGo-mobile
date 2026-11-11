/// "Share" (the trip link, `/sharing/trips/<id>/share/`) and "Call" (a masked
/// call, `/calls/trips/<id>/start/`) on the trip screens and the Safety sheet
/// (2026-11-09). Neither ever shows a phone number.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../services/api_service.dart';
import '../services/session_events.dart' show kLoadTimeout;
import '../services/sharing_service.dart';
import '../ui/appearance_settings.dart' show sgStrings;
import '../ui/sg_text.dart';
import '../ui/sg_tokens.dart';
import '../ui/sg_widgets.dart';

void _say(BuildContext context, String m) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/// Test seams: what opens the share sheet and what dials.
typedef ShareText = Future<void> Function(String text);
typedef Dial = Future<bool> Function(Uri tel);

Future<void> _systemShare(String text) =>
    SharePlus.instance.share(ShareParams(text: text));

Future<bool> _systemDial(Uri tel) =>
    launchUrl(tel, mode: LaunchMode.externalApplication);

/// Share: a live link goes straight to "Share the link again" / "Stop
/// sharing"; otherwise the link is started and handed to the share sheet
/// (copied when there is no share sheet).
Future<void> shareTripLink(
  BuildContext context,
  String? tripId, {
  SharingService? service,
  ShareText? share,
}) async {
  final l = sgStrings(context);
  final id = tripId?.trim() ?? '';
  if (id.isEmpty) return _say(context, l.shareFailed);
  final s = service ?? SharingService();
  final send = share ?? _systemShare;

  Future<void> hand(String url) async {
    final text = l.shareTripText(url);
    try {
      await send(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) _say(context, l.linkCopied);
    }
  }

  TripShareLink current;
  try {
    current = await s.tripShare(id).timeout(kLoadTimeout);
  } catch (_) {
    current = const TripShareLink(active: false);
  }
  if (!context.mounted) return;

  if (current.active && current.url != null) {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => SgSheetSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetRow(
              key: const Key('share_again'),
              icon: SgIcons.share,
              label: l.shareLinkAgain,
              onTap: () => Navigator.pop(c, 'again'),
            ),
            _SheetRow(
              key: const Key('share_stop'),
              icon: SgIcons.close,
              label: l.stopSharing,
              danger: true,
              onTap: () => Navigator.pop(c, 'stop'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'again') return hand(current.url!);
    if (choice == 'stop') {
      try {
        await s.stopTripShare(id).timeout(kLoadTimeout);
        if (context.mounted) _say(context, l.sharingStopped);
      } catch (_) {
        if (context.mounted) _say(context, l.shareFailed);
      }
    }
    return;
  }

  try {
    final started = await s.startTripShare(id).timeout(kLoadTimeout);
    if (!context.mounted) return;
    if (!started.active || started.url == null) {
      return _say(context, l.shareFailed);
    }
    await hand(started.url!);
  } on SharingError catch (e) {
    final m = e.message?.trim() ?? '';
    if (context.mounted) {
      _say(context, e.status == 409 && m.isNotEmpty ? m : l.shareFailed);
    }
  } catch (_) {
    if (context.mounted) _say(context, l.shareFailed);
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: SgSpace.s3),
      child: Row(
        children: [
          SgIcon(
            icon,
            size: 20,
            color: danger ? SgColors.danger : SgColors.goldText,
          ),
          const SizedBox(width: SgSpace.s3),
          Text(
            label,
            style: SgText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: danger ? SgColors.danger : SgColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

/// A refused or failed call start; [message] is the server's sentence.
class CallError implements Exception {
  const CallError(this.code, {this.status = 0, this.message});
  final String code;
  final int status;
  final String? message;
}

/// `POST /calls/trips/<id>/start/` and `/calls/sessions/<id>/end/`.
class CallService {
  CallService({ApiService? api}) : _apiOverride = api;
  final ApiService? _apiOverride;
  ApiService get _api => _apiOverride ?? ApiService();

  /// The number to dial (the bridge, never the driver's own) and the
  /// session to end afterwards.
  Future<({String number, String? sessionId})> start(String tripId) async {
    final r = await _api.authedRequest(
      (h) => http.post(
        Uri.parse('${AppConfig.baseUrl}/calls/trips/$tripId/start/'),
        headers: h,
      ),
    );
    Object? body;
    try {
      body = r == null ? null : json.decode(r.body);
    } catch (_) {
      body = null;
    }
    if (r == null || (r.statusCode != 200 && r.statusCode != 201)) {
      final err = body is Map ? body['error'] : null;
      throw CallError(
        err is Map ? err['code']?.toString() ?? 'HTTP' : 'NETWORK',
        status: r?.statusCode ?? 0,
        message: err is Map ? err['message']?.toString() : null,
      );
    }
    final data = body is Map ? body['data'] : null;
    final call = data is Map ? data['call'] : null;
    final number = call is Map ? call['number']?.toString().trim() ?? '' : '';
    if (number.isEmpty) throw const CallError('NO_NUMBER');
    return (number: number, sessionId: (call as Map)['session_id']?.toString());
  }

  /// Best effort; a failure is ignored.
  Future<void> end(String sessionId) async {
    try {
      await _api
          .authedRequest(
            (h) => http.post(
              Uri.parse('${AppConfig.baseUrl}/calls/sessions/$sessionId/end/'),
              headers: h,
            ),
          )
          .timeout(kLoadTimeout);
    } catch (_) {}
  }
}

/// Ends the call session when the rider comes back to the app.
class _EndOnResume with WidgetsBindingObserver {
  _EndOnResume(this.service, this.sessionId) {
    WidgetsBinding.instance.addObserver(this);
  }
  final CallService service;
  final String sessionId;
  bool _left = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _left = true;
    } else if (state == AppLifecycleState.resumed && _left) {
      WidgetsBinding.instance.removeObserver(this);
      unawaited(service.end(sessionId));
    }
  }
}

/// Call: the server's bridge number goes to the dialler. Outside the trip
/// or with calling down, the server's own sentence is shown.
Future<void> callDriverMasked(
  BuildContext context,
  String? tripId, {
  CallService? service,
  Dial? dial,
}) async {
  final l = sgStrings(context);
  final id = tripId?.trim() ?? '';
  if (id.isEmpty) return _say(context, l.callFailed);
  final s = service ?? CallService();
  try {
    final call = await s.start(id).timeout(kLoadTimeout);
    final ok = await (dial ?? _systemDial)(
      Uri(scheme: 'tel', path: call.number),
    );
    if (!ok) {
      if (context.mounted) _say(context, l.dialerUnavailable);
      return;
    }
    final session = call.sessionId;
    if (session != null && session.isNotEmpty) _EndOnResume(s, session);
  } on CallError catch (e) {
    final m = e.message?.trim() ?? '';
    if (context.mounted) {
      _say(
        context,
        (e.status == 409 || e.status == 503) && m.isNotEmpty ? m : l.callFailed,
      );
    }
  } catch (_) {
    if (context.mounted) _say(context, l.callFailed);
  }
}
