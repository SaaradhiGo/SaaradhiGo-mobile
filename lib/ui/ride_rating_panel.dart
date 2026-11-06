/// "How was your ride with Ravi?" and the one gold Done (design: MobileTrip).
library;

import 'package:flutter/material.dart';

import '../services/rating_service.dart';
import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';
import 'trip_widgets.dart';

/// Stars and Done. Done saves the stars if any were chosen, then calls
/// [onDone] with whether the trip ended up rated. No tips: the API has none.
class RideRatingPanel extends StatefulWidget {
  const RideRatingPanel({
    super.key,
    required this.tripId,
    this.driverName,
    this.service,
    required this.onDone,
  });

  final String tripId;
  final String? driverName;
  final RatingService? service;
  final ValueChanged<bool> onDone;

  @override
  State<RideRatingPanel> createState() => _RideRatingPanelState();
}

class _RideRatingPanelState extends State<RideRatingPanel> {
  late final RatingService _service = widget.service ?? RatingService();
  int _score = 0;
  bool _busy = false;
  String? _error;

  Future<void> _done() async {
    if (_score == 0) return widget.onDone(false);
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await _service.rateTrip(
      tripId: widget.tripId,
      score: _score,
      comments: '',
    );
    if (!mounted) return;
    if (r.isSettled) return widget.onDone(true);
    setState(() {
      _busy = false;
      _error = r.message ?? 'Could not save your rating.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final who = firstNameOf(widget.driverName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          who.isEmpty ? 'How was your ride?' : 'How was your ride with $who?',
          textAlign: TextAlign.center,
          style: SgText.body.copyWith(color: SgColors.inkMuted),
        ),
        const SizedBox(height: SgSpace.s2),
        SgStars(
          score: _score,
          onChanged: _busy ? null : (v) => setState(() => _score = v),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: SgSpace.s2),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: SgText.caption.copyWith(color: SgColors.danger),
            ),
          ),
        const SizedBox(height: SgSpace.s4),
        SgPrimaryButton(label: 'Done', onPressed: _busy ? null : _done),
      ],
    );
  }
}
