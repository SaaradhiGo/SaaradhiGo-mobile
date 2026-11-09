/// The rider's safety controls: raise an SOS, call 112, share the trip.
///
/// Three things a rider might need during a ride, in the order they need them.
///
/// DESIGN NOTES THAT ARE NOT COSMETIC
/// ----------------------------------
/// 1. **112 is always reachable.** It is offered before the SOS completes, and
///    again if the SOS fails. The app is not a substitute for the emergency
///    services and must never behave as though it were.
/// 2. **An SOS failure is shown, not swallowed.** `SosService` returns a
///    message instead of throwing, and this sheet puts it on screen with the
///    dialler next to it. A spinner that silently gives up is the worst
///    possible behaviour in this file.
/// 3. **Sharing shares facts the server gave us** — driver name, vehicle
///    number, trip id, and the rider's current coordinates as a map link. It
///    does NOT invent a "live tracking" URL: no such public endpoint exists,
///    and a link that 404s during an emergency is worse than no link.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/market/market_config_store.dart';
import '../services/sos_service.dart';
import 'hold_to_send_button.dart';
import 'trip_actions.dart';
import '../core/rider_flags.dart';

import 'package:go_router/go_router.dart';

import '../ui/account_widgets.dart';
import '../ui/appearance_settings.dart' show sgStrings;
import '../ui/sg_text.dart';
import '../ui/sg_tokens.dart';
import '../ui/sg_widgets.dart';

/// India's single emergency number. One constant, named, because a literal
/// '112' three screens deep is how a market launch ships the wrong number.
const String kIndiaEmergencyNumber = '112';

/// What the sheet actually dials: the configured market's number (112 for
/// India, which is also the built-in default).
String get _emergencyNumber =>
    MarketConfigStore.instance.current.emergency.number;

/// Everything the sheet needs. Passed in rather than read from a provider so
/// the sheet is testable without the whole app graph.
@immutable
class TripSafetyContext {
  const TripSafetyContext({
    this.tripId,
    this.driverName,
    this.vehicleNumber,
    this.vehicleModel,
    this.lat,
    this.lng,
  });

  final String? tripId;
  final String? driverName;
  final String? vehicleNumber;
  final String? vehicleModel;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  /// The message a rider sends to someone they trust.
  ///
  /// Plain text on purpose: it has to survive SMS, WhatsApp and a paste into
  /// anything. Every field is omitted when unknown rather than printed as
  /// "null" or "unknown", which would read as carelessness at the worst moment.
  String shareMessage() {
    final parts = <String>['I am on a SaaradhiGo ride.'];

    if (driverName != null && driverName!.trim().isNotEmpty) {
      parts.add('Driver: ${driverName!.trim()}');
    }
    final vehicle = [vehicleModel, vehicleNumber]
        .where((v) => v != null && v.trim().isNotEmpty)
        .map((v) => v!.trim())
        .join(' ');
    if (vehicle.isNotEmpty) parts.add('Vehicle: $vehicle');
    if (tripId != null && tripId!.trim().isNotEmpty) {
      parts.add('Trip: #${tripId!.trim()}');
    }
    if (hasLocation) {
      parts.add(
        'My location: https://www.google.com/maps/search/?api=1&query='
        '${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}',
      );
    }
    return parts.join('\n');
  }
}

/// Offers the trip details to an SMS composer, else copies them.
Future<void> shareTripDetails(
  BuildContext context,
  TripSafetyContext trip,
) async {
  final message = trip.shareMessage();
  final sms = Uri(scheme: 'sms', queryParameters: {'body': message});
  final launched = await launchUrl(sms, mode: LaunchMode.externalApplication);
  if (!launched) {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sgStrings(context).tripDetailsCopied)),
    );
  }
}

Future<void> showSafetySheet(
  BuildContext context, {
  required TripSafetyContext trip,
  SosService? service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SgColors.bg200,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafetySheet(trip: trip, service: service),
  );
}

class SafetySheet extends StatefulWidget {
  const SafetySheet({super.key, required this.trip, this.service});

  final TripSafetyContext trip;

  /// Injectable for tests. Nothing in the app passes it.
  final SosService? service;

  @override
  State<SafetySheet> createState() => _SafetySheetState();
}

class _SafetySheetState extends State<SafetySheet> {
  late final SosService _sos = widget.service ?? SosService();
  bool _sending = false;
  SosResult? _result;

  /// What the hold will send. A tap on a chip only chooses; it never sends.
  SosCategory _category = SosCategory.panic;

  /// null: not asked. true: the server recorded the mistake. false: it did not.
  bool? _mistake;
  bool _reportingMistake = false;

  @override
  void dispose() {
    if (widget.service == null) _sos.dispose();
    super.dispose();
  }

  Future<void> _raise(SosCategory category) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _result = null;
      _mistake = null;
    });

    final result = await _sos.raise(
      category: category,
      tripId: widget.trip.tripId,
      lat: widget.trip.lat,
      lng: widget.trip.lng,
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = result;
    });
  }

  Future<void> _reportMistake() async {
    final id = _result?.sosId;
    if (id == null || _reportingMistake) return;
    setState(() => _reportingMistake = true);
    final ok = await _sos.reportMistake(id);
    if (!mounted) return;
    setState(() {
      _reportingMistake = false;
      _mistake = ok;
    });
  }

  Future<void> _callSupport(String number) async {
    await launchUrl(
      Uri.parse('tel:$number'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _call112() async {
    final uri = Uri.parse('tel:$_emergencyNumber');
    // No `canLaunchUrl` gate: on a device without a dialler there is nothing
    // better to do than try, and a false negative here costs a rider the call.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _reportSomething() {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).maybePop();
    router?.push('/help-support');
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final l = sgStrings(context);

    return SafeArea(
      // Scrolls: with the categories, the hold button and the rows it is
      // taller than a small phone's half-height sheet.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SgSpace.s4,
          SgSpace.s3,
          SgSpace.s4,
          SgSpace.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SgColors.lineStrong,
                  borderRadius: BorderRadius.circular(SgRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: SgSpace.s4),
            Text(l.safety, style: SgText.heading),
            const SizedBox(height: SgSpace.s4),

            // The emergency block: the existing hold-to-send SOS, and the
            // emergency number from app-config.
            Container(
              key: const Key('safety_emergency_block'),
              padding: const EdgeInsets.all(SgSpace.s4),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  SgColors.danger.withValues(alpha: 0.14),
                  SgColors.bg100,
                ),
                borderRadius: BorderRadius.circular(SgRadius.lg),
                border: Border.all(color: SgColors.danger),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.inDanger,
                    style: SgText.heading.copyWith(color: SgColors.danger),
                  ),
                  const SizedBox(height: SgSpace.s1),
                  Text(l.holdForSos, style: SgText.body),
                  const SizedBox(height: SgSpace.s3),
                  if (result != null)
                    _ResultBanner(
                      result: result,
                      onCall: _call112,
                      mistake: _mistake,
                      reportingMistake: _reportingMistake,
                      onMistake: result.ok && result.sosId != null
                          ? _reportMistake
                          : null,
                    ),
                  if (_sending)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: SgColors.gold500,
                        ),
                      ),
                    )
                  else if (result?.ok != true) ...[
                    Wrap(
                      spacing: SgSpace.s2,
                      runSpacing: SgSpace.s2,
                      children: [
                        for (final category in SosCategory.values)
                          ChoiceChip(
                            key: Key('sos_${category.wireValue}'),
                            label: Text(category.label),
                            selected: _category == category,
                            selectedColor: SgColors.danger.withValues(
                              alpha: 0.24,
                            ),
                            backgroundColor: SgColors.bg100,
                            labelStyle: TextStyle(color: SgColors.ink),
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                      ],
                    ),
                    const SizedBox(height: SgSpace.s3),
                    HoldToSendButton(
                      key: const Key('sos_hold'),
                      label: sgStrings(context).holdToSendAlert,
                      onConfirmed: () => _raise(_category),
                    ),
                  ],
                  const SizedBox(height: SgSpace.s3),
                  OutlinedButton.icon(
                    key: const Key('safety_call_112'),
                    onPressed: _call112,
                    icon: Icon(Icons.call, color: SgColors.danger),
                    label: Text(
                      l.callEmergency(_emergencyNumber),
                      style: SgText.body.copyWith(
                        color: SgColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: SgColors.danger, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SgRadius.md),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SgSpace.s4),
            // Route-deviation alerts and night check-ins are not available;
            // their rows are left out.
            SgListGroup([
              if (RiderFlags.shareTrip &&
                  (widget.trip.tripId ?? '').trim().isNotEmpty)
                SgListRow(
                  key: const Key('safety_share_trip'),
                  icon: SgIcons.share,
                  label: l.shareTrip,
                  chevron: true,
                  onTap: () => shareTripLink(context, widget.trip.tripId),
                ),
              SgListRow(
                key: const Key('safety_report'),
                icon: SgIcons.help,
                label: l.reportSomething,
                chevron: true,
                onTap: _reportSomething,
              ),
              if (MarketConfigStore.instance.current.supportPhone
                  case final support?)
                SgListRow(
                  key: const Key('safety_call_support'),
                  icon: SgIcons.call,
                  label: l.callSupport,
                  chevron: true,
                  onTap: () => _callSupport(support),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.result,
    required this.onCall,
    this.mistake,
    this.reportingMistake = false,
    this.onMistake,
  });

  final SosResult result;
  final VoidCallback onCall;
  final bool? mistake;
  final bool reportingMistake;
  final VoidCallback? onMistake;

  @override
  Widget build(BuildContext context) {
    if (result.ok) {
      final reference = result.sosId != null
          ? ' Reference #${result.sosId}.'
          : '';
      return Container(
        key: const Key('sos_success'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SgColors.success.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: SgColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      mistake == true
                          ? 'Marked as a mistake. Our safety team has been told.$reference'
                          : 'Alert sent. Our safety team has been alerted.$reference '
                                'Keep your phone with you.',
                      style: TextStyle(
                        color: SgColors.ink,
                        fontSize: SgText.sizeSmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (onMistake != null && mistake != true) ...[
              const SizedBox(height: 6),
              TextButton(
                key: const Key('sos_mistake'),
                onPressed: reportingMistake ? null : onMistake,
                style: TextButton.styleFrom(
                  foregroundColor: SgColors.ink,
                  minimumSize: const Size(48, 48),
                ),
                child: Text(
                  mistake == false
                      ? 'That did not go through. Tap to try again'
                      : 'Tap if this was a mistake',
                  style: const TextStyle(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      key: const Key('sos_failure'),
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SgColors.danger.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.message ??
                'We could not alert our team. Please call $_emergencyNumber.',
            style: TextStyle(color: SgColors.ink, fontSize: SgText.sizeSmall),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('sos_failure_call_112'),
            onPressed: onCall,
            icon: Icon(Icons.call, color: SgColors.ink),
            label: Text(
              'Call $_emergencyNumber now',
              style: TextStyle(color: SgColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
