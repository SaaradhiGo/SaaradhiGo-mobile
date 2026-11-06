import '../../ui/appearance_settings.dart' show sgStrings;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/referral/referral_models.dart';
import '../../services/referral_service.dart';
import '../../services/token_store.dart';

import '../../ui/sg_tokens.dart';

/// The text a rider shares. The API supplies the code and the offer (never a
/// ready-made message), so this is a neutral line built from them.
String referralShareText(ReferralMine mine) {
  final offer = mine.offer;
  final reward =
      offer?.refereeRewardMinor != null && offer!.refereeRewardMinor > 0
      ? offer.refereeReward
      : null;
  final base =
      'Join me on SaaradhiGo. Use my referral code ${mine.code} when you sign up.';
  return reward == null
      ? base
      : '$base You get $reward after your first rides.';
}

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({
    super.key,
    this.service,
    this.tokenReader,
    this.shareOverride,
    this.audience = 'rider',
  });

  final ReferralService? service;
  final Future<String?> Function()? tokenReader;
  final Future<void> Function(String text)? shareOverride;

  /// `rider` here; the wording below is the rider's.
  final String audience;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  ReferralMine? _mine;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final token = await (widget.tokenReader ?? TokenStore.readAccessToken)();
    ReferralMine? mine;
    if (token != null && token.isNotEmpty) {
      mine = await (widget.service ?? ReferralService()).fetchMine(token);
    }
    if (!mounted) return;
    setState(() {
      _mine = mine;
      _failed = mine == null;
      _loading = false;
    });
  }

  Future<void> _share(ReferralMine mine) async {
    final text = referralShareText(mine);
    try {
      if (widget.shareOverride != null) {
        await widget.shareOverride!(text);
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sgStrings(context).copiedPasteChat)),
      );
    }
  }

  Future<void> _copy(ReferralMine mine) async {
    await Clipboard.setData(ClipboardData(text: mine.code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(sgStrings(context).referralCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Refer & Earn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "We couldn't load your referral details.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('referral_retry'),
                      onPressed: _load,
                      child: Text(sgStrings(context).tryAgain),
                    ),
                  ],
                ),
              ),
            )
          : _content(context, _mine!),
    );
  }

  Widget _content(BuildContext context, ReferralMine mine) {
    final scheme = Theme.of(context).colorScheme;
    final offer = mine.offer;
    final earned = mine.earnedMinorByCurrency;
    final pending = mine.pendingMinorByCurrency;
    final earnedText = earned.entries
        .where((e) => e.value > 0)
        .map((e) => formatMinor(e.value, e.key))
        .whereType<String>()
        .join(' + ');
    final pendingText = pending.entries
        .map((e) => formatMinor(e.value, e.key))
        .whereType<String>()
        .join(' + ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Text(
                'Your referral code',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                mine.code,
                key: const Key('referral_code'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('referral_copy'),
                      onPressed: () => _copy(mine),
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(sgStrings(context).copy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('referral_share'),
                      onPressed: () => _share(mine),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                      icon: const Icon(Icons.share, size: 18),
                      label: Text(sgStrings(context).share),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (offer != null)
          Text(
            _offerLine(offer),
            key: const Key('referral_offer'),
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.4,
            ),
          )
        else
          Text(
            'There is no referral offer running right now. Your code stays the same and will work when one starts.',
            key: const Key('referral_no_offer'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
        if (mine.attachedTo != null) ...[
          const SizedBox(height: 12),
          Text(
            _attachedLine(mine.attachedTo!),
            key: const Key('referral_attached'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Your invites',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _stat(context, 'Invited', '${mine.invites}'),
            const SizedBox(width: 10),
            _stat(context, 'Completed rides', '${mine.qualifiedCount}'),
            const SizedBox(width: 10),
            _stat(
              context,
              'Pending review',
              '${mine.pendingReviewCount}',
              key: const Key('referral_pending_count'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (earnedText.isNotEmpty)
          Text(
            'Rewards earned: $earnedText',
            key: const Key('referral_earned'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          )
        else
          Text(
            'No rewards earned yet',
            key: const Key('referral_earned'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
        if (pendingText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Pending review: $pendingText',
            key: const Key('referral_pending_amount'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
        const SizedBox(height: 16),
        if (mine.referrals.isEmpty)
          Text(
            'Nobody has used your code yet. Share it to get started.',
            key: const Key('referral_empty'),
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
          )
        else
          ...mine.referrals.map((r) => _row(context, r)),
      ],
    );
  }

  String _offerLine(ReferralOffer offer) {
    final trips = offer.requiredTrips;
    final ridesPart = trips > 0
        ? 'completes $trips ${trips == 1 ? 'ride' : 'rides'}'
        : 'takes their first rides';
    final mineR = offer.referrerRewardMinor > 0 ? offer.referrerReward : null;
    final theirs = offer.refereeRewardMinor > 0 ? offer.refereeReward : null;
    if (mineR != null && theirs != null) {
      return 'When a friend you invite $ridesPart, you get $mineR and they get $theirs.';
    }
    if (mineR != null) {
      return 'When a friend you invite $ridesPart, you get $mineR.';
    }
    if (theirs != null) {
      return 'When a friend you invite $ridesPart, they get $theirs.';
    }
    return 'Invite friends to SaaradhiGo with your code.';
  }

  String _attachedLine(ReferralAttachedTo a) {
    if (a.status == 'under review') {
      return 'You joined with a referral code. Your reward is pending review.';
    }
    if (a.requiredTrips > 0) {
      return 'You joined with a referral code: ${a.tripsCompleted} of ${a.requiredTrips} rides done.';
    }
    return 'You joined with a referral code.';
  }

  Widget _stat(BuildContext context, String label, String value, {Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              key: key,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ReferralRow r) {
    final scheme = Theme.of(context).colorScheme;
    final String label;
    if (r.pendingReview) {
      label = 'Pending review';
    } else if (r.status == 'rewarded') {
      label = r.rewardMinor > 0
          ? 'Reward earned: ${formatMinor(r.rewardMinor, r.currency)}'
          : 'Completed';
    } else if (r.status == 'qualified') {
      label = 'Reward on its way';
    } else {
      label = r.requiredTrips > 0
          ? '${r.tripsCompleted} of ${r.requiredTrips} rides'
          : 'Joined';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                r.who,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: r.pendingReview
                    ? SgColors.goldText
                    : scheme.onSurface.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
