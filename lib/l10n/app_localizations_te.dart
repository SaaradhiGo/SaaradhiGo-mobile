// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get themeSwitchToDark => 'డార్క్ థీమ్‌కు మారండి';

  @override
  String get themeSwitchToLight => 'లైట్ థీమ్‌కు మారండి';

  @override
  String get appearance => 'రూపం';

  @override
  String get themeDark => 'డార్క్ (నలుపు, బంగారు)';

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

  @override
  String fareUpdatedTimePassed(String fare) {
    return 'సమయం గడిచినందున ఛార్జీ $fareకు మారింది';
  }

  @override
  String fareUpdatedPickupChanged(String fare) {
    return 'పికప్ మారినందున ఛార్జీ $fareకు మారింది';
  }

  @override
  String get fareUpdating => 'ఛార్జీ నవీకరిస్తున్నాం';

  @override
  String askedDriversNearby(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'దగ్గరలోని $n డ్రైవర్లను అడిగాం',
      one: 'దగ్గరలోని 1 డ్రైవర్‌ను అడిగాం',
    );
    return '$_temp0';
  }

  @override
  String get yourRides => 'మీ రైడ్‌లు';

  @override
  String get paymentMethods => 'చెల్లింపు పద్ధతులు';

  @override
  String get notifications => 'నోటిఫికేషన్లు';

  @override
  String get referFriend => 'స్నేహితుడిని ఆహ్వానించండి';

  @override
  String get profile => 'ప్రొఫైల్';

  @override
  String get helpSupport => 'సహాయం';

  @override
  String get personalInfo => 'వ్యక్తిగత వివరాలు';

  @override
  String get privacySecurity => 'గోప్యత, భద్రత';

  @override
  String get logOut => 'లాగ్ అవుట్';

  @override
  String get currentLocation => 'ప్రస్తుత స్థానం';

  @override
  String get useMyLocation => 'నా స్థానం వాడండి';

  @override
  String get selectPickupFirst => 'ముందు పికప్ ఎంచుకోండి';

  @override
  String get locationServicesOff =>
      'లొకేషన్ ఆఫ్‌లో ఉంది. సెట్టింగ్స్‌లో ఆన్ చేయండి.';

  @override
  String get locationDenied => 'లొకేషన్ అనుమతి లేదు.';

  @override
  String get locationDeniedForever =>
      'లొకేషన్ అనుమతి శాశ్వతంగా నిరాకరించబడింది. సెట్టింగ్స్‌లో ఇవ్వండి.';

  @override
  String get locationNotFound => 'మీ స్థానం దొరకలేదు. పికప్ నమోదు చేయండి.';

  @override
  String get resumingRide => 'మీ రైడ్ తిరిగి తెరుస్తున్నాం...';

  @override
  String get activeRideTitle => 'యాక్టివ్ రైడ్';

  @override
  String get activeRideBody => 'మీకు ఇప్పటికే ఒక రైడ్ ఉంది. చూడాలా?';

  @override
  String get dismiss => 'మూసివేయండి';

  @override
  String get whereTo => 'ఎక్కడికి?';

  @override
  String get placesAppearHere => 'మీరు వెళ్లే స్థలాలు ఇక్కడ కనిపిస్తాయి.';

  @override
  String get back => 'వెనుకకు';

  @override
  String get findingSaaradhi => 'మీ సారథిని వెతుకుతున్నాం';

  @override
  String get noSaaradhiNearby => 'ఇప్పుడు దగ్గరలో సారథి లేరు';

  @override
  String get cancelSearchTitle => 'వెతకడం ఆపాలా?';

  @override
  String get cancelSearchBody => 'రైడ్ అభ్యర్థన రద్దు చేయాలా?';

  @override
  String get wait => 'ఆగండి';

  @override
  String get cancelAnyway => 'అయినా రద్దు';

  @override
  String get ongoingRideTitle => 'కొనసాగుతున్న రైడ్';

  @override
  String get cancelActiveRequestBody =>
      'మీ రైడ్ అభ్యర్థన యాక్టివ్‌లో ఉంది. రద్దు చేయాలా?';

  @override
  String get cancelOngoingRideBody => 'కొనసాగుతున్న రైడ్ రద్దు చేయాలా?';

  @override
  String get continueRide => 'రైడ్ కొనసాగించండి';

  @override
  String get driverPhoneUnavailable => 'డ్రైవర్ ఫోన్ లేదు. చాట్ వాడండి.';

  @override
  String get dialerUnavailable => 'ఈ ఫోన్‌లో డయలర్ తెరవలేదు.';

  @override
  String get callFailed => 'కాల్ కాలేదు.';

  @override
  String get payWithCashTitle => 'నగదుతో చెల్లించండి';

  @override
  String get handToDriver => 'డ్రైవర్‌కు ఇవ్వండి';

  @override
  String get payFromWallet => 'వాలెట్ నుండి చెల్లించండి';

  @override
  String get notEnoughBalance => 'బ్యాలెన్స్ సరిపోదు';

  @override
  String get payViaUpiCard => 'UPI/కార్డ్‌తో చెల్లించండి';

  @override
  String get payCashInstead => 'బదులుగా నగదు ఇవ్వాలా?';

  @override
  String get thanksForRating => 'రేటింగ్‌కు ధన్యవాదాలు.';

  @override
  String get insufficientBalance => 'బ్యాలెన్స్ సరిపోదు';

  @override
  String get wouldYouLike => 'మీరు ఏం చేయాలనుకుంటున్నారు:';

  @override
  String get addMoney => 'డబ్బు జోడించండి';

  @override
  String get payUpiCard => 'UPI/కార్డ్‌తో చెల్లించండి';

  @override
  String get cashReceived => 'నగదు అందింది. ధన్యవాదాలు.';

  @override
  String get signInToPay => 'చెల్లించడానికి మళ్లీ సైన్ ఇన్ చేయండి.';

  @override
  String get noActiveTrip =>
      'యాక్టివ్ ట్రిప్ లేదు. రిఫ్రెష్ చేసి ప్రయత్నించండి.';

  @override
  String get searchForHelp => 'సహాయం వెతకండి';

  @override
  String get howWasRide => 'మీ రైడ్ ఎలా ఉంది?';

  @override
  String get done => 'పూర్తి';

  @override
  String get couldNotSaveRating => 'రేటింగ్ సేవ్ కాలేదు.';

  @override
  String get messageDriverHint => 'డ్రైవర్‌కు మెసేజ్ చేయండి';

  @override
  String get noRidesYet => 'ఇంకా రైడ్‌లు లేవు';

  @override
  String get ridesShowHere => 'మీ రైడ్‌లు ఇక్కడ కనిపిస్తాయి.';

  @override
  String get setPickupFirst => 'ముందు హోమ్‌లో పికప్ పెట్టండి.';

  @override
  String get rideHereAgain => 'మళ్లీ ఇక్కడికి';

  @override
  String get mapUnavailable => 'మ్యాప్ లేదు';

  @override
  String get checkConnection => 'కనెక్షన్ చూడండి';

  @override
  String get retry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get faresUnavailable => 'ఛార్జీలు లోడ్ కాలేదు';

  @override
  String get checkConnectionRetry => 'కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి';

  @override
  String get cancelGoBack => 'రద్దు చేసి వెనక్కి వెళ్లాలా?';

  @override
  String get passwordHint => 'పాస్‌వర్డ్';

  @override
  String get forgotPassword => 'పాస్‌వర్డ్ మర్చిపోయారా?';

  @override
  String get enterEmail => 'మీ ఈమెయిల్ ఇవ్వండి';

  @override
  String get enterPassword => 'పాస్‌వర్డ్ ఇవ్వండి';

  @override
  String get validPhone => 'సరైన ఫోన్ నంబర్ ఇవ్వండి';

  @override
  String get otpSent => 'కోడ్ పంపాం. మెసేజ్‌లు చూడండి.';

  @override
  String get tryAgain => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get searchingForDriver => 'డ్రైవర్ కోసం వెతుకుతున్నాం';

  @override
  String get confirmPickup => 'పికప్ నిర్ధారించండి';

  @override
  String get shareOnlyInCar => 'కారులో మాత్రమే చెప్పండి';

  @override
  String get youHaveArrived => 'మీరు చేరుకున్నారు';

  @override
  String get filterAll => 'అన్నీ';

  @override
  String get filterPayments => 'చెల్లింపులు';

  @override
  String get tripDetailsCopied =>
      'ట్రిప్ వివరాలు కాపీ అయ్యాయి. పేస్ట్ చేసి పంపండి';

  @override
  String get holdToSendAlert => 'అలర్ట్ కోసం నొక్కి పట్టండి';

  @override
  String get ratingCommentHint => 'ఇంకేమైనా చెప్పాలా? (ఐచ్ఛికం)';

  @override
  String get submitRating => 'రేటింగ్ పంపండి';

  @override
  String get remove => 'తీసివేయండి';

  @override
  String get promoCodeHint => 'ప్రోమో కోడ్';

  @override
  String get youPay => 'మీరు చెల్లించేది';

  @override
  String get cancel => 'రద్దు';

  @override
  String get enterEmailFirst => 'ముందు ఈమెయిల్ ఇచ్చి మళ్లీ నొక్కండి';

  @override
  String get update => 'అప్‌డేట్';

  @override
  String get navHome => 'హోమ్';

  @override
  String get navHistory => 'చరిత్ర';

  @override
  String get helpRideIssues => 'రైడ్ సమస్యలు';

  @override
  String get helpPaymentWallet => 'చెల్లింపు, వాలెట్';

  @override
  String get helpAccountApp => 'ఖాతా, యాప్';

  @override
  String get reportProblem => 'సమస్య చెప్పండి';

  @override
  String get supportRepliesInApp => 'సపోర్ట్ యాప్‌లోనే జవాబిస్తుంది';

  @override
  String get emailSupport => 'ఈమెయిల్ సపోర్ట్';

  @override
  String get searchIssues => 'సమస్యలు వెతకండి...';

  @override
  String get twoFactor => 'రెండు దశల ధృవీకరణ';

  @override
  String get changePassword => 'పాస్‌వర్డ్ మార్చండి';

  @override
  String get locationPermissions => 'లొకేషన్ అనుమతులు';

  @override
  String get notificationPreferences => 'నోటిఫికేషన్ ఎంపికలు';

  @override
  String get manageMyData => 'నా డేటా';

  @override
  String get alwaysOnRides => 'ఎప్పుడూ ఆన్. రైడ్‌లకు, భద్రతకు అవసరం.';

  @override
  String get offUnlessOn => 'మీరు ఆన్ చేస్తేనే.';

  @override
  String get rideUpdatesWhatsapp => 'WhatsAppలో రైడ్ అప్‌డేట్లు';

  @override
  String get offersWhatsapp => 'WhatsAppలో ఆఫర్లు';

  @override
  String get copiedPasteChat => 'కాపీ అయింది. ఏ చాట్‌లోనైనా పేస్ట్ చేయండి.';

  @override
  String get referralCopied => 'రెఫరల్ కోడ్ కాపీ అయింది';

  @override
  String get copy => 'కాపీ';

  @override
  String get share => 'పంచుకోండి';

  @override
  String get camera => 'కెమెరా';

  @override
  String get gallery => 'గ్యాలరీ';

  @override
  String get emergencyPhoneHint => 'అత్యవసర ఫోన్ నంబర్';

  @override
  String get problemType => 'సమస్య రకం';

  @override
  String get describeProblem => 'సమస్య వివరించండి';

  @override
  String get submit => 'పంపండి';

  @override
  String get saaradhiWallet => 'SaaradhiGo వాలెట్';

  @override
  String get addPaymentMethod => 'కొత్త చెల్లింపు పద్ధతి';

  @override
  String get searchADestination => 'గమ్యస్థానాన్ని వెతకండి';

  @override
  String get accountYourTrips => 'మీ ట్రిప్‌లు';

  @override
  String get accountTripsHint => 'రసీదులు లాక్ చేసిన ఛార్జీతో సరిపోలుతాయి';

  @override
  String get accountSavedPlaces => 'సేవ్ చేసిన స్థలాలు';

  @override
  String get accountNoSavedPlaces => 'ఇంకా సేవ్ చేసిన స్థలాలు లేవు';

  @override
  String get accountPayment => 'చెల్లింపు';

  @override
  String get accountTheme => 'థీమ్';

  @override
  String get accountHelp => 'సహాయం';

  @override
  String get accountSignOut => 'సైన్ అవుట్';

  @override
  String get accountDelete => 'ఖాతాను తొలగించండి';

  @override
  String get deleteAccountTitle => 'మీ ఖాతాను తొలగించాలా?';

  @override
  String get deleteAccountBody =>
      'మీ ఖాతా మరియు వ్యక్తిగత వివరాలు తొలగించబడతాయి. దీన్ని రద్దు చేయలేరు.';

  @override
  String get deleteAccountConfirm => 'తొలగించు';

  @override
  String get deleteAccountFailed =>
      'మీ ఖాతాను తొలగించలేకపోయాం. మళ్లీ ప్రయత్నించండి.';

  @override
  String get menu => 'మెను';

  @override
  String get chooseARide => 'రైడ్‌ను ఎంచుకోండి';

  @override
  String fareHeldMin(int n) {
    return 'ఛార్జీ $n నిమి. పాటు నిలిపి ఉంది';
  }

  @override
  String arrivingInMin(int n) {
    return '$n నిమిషాల్లో వస్తున్నారు';
  }

  @override
  String get statusOnTheWay => 'దారిలో ఉన్నారు';

  @override
  String get statusArrived => 'చేరుకున్నారు';

  @override
  String get yourRideCode => 'మీ రైడ్ కోడ్';

  @override
  String get tellDriverInPerson => 'డ్రైవర్‌కు నేరుగా చెప్పండి';

  @override
  String get showCode => 'చూపించు';

  @override
  String get hideCode => 'దాచు';

  @override
  String get savedWork => 'ఆఫీస్';

  @override
  String get loadErrWallet => 'మీ వాలెట్‌ను లోడ్ చేయలేకపోయాము.';

  @override
  String get loadErrTrips => 'మీ ట్రిప్‌లను లోడ్ చేయలేకపోయాము.';

  @override
  String get loadErrPlaces => 'మీ ప్రదేశాలను లోడ్ చేయలేకపోయాము.';

  @override
  String get authSessionExpired =>
      'మీ సెషన్ ముగిసింది. దయచేసి మళ్లీ లాగిన్ అవ్వండి.';

  @override
  String get placeSetHome => 'ఇంటిని సెట్ చేయండి';

  @override
  String get placeSetWork => 'ఆఫీస్‌ను సెట్ చేయండి';

  @override
  String get placeAdd => 'స్థలాన్ని జోడించండి';

  @override
  String get placeEdit => 'స్థలాన్ని మార్చండి';

  @override
  String get placeSaveThis => 'ఈ స్థలాన్ని సేవ్ చేయండి';

  @override
  String get placeSave => 'సేవ్ చేయండి';

  @override
  String get placeSearchHint => 'చిరునామా కోసం వెతకండి';

  @override
  String get placeDragHint => 'పిన్‌ను సరైన చోట ఉంచడానికి మ్యాప్‌ను జరపండి';

  @override
  String get placeLabel => 'ఇలా సేవ్ చేయండి';

  @override
  String get placeOther => 'ఇతర';

  @override
  String get placeNameHint => 'పేరు, ఉదా. జిమ్';

  @override
  String get placeNameRequired => 'ఈ స్థలానికి ఒక పేరు ఇవ్వండి';

  @override
  String get placeDeleteTitle => 'ఈ స్థలాన్ని తొలగించాలా?';

  @override
  String placeDeleteBody(String name) {
    return '$name మీ సేవ్ చేసిన స్థలాల నుండి తీసివేయబడుతుంది.';
  }

  @override
  String get placeDelete => 'తొలగించు';

  @override
  String get placeSaveFailed =>
      'ఈ స్థలాన్ని సేవ్ చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get placeDeleteFailed =>
      'ఈ స్థలాన్ని తొలగించలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get placeLimitHome =>
      'మీకు ఇప్పటికే ఇల్లు సేవ్ చేయబడింది. దాన్ని మార్చండి.';

  @override
  String get placeLimitWork =>
      'మీకు ఇప్పటికే ఆఫీస్ సేవ్ చేయబడింది. దాన్ని మార్చండి.';

  @override
  String placeLimitOther(int count) {
    return 'మీరు గరిష్టంగా $count ఇతర స్థలాలను సేవ్ చేయవచ్చు.';
  }

  @override
  String get placeOutsideArea => 'ప్రస్తుతానికి మా సేవా ప్రాంతం వెలుపల ఉంది';

  @override
  String get placeNoResults => 'స్థలాలు ఏవీ కనబడలేదు';

  @override
  String get trustedContacts => 'నమ్మకమైన కాంటాక్ట్‌లు';

  @override
  String trustedContactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count నమ్మకమైన కాంటాక్ట్‌లు',
      one: '1 నమ్మకమైన కాంటాక్ట్',
    );
    return '$_temp0';
  }

  @override
  String get trustedContactsNone => 'ఇంకా నమ్మకమైన కాంటాక్ట్‌లు లేవు';

  @override
  String get autoShareTrips => 'ప్రతి ట్రిప్‌ను ఆటోమేటిక్‌గా షేర్ చేయండి';

  @override
  String get autoShareFailed =>
      'ఈ సెట్టింగ్‌ను మార్చలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get contactAdd => 'కాంటాక్ట్‌ను జోడించండి';

  @override
  String get contactName => 'పేరు';

  @override
  String get contactPick => 'కాంటాక్ట్‌ల నుండి ఎంచుకోండి';

  @override
  String contactRemoveTitle(String name) {
    return '$nameను తీసివేయాలా?';
  }

  @override
  String get contactRemoveBody => 'వారికి ఇకపై మీ ట్రిప్ లింక్‌లు రావు.';

  @override
  String get contactOptedOut => 'సందేశాలు ఆపివేశారు';

  @override
  String get contactsLoadErr => 'మీ నమ్మకమైన కాంటాక్ట్‌లను లోడ్ చేయలేకపోయాము.';

  @override
  String get contactSaveFailed =>
      'ఈ కాంటాక్ట్‌ను జోడించలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get contactRemoveFailed =>
      'ఈ కాంటాక్ట్‌ను తీసివేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get shareTrip => 'ట్రిప్‌ను షేర్ చేయండి';

  @override
  String shareTripText(String url) {
    return 'నా SaaradhiGo ట్రిప్‌ను ఇక్కడ చూడండి: $url';
  }

  @override
  String get shareLinkAgain => 'లింక్‌ను మళ్లీ షేర్ చేయండి';

  @override
  String get stopSharing => 'షేర్ చేయడం ఆపండి';

  @override
  String get sharingStopped => 'షేర్ చేయడం ఆపబడింది';

  @override
  String get shareFailed =>
      'ఈ ట్రిప్‌ను షేర్ చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get linkCopied => 'లింక్ కాపీ చేయబడింది';
}
