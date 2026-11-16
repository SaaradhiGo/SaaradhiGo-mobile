/// The `invoice` block of the trip detail (`GET /ride/trip/<id>/`), read
/// defensively: the title, issuer and tax fields arrive with the legal-entity
/// change and are absent on older servers.
library;

class InvoiceLine {
  const InvoiceLine(this.label, this.amount);
  final String label;
  final String amount;
}

class InvoiceRefund {
  const InvoiceRefund(this.label, this.amount, this.date);
  final String label;
  final String amount;
  final String date;
}

class TripInvoice {
  const TripInvoice({
    required this.title,
    required this.companyName,
    this.companyAddress = '',
    this.gstin = '',
    this.cin = '',
    this.supportEmail = '',
    this.supportPhone = '',
    this.number = '',
    this.taxShown = false,
    this.lines = const [],
    this.taxable,
    this.taxLabel = '',
    this.taxAmount,
    this.taxIncluded = true,
    this.extras = const [],
    this.total,
    this.tip,
    this.totalCharged,
    this.currency,
    this.refunds = const [],
    this.netCharged,
  });

  /// "Receipt" while GST is off, "Tax invoice" when on.
  final String title;
  final String companyName;
  final String companyAddress;
  final String gstin;
  final String cin;
  final String supportEmail;
  final String supportPhone;
  final String number;

  /// False: show no taxable-value or GST lines.
  final bool taxShown;
  final List<InvoiceLine> lines;
  final String? taxable;
  final String taxLabel;
  final String? taxAmount;
  final bool taxIncluded;
  final List<InvoiceLine> extras;

  /// The ride total: fare plus booking fee, without tip.
  final String? total;

  /// US trips only: the tip, and what the card was charged in all (ride total
  /// plus tip). Absent on India trips, where total charged is the total.
  final String? tip;
  final String? totalCharged;
  final String? currency;

  /// Refunds that went through, then what the card paid net of them.
  final List<InvoiceRefund> refunds;
  final String? netCharged;

  /// Null when the trip has no usable invoice.
  static TripInvoice? fromTrip(Object? trip) {
    final inv = trip is Map ? trip['invoice'] : null;
    if (inv is! Map) return null;
    String s(Object? m, String k) =>
        (m is Map ? (m[k] ?? '') : '').toString().trim();
    final company = inv['company'];
    final breakdown = inv['breakdown'];
    List<InvoiceLine> list(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map && s(e, 'label').isNotEmpty)
            InvoiceLine(s(e, 'label'), s(e, 'amount')),
    ];
    final tax = breakdown is Map ? breakdown['tax'] : null;
    final title = s(inv, 'title').isNotEmpty
        ? s(inv, 'title')
        : s(breakdown, 'title');
    return TripInvoice(
      // Older servers send no title: a receipt, never a claim of GST.
      title: title.isEmpty ? 'Receipt' : title,
      companyName: s(company, 'name'),
      companyAddress: s(company, 'address'),
      gstin: s(company, 'gstin'),
      cin: s(company, 'cin'),
      supportEmail: s(company, 'support_email'),
      supportPhone: s(company, 'support_phone'),
      number: s(inv, 'number'),
      // Absent means not shown: never print tax the server did not vouch for.
      taxShown: breakdown is Map && breakdown['tax_shown'] == true,
      lines: list(breakdown is Map ? breakdown['lines'] : null),
      taxable: breakdown is Map ? breakdown['taxable']?.toString() : null,
      taxLabel: tax is Map
          ? '${s(tax, 'label')} ${s(tax, 'percent')}%'.trim()
          : '',
      taxAmount: tax is Map ? tax['amount']?.toString() : null,
      taxIncluded: tax is Map ? tax['included'] != false : true,
      extras: list(breakdown is Map ? breakdown['extras'] : null),
      total:
          (breakdown is Map ? breakdown['total'] : null)?.toString() ??
          inv['total']?.toString(),
      // The server puts the US lines inside the breakdown; older ones at the top.
      tip:
          (breakdown is Map ? breakdown['tip'] : null)?.toString() ??
          inv['tip']?.toString(),
      totalCharged:
          (breakdown is Map ? breakdown['total_charged'] : null)?.toString() ??
          inv['total_charged']?.toString(),
      currency:
          inv['currency']?.toString() ??
          (breakdown is Map ? breakdown['currency'] : null)?.toString(),
      refunds: [
        if (breakdown is Map && breakdown['refunds'] is List)
          for (final r in breakdown['refunds'] as List)
            if (r is Map && s(r, 'amount').isNotEmpty)
              InvoiceRefund(s(r, 'label'), s(r, 'amount'), s(r, 'date')),
      ],
      netCharged: (breakdown is Map ? breakdown['net_charged'] : null)
          ?.toString(),
    );
  }
}
