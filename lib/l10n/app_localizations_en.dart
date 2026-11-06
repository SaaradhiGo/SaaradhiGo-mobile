// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get themeSwitchToDark => 'Switch to dark theme';

  @override
  String get themeSwitchToLight => 'Switch to light theme';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeDark => 'Dark (black and gold)';

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

  @override
  String get yourRides => 'Your rides';

  @override
  String get paymentMethods => 'Payment methods';

  @override
  String get notifications => 'Notifications';

  @override
  String get referFriend => 'Refer a friend';

  @override
  String get profile => 'Profile';

  @override
  String get helpSupport => 'Help and support';

  @override
  String get personalInfo => 'Personal information';

  @override
  String get privacySecurity => 'Privacy and security';

  @override
  String get logOut => 'Log out';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get selectPickupFirst => 'Please select pickup location first';

  @override
  String get locationServicesOff =>
      'Location services are disabled. Please enable them in settings.';

  @override
  String get locationDenied => 'Location permissions are denied.';

  @override
  String get locationDeniedForever =>
      'Location permissions are permanently denied, we cannot request permissions.';

  @override
  String get locationNotFound =>
      'We couldn\'t find your location. Enter your pickup point.';

  @override
  String get resumingRide => 'Resuming your active ride...';

  @override
  String get activeRideTitle => 'Active Ride';

  @override
  String get activeRideBody =>
      'You already have an active ride request or trip. Would you like to view it?';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get whereTo => 'Where to?';

  @override
  String get placesAppearHere => 'Places you ride to will appear here.';

  @override
  String get back => 'Back';

  @override
  String get findingSaaradhi => 'Finding your Saaradhi';

  @override
  String get noSaaradhiNearby => 'No Saaradhi nearby right now';

  @override
  String get cancelSearchTitle => 'Cancel Search?';

  @override
  String get cancelSearchBody =>
      'Are you sure you want to cancel your ride request?';

  @override
  String get wait => 'Wait';

  @override
  String get cancelAnyway => 'Cancel Anyway';

  @override
  String get ongoingRideTitle => 'Ongoing Ride';

  @override
  String get cancelActiveRequestBody =>
      'You have an active ride request. Are you sure you want to cancel?';

  @override
  String get cancelOngoingRideBody =>
      'Are you sure you want to cancel your ongoing ride?';

  @override
  String get continueRide => 'Continue Ride';

  @override
  String get driverPhoneUnavailable =>
      'Driver phone unavailable. Use in-app chat instead.';

  @override
  String get dialerUnavailable => 'Could not open dialer on this device.';

  @override
  String get callFailed => 'Could not start a call.';

  @override
  String get payWithCashTitle => 'Pay with Cash';

  @override
  String get handToDriver => 'Hand it to your driver';

  @override
  String get payFromWallet => 'Pay from Wallet';

  @override
  String get notEnoughBalance => 'Not enough balance';

  @override
  String get payViaUpiCard => 'Pay via UPI/Card';

  @override
  String get payCashInstead => 'Pay with Cash instead?';

  @override
  String get thanksForRating => 'Thanks for rating your trip.';

  @override
  String get insufficientBalance => 'Insufficient Balance';

  @override
  String get wouldYouLike => 'Would you like to:';

  @override
  String get addMoney => 'Add Money';

  @override
  String get payUpiCard => 'Pay with UPI/Card';

  @override
  String get cashReceived => 'Cash payment received. Thank you.';

  @override
  String get signInToPay => 'Please sign in again to pay for this trip.';

  @override
  String get noActiveTrip =>
      'No active trip found. Please refresh and try again.';

  @override
  String get searchForHelp => 'Search for help';

  @override
  String get howWasRide => 'How was your ride?';

  @override
  String get done => 'Done';

  @override
  String get couldNotSaveRating => 'Could not save your rating.';

  @override
  String get messageDriverHint => 'Message your driver';

  @override
  String get noRidesYet => 'No rides yet';

  @override
  String get ridesShowHere => 'Rides you take will show here.';

  @override
  String get setPickupFirst => 'Set your pickup on the home screen first.';

  @override
  String get rideHereAgain => 'Ride here again';

  @override
  String get mapUnavailable => 'Map unavailable';

  @override
  String get checkConnection => 'Please check your connection';

  @override
  String get retry => 'Retry';

  @override
  String get faresUnavailable => 'Unable to load fare estimates';

  @override
  String get checkConnectionRetry =>
      'Please check your connection and try again';

  @override
  String get cancelGoBack => 'Are you sure you want to cancel and go back?';

  @override
  String get passwordHint => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get enterEmail => 'Enter your email address';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get validPhone => 'Please enter a valid phone number';

  @override
  String get otpSent => 'OTP sent. Check your messages.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get searchingForDriver => 'Searching for a driver';

  @override
  String get confirmPickup => 'Confirm pickup';

  @override
  String get shareOnlyInCar => 'Share only in the car';

  @override
  String get youHaveArrived => 'You have arrived';

  @override
  String get filterAll => 'All';

  @override
  String get filterPayments => 'Payments';

  @override
  String get tripDetailsCopied => 'Trip details copied — paste to share';

  @override
  String get holdToSendAlert => 'Hold to send alert';

  @override
  String get ratingCommentHint => 'Anything you want us to know? (optional)';

  @override
  String get submitRating => 'Submit rating';

  @override
  String get remove => 'Remove';

  @override
  String get promoCodeHint => 'Promo code';

  @override
  String get youPay => 'You pay';

  @override
  String get cancel => 'Cancel';

  @override
  String get enterEmailFirst =>
      'Enter your email address first, then tap again';

  @override
  String get update => 'Update';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get helpRideIssues => 'Ride Issues';

  @override
  String get helpPaymentWallet => 'Payment & Wallet';

  @override
  String get helpAccountApp => 'Account & App';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get supportRepliesInApp => 'Support replies in the app';

  @override
  String get emailSupport => 'Email Support';

  @override
  String get searchIssues => 'Search for issues...';

  @override
  String get twoFactor => 'Two-Factor Authentication';

  @override
  String get changePassword => 'Change Password';

  @override
  String get locationPermissions => 'Location Permissions';

  @override
  String get notificationPreferences => 'Notification Preferences';

  @override
  String get manageMyData => 'Manage My Data';

  @override
  String get alwaysOnRides =>
      'Always on. Needed for your rides and your safety.';

  @override
  String get offUnlessOn => 'Off unless you turn it on.';

  @override
  String get rideUpdatesWhatsapp => 'Ride updates on WhatsApp';

  @override
  String get offersWhatsapp => 'Offers on WhatsApp';

  @override
  String get copiedPasteChat => 'Copied. Paste it into any chat.';

  @override
  String get referralCopied => 'Referral code copied';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get emergencyPhoneHint => 'Emergency phone number';

  @override
  String get problemType => 'Type of problem';

  @override
  String get describeProblem => 'Describe the problem';

  @override
  String get submit => 'Submit';

  @override
  String get saaradhiWallet => 'SaaradhiGo Wallet';

  @override
  String get addPaymentMethod => 'Add New Payment Method';
}
