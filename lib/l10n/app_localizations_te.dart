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

  @override
  String minutesShort(int n) {
    return '$n నిమి';
  }

  @override
  String driverOnWay(String name) {
    return '$name వస్తున్నారు';
  }

  @override
  String driverArrived(String name) {
    return '$name వచ్చారు';
  }

  @override
  String get yourDriver => 'మీ డ్రైవర్';

  @override
  String get ridePin => 'రైడ్ PIN';

  @override
  String get ridePinHint => 'కారులో డ్రైవర్‌కు చెప్పండి';

  @override
  String get call => 'కాల్';

  @override
  String get message => 'సందేశం';

  @override
  String get safety => 'భద్రత';

  @override
  String get cancelRide => 'రైడ్ రద్దు చేయండి';

  @override
  String arrivingAbout(String time) {
    return 'సుమారు $timeకి చేరుకుంటారు';
  }

  @override
  String get arrivingSoon => 'త్వరలో చేరుకుంటారు';

  @override
  String minutesLeft(int n) {
    return '$n నిమి మిగిలాయి';
  }

  @override
  String onTheWayTo(String place) {
    return '$place కు వెళ్తున్నాం';
  }

  @override
  String get locked => 'లాక్';

  @override
  String get viewSummary => 'సారాంశం చూడండి';

  @override
  String get ticketSaid => 'మీ టికెట్‌లో';

  @override
  String get tripCost => 'ట్రిప్ ఖర్చు';

  @override
  String get exactlyQuoted => 'మీకు చెప్పినంతే';

  @override
  String get promotion => 'ప్రమోషన్';

  @override
  String differenceUnexplained(String amount) {
    return 'తేడా $amount: కారణం ఇంకా అందుబాటులో లేదు';
  }

  @override
  String get howItAddsUp => 'ఎలా లెక్కించారు';

  @override
  String payBy(String amount, String method) {
    return '$method ద్వారా $amount చెల్లించండి';
  }

  @override
  String payingCash(String amount, String name) {
    return 'నగదా? $name కు $amount ఇవ్వండి';
  }

  @override
  String rateDriver(String name) {
    return '$name కు రేటింగ్ ఇవ్వండి';
  }

  @override
  String get inDanger => 'ప్రమాదంలో ఉన్నారా?';

  @override
  String get holdForSos =>
      'SOS కోసం 2 సెకన్లు నొక్కి ఉంచండి. మా బృందానికి వెంటనే తెలుస్తుంది.';

  @override
  String callEmergency(String number) {
    return '$number కు కాల్ చేయండి';
  }

  @override
  String get reportSomething => 'ఏదైనా తెలియజేయండి';

  @override
  String get callSupport => 'SaaradhiGo సపోర్ట్‌కు కాల్';

  @override
  String noClassFree(String name) {
    return 'మీ దగ్గర $name ఖాళీగా లేదు';
  }

  @override
  String get notCharged => 'మీకు ఎలాంటి ఛార్జీ పడలేదు';

  @override
  String get keepLooking => 'వెతుకుతూనే ఉండండి';

  @override
  String get tryAnotherRide => 'లేదా మరో రైడ్ ప్రయత్నించండి';

  @override
  String get changeRide => 'రైడ్ మార్చండి';

  @override
  String get paymentFailed => 'చెల్లింపు జరగలేదు';

  @override
  String get moneyComesBack =>
      'మీ ఖాతా నుండి డబ్బు వెళ్లి ఉంటే, అది మీకు తిరిగి వస్తుంది.';

  @override
  String refundWithin(int days) {
    return '$days పని దినాల్లో తిరిగి వస్తుంది.';
  }

  @override
  String get stillToPay => 'ఇంకా చెల్లించాల్సింది';

  @override
  String get tryAnotherWay =>
      'మళ్లీ ప్రయత్నించండి లేదా వేరే విధంగా చెల్లించండి';

  @override
  String get talkSupportPayment => 'ఈ చెల్లింపు గురించి సపోర్ట్‌తో మాట్లాడండి';

  @override
  String get goHome => 'హోమ్‌కు వెళ్లండి';

  @override
  String get noDriversNearby => 'దగ్గరలో డ్రైవర్లు లేరు';

  @override
  String seatsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n సీట్లు',
      one: '1 సీటు',
    );
    return '$_temp0';
  }
}
