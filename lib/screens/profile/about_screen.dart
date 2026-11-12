import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/legal_entity.dart';
import '../../core/legal/policy_links.dart';
import '../../providers/remote_config_provider.dart';
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../components/market_overlays.dart';

/// Opens a policy page in the browser.
Future<void> openPolicy(PolicyLink link) =>
    launchUrl(link.uri(), mode: LaunchMode.externalApplication);

/// About: the operator of the service for the rider's market, the app version
/// and the links to the public policy pages. Nothing is shown that the server
/// did not send, except the operator's name.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.year, this.versionLoader});

  /// Test seams: the year for the copyright line and the version lookup.
  final int? year;
  final Future<String?> Function()? versionLoader;

  static Future<String?> _version() async {
    try {
      final i = await PackageInfo.fromPlatform();
      return '${i.version} (${i.buildNumber})';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = marketOf(context).countryCode;
    final entity = _entity(context, country);
    final links = policyLinksFor(country);
    return Scaffold(
      backgroundColor: SgColors.bg200,
      appBar: AppBar(
        backgroundColor: SgColors.bg100,
        elevation: 0,
        leading: IconButton(
          key: const Key('about_back'),
          icon: Icon(Icons.arrow_back, color: SgColors.ink, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text('About', style: SgText.title),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('SaaradhiGo', style: SgText.heading),
          const SizedBox(height: SgSpace.s2),
          FutureBuilder<String?>(
            future: (versionLoader ?? _version)(),
            builder: (c, snap) => (snap.data ?? '').isEmpty
                ? const SizedBox.shrink()
                : Text('Version ${snap.data}', style: SgText.caption),
          ),
          const SizedBox(height: SgSpace.s4),
          Text(
            entity.copyright(year ?? DateTime.now().year),
            key: const Key('about_operator'),
            style: SgText.body,
          ),
          for (final line in [
            entity.registeredAddress,
            if (entity.cin.isNotEmpty) 'CIN ${entity.cin}',
            if (entity.gstRegistered && entity.gstin.isNotEmpty)
              'GSTIN ${entity.gstin}',
            entity.supportPhone,
            entity.supportEmail,
          ])
            if (line.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: SgSpace.s1),
                child: Text(line, style: SgText.caption),
              ),
          const SizedBox(height: SgSpace.s6),
          Text('POLICIES AND INFORMATION', style: SgText.caption),
          const SizedBox(height: SgSpace.s2),
          for (final link in links)
            InkWell(
              key: Key('about_link_${link.path.substring(1)}'),
              onTap: () => openPolicy(link),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: SgColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(link.label, style: SgText.body)),
                    Icon(Icons.open_in_new, size: 16, color: SgColors.inkMuted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  LegalEntity _entity(BuildContext context, String country) {
    try {
      return Provider.of<RemoteConfigProvider>(context).legalFor(country);
    } on ProviderNotFoundException {
      return LegalEntity.fallback(country);
    }
  }
}
