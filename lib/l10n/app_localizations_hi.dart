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
  String askedDriversNearby(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'पास के $n ड्राइवरों से पूछा',
      one: 'पास के 1 ड्राइवर से पूछा',
    );
    return '$_temp0';
  }
}
