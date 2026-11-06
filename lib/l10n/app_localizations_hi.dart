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

  @override
  String waysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'वहाँ जाने के $count तरीके',
      one: 'वहाँ जाने का 1 तरीका',
    );
    return '$_temp0';
  }

  @override
  String get tagCheapest => 'सबसे सस्ता';

  @override
  String get tagFastest => 'सबसे तेज़';

  @override
  String bookClass(String name, String fare) {
    return '$name बुक करें · $fare';
  }

  @override
  String get selectRide => 'राइड चुनें';

  @override
  String get change => 'बदलें';

  @override
  String get payCash => 'नकद';

  @override
  String get payWallet => 'वॉलेट';

  @override
  String get payOnline => 'UPI / कार्ड';

  @override
  String get fareTicket => 'आपका किराया टिकट';

  @override
  String get fareLocked => 'बुक करते ही तय। यह नहीं बढ़ेगा।';

  @override
  String get pickupLabel => 'पिकअप';

  @override
  String get dropLabel => 'ड्रॉप';

  @override
  String get edit => 'बदलें';

  @override
  String get dragToMove => 'पिकअप बदलने के लिए नक्शा खिसकाएँ';

  @override
  String seeHowWorkedOut(String fare) {
    return 'देखें $fare कैसे बना';
  }

  @override
  String get confirmAndBook => 'पिकअप पक्का करें और बुक करें';

  @override
  String findingClass(String name) {
    return '$name ड्राइवर ढूँढ रहे हैं';
  }

  @override
  String fareLockedAt(String fare) {
    return 'किराया $fare पर तय';
  }

  @override
  String get waitingAccept => 'किसी के स्वीकार करने का इंतज़ार';

  @override
  String get closeAppNote => 'आप ऐप बंद कर सकते हैं; हम आपको सूचित करेंगे।';

  @override
  String get freeToCancel => 'रद्द करना मुफ़्त है';

  @override
  String get cancelRequest => 'अनुरोध रद्द करें';

  @override
  String minutesShort(int n) {
    return '$n मिनट';
  }

  @override
  String driverOnWay(String name) {
    return '$name आ रहे हैं';
  }

  @override
  String driverArrived(String name) {
    return '$name पहुँच गए हैं';
  }

  @override
  String get yourDriver => 'आपके ड्राइवर';

  @override
  String get ridePin => 'राइड PIN';

  @override
  String get ridePinHint => 'कार में ड्राइवर को बताएँ';

  @override
  String get call => 'कॉल';

  @override
  String get message => 'संदेश';

  @override
  String get safety => 'सुरक्षा';

  @override
  String get cancelRide => 'राइड रद्द करें';

  @override
  String arrivingAbout(String time) {
    return 'लगभग $time पहुँचेंगे';
  }

  @override
  String get arrivingSoon => 'जल्द पहुँचेंगे';

  @override
  String minutesLeft(int n) {
    return '$n मिनट बाकी';
  }

  @override
  String onTheWayTo(String place) {
    return '$place की ओर';
  }

  @override
  String get locked => 'तय';

  @override
  String get viewSummary => 'सारांश देखें';

  @override
  String get ticketSaid => 'आपके टिकट में';

  @override
  String get tripCost => 'ट्रिप का खर्च';

  @override
  String get exactlyQuoted => 'ठीक उतना ही जितना बताया था';

  @override
  String get promotion => 'प्रमोशन';

  @override
  String differenceUnexplained(String amount) {
    return 'अंतर $amount: कारण अभी उपलब्ध नहीं';
  }

  @override
  String get howItAddsUp => 'कैसे जुड़ा';

  @override
  String payBy(String amount, String method) {
    return '$method से $amount चुकाएँ';
  }

  @override
  String payingCash(String amount, String name) {
    return 'नकद? $name को $amount दें';
  }

  @override
  String rateDriver(String name) {
    return '$name को रेट करें';
  }

  @override
  String get inDanger => 'ख़तरे में हैं?';

  @override
  String get holdForSos =>
      'SOS के लिए 2 सेकंड दबाए रखें। हमारी टीम को तुरंत पता चलेगा।';

  @override
  String callEmergency(String number) {
    return '$number पर कॉल करें';
  }

  @override
  String get reportSomething => 'कुछ रिपोर्ट करें';

  @override
  String get callSupport => 'SaaradhiGo सपोर्ट को कॉल करें';

  @override
  String noClassFree(String name) {
    return 'आपके पास कोई $name खाली नहीं';
  }

  @override
  String get notCharged => 'आपसे कोई पैसा नहीं लिया गया';

  @override
  String get keepLooking => 'ढूँढते रहें';

  @override
  String get tryAnotherRide => 'या कोई और राइड आज़माएँ';

  @override
  String get changeRide => 'राइड बदलें';

  @override
  String get paymentFailed => 'भुगतान नहीं हुआ';

  @override
  String get moneyComesBack =>
      'अगर आपके खाते से पैसे कटे हैं, तो वे वापस आएँगे।';

  @override
  String refundWithin(int days) {
    return 'यह $days कामकाजी दिनों में वापस आएगा।';
  }

  @override
  String get stillToPay => 'अभी चुकाना है';

  @override
  String get tryAnotherWay => 'फिर कोशिश करें या दूसरे तरीके से चुकाएँ';

  @override
  String get talkSupportPayment => 'इस भुगतान के बारे में सपोर्ट से बात करें';

  @override
  String get goHome => 'होम पर जाएँ';

  @override
  String get noDriversNearby => 'पास में कोई ड्राइवर नहीं';

  @override
  String seatsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n सीटें',
      one: '1 सीट',
    );
    return '$_temp0';
  }

  @override
  String fareUpdatedTimePassed(String fare) {
    return 'समय बीत जाने से किराया $fare हो गया';
  }

  @override
  String fareUpdatedPickupChanged(String fare) {
    return 'पिकअप बदलने से किराया $fare हो गया';
  }

  @override
  String get fareUpdating => 'किराया अपडेट हो रहा है';

  @override
  String get yourRides => 'आपकी राइड';

  @override
  String get paymentMethods => 'भुगतान के तरीके';

  @override
  String get notifications => 'सूचनाएँ';

  @override
  String get referFriend => 'दोस्त को बुलाएँ';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get helpSupport => 'मदद और सहायता';

  @override
  String get personalInfo => 'निजी जानकारी';

  @override
  String get privacySecurity => 'गोपनीयता और सुरक्षा';

  @override
  String get logOut => 'लॉग आउट';

  @override
  String get currentLocation => 'मौजूदा जगह';

  @override
  String get useMyLocation => 'मेरी जगह इस्तेमाल करें';

  @override
  String get selectPickupFirst => 'पहले पिकअप चुनें';

  @override
  String get locationServicesOff => 'लोकेशन बंद है। सेटिंग्स में चालू करें।';

  @override
  String get locationDenied => 'लोकेशन की अनुमति नहीं है।';

  @override
  String get locationDeniedForever =>
      'लोकेशन की अनुमति हमेशा के लिए बंद है। सेटिंग्स में दें।';

  @override
  String get locationNotFound => 'आपकी जगह नहीं मिली। पिकअप डालें।';

  @override
  String get resumingRide => 'आपकी राइड फिर खोल रहे हैं...';

  @override
  String get activeRideTitle => 'चालू राइड';

  @override
  String get activeRideBody => 'आपकी एक राइड पहले से चालू है। देखें?';

  @override
  String get dismiss => 'बंद करें';

  @override
  String get whereTo => 'कहाँ जाना है?';

  @override
  String get placesAppearHere => 'आपकी जगहें यहाँ दिखेंगी।';

  @override
  String get back => 'वापस';

  @override
  String get findingSaaradhi => 'आपका सारथी ढूँढ रहे हैं';

  @override
  String get noSaaradhiNearby => 'अभी पास में कोई सारथी नहीं';

  @override
  String get cancelSearchTitle => 'खोज रद्द करें?';

  @override
  String get cancelSearchBody => 'राइड अनुरोध रद्द करें?';

  @override
  String get wait => 'रुकें';

  @override
  String get cancelAnyway => 'फिर भी रद्द करें';

  @override
  String get ongoingRideTitle => 'चालू राइड';

  @override
  String get cancelActiveRequestBody => 'आपका राइड अनुरोध चालू है। रद्द करें?';

  @override
  String get cancelOngoingRideBody => 'चालू राइड रद्द करें?';

  @override
  String get continueRide => 'राइड जारी रखें';

  @override
  String get driverPhoneUnavailable => 'ड्राइवर का फ़ोन नहीं है। चैट करें।';

  @override
  String get dialerUnavailable => 'इस फ़ोन पर डायलर नहीं खुला।';

  @override
  String get callFailed => 'कॉल नहीं हो सकी।';

  @override
  String get payWithCashTitle => 'नकद से भुगतान';

  @override
  String get handToDriver => 'ड्राइवर को दें';

  @override
  String get payFromWallet => 'वॉलेट से भुगतान';

  @override
  String get notEnoughBalance => 'बैलेंस कम है';

  @override
  String get payViaUpiCard => 'UPI/कार्ड से भुगतान';

  @override
  String get payCashInstead => 'इसके बजाय नकद दें?';

  @override
  String get thanksForRating => 'रेटिंग के लिए धन्यवाद।';

  @override
  String get insufficientBalance => 'बैलेंस कम है';

  @override
  String get wouldYouLike => 'आप क्या करना चाहेंगे:';

  @override
  String get addMoney => 'पैसे जोड़ें';

  @override
  String get payUpiCard => 'UPI/कार्ड से भुगतान';

  @override
  String get cashReceived => 'नकद मिल गया। धन्यवाद।';

  @override
  String get signInToPay => 'भुगतान के लिए फिर से साइन इन करें।';

  @override
  String get noActiveTrip =>
      'कोई चालू ट्रिप नहीं। रिफ्रेश करके फिर कोशिश करें।';

  @override
  String get searchForHelp => 'मदद खोजें';

  @override
  String get howWasRide => 'आपकी राइड कैसी रही?';

  @override
  String get done => 'हो गया';

  @override
  String get couldNotSaveRating => 'रेटिंग सेव नहीं हुई।';

  @override
  String get messageDriverHint => 'ड्राइवर को संदेश भेजें';

  @override
  String get noRidesYet => 'अभी कोई राइड नहीं';

  @override
  String get ridesShowHere => 'आपकी राइड यहाँ दिखेंगी।';

  @override
  String get setPickupFirst => 'पहले होम पर पिकअप चुनें।';

  @override
  String get rideHereAgain => 'फिर यहाँ जाएँ';

  @override
  String get mapUnavailable => 'नक्शा उपलब्ध नहीं';

  @override
  String get checkConnection => 'कनेक्शन जाँचें';

  @override
  String get retry => 'फिर कोशिश करें';

  @override
  String get faresUnavailable => 'किराया लोड नहीं हुआ';

  @override
  String get checkConnectionRetry => 'कनेक्शन जाँचकर फिर कोशिश करें';

  @override
  String get cancelGoBack => 'रद्द करके वापस जाएँ?';

  @override
  String get passwordHint => 'पासवर्ड';

  @override
  String get forgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get enterEmail => 'अपना ईमेल डालें';

  @override
  String get enterPassword => 'पासवर्ड डालें';

  @override
  String get validPhone => 'सही फ़ोन नंबर डालें';

  @override
  String get otpSent => 'कोड भेजा गया। संदेश देखें।';

  @override
  String get tryAgain => 'फिर कोशिश करें';

  @override
  String get searchingForDriver => 'ड्राइवर ढूँढ रहे हैं';

  @override
  String get confirmPickup => 'पिकअप पक्का करें';

  @override
  String get shareOnlyInCar => 'सिर्फ़ कार में बताएँ';

  @override
  String get youHaveArrived => 'आप पहुँच गए';

  @override
  String get filterAll => 'सभी';

  @override
  String get filterPayments => 'भुगतान';

  @override
  String get tripDetailsCopied => 'ट्रिप की जानकारी कॉपी हुई। पेस्ट करके भेजें';

  @override
  String get holdToSendAlert => 'अलर्ट के लिए दबाए रखें';

  @override
  String get ratingCommentHint => 'कुछ और बताना है? (वैकल्पिक)';

  @override
  String get submitRating => 'रेटिंग भेजें';

  @override
  String get remove => 'हटाएँ';

  @override
  String get promoCodeHint => 'प्रोमो कोड';

  @override
  String get youPay => 'आप देंगे';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get enterEmailFirst => 'पहले ईमेल डालें, फिर दबाएँ';

  @override
  String get update => 'अपडेट करें';

  @override
  String get navHome => 'होम';

  @override
  String get navHistory => 'इतिहास';

  @override
  String get helpRideIssues => 'राइड की समस्याएँ';

  @override
  String get helpPaymentWallet => 'भुगतान और वॉलेट';

  @override
  String get helpAccountApp => 'खाता और ऐप';

  @override
  String get reportProblem => 'समस्या बताएँ';

  @override
  String get supportRepliesInApp => 'सपोर्ट ऐप में जवाब देगा';

  @override
  String get emailSupport => 'ईमेल सपोर्ट';

  @override
  String get searchIssues => 'समस्याएँ खोजें...';

  @override
  String get twoFactor => 'दो-चरण सत्यापन';

  @override
  String get changePassword => 'पासवर्ड बदलें';

  @override
  String get locationPermissions => 'लोकेशन अनुमतियाँ';

  @override
  String get notificationPreferences => 'सूचना सेटिंग';

  @override
  String get manageMyData => 'मेरा डेटा';

  @override
  String get alwaysOnRides => 'हमेशा चालू। राइड और सुरक्षा के लिए ज़रूरी।';

  @override
  String get offUnlessOn => 'आप चालू करें तभी।';

  @override
  String get rideUpdatesWhatsapp => 'WhatsApp पर राइड अपडेट';

  @override
  String get offersWhatsapp => 'WhatsApp पर ऑफ़र';

  @override
  String get copiedPasteChat => 'कॉपी हुआ। किसी भी चैट में पेस्ट करें।';

  @override
  String get referralCopied => 'रेफ़रल कोड कॉपी हुआ';

  @override
  String get copy => 'कॉपी';

  @override
  String get share => 'शेयर करें';

  @override
  String get camera => 'कैमरा';

  @override
  String get gallery => 'गैलरी';

  @override
  String get emergencyPhoneHint => 'आपातकालीन फ़ोन नंबर';

  @override
  String get problemType => 'समस्या का प्रकार';

  @override
  String get describeProblem => 'समस्या बताएँ';

  @override
  String get submit => 'भेजें';

  @override
  String get saaradhiWallet => 'SaaradhiGo वॉलेट';

  @override
  String get addPaymentMethod => 'नया भुगतान तरीका जोड़ें';
}
