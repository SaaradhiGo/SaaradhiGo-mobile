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

  @override
  String waysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ways to get there',
      one: '1 way to get there',
    );
    return '$_temp0';
  }

  @override
  String get tagCheapest => 'Cheapest';

  @override
  String get tagFastest => 'Fastest';

  @override
  String bookClass(String name, String fare) {
    return 'Book $name · $fare';
  }

  @override
  String get selectRide => 'Select a ride';

  @override
  String get change => 'Change';

  @override
  String get payCash => 'Cash';

  @override
  String get payWallet => 'Wallet';

  @override
  String get payOnline => 'UPI / card';

  @override
  String get fareTicket => 'Your fare ticket';

  @override
  String get fareLocked => 'Locked when you book. It will not go up.';

  @override
  String get pickupLabel => 'Pickup';

  @override
  String get dropLabel => 'Drop';

  @override
  String get edit => 'Edit';

  @override
  String get dragToMove => 'Drag the map to move your pickup';

  @override
  String seeHowWorkedOut(String fare) {
    return 'See how $fare is worked out';
  }

  @override
  String get confirmAndBook => 'Confirm pickup and book';

  @override
  String findingClass(String name) {
    return 'Finding a $name driver';
  }

  @override
  String fareLockedAt(String fare) {
    return 'Fare locked at $fare';
  }

  @override
  String get waitingAccept => 'Waiting for one to accept';

  @override
  String get closeAppNote => 'You can close the app; we will notify you.';

  @override
  String get freeToCancel => 'Free to cancel';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String minutesShort(int n) {
    return '$n min';
  }

  @override
  String driverOnWay(String name) {
    return '$name is on the way';
  }

  @override
  String driverArrived(String name) {
    return '$name has arrived';
  }

  @override
  String get yourDriver => 'Your driver';

  @override
  String get ridePin => 'Ride PIN';

  @override
  String get ridePinHint => 'Tell it to your driver in the car';

  @override
  String get call => 'Call';

  @override
  String get message => 'Message';

  @override
  String get safety => 'Safety';

  @override
  String get cancelRide => 'Cancel ride';

  @override
  String arrivingAbout(String time) {
    return 'Arriving about $time';
  }

  @override
  String get arrivingSoon => 'Arriving soon';

  @override
  String minutesLeft(int n) {
    return '$n min left';
  }

  @override
  String onTheWayTo(String place) {
    return 'On the way to $place';
  }

  @override
  String get locked => 'Locked';

  @override
  String get viewSummary => 'View summary';

  @override
  String get ticketSaid => 'Your ticket said';

  @override
  String get tripCost => 'Trip cost';

  @override
  String get exactlyQuoted => 'Exactly what you were quoted';

  @override
  String get promotion => 'Promotion';

  @override
  String differenceUnexplained(String amount) {
    return 'Difference $amount: the reason is not available yet';
  }

  @override
  String get howItAddsUp => 'How it adds up';

  @override
  String payBy(String amount, String method) {
    return 'Pay $amount by $method';
  }

  @override
  String payingCash(String amount, String name) {
    return 'Paying cash? Give $amount to $name';
  }

  @override
  String rateDriver(String name) {
    return 'Rate $name';
  }

  @override
  String get inDanger => 'In danger?';

  @override
  String get holdForSos =>
      'Hold 2 seconds for SOS. Our team is alerted at once.';

  @override
  String callEmergency(String number) {
    return 'Call $number';
  }

  @override
  String get reportSomething => 'Report something';

  @override
  String get callSupport => 'Call SaaradhiGo support';

  @override
  String noClassFree(String name) {
    return 'No $name free near you';
  }

  @override
  String get notCharged => 'You have not been charged';

  @override
  String get keepLooking => 'Keep looking';

  @override
  String get tryAnotherRide => 'Or try another ride';

  @override
  String get changeRide => 'Change ride';

  @override
  String get paymentFailed => 'Payment did not go through';

  @override
  String get moneyComesBack =>
      'If money left your account, it will come back to you.';

  @override
  String refundWithin(int days) {
    return 'It comes back within $days working days.';
  }

  @override
  String get stillToPay => 'Still to pay';

  @override
  String get tryAnotherWay => 'Try again or pay another way';

  @override
  String get talkSupportPayment => 'Talk to support about this payment';

  @override
  String get goHome => 'Go home';

  @override
  String get noDriversNearby => 'No drivers nearby';

  @override
  String seatsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n seats',
      one: '1 seat',
    );
    return '$_temp0';
  }

  @override
  String fareUpdatedTimePassed(String fare) {
    return 'Fare updated to $fare because time passed';
  }

  @override
  String fareUpdatedPickupChanged(String fare) {
    return 'Fare updated to $fare because the pickup changed';
  }

  @override
  String get fareUpdating => 'Updating your fare';

  @override
  String askedDriversNearby(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Asked $n drivers nearby',
      one: 'Asked 1 driver nearby',
    );
    return '$_temp0';
  }
}
