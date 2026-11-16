import 'package:flutter/material.dart';

import '../services/tip_service.dart';
import '../ui/sg_text.dart';
import '../ui/sg_tokens.dart';
import '../ui/sg_widgets.dart';

/// A trip paid by the card held at booking (USA): nothing to choose. The card
/// is charged automatically; the rider may add a tip, 100% to the driver.
class CardPaidPanel extends StatefulWidget {
  const CardPaidPanel({
    super.key,
    required this.tripId,
    required this.amountText,
    required this.driverFirst,
    required this.tipPresets,
    required this.onDone,
    this.onTipped,
    this.tipService,
  });

  final String? tripId;
  final String amountText;
  final String driverFirst;

  /// Percent presets from the market (empty: tips are off here).
  final List<int> tipPresets;
  final VoidCallback onDone;
  final VoidCallback? onTipped;
  final TipService? tipService;

  @override
  State<CardPaidPanel> createState() => _CardPaidPanelState();
}

class _CardPaidPanelState extends State<CardPaidPanel> {
  int? _sentPercent;
  bool _busy = false;
  String? _error;

  Future<void> _tip(int percent) async {
    final id = widget.tripId;
    if (id == null || _busy || _sentPercent != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem = await (widget.tipService ?? TipService()).tip(id, percent);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (problem == null) {
        _sentPercent = percent;
      } else {
        _error = problem;
      }
    });
    if (problem == null) widget.onTipped?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('card_paid_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Charged to your card: ${widget.amountText}',
          key: const Key('card_paid_line'),
          style: SgText.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: SgSpace.s1),
        Text(
          'Nothing else to pay. Your receipt is below and in your email.',
          style: SgText.body.copyWith(color: SgColors.inkMuted),
        ),
        if (widget.tipPresets.isNotEmpty) ...[
          const SizedBox(height: SgSpace.s4),
          Text(
            _sentPercent == null
                ? 'Add a tip for ${widget.driverFirst}? 100% goes to your driver.'
                : 'Thanks! Your $_sentPercent% tip goes to ${widget.driverFirst}.',
            key: const Key('tip_prompt'),
            style: SgText.body,
          ),
          const SizedBox(height: SgSpace.s2),
          Wrap(
            spacing: SgSpace.s2,
            runSpacing: SgSpace.s2,
            children: [
              for (final pct in widget.tipPresets)
                ChoiceChip(
                  key: Key('tip_$pct'),
                  label: Text('$pct%'),
                  selected: _sentPercent == pct,
                  onSelected: (_busy || _sentPercent != null)
                      ? null
                      : (_) => _tip(pct),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: SgSpace.s2),
              child: Text(
                _error!,
                style: SgText.body.copyWith(color: SgColors.danger),
              ),
            ),
        ],
        const SizedBox(height: SgSpace.s5),
        SgPrimaryButton(
          key: const Key('card_paid_done'),
          label: 'Done',
          onPressed: _busy ? null : widget.onDone,
        ),
      ],
    );
  }
}
