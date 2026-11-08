import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te'),
  ];

  /// Home header sun/moon button, shown in the light theme
  ///
  /// In en, this message translates to:
  /// **'Switch to dark theme'**
  String get themeSwitchToDark;

  /// Home header sun/moon button, shown in the dark theme
  ///
  /// In en, this message translates to:
  /// **'Switch to light theme'**
  String get themeSwitchToLight;

  /// Account row and sheet title: choose the colour theme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Theme option: dark.
  ///
  /// In en, this message translates to:
  /// **'Dark (black and gold)'**
  String get themeDark;

  /// Theme option: light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option: follow the device setting.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get themeAutomatic;

  /// Subtitle under the Automatic theme option.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone'**
  String get themeAutomaticHint;

  /// Account row and sheet title: choose the app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language option, shown in its own script.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Language option, shown in its own script.
  ///
  /// In en, this message translates to:
  /// **'తెలుగు'**
  String get languageTelugu;

  /// Language option, shown in its own script.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// Sign-in: heading above the three language tiles.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get langChooseTitle;

  /// Sign-in: heading above the phone field.
  ///
  /// In en, this message translates to:
  /// **'Your mobile number'**
  String get phoneTitle;

  /// Sign-in: hint in the empty phone field.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneHint;

  /// Sign-in: primary button that asks for an SMS code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// Sign-in: switch to email and password.
  ///
  /// In en, this message translates to:
  /// **'Use email instead'**
  String get useEmail;

  /// Sign-in: switch back to the phone number.
  ///
  /// In en, this message translates to:
  /// **'Use mobile number instead'**
  String get useMobile;

  /// Sign-in: small print under the button.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the Terms of Service and Privacy Policy.'**
  String get termsLine;

  /// Verify code: heading.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get verifyTitle;

  /// Verify code: where the SMS went.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}'**
  String verifySentTo(String phone);

  /// Verify code: resend countdown, e.g. 0:42.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {time}'**
  String verifyResendIn(String time);

  /// Verify code: resend button.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get verifyResend;

  /// Verify code: primary button.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// Verify code: go back and edit the phone number.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// Home headline with the rider's first name.
  ///
  /// In en, this message translates to:
  /// **'Where are you going, {name}?'**
  String homeHeadlineNamed(String name);

  /// Home headline when the name is unknown.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get homeHeadline;

  /// Home: tag on the pickup row when it is the current location.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get youAreHere;

  /// Home: hint in the empty pickup field.
  ///
  /// In en, this message translates to:
  /// **'Enter pickup point'**
  String get pickupHint;

  /// Home: hint in the destination field.
  ///
  /// In en, this message translates to:
  /// **'Search destination'**
  String get searchDestination;

  /// Home: section eyebrow above the fare cards.
  ///
  /// In en, this message translates to:
  /// **'Fares from here, right now'**
  String get faresFromHere;

  /// Home: the lock-icon promise line.
  ///
  /// In en, this message translates to:
  /// **'The fare you book is the fare you pay.'**
  String get fareLockLine;

  /// Home: fare card when quoting failed.
  ///
  /// In en, this message translates to:
  /// **'Tap to see fares'**
  String get tapToSeeFares;

  /// Bottom tab: home / book a ride.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get tabRide;

  /// Bottom tab: ride history.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tabTrips;

  /// Bottom tab: profile and settings.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// Account row: open the wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// Every fare: heading with the number of classes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 way to get there} other{{count} ways to get there}}'**
  String waysToGo(int count);

  /// Every fare: tag on the lowest fare.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get tagCheapest;

  /// Every fare: tag on the lowest pickup time.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get tagFastest;

  /// Every fare: primary button.
  ///
  /// In en, this message translates to:
  /// **'Book {name} · {fare}'**
  String bookClass(String name, String fare);

  /// Every fare: button before a class is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a ride'**
  String get selectRide;

  /// Change action (payment method).
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// Payment method: cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// Payment method: wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get payWallet;

  /// Payment method: online.
  ///
  /// In en, this message translates to:
  /// **'UPI / card'**
  String get payOnline;

  /// Fare ticket: eyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your fare ticket'**
  String get fareTicket;

  /// Fare ticket: the lock promise.
  ///
  /// In en, this message translates to:
  /// **'Locked when you book. It will not go up.'**
  String get fareLocked;

  /// Fare ticket: pickup row label.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickupLabel;

  /// Fare ticket: drop row label.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get dropLabel;

  /// Fare ticket: edit the pickup.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Fare ticket: hint after Edit.
  ///
  /// In en, this message translates to:
  /// **'Drag the map to move your pickup'**
  String get dragToMove;

  /// Fare ticket: opens the breakdown.
  ///
  /// In en, this message translates to:
  /// **'See how {fare} is worked out'**
  String seeHowWorkedOut(String fare);

  /// Fare ticket: primary button.
  ///
  /// In en, this message translates to:
  /// **'Confirm pickup and book'**
  String get confirmAndBook;

  /// Finding: heading.
  ///
  /// In en, this message translates to:
  /// **'Finding a {name} driver'**
  String findingClass(String name);

  /// Finding: checklist line.
  ///
  /// In en, this message translates to:
  /// **'Fare locked at {fare}'**
  String fareLockedAt(String fare);

  /// Finding: current checklist line.
  ///
  /// In en, this message translates to:
  /// **'Waiting for one to accept'**
  String get waitingAccept;

  /// Finding: note.
  ///
  /// In en, this message translates to:
  /// **'You can close the app; we will notify you.'**
  String get closeAppNote;

  /// Note under a cancel action when cancelling costs nothing.
  ///
  /// In en, this message translates to:
  /// **'Free to cancel'**
  String get freeToCancel;

  /// Finding: secondary button.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// A number of minutes, e.g. the pickup ETA.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String minutesShort(int n);

  /// Arriving: under the ETA, or alone without one.
  ///
  /// In en, this message translates to:
  /// **'{name} is on the way'**
  String driverOnWay(String name);

  /// Arriving: the driver is at the pickup.
  ///
  /// In en, this message translates to:
  /// **'{name} has arrived'**
  String driverArrived(String name);

  /// Stand-in when the driver's name is unknown.
  ///
  /// In en, this message translates to:
  /// **'Your driver'**
  String get yourDriver;

  /// Arriving: label on the PIN panel.
  ///
  /// In en, this message translates to:
  /// **'Ride PIN'**
  String get ridePin;

  /// Arriving: under the PIN label.
  ///
  /// In en, this message translates to:
  /// **'Tell it to your driver in the car'**
  String get ridePinHint;

  /// Call the driver.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// Message the driver.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// Open the safety sheet.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// Arriving: cancel link.
  ///
  /// In en, this message translates to:
  /// **'Cancel ride'**
  String get cancelRide;

  /// On trip: arrival estimate; the word about is required.
  ///
  /// In en, this message translates to:
  /// **'Arriving about {time}'**
  String arrivingAbout(String time);

  /// On trip: past the estimate.
  ///
  /// In en, this message translates to:
  /// **'Arriving soon'**
  String get arrivingSoon;

  /// On trip: minutes left.
  ///
  /// In en, this message translates to:
  /// **'{n} min left'**
  String minutesLeft(int n);

  /// On trip: when no estimate exists.
  ///
  /// In en, this message translates to:
  /// **'On the way to {place}'**
  String onTheWayTo(String place);

  /// On trip: the fare is locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// On trip: after the trip ends.
  ///
  /// In en, this message translates to:
  /// **'View summary'**
  String get viewSummary;

  /// Receipt: left tile.
  ///
  /// In en, this message translates to:
  /// **'Your ticket said'**
  String get ticketSaid;

  /// Receipt: right tile.
  ///
  /// In en, this message translates to:
  /// **'Trip cost'**
  String get tripCost;

  /// Receipt: when the two match.
  ///
  /// In en, this message translates to:
  /// **'Exactly what you were quoted'**
  String get exactlyQuoted;

  /// Receipt: promo difference line.
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get promotion;

  /// Receipt: a difference the API does not explain.
  ///
  /// In en, this message translates to:
  /// **'Difference {amount}: the reason is not available yet'**
  String differenceUnexplained(String amount);

  /// Receipt: expandable breakdown.
  ///
  /// In en, this message translates to:
  /// **'How it adds up'**
  String get howItAddsUp;

  /// Receipt: primary button.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} by {method}'**
  String payBy(String amount, String method);

  /// Receipt: cash note.
  ///
  /// In en, this message translates to:
  /// **'Paying cash? Give {amount} to {name}'**
  String payingCash(String amount, String name);

  /// Rating heading.
  ///
  /// In en, this message translates to:
  /// **'Rate {name}'**
  String rateDriver(String name);

  /// Safety: emergency block heading.
  ///
  /// In en, this message translates to:
  /// **'In danger?'**
  String get inDanger;

  /// Safety: emergency block line.
  ///
  /// In en, this message translates to:
  /// **'Hold 2 seconds for SOS. Our team is alerted at once.'**
  String get holdForSos;

  /// Safety: call the emergency number from config.
  ///
  /// In en, this message translates to:
  /// **'Call {number}'**
  String callEmergency(String number);

  /// Safety: opens support.
  ///
  /// In en, this message translates to:
  /// **'Report something'**
  String get reportSomething;

  /// Safety: support phone row.
  ///
  /// In en, this message translates to:
  /// **'Call SaaradhiGo support'**
  String get callSupport;

  /// No driver found: heading.
  ///
  /// In en, this message translates to:
  /// **'No {name} free near you'**
  String noClassFree(String name);

  /// No driver found: reassurance.
  ///
  /// In en, this message translates to:
  /// **'You have not been charged'**
  String get notCharged;

  /// No driver found: retry the search.
  ///
  /// In en, this message translates to:
  /// **'Keep looking'**
  String get keepLooking;

  /// No driver found: alternatives heading.
  ///
  /// In en, this message translates to:
  /// **'Or try another ride'**
  String get tryAnotherRide;

  /// No driver found: back to every fare.
  ///
  /// In en, this message translates to:
  /// **'Change ride'**
  String get changeRide;

  /// Payment failed: banner heading.
  ///
  /// In en, this message translates to:
  /// **'Payment did not go through'**
  String get paymentFailed;

  /// Payment failed: refund reassurance.
  ///
  /// In en, this message translates to:
  /// **'If money left your account, it will come back to you.'**
  String get moneyComesBack;

  /// Payment failed: refund time from config.
  ///
  /// In en, this message translates to:
  /// **'It comes back within {days} working days.'**
  String refundWithin(int days);

  /// Payment failed: amount label.
  ///
  /// In en, this message translates to:
  /// **'Still to pay'**
  String get stillToPay;

  /// Payment failed: primary, back to the payment choices.
  ///
  /// In en, this message translates to:
  /// **'Try again or pay another way'**
  String get tryAnotherWay;

  /// Payment failed: support row.
  ///
  /// In en, this message translates to:
  /// **'Talk to support about this payment'**
  String get talkSupportPayment;

  /// Go to the home screen.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get goHome;

  /// Every fare: a class with no driver near.
  ///
  /// In en, this message translates to:
  /// **'No drivers nearby'**
  String get noDriversNearby;

  /// Every fare: seats in the class.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 seat} other{{n} seats}}'**
  String seatsCount(int n);

  /// Fare ticket: the server's quote expired before booking; this is the fresh fare. Confirm again books it.
  ///
  /// In en, this message translates to:
  /// **'Fare updated to {fare} because time passed'**
  String fareUpdatedTimePassed(String fare);

  /// Fare ticket: the pickup, drop or class changed after the quote; this is the fresh fare.
  ///
  /// In en, this message translates to:
  /// **'Fare updated to {fare} because the pickup changed'**
  String fareUpdatedPickupChanged(String fare);

  /// Fare ticket: re-quoting after the rider moved the pickup pin.
  ///
  /// In en, this message translates to:
  /// **'Updating your fare'**
  String get fareUpdating;

  /// Finding: how many drivers the search has offered the ride to so far (dispatch_progress drivers_notified, summed over waves). Shown only when above zero.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Asked 1 driver nearby} other{Asked {n} drivers nearby}}'**
  String askedDriversNearby(int n);

  /// Rider screen text, moved from code: Your rides
  ///
  /// In en, this message translates to:
  /// **'Your rides'**
  String get yourRides;

  /// Rider screen text, moved from code: Payment methods
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethods;

  /// Rider screen text, moved from code: Notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Rider screen text, moved from code: Refer a friend
  ///
  /// In en, this message translates to:
  /// **'Refer a friend'**
  String get referFriend;

  /// Rider screen text, moved from code: Profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Rider screen text, moved from code: Help and support
  ///
  /// In en, this message translates to:
  /// **'Help and support'**
  String get helpSupport;

  /// Rider screen text, moved from code: Personal information
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get personalInfo;

  /// Rider screen text, moved from code: Privacy and security
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get privacySecurity;

  /// Rider screen text, moved from code: Log out
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// Rider screen text, moved from code: Current Location
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// Rider screen text, moved from code: Use my location
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// Rider screen text, moved from code: Please select pickup location first
  ///
  /// In en, this message translates to:
  /// **'Please select pickup location first'**
  String get selectPickupFirst;

  /// Rider screen text, moved from code: Location services are disabled. Please enable them in settings.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable them in settings.'**
  String get locationServicesOff;

  /// Rider screen text, moved from code: Location permissions are denied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are denied.'**
  String get locationDenied;

  /// Rider screen text, moved from code: Location permissions are permanently denied, we cannot request permissions.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied, we cannot request permissions.'**
  String get locationDeniedForever;

  /// Rider screen text, moved from code: We couldn't find your location. Enter your pickup point.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find your location. Enter your pickup point.'**
  String get locationNotFound;

  /// Rider screen text, moved from code: Resuming your active ride...
  ///
  /// In en, this message translates to:
  /// **'Resuming your active ride...'**
  String get resumingRide;

  /// Rider screen text, moved from code: Active Ride
  ///
  /// In en, this message translates to:
  /// **'Active Ride'**
  String get activeRideTitle;

  /// Rider screen text, moved from code: You already have an active ride request or trip. Would you like to view it?
  ///
  /// In en, this message translates to:
  /// **'You already have an active ride request or trip. Would you like to view it?'**
  String get activeRideBody;

  /// Rider screen text, moved from code: Dismiss
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Rider screen text, moved from code: Where to?
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// Rider screen text, moved from code: Places you ride to will appear here.
  ///
  /// In en, this message translates to:
  /// **'Places you ride to will appear here.'**
  String get placesAppearHere;

  /// Rider screen text, moved from code: Back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Rider screen text, moved from code: Finding your Saaradhi
  ///
  /// In en, this message translates to:
  /// **'Finding your Saaradhi'**
  String get findingSaaradhi;

  /// Rider screen text, moved from code: No Saaradhi nearby right now
  ///
  /// In en, this message translates to:
  /// **'No Saaradhi nearby right now'**
  String get noSaaradhiNearby;

  /// Rider screen text, moved from code: Cancel Search?
  ///
  /// In en, this message translates to:
  /// **'Cancel Search?'**
  String get cancelSearchTitle;

  /// Rider screen text, moved from code: Are you sure you want to cancel your ride request?
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel your ride request?'**
  String get cancelSearchBody;

  /// Rider screen text, moved from code: Wait
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get wait;

  /// Rider screen text, moved from code: Cancel Anyway
  ///
  /// In en, this message translates to:
  /// **'Cancel Anyway'**
  String get cancelAnyway;

  /// Rider screen text, moved from code: Ongoing Ride
  ///
  /// In en, this message translates to:
  /// **'Ongoing Ride'**
  String get ongoingRideTitle;

  /// Rider screen text, moved from code: You have an active ride request. Are you sure you want to cancel?
  ///
  /// In en, this message translates to:
  /// **'You have an active ride request. Are you sure you want to cancel?'**
  String get cancelActiveRequestBody;

  /// Rider screen text, moved from code: Are you sure you want to cancel your ongoing ride?
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel your ongoing ride?'**
  String get cancelOngoingRideBody;

  /// Rider screen text, moved from code: Continue Ride
  ///
  /// In en, this message translates to:
  /// **'Continue Ride'**
  String get continueRide;

  /// Rider screen text, moved from code: Driver phone unavailable. Use in-app chat instead.
  ///
  /// In en, this message translates to:
  /// **'Driver phone unavailable. Use in-app chat instead.'**
  String get driverPhoneUnavailable;

  /// Rider screen text, moved from code: Could not open dialer on this device.
  ///
  /// In en, this message translates to:
  /// **'Could not open dialer on this device.'**
  String get dialerUnavailable;

  /// Rider screen text, moved from code: Could not start a call.
  ///
  /// In en, this message translates to:
  /// **'Could not start a call.'**
  String get callFailed;

  /// Rider screen text, moved from code: Pay with Cash
  ///
  /// In en, this message translates to:
  /// **'Pay with Cash'**
  String get payWithCashTitle;

  /// Rider screen text, moved from code: Hand it to your driver
  ///
  /// In en, this message translates to:
  /// **'Hand it to your driver'**
  String get handToDriver;

  /// Rider screen text, moved from code: Pay from Wallet
  ///
  /// In en, this message translates to:
  /// **'Pay from Wallet'**
  String get payFromWallet;

  /// Rider screen text, moved from code: Not enough balance
  ///
  /// In en, this message translates to:
  /// **'Not enough balance'**
  String get notEnoughBalance;

  /// Rider screen text, moved from code: Pay via UPI/Card
  ///
  /// In en, this message translates to:
  /// **'Pay via UPI/Card'**
  String get payViaUpiCard;

  /// Rider screen text, moved from code: Pay with Cash instead?
  ///
  /// In en, this message translates to:
  /// **'Pay with Cash instead?'**
  String get payCashInstead;

  /// Rider screen text, moved from code: Thanks for rating your trip.
  ///
  /// In en, this message translates to:
  /// **'Thanks for rating your trip.'**
  String get thanksForRating;

  /// Rider screen text, moved from code: Insufficient Balance
  ///
  /// In en, this message translates to:
  /// **'Insufficient Balance'**
  String get insufficientBalance;

  /// Rider screen text, moved from code: Would you like to:
  ///
  /// In en, this message translates to:
  /// **'Would you like to:'**
  String get wouldYouLike;

  /// Rider screen text, moved from code: Add Money
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get addMoney;

  /// Rider screen text, moved from code: Pay with UPI/Card
  ///
  /// In en, this message translates to:
  /// **'Pay with UPI/Card'**
  String get payUpiCard;

  /// Rider screen text, moved from code: Cash payment received. Thank you.
  ///
  /// In en, this message translates to:
  /// **'Cash payment received. Thank you.'**
  String get cashReceived;

  /// Rider screen text, moved from code: Please sign in again to pay for this trip.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to pay for this trip.'**
  String get signInToPay;

  /// Rider screen text, moved from code: No active trip found. Please refresh and try again.
  ///
  /// In en, this message translates to:
  /// **'No active trip found. Please refresh and try again.'**
  String get noActiveTrip;

  /// Rider screen text, moved from code: Search for help
  ///
  /// In en, this message translates to:
  /// **'Search for help'**
  String get searchForHelp;

  /// Rider screen text, moved from code: How was your ride?
  ///
  /// In en, this message translates to:
  /// **'How was your ride?'**
  String get howWasRide;

  /// Rider screen text, moved from code: Done
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Rider screen text, moved from code: Could not save your rating.
  ///
  /// In en, this message translates to:
  /// **'Could not save your rating.'**
  String get couldNotSaveRating;

  /// Rider screen text, moved from code: Message your driver
  ///
  /// In en, this message translates to:
  /// **'Message your driver'**
  String get messageDriverHint;

  /// Rider screen text, moved from code: No rides yet
  ///
  /// In en, this message translates to:
  /// **'No rides yet'**
  String get noRidesYet;

  /// Rider screen text, moved from code: Rides you take will show here.
  ///
  /// In en, this message translates to:
  /// **'Rides you take will show here.'**
  String get ridesShowHere;

  /// Rider screen text, moved from code: Set your pickup on the home screen first.
  ///
  /// In en, this message translates to:
  /// **'Set your pickup on the home screen first.'**
  String get setPickupFirst;

  /// Rider screen text, moved from code: Ride here again
  ///
  /// In en, this message translates to:
  /// **'Ride here again'**
  String get rideHereAgain;

  /// Rider screen text, moved from code: Map unavailable
  ///
  /// In en, this message translates to:
  /// **'Map unavailable'**
  String get mapUnavailable;

  /// Rider screen text, moved from code: Please check your connection
  ///
  /// In en, this message translates to:
  /// **'Please check your connection'**
  String get checkConnection;

  /// Rider screen text, moved from code: Retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Rider screen text, moved from code: Unable to load fare estimates
  ///
  /// In en, this message translates to:
  /// **'Unable to load fare estimates'**
  String get faresUnavailable;

  /// Rider screen text, moved from code: Please check your connection and try again
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again'**
  String get checkConnectionRetry;

  /// Rider screen text, moved from code: Are you sure you want to cancel and go back?
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel and go back?'**
  String get cancelGoBack;

  /// Rider screen text, moved from code: Password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// Rider screen text, moved from code: Forgot password?
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Rider screen text, moved from code: Enter your email address
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterEmail;

  /// Rider screen text, moved from code: Enter your password
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// Rider screen text, moved from code: Please enter a valid phone number
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get validPhone;

  /// Rider screen text, moved from code: OTP sent. Check your messages.
  ///
  /// In en, this message translates to:
  /// **'OTP sent. Check your messages.'**
  String get otpSent;

  /// Rider screen text, moved from code: Try again
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Rider screen text, moved from code: Searching for a driver
  ///
  /// In en, this message translates to:
  /// **'Searching for a driver'**
  String get searchingForDriver;

  /// Rider screen text, moved from code: Confirm pickup
  ///
  /// In en, this message translates to:
  /// **'Confirm pickup'**
  String get confirmPickup;

  /// Rider screen text, moved from code: Share only in the car
  ///
  /// In en, this message translates to:
  /// **'Share only in the car'**
  String get shareOnlyInCar;

  /// Rider screen text, moved from code: You have arrived
  ///
  /// In en, this message translates to:
  /// **'You have arrived'**
  String get youHaveArrived;

  /// Rider screen text, moved from code: All
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Rider screen text, moved from code: Payments
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get filterPayments;

  /// Rider screen text, moved from code: Trip details copied — paste to share
  ///
  /// In en, this message translates to:
  /// **'Trip details copied — paste to share'**
  String get tripDetailsCopied;

  /// Rider screen text, moved from code: Hold to send alert
  ///
  /// In en, this message translates to:
  /// **'Hold to send alert'**
  String get holdToSendAlert;

  /// Rider screen text, moved from code: Anything you want us to know? (optional)
  ///
  /// In en, this message translates to:
  /// **'Anything you want us to know? (optional)'**
  String get ratingCommentHint;

  /// Rider screen text, moved from code: Submit rating
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get submitRating;

  /// Rider screen text, moved from code: Remove
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Rider screen text, moved from code: Promo code
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get promoCodeHint;

  /// Rider screen text, moved from code: You pay
  ///
  /// In en, this message translates to:
  /// **'You pay'**
  String get youPay;

  /// Rider screen text, moved from code: Cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Rider screen text, moved from code: Enter your email address first, then tap again
  ///
  /// In en, this message translates to:
  /// **'Enter your email address first, then tap again'**
  String get enterEmailFirst;

  /// Rider screen text, moved from code: Update
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Rider screen text, moved from code: Home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Rider screen text, moved from code: History
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// Rider screen text, moved from code: Ride Issues
  ///
  /// In en, this message translates to:
  /// **'Ride Issues'**
  String get helpRideIssues;

  /// Rider screen text, moved from code: Payment & Wallet
  ///
  /// In en, this message translates to:
  /// **'Payment & Wallet'**
  String get helpPaymentWallet;

  /// Rider screen text, moved from code: Account & App
  ///
  /// In en, this message translates to:
  /// **'Account & App'**
  String get helpAccountApp;

  /// Rider screen text, moved from code: Report a problem
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblem;

  /// Rider screen text, moved from code: Support replies in the app
  ///
  /// In en, this message translates to:
  /// **'Support replies in the app'**
  String get supportRepliesInApp;

  /// Rider screen text, moved from code: Email Support
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get emailSupport;

  /// Rider screen text, moved from code: Search for issues...
  ///
  /// In en, this message translates to:
  /// **'Search for issues...'**
  String get searchIssues;

  /// Rider screen text, moved from code: Two-Factor Authentication
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get twoFactor;

  /// Rider screen text, moved from code: Change Password
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// Rider screen text, moved from code: Location Permissions
  ///
  /// In en, this message translates to:
  /// **'Location Permissions'**
  String get locationPermissions;

  /// Rider screen text, moved from code: Notification Preferences
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notificationPreferences;

  /// Rider screen text, moved from code: Manage My Data
  ///
  /// In en, this message translates to:
  /// **'Manage My Data'**
  String get manageMyData;

  /// Rider screen text, moved from code: Always on. Needed for your rides and your safety.
  ///
  /// In en, this message translates to:
  /// **'Always on. Needed for your rides and your safety.'**
  String get alwaysOnRides;

  /// Rider screen text, moved from code: Off unless you turn it on.
  ///
  /// In en, this message translates to:
  /// **'Off unless you turn it on.'**
  String get offUnlessOn;

  /// Rider screen text, moved from code: Ride updates on WhatsApp
  ///
  /// In en, this message translates to:
  /// **'Ride updates on WhatsApp'**
  String get rideUpdatesWhatsapp;

  /// Rider screen text, moved from code: Offers on WhatsApp
  ///
  /// In en, this message translates to:
  /// **'Offers on WhatsApp'**
  String get offersWhatsapp;

  /// Rider screen text, moved from code: Copied. Paste it into any chat.
  ///
  /// In en, this message translates to:
  /// **'Copied. Paste it into any chat.'**
  String get copiedPasteChat;

  /// Rider screen text, moved from code: Referral code copied
  ///
  /// In en, this message translates to:
  /// **'Referral code copied'**
  String get referralCopied;

  /// Rider screen text, moved from code: Copy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Rider screen text, moved from code: Share
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Rider screen text, moved from code: Camera
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// Rider screen text, moved from code: Gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// Rider screen text, moved from code: Emergency phone number
  ///
  /// In en, this message translates to:
  /// **'Emergency phone number'**
  String get emergencyPhoneHint;

  /// Rider screen text, moved from code: Type of problem
  ///
  /// In en, this message translates to:
  /// **'Type of problem'**
  String get problemType;

  /// Rider screen text, moved from code: Describe the problem
  ///
  /// In en, this message translates to:
  /// **'Describe the problem'**
  String get describeProblem;

  /// Rider screen text, moved from code: Submit
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Rider screen text, moved from code: SaaradhiGo Wallet
  ///
  /// In en, this message translates to:
  /// **'SaaradhiGo Wallet'**
  String get saaradhiWallet;

  /// Rider screen text, moved from code: Add New Payment Method
  ///
  /// In en, this message translates to:
  /// **'Add New Payment Method'**
  String get addPaymentMethod;

  /// Home sheet: the destination field's hint
  ///
  /// In en, this message translates to:
  /// **'Search a destination'**
  String get searchADestination;

  /// Account row
  ///
  /// In en, this message translates to:
  /// **'Your trips'**
  String get accountYourTrips;

  /// Account row subtitle under Your trips
  ///
  /// In en, this message translates to:
  /// **'Receipts match the locked fare'**
  String get accountTripsHint;

  /// Account row
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get accountSavedPlaces;

  /// Saved places sheet when the list is empty
  ///
  /// In en, this message translates to:
  /// **'No saved places yet'**
  String get accountNoSavedPlaces;

  /// Account row
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get accountPayment;

  /// Account row
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get accountTheme;

  /// Account row
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get accountHelp;

  /// Account: sign out
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// Account: delete account link
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// Delete account dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// Delete account dialog body
  ///
  /// In en, this message translates to:
  /// **'Your account and personal details will be removed. This cannot be undone.'**
  String get deleteAccountBody;

  /// Delete account dialog: confirm button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAccountConfirm;

  /// Delete account failed
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. Try again.'**
  String get deleteAccountFailed;

  /// Home: the menu button over the map
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
