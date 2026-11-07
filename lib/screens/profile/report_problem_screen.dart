/// Raise a support ticket. The thing Help & Support implied and did not do.
///
/// `help_support_screen.dart` renders tiles labelled "Ride Issues", "Payment
/// & Wallet", "Safety", "Live Chat" and "Email Support", none of which had a
/// handler. `/support/tickets/create/` has been live and tested the whole
/// time, and the driver app has used it since its support work.
///
/// Deliberately plain: a form, a submit button, and states that tell the
/// truth. Four states, because a rider raising a complaint needs to know
/// which one they are in -- idle, submitting, submitted, failed -- and the
/// failure has to name the reason and leave what they typed intact.
library;

import '../../ui/appearance_settings.dart' show sgStrings;
import 'package:flutter/material.dart';

import '../../services/models/support_ticket.dart';
import '../../services/support_service.dart';

import '../../ui/sg_tokens.dart';
import '../../ui/sg_text.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({
    super.key,
    this.initialIssueType,
    this.tripId,
    SupportService? supportService,
  }) : service = supportService;

  /// Preselected when the rider arrived from a specific category or trip.
  final SupportIssueType? initialIssueType;

  /// Attaches the ticket to a trip, so support does not have to ask which one.
  final String? tripId;

  /// Injectable for tests.
  final SupportService? service;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  late SupportIssueType _issueType =
      widget.initialIssueType ?? SupportIssueType.other;

  bool _submitting = false;
  String? _error;
  SupportTicket? _created;
  bool _createdWithoutDetail = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await _service.createTicket(
      issueType: _issueType,
      description: _descriptionController.text,
      tripId: widget.tripId,
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result.isCreated) {
        _created = result.ticket;
        _createdWithoutDetail = result.ticket == null;
      } else {
        // The rider's text is deliberately left in the field: making someone
        // retype a complaint is how a complaint stops being made.
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgColors.bg000,
      appBar: AppBar(
        backgroundColor: SgColors.bg000,
        foregroundColor: SgColors.ink,
        title: Text(sgStrings(context).reportProblem),
      ),
      body: SafeArea(
        child: _created != null || _createdWithoutDetail
            ? _buildSubmitted()
            : _buildForm(),
      ),
    );
  }

  Widget _buildSubmitted() {
    final ticket = _created;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: SgColors.goldText,
            ),
            const SizedBox(height: 16),
            Text(
              'Thanks — we have it',
              style: TextStyle(
                color: SgColors.ink,
                fontSize: SgText.sizeTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ticket != null
                  // A reference is what makes this different from a
                  // reassurance: the rider can quote it.
                  ? 'Your reference is #${ticket.id}. Support will reply in '
                        'the app.'
                  : 'Support will reply in the app.',
              style: TextStyle(color: SgColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: SgColors.gold500,
                foregroundColor: SgColors.onGold,
              ),
              child: Text(sgStrings(context).done),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What went wrong?',
              style: TextStyle(
                color: SgColors.ink,
                fontSize: SgText.sizeTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SupportIssueType>(
              initialValue: _issueType,
              dropdownColor: SgColors.bg200,
              style: TextStyle(color: SgColors.ink),
              decoration: InputDecoration(
                labelText: sgStrings(context).problemType,
                labelStyle: TextStyle(color: SgColors.inkMuted),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in SupportIssueType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _issueType = value ?? _issueType),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              enabled: !_submitting,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              style: TextStyle(color: SgColors.ink),
              decoration: InputDecoration(
                labelText: sgStrings(context).describeProblem,
                labelStyle: TextStyle(color: SgColors.inkMuted),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                helperText: 'Include what happened and when, if you can.',
                helperStyle: TextStyle(color: SgColors.inkSubtle),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Please describe the problem.';
                if (text.length < 10) {
                  // The server accepts anything non-empty; a one-word ticket
                  // just means support has to ask, which costs the rider
                  // another day.
                  return 'A sentence or two helps support act on it.';
                }
                return null;
              },
            ),
            if (widget.tripId != null) ...[
              const SizedBox(height: 8),
              Text(
                'This will be attached to trip #${widget.tripId}.',
                style: TextStyle(
                  color: SgColors.inkMuted,
                  fontSize: SgText.sizeSmall,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SgColors.danger.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SgColors.danger),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: SgColors.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: SgColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: SgColors.gold500,
                foregroundColor: SgColors.onGold,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SgColors.bg000,
                      ),
                    )
                  : Text(sgStrings(context).submit),
            ),
          ],
        ),
      ),
    );
  }
}
