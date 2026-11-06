// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appearance => 'रूप';

  @override
  String get themeDark => 'डार्क';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeAutomatic => 'ऑटोमैटिक';

  @override
  String get themeAutomaticHint => 'फ़ोन की सेटिंग के अनुसार';

  @override
  String get language => 'भाषा';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTelugu => 'తెలుగు';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get langChooseTitle => 'अपनी भाषा चुनें';

  @override
  String get phoneTitle => 'आपका मोबाइल नंबर';

  @override
  String get phoneHint => 'मोबाइल नंबर';

  @override
  String get sendCode => 'कोड भेजें';

  @override
  String get useEmail => 'ईमेल से जारी रखें';

  @override
  String get useMobile => 'मोबाइल नंबर से जारी रखें';

  @override
  String get termsLine =>
      'जारी रखकर आप सेवा की शर्तों और गोपनीयता नीति से सहमत होते हैं।';

  @override
  String get verifyTitle => 'कोड डालें';

  @override
  String verifySentTo(String phone) {
    return 'हमने $phone पर 6 अंकों का कोड भेजा है';
  }

  @override
  String verifyResendIn(String time) {
    return '$time में दोबारा भेजें';
  }

  @override
  String get verifyResend => 'कोड दोबारा भेजें';

  @override
  String get verifyButton => 'सत्यापित करें';

  @override
  String get changeNumber => 'नंबर बदलें';

  @override
  String homeHeadlineNamed(String name) {
    return '$name, आप कहाँ जा रहे हैं?';
  }

  @override
  String get homeHeadline => 'आप कहाँ जा रहे हैं?';

  @override
  String get youAreHere => 'आप यहाँ हैं';

  @override
  String get pickupHint => 'पिकअप जगह डालें';

  @override
  String get searchDestination => 'मंज़िल खोजें';

  @override
  String get faresFromHere => 'यहाँ से अभी के किराए';

  @override
  String get fareLockLine => 'जो किराया बुक करें, वही चुकाएँ।';

  @override
  String get tapToSeeFares => 'किराए देखने के लिए टैप करें';

  @override
  String get tabRide => 'राइड';

  @override
  String get tabTrips => 'ट्रिप';

  @override
  String get tabAccount => 'खाता';

  @override
  String get wallet => 'वॉलेट';
}
