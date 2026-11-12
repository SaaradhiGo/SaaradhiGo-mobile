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
    String money(String? v) => v == null
        ? ''
        : (double.tryParse(v) == null
              ? v
              : exactMoney(double.parse(v), i.currency));
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
          Text(
            money(amount),
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
          for (final l in i.extras) row(l.label, l.amount),
          if (i.total != null) row('Total', i.total, bold: true),
        ],
      ),
    );
  }
}
