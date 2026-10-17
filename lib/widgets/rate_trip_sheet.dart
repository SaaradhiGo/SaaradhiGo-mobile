/// Rate the trip that just ended.
///
/// Deliberately skippable. A rating prompt that blocks a rider from closing
/// their app is a prompt they learn to dismiss without reading, and the
/// average it produces is worse than no average. Stars, an optional comment,
/// Submit, and Not now.
///
/// `alreadyRated` is treated as success, not as an error: the rating exists,
/// which is what the rider wanted, and nagging them about a 409 teaches them
/// the prompt is broken.
library;

import 'package:flutter/material.dart';

import '../services/rating_service.dart';

/// Shows the sheet and returns true when the trip ends up rated (including
/// when it was already rated), so the caller can stop prompting for it.
Future<bool> showRateTripSheet(
  BuildContext context, {
  required String tripId,
  String? driverName,
  RatingService? service,
}) async {
  final rated = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        RateTripSheet(tripId: tripId, driverName: driverName, service: service),
  );
  return rated ?? false;
}

class RateTripSheet extends StatefulWidget {
  const RateTripSheet({
    super.key,
    required this.tripId,
    this.driverName,
    this.service,
  });

  final String tripId;
  final String? driverName;
  final RatingService? service;

  @override
  State<RateTripSheet> createState() => _RateTripSheetState();
}

class _RateTripSheetState extends State<RateTripSheet> {
  late final RatingService _service = widget.service ?? RatingService();
  final _commentController = TextEditingController();

  int _score = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score == 0) {
      setState(() => _error = 'Tap a star to rate the trip.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await _service.rateTrip(
      tripId: widget.tripId,
      score: _score,
      comments: _commentController.text,
    );

    if (!mounted) return;

    if (result.isSettled) {
      // Submitted, or already rated. Both mean stop asking.
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _submitting = false;
      _error = result.message ?? 'Could not save your rating.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.driverName?.trim();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              who != null && who.isNotEmpty
                  ? 'How was your trip with $who?'
                  : 'How was your trip?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    // A real semantic label: a screen reader user has to be
                    // able to pick a rating, and five identical "star"
                    // buttons are unusable.
                    tooltip: '$star star${star == 1 ? '' : 's'}',
                    iconSize: 40,
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _score = star;
                            _error = null;
                          }),
                    icon: Icon(
                      star <= _score ? Icons.star : Icons.star_border,
                      color: const Color(0xFFEEBD2B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              enabled: !_submitting,
              maxLines: 3,
              maxLength: 500,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Anything you want us to know? (optional)',
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(),
                counterStyle: TextStyle(color: Colors.white38),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF8A80)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEBD2B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Submit rating'),
            ),
            TextButton(
              // Skippable on purpose. A prompt a rider cannot dismiss is one
              // they learn to tap through without reading.
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text(
                'Not now',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
