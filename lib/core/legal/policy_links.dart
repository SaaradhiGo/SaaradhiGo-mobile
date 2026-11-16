/// The public policy pages, on the website. Production host, or the QA host in
/// a QA build (the build that shows the QA badge).
library;

import '../app_config.dart';

const String kProductionSite = 'https://www.saaradhigo.com';
const String kQaSite = 'https://www.qa.saaradhigo.com';

/// The site the policy links open for this build.
String siteHost() => AppConfig.showEnvironmentBadge ? kQaSite : kProductionSite;

class PolicyLink {
  const PolicyLink(this.label, this.path, {this.indiaOnly = false});

  final String label;
  final String path;

  /// Shown only for the India market (the grievance page).
  final bool indiaOnly;

  Uri uri([String? host]) => Uri.parse('${host ?? siteHost()}$path');
}

/// The pages a rider can open from About, in the order they are listed.
const List<PolicyLink> kRiderPolicyLinks = <PolicyLink>[
  PolicyLink('About SaaradhiGo', '/about'),
  PolicyLink('Contact us', '/contact'),
  PolicyLink('Fares', '/fares'),
  PolicyLink('Terms of service', '/terms'),
  PolicyLink('Privacy policy', '/privacy'),
  PolicyLink('Refunds and cancellations', '/refunds'),
  PolicyLink('Text messages', '/text-messages'),
  PolicyLink('Grievance redressal', '/grievance', indiaOnly: true),
  PolicyLink('Cookies', '/cookies'),
  PolicyLink('Safety', '/safety'),
];

List<PolicyLink> policyLinksFor(String countryCode) => [
  for (final l in kRiderPolicyLinks)
    if (!l.indiaOnly || countryCode.toUpperCase() == 'IN') l,
];
