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

import '../services/sos_service.dart';

/// India's single emergency number. One constant, named, because a literal
/// '112' three screens deep is how a market launch ships the wrong number.
const String kIndiaEmergencyNumber = '112';

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

Future<void> showSafetySheet(
  BuildContext context, {
  required TripSafetyContext trip,
  SosService? service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1917),
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

  Future<void> _call112() async {
    final uri = Uri.parse('tel:$kIndiaEmergencyNumber');
    // No `canLaunchUrl` gate: on a device without a dialler there is nothing
    // better to do than try, and a false negative here costs a rider the call.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareTrip() async {
    final message = widget.trip.shareMessage();

    // SMS composer, not a share sheet. `url_launcher` is already a dependency;
    // adding a share plugin would add an Android build surface that cannot be
    // verified on this machine. The rider picks the recipient either way.
    final sms = Uri(scheme: 'sms', queryParameters: {'body': message});
    final launched =
        await launchUrl(sms, mode: LaunchMode.externalApplication);

    if (!launched) {
      // Clipboard is the honest fallback: the details are still in the rider's
      // hands and they can paste them anywhere.
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip details copied — paste to share')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Safety',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Our team is alerted immediately. For police, fire or '
              'ambulance, call 112.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 18),

            // 112 first, deliberately.
            ElevatedButton.icon(
              key: const Key('safety_call_112'),
              onPressed: _call112,
              icon: const Icon(Icons.call),
              label: const Text('Call 112'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('safety_share_trip'),
              onPressed: _shareTrip,
              icon: const Icon(Icons.ios_share),
              label: const Text('Share my trip'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 18),
            const Divider(color: Colors.white12),
            const SizedBox(height: 6),
            const Text(
              'Tell SaaradhiGo what is wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            if (result != null) _ResultBanner(result: result, onCall: _call112),

            if (_sending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (result?.ok != true)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in SosCategory.values)
                    ActionChip(
                      key: Key('sos_${category.wireValue}'),
                      label: Text(category.label),
                      backgroundColor: const Color(0xFF262522),
                      labelStyle: const TextStyle(color: Colors.white),
                      onPressed: () => _raise(category),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, required this.onCall});

  final SosResult result;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    if (result.ok) {
      return Container(
        key: const Key('sos_success'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF064E3B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user, color: Color(0xFF6EE7B7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.sosId != null
                    ? 'Our safety team has been alerted. Reference '
                        '#${result.sosId}. Keep your phone with you.'
                    : 'Our safety team has been alerted. Keep your phone '
                        'with you.',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('sos_failure'),
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.message ?? 'We could not alert our team. Please call 112.',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('sos_failure_call_112'),
            onPressed: onCall,
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text('Call 112 now',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
