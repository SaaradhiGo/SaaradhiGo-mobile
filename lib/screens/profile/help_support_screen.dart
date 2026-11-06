import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import '../../services/support_service.dart';
import 'report_problem_screen.dart';

import '../../ui/sg_tokens.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static Color get _screenBackground => SgColors.bg000;

  void _openHomeTab(BuildContext context, int tabIndex) {
    context.go('/home?tab=$tabIndex');
  }

  void _handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
      return;
    }
    context.go('/home?tab=3');
  }

  /// Open the ticket form, preselecting what the rider tapped.
  static void _report(BuildContext context, SupportIssueType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportProblemScreen(initialIssueType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 84,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: SgColors.bg100.withValues(alpha: 0.90),
            border: Border(top: BorderSide(color: SgColors.line)),
          ),
          child: Row(
            children: [
              _HelpNavItem(
                icon: Icons.home,
                label: 'Home',
                selected: false,
                onTap: () => _openHomeTab(context, 0),
              ),
              _HelpNavItem(
                icon: Icons.history,
                label: 'History',
                selected: false,
                onTap: () => _openHomeTab(context, 1),
              ),
              _HelpNavItem(
                icon: Icons.account_balance_wallet,
                label: 'Wallet',
                selected: false,
                onTap: () => _openHomeTab(context, 2),
              ),
              _HelpNavItem(
                icon: Icons.person,
                label: 'Profile',
                selected: true,
                onTap: () => _openHomeTab(context, 3),
              ),
            ],
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
                    onTap: () => _handleBack(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: SgColors.bg300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        color: SgColors.ink,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Help & Support',
                    style: TextStyle(
                      color: SgColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const _HelpSearchField(),
                  const SizedBox(height: 32),
                  const _HelpSectionLabel('Common Topics'),
                  const SizedBox(height: 16),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 1.70,
                        ),
                    children: [
                      _MiniTile(
                        icon: Icons.directions_car,
                        label: 'Ride Issues',
                        onTap: () =>
                            _report(context, SupportIssueType.fareDispute),
                      ),
                      _MiniTile(
                        icon: Icons.account_balance_wallet,
                        label: 'Payment & Wallet',
                        onTap: () => _report(context, SupportIssueType.payment),
                      ),
                      _MiniTile(
                        icon: Icons.person,
                        label: 'Account & App',
                        onTap: () => _report(context, SupportIssueType.account),
                      ),
                      _MiniTile(
                        icon: Icons.shield,
                        label: 'Safety',
                        iconBackground: SgColors.goldSoft,
                        onTap: () => _report(context, SupportIssueType.safety),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const _HelpSectionLabel('Contact Us'),
                  const SizedBox(height: 16),
                  // "Live Chat" promised something that does not exist --
                  // there is no chat service behind this app. Replaced with
                  // the ticket flow, which is real, and described honestly:
                  // support replies in the app rather than instantly.
                  _ContactTile(
                    icon: Icons.edit_note,
                    title: 'Report a problem',
                    subtitle: 'Support replies in the app',
                    onTap: () => _report(context, SupportIssueType.other),
                  ),
                  const SizedBox(height: 12),
                  _ContactTile(
                    icon: Icons.mail,
                    title: 'Email Support',
                    // Was support@saaradhigo.com. The platform runs on
                    // saaradhigo.com -- api.saaradhigo.com, and
                    // PLATFORM_CONTACT_DOMAIN -- so the .com address was a
                    // dead end for anyone who typed it in.
                    subtitle: 'support@saaradhigo.com',
                    onTap: () => _report(context, SupportIssueType.other),
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

class _HelpNavItem extends StatelessWidget {
  const _HelpNavItem({
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24, shadows: shadows),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                shadows: shadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSearchField extends StatelessWidget {
  const _HelpSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: SgColors.bg300,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SgColors.line),
      ),
      child: TextField(
        style: TextStyle(color: SgColors.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search for issues...',
          hintStyle: TextStyle(color: SgColors.inkSubtle),
          prefixIcon: Icon(Icons.search, color: SgColors.inkSubtle),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _HelpSectionLabel extends StatelessWidget {
  const _HelpSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: SgColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.label,
    this.iconBackground,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconBackground;

  /// These tiles had no handler at all, so a rider could tap "Safety" on a
  /// screen called Help & Support and nothing would happen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: SgColors.bg300,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SgColors.line),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBackground ?? SgColors.goldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: SgColors.goldText, size: 20),
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                color: SgColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SgColors.bg300,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SgColors.line),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: SgColors.gold500.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: SgColors.goldText, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: SgColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: SgColors.inkMuted, fontSize: 13),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: SgColors.inkSubtle,
          size: 20,
        ),
      ),
    );
  }
}
