/// The Appearance and Language rows in Account, and the sheets they open.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'account_widgets.dart';
import 'sg_appearance.dart';
import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';

/// The app's strings; English where no localizations are installed (a bare
/// test harness).
AppLocalizations sgStrings(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));

String themeChoiceLabel(AppLocalizations l, SgThemeChoice c) => switch (c) {
  SgThemeChoice.dark => l.themeDark,
  SgThemeChoice.light => l.themeLight,
  SgThemeChoice.automatic => l.themeAutomatic,
};

String languageLabel(AppLocalizations l, String code) => switch (code) {
  'te' => l.languageTelugu,
  'hi' => l.languageHindi,
  _ => l.languageEnglish,
};

/// Two rows: Appearance (Dark / Light / Automatic) and Language.
List<Widget> appearanceRows(BuildContext context, {SgAppearance? appearance}) {
  final a = appearance ?? SgAppearance.instance;
  final l = sgStrings(context);
  return [
    SgListRow(
      key: const Key('profile_appearance'),
      icon: SgIcons.theme,
      label: l.appearance,
      value: themeChoiceLabel(l, a.theme),
      chevron: true,
      onTap: () => _showChoices<SgThemeChoice>(
        context,
        title: l.appearance,
        options: [
          for (final c in SgThemeChoice.values)
            (
              c,
              themeChoiceLabel(l, c),
              c == SgThemeChoice.automatic ? l.themeAutomaticHint : null,
            ),
        ],
        selected: a.theme,
        onSelected: a.setTheme,
      ),
    ),
    SgListRow(
      key: const Key('profile_language'),
      icon: SgIcons.language,
      label: l.language,
      value: languageLabel(l, a.language),
      chevron: true,
      onTap: () => _showChoices<String>(
        context,
        title: l.language,
        options: [
          for (final code in SgAppearance.supportedLanguages)
            (code, languageLabel(l, code), null),
        ],
        selected: a.language,
        onSelected: a.setLanguage,
      ),
    ),
  ];
}

/// The language sheet on its own (the home header's language chip).
Future<void> showLanguagePicker(
  BuildContext context, {
  SgAppearance? appearance,
}) {
  final a = appearance ?? SgAppearance.instance;
  final l = sgStrings(context);
  return _showChoices<String>(
    context,
    title: l.language,
    options: [
      for (final code in SgAppearance.supportedLanguages)
        (code, languageLabel(l, code), null),
    ],
    selected: a.language,
    onSelected: a.setLanguage,
  );
}

/// The payment method the booking flow uses, in the rider's language.
String paymentMethodLabel(AppLocalizations l, String method) =>
    switch (method.trim().toLowerCase()) {
      'cash' => l.payCash,
      'wallet' => l.payWallet,
      'online' || 'upi' || 'card' || 'upi_card' => l.payOnline,
      '' => l.payCash,
      _ => method[0].toUpperCase() + method.substring(1),
    };

/// The short mark on the language chip: EN, తె, हि.
String languageShort(String code) => switch (code) {
  'te' => 'తె',
  'hi' => 'हि',
  _ => 'EN',
};

Future<void> _showChoices<T>(
  BuildContext context, {
  required String title,
  required List<(T, String, String?)> options,
  required T selected,
  required Future<void> Function(T) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SgColors.bg100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(SgRadius.lg)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SgSpace.s4,
          SgSpace.s4,
          SgSpace.s4,
          SgSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: SgText.title),
            const SizedBox(height: SgSpace.s3),
            for (final (value, label, hint) in options)
              _ChoiceRow(
                key: Key('choice_$value'),
                label: label,
                hint: hint,
                selected: value == selected,
                onTap: () {
                  Navigator.of(sheet).pop();
                  onSelected(value);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SgRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: SgText.body),
                  if (hint != null) Text(hint!, style: SgText.caption),
                ],
              ),
            ),
            if (selected)
              SgIcon(SgIcons.check, size: 22, color: SgColors.goldText),
          ],
        ),
      ),
    ),
  );
}
