// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appearance => 'Appearance';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeAutomatic => 'Automatic';

  @override
  String get themeAutomaticHint => 'Follows your phone';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTelugu => 'తెలుగు';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get langChooseTitle => 'Choose your language';

  @override
  String get phoneTitle => 'Your mobile number';

  @override
  String get phoneHint => 'Mobile number';

  @override
  String get sendCode => 'Send code';

  @override
  String get useEmail => 'Use email instead';

  @override
  String get useMobile => 'Use mobile number instead';

  @override
  String get termsLine =>
      'By continuing you agree to the Terms of Service and Privacy Policy.';

  @override
  String get verifyTitle => 'Enter the code';

  @override
  String verifySentTo(String phone) {
    return 'We sent a 6-digit code to $phone';
  }

  @override
  String verifyResendIn(String time) {
    return 'Resend code in $time';
  }

  @override
  String get verifyResend => 'Resend code';

  @override
  String get verifyButton => 'Verify';

  @override
  String get changeNumber => 'Change number';

  @override
  String homeHeadlineNamed(String name) {
    return 'Where are you going, $name?';
  }

  @override
  String get homeHeadline => 'Where are you going?';

  @override
  String get youAreHere => 'You are here';

  @override
  String get pickupHint => 'Enter pickup point';

  @override
  String get searchDestination => 'Search destination';

  @override
  String get faresFromHere => 'Fares from here, right now';

  @override
  String get fareLockLine => 'The fare you book is the fare you pay.';

  @override
  String get tapToSeeFares => 'Tap to see fares';

  @override
  String get tabRide => 'Ride';

  @override
  String get tabTrips => 'Trips';

  @override
  String get tabAccount => 'Account';

  @override
  String get wallet => 'Wallet';
}
