// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appearance => 'రూపం';

  @override
  String get themeDark => 'డార్క్';

  @override
  String get themeLight => 'లైట్';

  @override
  String get themeAutomatic => 'ఆటోమేటిక్';

  @override
  String get themeAutomaticHint => 'మీ ఫోన్ సెట్టింగ్ ప్రకారం';

  @override
  String get language => 'భాష';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTelugu => 'తెలుగు';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get langChooseTitle => 'మీ భాషను ఎంచుకోండి';

  @override
  String get phoneTitle => 'మీ మొబైల్ నంబర్';

  @override
  String get phoneHint => 'మొబైల్ నంబర్';

  @override
  String get sendCode => 'కోడ్ పంపండి';

  @override
  String get useEmail => 'ఈమెయిల్‌తో కొనసాగండి';

  @override
  String get useMobile => 'మొబైల్ నంబర్‌తో కొనసాగండి';

  @override
  String get termsLine =>
      'కొనసాగడం ద్వారా మీరు సేవా నిబంధనలు మరియు గోప్యతా విధానానికి అంగీకరిస్తున్నారు.';

  @override
  String get verifyTitle => 'కోడ్ నమోదు చేయండి';

  @override
  String verifySentTo(String phone) {
    return '$phone కు 6 అంకెల కోడ్ పంపాము';
  }

  @override
  String verifyResendIn(String time) {
    return '$time లో మళ్లీ పంపండి';
  }

  @override
  String get verifyResend => 'కోడ్ మళ్లీ పంపండి';

  @override
  String get verifyButton => 'ధృవీకరించండి';

  @override
  String get changeNumber => 'నంబర్ మార్చండి';

  @override
  String homeHeadlineNamed(String name) {
    return '$name, మీరు ఎక్కడికి వెళ్తున్నారు?';
  }

  @override
  String get homeHeadline => 'మీరు ఎక్కడికి వెళ్తున్నారు?';

  @override
  String get youAreHere => 'మీరు ఇక్కడ';

  @override
  String get pickupHint => 'పికప్ చోటు నమోదు చేయండి';

  @override
  String get searchDestination => 'గమ్యస్థానం వెతకండి';

  @override
  String get faresFromHere => 'ఇక్కడి నుండి ఇప్పటి ఛార్జీలు';

  @override
  String get fareLockLine => 'బుక్ చేసిన ఛార్జీయే మీరు చెల్లించేది.';

  @override
  String get tapToSeeFares => 'ఛార్జీలు చూడటానికి నొక్కండి';

  @override
  String get tabRide => 'రైడ్';

  @override
  String get tabTrips => 'ట్రిప్పులు';

  @override
  String get tabAccount => 'ఖాతా';

  @override
  String get wallet => 'వాలెట్';

  @override
  String waysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'అక్కడికి $count మార్గాలు',
      one: 'అక్కడికి 1 మార్గం',
    );
    return '$_temp0';
  }

  @override
  String get tagCheapest => 'చౌకైనది';

  @override
  String get tagFastest => 'వేగమైనది';

  @override
  String bookClass(String name, String fare) {
    return '$name బుక్ చేయండి · $fare';
  }

  @override
  String get selectRide => 'రైడ్ ఎంచుకోండి';

  @override
  String get change => 'మార్చండి';

  @override
  String get payCash => 'నగదు';

  @override
  String get payWallet => 'వాలెట్';

  @override
  String get payOnline => 'UPI / కార్డ్';

  @override
  String get fareTicket => 'మీ ఛార్జీ టికెట్';

  @override
  String get fareLocked => 'బుక్ చేసినప్పుడు లాక్ అవుతుంది. పెరగదు.';

  @override
  String get pickupLabel => 'పికప్';

  @override
  String get dropLabel => 'డ్రాప్';

  @override
  String get edit => 'మార్చండి';

  @override
  String get dragToMove => 'పికప్ మార్చడానికి మ్యాప్‌ను జరపండి';

  @override
  String seeHowWorkedOut(String fare) {
    return '$fare ఎలా లెక్కించారో చూడండి';
  }

  @override
  String get confirmAndBook => 'పికప్ నిర్ధారించి బుక్ చేయండి';

  @override
  String findingClass(String name) {
    return '$name డ్రైవర్ కోసం వెతుకుతున్నాం';
  }

  @override
  String fareLockedAt(String fare) {
    return 'ఛార్జీ $fare వద్ద లాక్';
  }

  @override
  String get waitingAccept => 'ఒకరు అంగీకరించే వరకు వేచి ఉన్నాం';

  @override
  String get closeAppNote => 'యాప్ మూసివేయవచ్చు; మేము మీకు తెలియజేస్తాం.';

  @override
  String get freeToCancel => 'రద్దు చేయడం ఉచితం';

  @override
  String get cancelRequest => 'అభ్యర్థన రద్దు చేయండి';
}
