import '../../ui/appearance_settings.dart' show sgStrings;
import 'package:flutter/material.dart';

import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

import '../../ui/sg_tokens.dart';
import '../../ui/sg_text.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  void _openHomeTab(int tabIndex) {
    FocusScope.of(context).unfocus();
    context.go('/home?tab=$tabIndex');
  }

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
      return;
    }
    _openHomeTab(3);
  }

  void _showComingSoon(String label) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label will be available soon.'),
          backgroundColor: SgColors.bg300,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: SgColors.bg200,
      bottomNavigationBar: SafeArea(
        top: false,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              // Grows with the text size rather than clip the labels.
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              decoration: BoxDecoration(
                color: SgColors.bg100.withValues(alpha: 0.90),
                border: Border(top: BorderSide(color: SgColors.line)),
              ),
              child: Row(
                children: [
                  _PrivacyNavItem(
                    key: const Key('privacy-nav-home'),
                    icon: Icons.home,
                    label: sgStrings(context).navHome,
                    selected: false,
                    onTap: () => _openHomeTab(0),
                  ),
                  _PrivacyNavItem(
                    key: const Key('privacy-nav-history'),
                    icon: Icons.history,
                    label: sgStrings(context).navHistory,
                    selected: false,
                    onTap: () => _openHomeTab(1),
                  ),
                  _PrivacyNavItem(
                    key: const Key('privacy-nav-wallet'),
                    icon: Icons.account_balance_wallet,
                    label: sgStrings(context).wallet,
                    selected: false,
                    onTap: () => _openHomeTab(2),
                  ),
                  _PrivacyNavItem(
                    key: const Key('privacy-nav-profile'),
                    icon: Icons.person,
                    label: sgStrings(context).profile,
                    selected: true,
                    onTap: () => _openHomeTab(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  InkWell(
                    key: const Key('privacy-back'),
                    onTap: _handleBack,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: SgColors.bg300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: SgColors.ink,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Privacy & Security',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SgColors.ink,
                        fontSize: SgText.sizeHeading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40, height: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                children: [
                  const _PrivacySectionLabel('Account Security'),
                  const SizedBox(height: 14),
                  _PrivacyCard(
                    child: Column(
                      children: [
                        _PrivacyToggleRow(
                          key: const Key('privacy-toggle-two-factor'),
                          title: sgStrings(context).twoFactor,
                          subtitle:
                              'Add an extra layer of security to your account.',
                          value: auth.twoFactorEnabled,
                          // Awaited, not unawaited. The provider sets its
                          // in-memory field synchronously and then persists to
                          // SharedPreferences; firing that off unawaited meant a
                          // rider could change their two-factor authentication
                          // and kill the app before the write landed, leaving the
                          // switch showing one thing and storage holding another.
                          onChanged: (value) async {
                            await context
                                .read<AuthProvider>()
                                .setTwoFactorEnabled(value);
                          },
                        ),
                        const _PrivacyDivider(),
                        _PrivacyActionRow(
                          key: const Key('privacy-row-change-password'),
                          title: sgStrings(context).changePassword,
                          subtitle:
                              'Update your password regularly to keep your account safe.',
                          onTap: () => _showComingSoon(
                            sgStrings(context).changePassword,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _PrivacySectionLabel('Data Privacy'),
                  const SizedBox(height: 14),
                  _PrivacyCard(
                    child: Column(
                      children: [
                        _PrivacyActionRow(
                          key: const Key('privacy-row-location-permissions'),
                          title: sgStrings(context).locationPermissions,
                          subtitle:
                              'Control when SaaradhiGo can access your location.',
                          onTap: () => _showComingSoon(
                            sgStrings(context).locationPermissions,
                          ),
                        ),
                        const _PrivacyDivider(),
                        _PrivacyActionRow(
                          key: const Key(
                            'privacy-row-notification-preferences',
                          ),
                          title: sgStrings(context).notificationPreferences,
                          subtitle:
                              'Choose how you want to receive offers and updates.',
                          onTap: () =>
                              context.push('/notification-preferences'),
                        ),
                        const _PrivacyDivider(),
                        _PrivacyActionRow(
                          key: const Key('privacy-row-manage-data'),
                          title: sgStrings(context).manageMyData,
                          subtitle:
                              'Download or delete your account data securely.',
                          onTap: () =>
                              _showComingSoon(sgStrings(context).manageMyData),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySectionLabel extends StatelessWidget {
  const _PrivacySectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: SgText.eyebrow.copyWith(color: SgColors.inkMuted),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SgColors.bg300,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SgColors.line),
      ),
      child: child,
    );
  }
}

class _PrivacyDivider extends StatelessWidget {
  const _PrivacyDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      height: 1,
      color: SgColors.bg200,
    );
  }
}

class _PrivacyActionRow extends StatelessWidget {
  const _PrivacyActionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Not `key: key`: that put this widget's own key on a descendant too, so
        // the same key appeared twice in the tree and every find.byKey() on it was
        // ambiguous -- unusable for tests, integration drivers and a11y tooling.
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: SgColors.ink,
                        fontSize: SgText.sizeBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: SgColors.inkMuted,
                        fontSize: SgText.sizeSmall,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: SgColors.inkSubtle, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  const _PrivacyToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: SgColors.ink,
                    fontSize: SgText.sizeBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: SgColors.inkMuted,
                    fontSize: SgText.sizeSmall,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            // Not `key: key`: that put this widget's own key on a descendant too, so
            // the same key appeared twice in the tree and every find.byKey() on it was
            // ambiguous -- unusable for tests, integration drivers and a11y tooling.
            value: value,
            onChanged: onChanged,
            activeThumbColor: SgColors.bg100,
            activeTrackColor: SgColors.gold500,
            inactiveThumbColor: SgColors.bg100,
            inactiveTrackColor: SgColors.lineStrong,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _PrivacyNavItem extends StatelessWidget {
  const _PrivacyNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SgColors.goldText : SgColors.inkMuted;
    final shadows = selected ? const <Shadow>[] : null;

    return Expanded(
      child: InkWell(
        // Not `key: key`: that put this widget's own key on a descendant too, so
        // the same key appeared twice in the tree and every find.byKey() on it was
        // ambiguous -- unusable for tests, integration drivers and a11y tooling.
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24, shadows: shadows),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: SgText.sizeSmall,
                fontWeight: FontWeight.w600,
                shadows: shadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
