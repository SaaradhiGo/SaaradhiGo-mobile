/// Theme and language, chosen in Account and kept on the device.
///
/// Dark is the default (spec 1.5). Automatic follows the device's light/dark
/// setting. The language is English, Telugu or Hindi; with no saved choice the
/// app starts in English.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';

enum SgThemeChoice { dark, light, automatic }

class SgAppearance extends ChangeNotifier {
  SgAppearance._();

  static final SgAppearance instance = SgAppearance._();

  static const themeKey = 'sg_theme_choice';
  static const localeKey = 'sg_locale';
  static const supportedLanguages = ['en', 'te', 'hi'];

  SgThemeChoice _theme = SgThemeChoice.dark;
  String _language = 'en';

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
    _theme = SgThemeChoice.values.firstWhere(
      (c) => c.name == p.getString(themeKey),
      orElse: () => SgThemeChoice.dark,
    );
    final lang = p.getString(localeKey);
    _language = supportedLanguages.contains(lang) ? lang! : 'en';
    apply();
  }

  /// Pushes the choice into [SgColors] and [SgText]. Safe to call any time.
  void apply() {
    SgColors.palette = palette;
    SgText.language = _language;
  }

  Future<void> setTheme(SgThemeChoice choice) async {
    if (choice == _theme) return;
    _theme = choice;
    apply();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(themeKey, choice.name);
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguages.contains(code) || code == _language) return;
    _language = code;
    apply();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(localeKey, code);
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
