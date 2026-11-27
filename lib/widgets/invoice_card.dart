import 'package:flutter/material.dart';

import '../services/models/trip_invoice.dart';
import '../ui/sg_text.dart';
import '../ui/sg_tokens.dart';
import '../ui/trip_widgets.dart' show exactMoney;

/// The receipt (or tax invoice) for a finished trip, issued by the market's
/// legal entity. Tax lines only when the server says tax is shown.
class InvoiceCard extends StatelessWidget {
  const InvoiceCard({super.key, required this.invoice});

  final TripInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    // A negative line ("Rounding") reads "−₹0.10", never "₹-0.10".
    String money(String? v) {
      final n = v == null ? null : double.tryParse(v);
      if (n == null) return v ?? '';
      return n < 0
          ? '−⁠${exactMoney(-n, i.currency)}'
          : exactMoney(n, i.currency);
    }

    Widget row(String label, String? amount, {bool bold = false}) => Padding(
      padding: const EdgeInsets.only(bottom: SgSpace.s1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: SgText.body.copyWith(
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          // An amount never wraps ("−$29.58" on one line).
          Text(
            money(amount),
            softWrap: false,
            style: SgText.body.copyWith(
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('invoice_card'),
      padding: const EdgeInsets.all(SgSpace.s4),
      decoration: BoxDecoration(
        color: SgColors.bg100,
        borderRadius: BorderRadius.circular(SgRadius.md),
        border: Border.all(color: SgColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i.title, key: const Key('invoice_title'), style: SgText.title),
          if (i.number.isNotEmpty) Text(i.number, style: SgText.caption),
          const SizedBox(height: SgSpace.s2),
          if (i.companyName.isNotEmpty)
            Text(
              i.companyName,
              key: const Key('invoice_company'),
              style: SgText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          for (final line in [
            i.companyAddress,
            if (i.gstin.isNotEmpty) 'GSTIN ${i.gstin}',
            if (i.cin.isNotEmpty) 'CIN ${i.cin}',
            i.supportPhone,
            i.supportEmail,
          ])
            if (line.isNotEmpty) Text(line, style: SgText.caption),
          const SizedBox(height: SgSpace.s3),
          for (final l in i.lines) row(l.label, l.amount),
          if (i.taxShown) ...[
            if (i.taxable != null) row('Taxable value', i.taxable),
            if (i.taxAmount != null)
              row(
                i.taxIncluded ? '${i.taxLabel} (included)' : i.taxLabel,
                i.taxAmount,
              ),
          ],
          for (final l in i.extras.where((x) => !x.onBehalf))
            row(l.label, l.amount),
          // 27 Nov (trip charges): tolls and airport fees, and whom each is for.
          if (i.extras.any((x) => x.onBehalf)) ...[
            KeyedSubtree(
              key: const Key('invoice_on_behalf'),
              child: row(
                i.onBehalfTitle,
                i.extras
                    .where((x) => x.onBehalf)
                    .fold<double>(
                      0,
                      (t, x) => t + (double.tryParse(x.amount) ?? 0),
                    )
                    .toStringAsFixed(2),
                bold: true,
              ),
            ),
            for (final l in i.extras.where((x) => x.onBehalf)) ...[
              row(l.label, l.amount),
              if (l.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: SgSpace.s1),
                  child: Text(l.note, style: SgText.caption),
                ),
            ],
          ],
          if (i.total != null) row('Ride total', i.total, bold: true),
          if ((double.tryParse(i.tip ?? '') ?? 0) > 0) row('Tip', i.tip),
          if (i.totalCharged != null && i.totalCharged != i.total)
            row('Total charged', i.totalCharged, bold: true),
          for (final r in i.refunds)
            Padding(
              key: const Key('invoice_refund'),
              padding: const EdgeInsets.only(bottom: SgSpace.s1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.date.isEmpty ? r.label : '${r.label} · ${r.date}',
                      style: SgText.body,
                    ),
                  ),
                  Text(
                    '\u2212\u2060${money(r.amount)}',
                    softWrap: false,
                    style: SgText.body,
                  ),
                ],
              ),
            ),
          if (i.netCharged != null && i.refunds.isNotEmpty)
            KeyedSubtree(
              key: const Key('invoice_net_charged'),
              child: row('Net charged', i.netCharged, bold: true),
            ),
        ],
      ),
    );
  }
}
