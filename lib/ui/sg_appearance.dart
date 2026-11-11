/// Theme and language, chosen in Account and kept on the device.
///
/// Light (Daylight) is the default (owner, 2026-11-06): a rider who never chose
/// gets Light, and an explicit earlier choice is kept. Dark is the black and
/// gold theme. Automatic follows the device's light/dark setting. The language is English, Telugu or Hindi; with no saved choice the
/// app starts in English.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';

/// In the order the Appearance sheet lists them.
enum SgThemeChoice { light, dark, automatic }

/// The account field `preferred_theme`: light | dark | auto.
String themeChoiceWire(SgThemeChoice c) => switch (c) {
  SgThemeChoice.light => 'light',
  SgThemeChoice.dark => 'dark',
  SgThemeChoice.automatic => 'auto',
};

SgThemeChoice? themeChoiceFromWire(Object? v) => switch (v) {
  'light' => SgThemeChoice.light,
  'dark' => SgThemeChoice.dark,
  'auto' => SgThemeChoice.automatic,
  _ => null,
};

class SgAppearance extends ChangeNotifier {
  SgAppearance._();

  static final SgAppearance instance = SgAppearance._();

  static const themeKey = 'sg_theme_choice';
  static const localeKey = 'sg_locale';
  static const supportedLanguages = ['en', 'te', 'hi'];

  SgThemeChoice _theme = SgThemeChoice.light;
  bool _themeSaved = false;
  String _language = 'en';
  bool _languageSaved = false;

  /// Called when the rider picks a language, so the account can keep it
  /// (PATCH /auth/profile/ preferred_language). Fire and forget; set in main.
  static void Function(String code)? onLanguagePicked;

  /// Called when the rider picks a theme, so the account keeps it
  /// (PATCH /auth/update/ preferred_theme). Fire and forget; set in main.
  static void Function(String wire)? onThemePicked;

  /// True once a theme has been chosen on this device.
  bool get hasSavedTheme => _themeSaved;

  /// True once a language has been chosen on this device. Sign-in shows the
  /// language tiles only while this is false.
  bool get hasSavedLanguage => _languageSaved;

  SgThemeChoice get theme => _theme;
  String get language => _language;
  Locale get locale => Locale(_language);

  ThemeMode get themeMode => switch (_theme) {
    SgThemeChoice.dark => ThemeMode.dark,
    SgThemeChoice.light => ThemeMode.light,
    SgThemeChoice.automatic => ThemeMode.system,
  };

  /// The palette for the current choice and device setting.
  SgPalette get palette {
    final brightness = switch (_theme) {
      SgThemeChoice.dark => Brightness.dark,
      SgThemeChoice.light => Brightness.light,
      SgThemeChoice.automatic =>
        SchedulerBinding.instance.platformDispatcher.platformBrightness,
    };
    return brightness == Brightness.light ? SgPalette.light : SgPalette.dark;
  }

  /// Reads the saved choices. Called once before the first frame.
  Future<void> restore([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final saved = p.getString(themeKey);
    final match = SgThemeChoice.values.where((c) => c.name == saved);
    _themeSaved = match.isNotEmpty;
    _theme = _themeSaved ? match.first : SgThemeChoice.light;
    final lang = p.getString(localeKey);
    _languageSaved = supportedLanguages.contains(lang);
    _language = _languageSaved ? lang! : 'en';
    apply();
  }

  /// Pushes the choice into [SgColors] and [SgText]. Safe to call any time.
  void apply() {
    SgColors.palette = palette;
    SgText.language = _language;
  }

  Future<void> setTheme(SgThemeChoice choice) async {
    final changed = choice != _theme;
    if (!changed && _themeSaved) return;
    _theme = choice;
    _themeSaved = true;
    apply();
    if (changed) notifyListeners();
    try {
      onThemePicked?.call(themeChoiceWire(choice));
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.setString(themeKey, choice.name);
  }

  /// The account's saved theme (`preferred_theme`), used only when this
  /// device has none.
  Future<void> adoptServerTheme(Object? wire) async {
    final choice = themeChoiceFromWire(wire);
    if (_themeSaved || choice == null) return;
    _theme = choice;
    _themeSaved = true;
    apply();
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(themeKey, choice.name);
    } catch (_) {}
  }

  /// The quick switch in the home header: dark when light shows, and light
  /// when dark shows (Automatic resolves to what is on screen).
  Future<void> toggleTheme() => setTheme(
    SgColors.isDark ? SgThemeChoice.light : SgThemeChoice.dark,
  );

  Future<void> setLanguage(String code) async {
    if (!supportedLanguages.contains(code)) return;
    final changed = code != _language;
    if (!changed && _languageSaved) return;
    _language = code;
    _languageSaved = true;
    apply();
    if (changed) notifyListeners();
    try {
      onLanguagePicked?.call(code);
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.setString(localeKey, code);
  }

  /// The account's saved language, used only when this device has none.
  Future<void> adoptServerLanguage(String? code) async {
    if (_languageSaved || !supportedLanguages.contains(code)) return;
    _language = code!;
    _languageSaved = true;
    apply();
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(localeKey, code);
    } catch (_) {}
  }

  /// The device switched light/dark. Only matters on Automatic.
  void platformBrightnessChanged() {
    if (_theme != SgThemeChoice.automatic) return;
    apply();
    notifyListeners();
  }
}

/// Rebuilds the whole tree when the theme or language changes, and follows the
/// device on Automatic.
///
/// Every widget reads [SgColors] and [SgText] in `build`, so marking every
/// element dirty is enough; the tree, the router and every State survive.
class SgAppearanceScope extends StatefulWidget {
  const SgAppearanceScope({
    super.key,
    required this.builder,
    SgAppearance? appearance,
  }) : _appearance = appearance;

  final Widget Function(BuildContext context, SgAppearance appearance) builder;
  final SgAppearance? _appearance;

  @override
  State<SgAppearanceScope> createState() => _SgAppearanceScopeState();
}

class _SgAppearanceScopeState extends State<SgAppearanceScope>
    with WidgetsBindingObserver {
  SgAppearance get _a => widget._appearance ?? SgAppearance.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _a.apply();
    _a.addListener(_changed);
  }

  @override
  void dispose() {
    _a.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _a.platformBrightnessChanged();

  void _changed() {
    if (!mounted) return;
    setState(() {});
    void dirty(Element e) {
      e.markNeedsBuild();
      e.visitChildren(dirty);
    }

    (context as Element).visitChildren(dirty);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _a);
}
