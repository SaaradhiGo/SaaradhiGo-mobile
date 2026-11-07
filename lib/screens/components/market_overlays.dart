import '../../ui/appearance_settings.dart' show sgStrings;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/market/app_http_client.dart';
import '../../core/market/booking_refusal.dart';
import '../../core/market/market_config.dart';
import '../../core/market/market_config_store.dart';

import '../../ui/sg_tokens.dart';
import '../../ui/sg_text.dart';

Color get _gold => SgColors.goldText;
Color get _goldFill => SgColors.gold500;
Color get _ink => SgColors.onGold;

/// Blocking screen for 426 APP_UPDATE_REQUIRED. Shown instead of the app;
/// the only way forward is the store link from the response body.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.info, this.onOpenStore});

  final UpdateRequired info;
  final Future<void> Function(String url)? onOpenStore;

  @override
  Widget build(BuildContext context) {
    final url = info.storeUrl;
    return Material(
      color: SgColors.bg200,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update, color: _gold, size: 56),
                const SizedBox(height: 24),
                Text(
                  'Update required',
                  key: Key('update_required_title'),
                  style: TextStyle(
                    color: SgColors.ink,
                    fontSize: SgText.sizeHeading,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  info.message ?? 'Please update the app to continue.',
                  key: const Key('update_required_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SgColors.inkMuted,
                    fontSize: SgText.sizeBody,
                  ),
                ),
                if (url != null) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('update_required_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _goldFill,
                        foregroundColor: _ink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        if (onOpenStore != null) {
                          await onOpenStore!(url);
                        } else {
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Text(sgStrings(context).update),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Active maintenance / info notices from app-config. Dismissible unless the
/// notice says it blocks. No notices => renders nothing.
class NoticeBanner extends StatefulWidget {
  const NoticeBanner({super.key, required this.notices});

  final List<AppNotice> notices;

  @override
  State<NoticeBanner> createState() => _NoticeBannerState();

  @visibleForTesting
  static void resetDismissed() => _NoticeBannerState._dismissed.clear();
}

class _NoticeBannerState extends State<NoticeBanner> {
  // Dismissed for this app session; a notice comes back on the next launch.
  static final Set<int> _dismissed = <int>{};

  @override
  Widget build(BuildContext context) {
    final visible = widget.notices
        .where((n) => n.blocking || !_dismissed.contains(n.id))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final n in visible)
          Material(
            key: Key('notice_${n.id}'),
            color: n.severity == 'warning' ? SgColors.gold500 : SgColors.bg300,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 8,
                8,
                8,
              ),
              child: Row(
                children: [
                  Icon(
                    n.severity == 'warning'
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: n.severity == 'warning'
                        ? SgColors.onGold
                        : SgColors.ink,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      n.message,
                      style: TextStyle(
                        color: n.severity == 'warning'
                            ? SgColors.onGold
                            : SgColors.ink,
                        fontSize: SgText.sizeSmall,
                      ),
                    ),
                  ),
                  if (!n.blocking)
                    IconButton(
                      key: Key('notice_dismiss_${n.id}'),
                      icon: Icon(
                        Icons.close,
                        color: n.severity == 'warning'
                            ? SgColors.onGold
                            : SgColors.ink,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _dismissed.add(n.id)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The card shown when a booking is refused with CITY_PAUSED / CITY_NOT_LIVE.
class BookingRefusalCard extends StatelessWidget {
  const BookingRefusalCard({super.key, required this.refusal, this.onDismiss});

  final BookingRefusal refusal;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('booking_refusal_card'),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: SgColors.bg300,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: _gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                refusal.message,
                key: const Key('booking_refusal_message'),
                style: TextStyle(
                  color: SgColors.ink,
                  fontSize: SgText.sizeSmall,
                ),
              ),
            ),
            TextButton(
              key: const Key('booking_refusal_ok'),
              onPressed: onDismiss,
              child: Text('OK', style: TextStyle(color: _gold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps the routed app: blocking update screen, notices at the top, booking
/// refusal at the bottom. Sits in MaterialApp.router(builder: ...).
class MarketOverlays extends StatelessWidget {
  const MarketOverlays({
    super.key,
    required this.child,
    this.update,
    this.refusals,
    this.market,
  });

  final Widget child;
  final UpdateRequiredState? update;
  final BookingRefusalState? refusals;
  final MarketConfigStore? market;

  @override
  Widget build(BuildContext context) {
    final u = update ?? UpdateRequiredState.instance;
    final r = refusals ?? BookingRefusalState.instance;
    final m = market ?? MarketConfigStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([u, r, m]),
      builder: (context, _) {
        final info = u.info;
        if (info != null) return UpdateRequiredScreen(info: info);
        final refusal = r.latest;
        return Stack(
          children: [
            child,
            if (m.current.notices.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NoticeBanner(notices: m.current.notices),
              ),
            if (refusal != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: BookingRefusalCard(
                    refusal: refusal,
                    onDismiss: r.dismiss,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The market config for [context], rebuilding when it changes. Tolerates a
/// tree with no [MarketConfigStore] provider (older tests, previews) by
/// falling back to the app-wide instance.
///
/// Pass `listen: false` from an event handler. Listening outside `build`
/// fails a Provider assertion in debug builds: on the login screen that threw
/// on "Continue", so a debug (QA) build could not sign in at all.
MarketConfig marketOf(BuildContext context, {bool listen = true}) {
  try {
    return Provider.of<MarketConfigStore>(context, listen: listen).current;
  } on ProviderNotFoundException {
    return MarketConfigStore.instance.current;
  }
}
