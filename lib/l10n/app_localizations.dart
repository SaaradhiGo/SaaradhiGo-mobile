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

  /// Account row and sheet title: choose the colour theme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Theme option: dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
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
