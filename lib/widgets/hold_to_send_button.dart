/// Press and hold to send (owner decision D4, 2026-11-02).
///
/// The SOS used to fire on a single tap, so an accidental tap sent a real
/// alert during the product audit. Now the rider holds for [holdFor]; a ring
/// fills while they hold, letting go early cancels, and completing the hold
/// fires [onConfirmed] at once with a heavy haptic. There is no cancel delay
/// after that: the way back is "Tap if this was a mistake" on the result.
///
/// Screen readers: TalkBack and VoiceOver users double-tap and hold, which
/// reaches the same long-press path; the hint says so.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/sg_tokens.dart';
import '../ui/sg_text.dart';

class HoldToSendButton extends StatefulWidget {
  const HoldToSendButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdFor = const Duration(seconds: 2),
    this.enabled = true,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration holdFor;
  final bool enabled;

  @override
  State<HoldToSendButton> createState() => _HoldToSendButtonState();
}

class _HoldToSendButtonState extends State<HoldToSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdFor,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    widget.onConfirmed();
    _hold.reset();
  }

  void _start() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  void _stop() {
    if (_hold.isAnimating) _hold.reverse();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final red = SgColors.danger;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      hint: 'Press and hold for ${widget.holdFor.inSeconds} seconds to send',
      excludeSemantics: true,
      // An explicit accessibility action, for a reader that offers one.
      onLongPress: widget.enabled ? widget.onConfirmed : null,
      // Raw pointer events, not gestures: a tap recogniser and a long-press
      // recogniser on the same widget cancel each other at the long-press
      // timeout, which would restart the ring half a second in.
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              color: widget.enabled
                  ? red.withValues(alpha: 0.18)
                  : SgColors.bg200,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.enabled ? red : SgColors.lineStrong,
              ),
            ),
            child: Stack(
              children: [
                // The fill shows how long is left to hold.
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _hold.value,
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: red,
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos, color: SgColors.ink),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _hold.value > 0 ? 'Keep holding' : widget.label,
                          style: TextStyle(
                            color: SgColors.ink,
                            fontSize: SgText.px(16),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
