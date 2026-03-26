import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Playmaker'**
  String get appTitle;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @playerDetails.
  ///
  /// In en, this message translates to:
  /// **'Player Details'**
  String get playerDetails;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile Updated Successfully'**
  String get profileUpdated;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @nationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get nationality;

  /// No description provided for @playerId.
  ///
  /// In en, this message translates to:
  /// **'Player ID'**
  String get playerId;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// No description provided for @levelBeginnerDescription.
  ///
  /// In en, this message translates to:
  /// **'New to football, learning the basics.'**
  String get levelBeginnerDescription;

  /// No description provided for @casual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get casual;

  /// No description provided for @levelCasualDescription.
  ///
  /// In en, this message translates to:
  /// **'Plays regularly, understands the game.'**
  String get levelCasualDescription;

  /// No description provided for @skilled.
  ///
  /// In en, this message translates to:
  /// **'Skilled'**
  String get skilled;

  /// No description provided for @levelSkilledDescription.
  ///
  /// In en, this message translates to:
  /// **'Good technical skills, tactical awareness.'**
  String get levelSkilledDescription;

  /// No description provided for @elite.
  ///
  /// In en, this message translates to:
  /// **'Elite'**
  String get elite;

  /// No description provided for @levelEliteDescription.
  ///
  /// In en, this message translates to:
  /// **'Strong player, makes an impact.'**
  String get levelEliteDescription;

  /// No description provided for @expert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get expert;

  /// No description provided for @levelExpertDescription.
  ///
  /// In en, this message translates to:
  /// **'High-level skills, dominates matches.'**
  String get levelExpertDescription;

  /// No description provided for @skillLevel.
  ///
  /// In en, this message translates to:
  /// **'Skill Level'**
  String get skillLevel;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @squads.
  ///
  /// In en, this message translates to:
  /// **'Squads'**
  String get squads;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @fields.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get fields;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterYourName;

  /// No description provided for @selectPositionAndLevel.
  ///
  /// In en, this message translates to:
  /// **'Select Position & Level'**
  String get selectPositionAndLevel;

  /// No description provided for @preferredPosition.
  ///
  /// In en, this message translates to:
  /// **'Preferred Position'**
  String get preferredPosition;

  /// No description provided for @completeProfileButton.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get completeProfileButton;

  /// No description provided for @playMoreToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Play {count} matches to unlock'**
  String playMoreToUnlock(int count);

  /// No description provided for @almostUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Almost'**
  String get almostUnlocked;

  /// No description provided for @justUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked!'**
  String get justUnlocked;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsConditions;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent. Your profile, bookings, and all associated data will be permanently removed.'**
  String get deleteAccountConfirmation;

  /// No description provided for @typeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type \"{word}\" to confirm deletion:'**
  String typeToConfirm(Object word);

  /// No description provided for @languageSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettingsTitle;

  /// No description provided for @rtlLayoutInfo.
  ///
  /// In en, this message translates to:
  /// **'The app will support right-to-left layout automatically when Arabic is selected. This affects all screens and components, providing a seamless experience for Arabic users.'**
  String get rtlLayoutInfo;

  /// No description provided for @birthDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get birthDateTitle;

  /// No description provided for @hintDD.
  ///
  /// In en, this message translates to:
  /// **'DD'**
  String get hintDD;

  /// No description provided for @hintMM.
  ///
  /// In en, this message translates to:
  /// **'MM'**
  String get hintMM;

  /// No description provided for @hintYYYY.
  ///
  /// In en, this message translates to:
  /// **'YYYY'**
  String get hintYYYY;

  /// No description provided for @phoneNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberTitle;

  /// No description provided for @hintPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get hintPhoneNumber;

  /// No description provided for @fullNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameTitle;

  /// No description provided for @hintEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get hintEnterFullName;

  /// No description provided for @couldNotFetchUpdatedProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch updated profile after image upload.'**
  String get couldNotFetchUpdatedProfile;

  /// No description provided for @deleteAccountWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent. Your profile, bookings, and all associated data will be permanently removed.'**
  String get deleteAccountWarningMessage;

  /// No description provided for @typeToConfirmDeletion.
  ///
  /// In en, this message translates to:
  /// **'Type \"{word}\" to confirm deletion:'**
  String typeToConfirmDeletion(String word);

  /// No description provided for @pleaseTypeExactly.
  ///
  /// In en, this message translates to:
  /// **'Please type exactly \"{word}\"'**
  String pleaseTypeExactly(String word);

  /// No description provided for @accountDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account successfully deleted'**
  String get accountDeletedSuccess;

  /// No description provided for @errorDeletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Error deleting account: {error}'**
  String errorDeletingAccount(String error);

  /// No description provided for @logoutConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account?'**
  String get logoutConfirmationMessage;

  /// No description provided for @createProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfileTitle;

  /// No description provided for @signUpToAccessFeatures.
  ///
  /// In en, this message translates to:
  /// **'Sign up to access all features:'**
  String get signUpToAccessFeatures;

  /// No description provided for @featureBookFields.
  ///
  /// In en, this message translates to:
  /// **'Book football fields'**
  String get featureBookFields;

  /// No description provided for @featureJoinCreateSquads.
  ///
  /// In en, this message translates to:
  /// **'Join and create squads'**
  String get featureJoinCreateSquads;

  /// No description provided for @featureScheduleMatches.
  ///
  /// In en, this message translates to:
  /// **'Schedule matches'**
  String get featureScheduleMatches;

  /// No description provided for @featureConnectPlayers.
  ///
  /// In en, this message translates to:
  /// **'Connect with players'**
  String get featureConnectPlayers;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @statGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get statGames;

  /// No description provided for @statFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get statFriends;

  /// No description provided for @statSquads.
  ///
  /// In en, this message translates to:
  /// **'Squads'**
  String get statSquads;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @squadsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Squads'**
  String get squadsTabTitle;

  /// No description provided for @friendsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsCardTitle;

  /// No description provided for @connectWithPlayersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with players'**
  String get connectWithPlayersSubtitle;

  /// No description provided for @friendsStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsStatLabel;

  /// No description provided for @mySquadsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'My Squads'**
  String get mySquadsCardTitle;

  /// No description provided for @mySquadsCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and manage your teams'**
  String get mySquadsCardSubtitle;

  /// No description provided for @teamsStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get teamsStatLabel;

  /// No description provided for @joinSquadsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Squads'**
  String get joinSquadsCardTitle;

  /// No description provided for @joinSquadsCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find and join teams in your area'**
  String get joinSquadsCardSubtitle;

  /// No description provided for @createSquadCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Squad'**
  String get createSquadCardTitle;

  /// No description provided for @createSquadCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start your own team and recruit players'**
  String get createSquadCardSubtitle;

  /// No description provided for @createAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountDialogTitle;

  /// No description provided for @createAccountDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Please create an account to access this feature.'**
  String get createAccountDialogMessage;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpButton;

  /// No description provided for @playTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playTabTitle;

  /// No description provided for @bookAFieldCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Book a Field'**
  String get bookAFieldCardTitle;

  /// No description provided for @bookAFieldCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find and book football fields near you'**
  String get bookAFieldCardSubtitle;

  /// No description provided for @joinMatchesCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Matches'**
  String get joinMatchesCardTitle;

  /// No description provided for @joinMatchesCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play with others in scheduled matches'**
  String get joinMatchesCardSubtitle;

  /// No description provided for @openMatchesStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Open Matches'**
  String get openMatchesStatLabel;

  /// No description provided for @failedToLoadBookingsSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to load bookings'**
  String get failedToLoadBookingsSnackbar;

  /// No description provided for @errorFetchingFieldDetailsSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Error fetching field details'**
  String get errorFetchingFieldDetailsSnackbar;

  /// No description provided for @recentlyPlayedFieldsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recently Played Fields'**
  String get recentlyPlayedFieldsTitle;

  /// No description provided for @yourFavoritePlacesToPlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your favorite places to play'**
  String get yourFavoritePlacesToPlaySubtitle;

  /// No description provided for @bookAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Book Again'**
  String get bookAgainButton;

  /// No description provided for @noRecentlyPlayedFields.
  ///
  /// In en, this message translates to:
  /// **'No recently played fields'**
  String get noRecentlyPlayedFields;

  /// No description provided for @errorLoadingFields.
  ///
  /// In en, this message translates to:
  /// **'Error loading fields'**
  String get errorLoadingFields;

  /// No description provided for @matchDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Match Details'**
  String get matchDetailsTitle;

  /// No description provided for @detailsTab.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsTab;

  /// No description provided for @chatTab.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTab;

  /// No description provided for @openInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get openInGoogleMaps;

  /// No description provided for @couldNotLaunchGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not launch Google Maps'**
  String get couldNotLaunchGoogleMaps;

  /// No description provided for @openInAppleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Apple Maps'**
  String get openInAppleMaps;

  /// No description provided for @couldNotLaunchAppleMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not launch Apple Maps'**
  String get couldNotLaunchAppleMaps;

  /// No description provided for @failedToAcceptJoinRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept join request'**
  String get failedToAcceptJoinRequest;

  /// No description provided for @joinRequestPending.
  ///
  /// In en, this message translates to:
  /// **'Join Request Pending'**
  String get joinRequestPending;

  /// No description provided for @joinMatchButton.
  ///
  /// In en, this message translates to:
  /// **'Join Match'**
  String get joinMatchButton;

  /// No description provided for @matchInformationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Match Information'**
  String get matchInformationSectionTitle;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @hostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get hostLabel;

  /// No description provided for @youSuffix.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youSuffix;

  /// No description provided for @unableToLoadHost.
  ///
  /// In en, this message translates to:
  /// **'Unable to load host'**
  String get unableToLoadHost;

  /// No description provided for @joinRequestsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Requests'**
  String get joinRequestsSectionTitle;

  /// No description provided for @playersSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get playersSectionTitle;

  /// No description provided for @playersJoinedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} joined'**
  String playersJoinedCount(String count);

  /// No description provided for @playersMaxCount.
  ///
  /// In en, this message translates to:
  /// **'{current} / {max}'**
  String playersMaxCount(String current, String max);

  /// No description provided for @addPlayersButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addPlayersButton;

  /// No description provided for @guestLabel.
  ///
  /// In en, this message translates to:
  /// **'Guest {number}'**
  String guestLabel(String number);

  /// No description provided for @invalidGuestEntry.
  ///
  /// In en, this message translates to:
  /// **'Invalid Guest Entry'**
  String get invalidGuestEntry;

  /// No description provided for @locationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationSectionTitle;

  /// No description provided for @locationAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Location access required'**
  String get locationAccessRequired;

  /// No description provided for @getDirectionsButton.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get getDirectionsButton;

  /// No description provided for @joinMatchSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Match'**
  String get joinMatchSheetTitle;

  /// No description provided for @joinAloneOption.
  ///
  /// In en, this message translates to:
  /// **'Join Alone'**
  String get joinAloneOption;

  /// No description provided for @joinAloneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play with other players'**
  String get joinAloneSubtitle;

  /// No description provided for @joinWithGuestsOption.
  ///
  /// In en, this message translates to:
  /// **'Join with Guests'**
  String get joinWithGuestsOption;

  /// No description provided for @joinWithGuestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your friends along'**
  String get joinWithGuestsSubtitle;

  /// No description provided for @numberOfGuestsLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of Guests'**
  String get numberOfGuestsLabel;

  /// No description provided for @joinWithXGuestsButton.
  ///
  /// In en, this message translates to:
  /// **'Join with {count} Guest(s)'**
  String joinWithXGuestsButton(String count);

  /// No description provided for @joinRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Join request sent!'**
  String get joinRequestSent;

  /// No description provided for @failedToSendJoinRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to send join request: {error}'**
  String failedToSendJoinRequest(String error);

  /// No description provided for @addPlayersSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Players'**
  String get addPlayersSheetTitle;

  /// No description provided for @addGuestsOption.
  ///
  /// In en, this message translates to:
  /// **'Add Guests'**
  String get addGuestsOption;

  /// No description provided for @addGuestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add guest players'**
  String get addGuestsSubtitle;

  /// No description provided for @addFriendsOption.
  ///
  /// In en, this message translates to:
  /// **'Add Friends'**
  String get addFriendsOption;

  /// No description provided for @addFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add from your friends list'**
  String get addFriendsSubtitle;

  /// No description provided for @addSquadOption.
  ///
  /// In en, this message translates to:
  /// **'Add Squad'**
  String get addSquadOption;

  /// No description provided for @addSquadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add players from your squad'**
  String get addSquadSubtitle;

  /// No description provided for @selectAction.
  ///
  /// In en, this message translates to:
  /// **'Select Action'**
  String get selectAction;

  /// No description provided for @addedXGuestsSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Added {count} guest(s) to the match'**
  String addedXGuestsSnackbar(String count);

  /// No description provided for @errorAddingGuestsSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Error adding guests: {error}'**
  String errorAddingGuestsSnackbar(String error);

  /// No description provided for @addedXPlayersSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Added {count} player(s) to the match'**
  String addedXPlayersSnackbar(String count);

  /// No description provided for @errorAddingPlayersSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Error adding players: {error}'**
  String errorAddingPlayersSnackbar(String error);

  /// No description provided for @allSquadMembersAlreadyInMatch.
  ///
  /// In en, this message translates to:
  /// **'All squad members are already in the match'**
  String get allSquadMembersAlreadyInMatch;

  /// No description provided for @cannotAddSquadMembersLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Cannot add squad members from {squadName}. Maximum limit of {maxPlayers} reached.'**
  String cannotAddSquadMembersLimitReached(String squadName, String maxPlayers);

  /// No description provided for @sentXFriendJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Sent {count} friend join request(s)'**
  String sentXFriendJoinRequests(String count);

  /// No description provided for @sentXSquadJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Sent {count} join request(s) for members of {squadName}'**
  String sentXSquadJoinRequests(String count, String squadName);

  /// No description provided for @requestedToAddXGuests.
  ///
  /// In en, this message translates to:
  /// **'Requested to add {count} guest(s)'**
  String requestedToAddXGuests(String count);

  /// No description provided for @failedToSendGuestAddRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to send guest add request: {error}'**
  String failedToSendGuestAddRequest(String error);

  /// No description provided for @minsSuffix.
  ///
  /// In en, this message translates to:
  /// **'mins'**
  String get minsSuffix;

  /// No description provided for @cannotAcceptRequestMaxPlayers.
  ///
  /// In en, this message translates to:
  /// **'Cannot accept request. Adding {count} player(s) would exceed the maximum of {maxPlayers}.'**
  String cannotAcceptRequestMaxPlayers(String count, String maxPlayers);

  /// No description provided for @playerAddedToMatchSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{playerName} has been added to the match'**
  String playerAddedToMatchSnackbar(String playerName);

  /// No description provided for @playerAddedWithGuestsSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{playerName} has been added to the match with {guestCount} guests'**
  String playerAddedWithGuestsSnackbar(String playerName, String guestCount);

  /// No description provided for @guestRequestApprovedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{playerName} request to add {guestCount} guests approved'**
  String guestRequestApprovedSnackbar(String playerName, String guestCount);

  /// No description provided for @declinedJoinRequestSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Declined join request'**
  String get declinedJoinRequestSnackbar;

  /// No description provided for @failedToDeclineJoinRequestSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to decline join request'**
  String get failedToDeclineJoinRequestSnackbar;

  /// No description provided for @errorParsingJoinRequest.
  ///
  /// In en, this message translates to:
  /// **'Error parsing join request: {error}'**
  String errorParsingJoinRequest(String error);

  /// No description provided for @errorRefreshingBooking.
  ///
  /// In en, this message translates to:
  /// **'Error re-fetching booking: {error}'**
  String errorRefreshingBooking(String error);

  /// No description provided for @bookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking not found'**
  String get bookingNotFound;

  /// No description provided for @youAreNotMemberOfSquads.
  ///
  /// In en, this message translates to:
  /// **'You are not a member of any squads'**
  String get youAreNotMemberOfSquads;

  /// No description provided for @selectSquadToRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Squad to Request'**
  String get selectSquadToRequestTitle;

  /// No description provided for @selectSquadTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Squad'**
  String get selectSquadTitle;

  /// No description provided for @membersSuffix.
  ///
  /// In en, this message translates to:
  /// **'members'**
  String get membersSuffix;

  /// No description provided for @matchesTab_errorLoadingFields.
  ///
  /// In en, this message translates to:
  /// **'Error loading fields: {e}'**
  String matchesTab_errorLoadingFields(String e);

  /// No description provided for @matchesTab_unknownPlayer.
  ///
  /// In en, this message translates to:
  /// **'Unknown Player'**
  String get matchesTab_unknownPlayer;

  /// No description provided for @matchesTab_errorFetchingHostInfo.
  ///
  /// In en, this message translates to:
  /// **'Error fetching host info: {e}'**
  String matchesTab_errorFetchingHostInfo(String e);

  /// No description provided for @matchesTab_matchInProgress.
  ///
  /// In en, this message translates to:
  /// **'Match in progress'**
  String get matchesTab_matchInProgress;

  /// No description provided for @matchesTab_timeLeftDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days} day(s), {hours} hr(s) left'**
  String matchesTab_timeLeftDaysHours(int days, int hours);

  /// No description provided for @matchesTab_timeLeftHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr(s), {minutes} min(s) left'**
  String matchesTab_timeLeftHoursMinutes(int hours, int minutes);

  /// No description provided for @matchesTab_timeLeftMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min(s) left'**
  String matchesTab_timeLeftMinutes(int minutes);

  /// No description provided for @matchesTab_startingSoon.
  ///
  /// In en, this message translates to:
  /// **'Starting soon'**
  String get matchesTab_startingSoon;

  /// No description provided for @matchesTab_errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String matchesTab_errorGeneric(String error);

  /// No description provided for @matchesTab_upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get matchesTab_upcoming;

  /// No description provided for @matchesTab_past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get matchesTab_past;

  /// No description provided for @matchesTab_noMatchesFound.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get matchesTab_noMatchesFound;

  /// No description provided for @matchesTab_startByJoiningOrBooking.
  ///
  /// In en, this message translates to:
  /// **'Start by joining a match or booking a field'**
  String get matchesTab_startByJoiningOrBooking;

  /// No description provided for @matchesTab_joinAMatch.
  ///
  /// In en, this message translates to:
  /// **'Join a Match'**
  String get matchesTab_joinAMatch;

  /// No description provided for @matchesTab_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get matchesTab_loading;

  /// No description provided for @matchesTab_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get matchesTab_completed;

  /// No description provided for @matchesTab_spotsLeft.
  ///
  /// In en, this message translates to:
  /// **'{spotsLeft} Spot(s) Left'**
  String matchesTab_spotsLeft(int spotsLeft);

  /// No description provided for @matchesTab_matchFull.
  ///
  /// In en, this message translates to:
  /// **'Match Full'**
  String get matchesTab_matchFull;

  /// No description provided for @fieldBooking_errorParsingRecurringOriginalDate.
  ///
  /// In en, this message translates to:
  /// **'Error parsing recurringOriginalDate (\'{date}\'): {e}'**
  String fieldBooking_errorParsingRecurringOriginalDate(String date, String e);

  /// No description provided for @fieldBooking_errorParsingRecurringEndDate.
  ///
  /// In en, this message translates to:
  /// **'Error parsing recurringEndDate (\'{date}\'): {e}'**
  String fieldBooking_errorParsingRecurringEndDate(String date, String e);

  /// No description provided for @fieldBooking_streetAddressNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Street address not available'**
  String get fieldBooking_streetAddressNotAvailable;

  /// No description provided for @fieldBooking_directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get fieldBooking_directions;

  /// No description provided for @fieldBooking_priceRangeEGP.
  ///
  /// In en, this message translates to:
  /// **'{priceRange} EGP'**
  String fieldBooking_priceRangeEGP(String priceRange);

  /// No description provided for @fieldBooking_selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get fieldBooking_selectDate;

  /// No description provided for @fieldBooking_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get fieldBooking_today;

  /// No description provided for @fieldBooking_availableTimeSlots.
  ///
  /// In en, this message translates to:
  /// **'Available Time Slots'**
  String get fieldBooking_availableTimeSlots;

  /// No description provided for @fieldBooking_noTimeSlotsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No time slots available'**
  String get fieldBooking_noTimeSlotsAvailable;

  /// No description provided for @fieldBooking_trySelectingAnotherDate.
  ///
  /// In en, this message translates to:
  /// **'Try selecting another date'**
  String get fieldBooking_trySelectingAnotherDate;

  /// No description provided for @fieldBooking_errorParsingTimeSlotForPastCheck.
  ///
  /// In en, this message translates to:
  /// **'Error parsing timeslot time for \'isPast\' check: {e}'**
  String fieldBooking_errorParsingTimeSlotForPastCheck(String e);

  /// No description provided for @fieldBooking_booked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get fieldBooking_booked;

  /// No description provided for @fieldBooking_pastTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get fieldBooking_pastTimeSlot;

  /// No description provided for @fieldBooking_continueToBooking.
  ///
  /// In en, this message translates to:
  /// **'Continue to Booking'**
  String get fieldBooking_continueToBooking;

  /// No description provided for @fieldBooking_bookingCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Booking created successfully'**
  String get fieldBooking_bookingCreatedSuccessfully;

  /// No description provided for @fieldBooking_available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get fieldBooking_available;

  /// No description provided for @fieldBooking_openMatchStatus.
  ///
  /// In en, this message translates to:
  /// **'Open Match'**
  String get fieldBooking_openMatchStatus;

  /// No description provided for @fieldBooking_durationHours.
  ///
  /// In en, this message translates to:
  /// **'{duration} hours'**
  String fieldBooking_durationHours(int duration);

  /// No description provided for @fieldBooking_durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}:{minutes} hours'**
  String fieldBooking_durationHoursMinutes(int hours, String minutes);

  /// No description provided for @fieldBooking_priceEGP.
  ///
  /// In en, this message translates to:
  /// **'{price} EGP'**
  String fieldBooking_priceEGP(dynamic price);

  /// No description provided for @fieldBooking_photoCounter.
  ///
  /// In en, this message translates to:
  /// **'{current} / {totalPhotos}'**
  String fieldBooking_photoCounter(int current, int totalPhotos);

  /// No description provided for @fieldsListView_locationNewCairo.
  ///
  /// In en, this message translates to:
  /// **'New Cairo'**
  String get fieldsListView_locationNewCairo;

  /// No description provided for @fieldsListView_locationNasrCity.
  ///
  /// In en, this message translates to:
  /// **'Nasr City'**
  String get fieldsListView_locationNasrCity;

  /// No description provided for @fieldsListView_locationShorouk.
  ///
  /// In en, this message translates to:
  /// **'Shorouk'**
  String get fieldsListView_locationShorouk;

  /// No description provided for @fieldsListView_locationMaadi.
  ///
  /// In en, this message translates to:
  /// **'Maadi'**
  String get fieldsListView_locationMaadi;

  /// No description provided for @fieldsListView_locationSheikhZayed.
  ///
  /// In en, this message translates to:
  /// **'Sheikh Zayed'**
  String get fieldsListView_locationSheikhZayed;

  /// No description provided for @fieldsListView_locationOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get fieldsListView_locationOctober;

  /// No description provided for @fieldsListView_errorCheckingLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'Error checking location permission: {e}'**
  String fieldsListView_errorCheckingLocationPermission(String e);

  /// No description provided for @fieldsListView_errorFetchingFields.
  ///
  /// In en, this message translates to:
  /// **'Error fetching fields: {e}'**
  String fieldsListView_errorFetchingFields(String e);

  /// No description provided for @fieldsListView_viewMap.
  ///
  /// In en, this message translates to:
  /// **'View Map'**
  String get fieldsListView_viewMap;

  /// No description provided for @fieldsListView_filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get fieldsListView_filter;

  /// No description provided for @fieldsListView_withinRadiusKm.
  ///
  /// In en, this message translates to:
  /// **'Within {radius} km'**
  String fieldsListView_withinRadiusKm(int radius);

  /// No description provided for @fieldsListView_createAccountToBook.
  ///
  /// In en, this message translates to:
  /// **'Please create an account to book a field.'**
  String get fieldsListView_createAccountToBook;

  /// No description provided for @fieldsListView_filterFields.
  ///
  /// In en, this message translates to:
  /// **'Filter Fields'**
  String get fieldsListView_filterFields;

  /// No description provided for @fieldsListView_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fieldsListView_location;

  /// No description provided for @fieldsListView_distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get fieldsListView_distance;

  /// No description provided for @fieldsListView_anyDistance.
  ///
  /// In en, this message translates to:
  /// **'Any Distance'**
  String get fieldsListView_anyDistance;

  /// No description provided for @fieldsListView_radiusKm.
  ///
  /// In en, this message translates to:
  /// **'{radius} km'**
  String fieldsListView_radiusKm(int radius);

  /// No description provided for @fieldsListView_minRadius.
  ///
  /// In en, this message translates to:
  /// **'1 km'**
  String get fieldsListView_minRadius;

  /// No description provided for @fieldsListView_maxRadius.
  ///
  /// In en, this message translates to:
  /// **'20 km'**
  String get fieldsListView_maxRadius;

  /// No description provided for @fieldsListView_applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get fieldsListView_applyFilters;

  /// No description provided for @fieldsListView_distanceMetersAway.
  ///
  /// In en, this message translates to:
  /// **'{distance}m away'**
  String fieldsListView_distanceMetersAway(String distance);

  /// No description provided for @fieldsListView_distanceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{distance}km away'**
  String fieldsListView_distanceKmAway(String distance);

  /// No description provided for @fieldsListView_priceRangeEgpHour.
  ///
  /// In en, this message translates to:
  /// **'{priceRange} EGP/hr'**
  String fieldsListView_priceRangeEgpHour(String priceRange);

  /// No description provided for @fieldsListView_amenityParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get fieldsListView_amenityParking;

  /// No description provided for @fieldsListView_amenityRestrooms.
  ///
  /// In en, this message translates to:
  /// **'Restrooms'**
  String get fieldsListView_amenityRestrooms;

  /// No description provided for @fieldsListView_amenityCafeteria.
  ///
  /// In en, this message translates to:
  /// **'Cafeteria'**
  String get fieldsListView_amenityCafeteria;

  /// No description provided for @fieldsListView_amenityFloodlights.
  ///
  /// In en, this message translates to:
  /// **'Floodlights'**
  String get fieldsListView_amenityFloodlights;

  /// No description provided for @fieldsListView_amenityRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get fieldsListView_amenityRecording;

  /// No description provided for @fieldsListView_noFieldsFound.
  ///
  /// In en, this message translates to:
  /// **'No Fields Found'**
  String get fieldsListView_noFieldsFound;

  /// No description provided for @fieldsListView_noFieldsFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or location to find available fields in your area.'**
  String get fieldsListView_noFieldsFoundSubtitle;

  /// No description provided for @fieldsListView_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get fieldsListView_refresh;

  /// No description provided for @bookingDetails_playerLimitReachedSomeAdded.
  ///
  /// In en, this message translates to:
  /// **'Player limit reached. Only {availableSlots} friends were added.'**
  String bookingDetails_playerLimitReachedSomeAdded(int availableSlots);

  /// No description provided for @bookingDetails_playerLimitReachedNoneAdded.
  ///
  /// In en, this message translates to:
  /// **'Player limit of {maxPlayers} already reached. Cannot add more players.'**
  String bookingDetails_playerLimitReachedNoneAdded(int maxPlayers);

  /// No description provided for @bookingDetails_matchSettings.
  ///
  /// In en, this message translates to:
  /// **'Match Settings'**
  String get bookingDetails_matchSettings;

  /// No description provided for @bookingDetails_matchSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure your match preferences'**
  String get bookingDetails_matchSettingsSubtitle;

  /// No description provided for @bookingDetails_privateMatch.
  ///
  /// In en, this message translates to:
  /// **'Private Match'**
  String get bookingDetails_privateMatch;

  /// No description provided for @bookingDetails_privateMatchSubtitlePrivate.
  ///
  /// In en, this message translates to:
  /// **'Players cannot request to join. Private game'**
  String get bookingDetails_privateMatchSubtitlePrivate;

  /// No description provided for @bookingDetails_privateMatchSubtitleOpen.
  ///
  /// In en, this message translates to:
  /// **'Other players can request to join your match'**
  String get bookingDetails_privateMatchSubtitleOpen;

  /// No description provided for @bookingDetails_limitMaxPlayers.
  ///
  /// In en, this message translates to:
  /// **'Limit Max Players'**
  String get bookingDetails_limitMaxPlayers;

  /// No description provided for @bookingDetails_limitMaxPlayersSubtitleLimit.
  ///
  /// In en, this message translates to:
  /// **'Set a maximum number of players'**
  String get bookingDetails_limitMaxPlayersSubtitleLimit;

  /// No description provided for @bookingDetails_limitMaxPlayersSubtitleNoLimit.
  ///
  /// In en, this message translates to:
  /// **'Allow any number of players to join'**
  String get bookingDetails_limitMaxPlayersSubtitleNoLimit;

  /// No description provided for @bookingDetails_cannotDecreaseMaxPlayersTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot Decrease Max Players'**
  String get bookingDetails_cannotDecreaseMaxPlayersTitle;

  /// No description provided for @bookingDetails_cannotDecreaseMaxPlayersMessage.
  ///
  /// In en, this message translates to:
  /// **'Please remove some players to decrease the Max Player number.'**
  String get bookingDetails_cannotDecreaseMaxPlayersMessage;

  /// No description provided for @bookingDetails_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get bookingDetails_ok;

  /// No description provided for @bookingDetails_cameraRecording.
  ///
  /// In en, this message translates to:
  /// **'Camera Recording'**
  String get bookingDetails_cameraRecording;

  /// No description provided for @bookingDetails_recordingEnabledPrice.
  ///
  /// In en, this message translates to:
  /// **'Recording enabled (+{price} EGP)'**
  String bookingDetails_recordingEnabledPrice(int price);

  /// No description provided for @bookingDetails_enableRecordingPrice.
  ///
  /// In en, this message translates to:
  /// **'Enable camera recording of your match (+{price} EGP)'**
  String bookingDetails_enableRecordingPrice(int price);

  /// No description provided for @bookingDetails_inviteFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends to join your match'**
  String get bookingDetails_inviteFriendsSubtitle;

  /// No description provided for @bookingDetails_playerCountFraction.
  ///
  /// In en, this message translates to:
  /// **'{current} / {max} Players'**
  String bookingDetails_playerCountFraction(int current, int max);

  /// No description provided for @bookingDetails_playerCountAbsolute.
  ///
  /// In en, this message translates to:
  /// **'{current} Players'**
  String bookingDetails_playerCountAbsolute(int current);

  /// No description provided for @bookingDetails_invitePlayers.
  ///
  /// In en, this message translates to:
  /// **'Invite Players'**
  String get bookingDetails_invitePlayers;

  /// No description provided for @bookingDetails_playersInvitedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Players Invited'**
  String bookingDetails_playersInvitedCount(int count);

  /// No description provided for @bookingDetails_tapToInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Tap to invite friends to your match'**
  String get bookingDetails_tapToInviteFriends;

  /// No description provided for @bookingDetails_bringGuests.
  ///
  /// In en, this message translates to:
  /// **'Bring Guests'**
  String get bookingDetails_bringGuests;

  /// No description provided for @bookingDetails_addPlayersWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Add players without an account'**
  String get bookingDetails_addPlayersWithoutAccount;

  /// No description provided for @bookingDetails_matchDescription.
  ///
  /// In en, this message translates to:
  /// **'Match Description'**
  String get bookingDetails_matchDescription;

  /// No description provided for @bookingDetails_matchDescriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add information for players about your match'**
  String get bookingDetails_matchDescriptionSubtitle;

  /// No description provided for @bookingDetails_matchDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Friendly match, all skill levels welcome! Bring both light and dark jerseys.'**
  String get bookingDetails_matchDescriptionHint;

  /// No description provided for @bookingDetails_totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get bookingDetails_totalAmount;

  /// No description provided for @bookingDetails_priceEgp.
  ///
  /// In en, this message translates to:
  /// **'{price} EGP'**
  String bookingDetails_priceEgp(int price);

  /// No description provided for @bookingDetails_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get bookingDetails_continue;

  /// No description provided for @bookingDetails_matchType.
  ///
  /// In en, this message translates to:
  /// **'Match Type'**
  String get bookingDetails_matchType;

  /// No description provided for @bookingDetails_matchTypePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get bookingDetails_matchTypePrivate;

  /// No description provided for @bookingDetails_matchTypePrivateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only invited players'**
  String get bookingDetails_matchTypePrivateSubtitle;

  /// No description provided for @bookingDetails_matchTypeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get bookingDetails_matchTypeOpen;

  /// No description provided for @bookingDetails_matchTypeOpenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anyone can join'**
  String get bookingDetails_matchTypeOpenSubtitle;

  /// No description provided for @bookingDetails_durationInMinutes.
  ///
  /// In en, this message translates to:
  /// **'{duration} min'**
  String bookingDetails_durationInMinutes(int duration);

  /// No description provided for @bookingDetails_durationHoursOnly.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String bookingDetails_durationHoursOnly(int hours);

  /// No description provided for @bookingDetails_durationHoursAndMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String bookingDetails_durationHoursAndMinutes(int hours, int minutes);

  /// No description provided for @paymob_paymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymob_paymentTitle;

  /// No description provided for @paymentScreen_checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get paymentScreen_checkoutTitle;

  /// No description provided for @paymentScreen_bookingSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking Summary'**
  String get paymentScreen_bookingSummaryTitle;

  /// No description provided for @paymentScreen_fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get paymentScreen_fieldLabel;

  /// No description provided for @paymentScreen_locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get paymentScreen_locationLabel;

  /// No description provided for @paymentScreen_dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get paymentScreen_dateLabel;

  /// No description provided for @paymentScreen_timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get paymentScreen_timeLabel;

  /// No description provided for @paymentScreen_playersLabel.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get paymentScreen_playersLabel;

  /// No description provided for @paymentScreen_playersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String paymentScreen_playersCount(int count);

  /// No description provided for @paymentScreen_cameraRecordingLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera Recording'**
  String get paymentScreen_cameraRecordingLabel;

  /// No description provided for @paymentScreen_cameraRecordingEnabledPrice.
  ///
  /// In en, this message translates to:
  /// **'Enabled (+{price} EGP)'**
  String paymentScreen_cameraRecordingEnabledPrice(int price);

  /// No description provided for @paymentScreen_fieldRentalLabel.
  ///
  /// In en, this message translates to:
  /// **'Field Rental'**
  String get paymentScreen_fieldRentalLabel;

  /// No description provided for @paymentScreen_priceEGP.
  ///
  /// In en, this message translates to:
  /// **'{price} EGP'**
  String paymentScreen_priceEGP(dynamic price);

  /// No description provided for @paymentScreen_totalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Price'**
  String get paymentScreen_totalPriceLabel;

  /// No description provided for @paymentScreen_paymentMethodSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentScreen_paymentMethodSectionTitle;

  /// No description provided for @paymentScreen_paymentMethodSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred payment method'**
  String get paymentScreen_paymentMethodSectionSubtitle;

  /// No description provided for @paymentScreen_creditCardOption.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get paymentScreen_creditCardOption;

  /// No description provided for @paymentScreen_creditCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay with your credit or debit card'**
  String get paymentScreen_creditCardSubtitle;

  /// No description provided for @paymentScreen_cashOption.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentScreen_cashOption;

  /// No description provided for @paymentScreen_cashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay cash at the field'**
  String get paymentScreen_cashSubtitle;

  /// No description provided for @paymentScreen_mobileWalletOption.
  ///
  /// In en, this message translates to:
  /// **'Mobile Wallet'**
  String get paymentScreen_mobileWalletOption;

  /// No description provided for @paymentScreen_mobileWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay with your mobile wallet'**
  String get paymentScreen_mobileWalletSubtitle;

  /// No description provided for @paymentScreen_payNowButton.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get paymentScreen_payNowButton;

  /// No description provided for @paymentScreen_failedToCreateBooking.
  ///
  /// In en, this message translates to:
  /// **'Failed to create booking: {e}'**
  String paymentScreen_failedToCreateBooking(String e);

  /// No description provided for @paymentScreen_selectMobileWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Mobile Wallet'**
  String get paymentScreen_selectMobileWalletTitle;

  /// No description provided for @paymentScreen_selectMobileWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred payment wallet'**
  String get paymentScreen_selectMobileWalletSubtitle;

  /// No description provided for @paymentScreen_vodafoneCash.
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash'**
  String get paymentScreen_vodafoneCash;

  /// No description provided for @paymentScreen_etisalatCash.
  ///
  /// In en, this message translates to:
  /// **'Etisalat Cash'**
  String get paymentScreen_etisalatCash;

  /// No description provided for @paymentScreen_orangeCash.
  ///
  /// In en, this message translates to:
  /// **'Orange Cash'**
  String get paymentScreen_orangeCash;

  /// No description provided for @paymentScreen_otherWallets.
  ///
  /// In en, this message translates to:
  /// **'Other Wallets'**
  String get paymentScreen_otherWallets;

  /// No description provided for @playerDetails_friendRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent to {name}'**
  String playerDetails_friendRequestSent(String name);

  /// No description provided for @playerDetails_errorSendingFriendRequest.
  ///
  /// In en, this message translates to:
  /// **'Error sending friend request: {e}'**
  String playerDetails_errorSendingFriendRequest(String e);

  /// No description provided for @playerDetails_removeFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Friend'**
  String get playerDetails_removeFriendTitle;

  /// No description provided for @playerDetails_removeFriendConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from your friends list?'**
  String playerDetails_removeFriendConfirmation(String name);

  /// No description provided for @playerDetails_removeButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get playerDetails_removeButton;

  /// No description provided for @playerDetails_friendRemovedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{name} removed from Friends'**
  String playerDetails_friendRemovedSnackbar(String name);

  /// No description provided for @playerDetails_errorRemovingFriend.
  ///
  /// In en, this message translates to:
  /// **'Error removing friend: {e}'**
  String playerDetails_errorRemovingFriend(String e);

  /// No description provided for @playerDetails_friendsButton.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get playerDetails_friendsButton;

  /// No description provided for @playerDetails_requestPendingButton.
  ///
  /// In en, this message translates to:
  /// **'Request Pending'**
  String get playerDetails_requestPendingButton;

  /// No description provided for @playerDetails_addFriendButton.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get playerDetails_addFriendButton;

  /// No description provided for @playerDetails_playerIDLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String playerDetails_playerIDLabel(String id);

  /// No description provided for @playerDetails_statMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get playerDetails_statMatches;

  /// No description provided for @playerDetails_statFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get playerDetails_statFriends;

  /// No description provided for @playerDetails_statSquads.
  ///
  /// In en, this message translates to:
  /// **'Squads'**
  String get playerDetails_statSquads;

  /// No description provided for @playerDetails_playerInfoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Player Info'**
  String get playerDetails_playerInfoSectionTitle;

  /// No description provided for @playerDetails_nationalityLabel.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get playerDetails_nationalityLabel;

  /// No description provided for @playerDetails_notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get playerDetails_notSet;

  /// No description provided for @playerDetails_positionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get playerDetails_positionLabel;

  /// No description provided for @playerDetails_ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get playerDetails_ageLabel;

  /// No description provided for @playerDetails_ageValue.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String playerDetails_ageValue(String age);

  /// No description provided for @playerDetails_skillLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Skill Level'**
  String get playerDetails_skillLevelLabel;

  /// No description provided for @playerDetails_memberSinceLabel.
  ///
  /// In en, this message translates to:
  /// **'Member Since'**
  String get playerDetails_memberSinceLabel;

  /// No description provided for @playerDetails_errorParsingJoinedDate.
  ///
  /// In en, this message translates to:
  /// **'Error parsing joined date: {e}'**
  String playerDetails_errorParsingJoinedDate(String e);

  /// No description provided for @playerDetails_addFriendDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get playerDetails_addFriendDialogTitle;

  /// No description provided for @playerDetails_addFriendDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Do you want to add {name} as a friend?'**
  String playerDetails_addFriendDialogContent(String name);

  /// No description provided for @playerDetails_addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get playerDetails_addButton;

  /// No description provided for @playerDetails_joinSquadDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Squad'**
  String get playerDetails_joinSquadDialogTitle;

  /// No description provided for @playerDetails_joinSquadDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Do you want to ask to join the squad {squadName}?'**
  String playerDetails_joinSquadDialogContent(String squadName);

  /// No description provided for @playerDetails_requestToJoinButton.
  ///
  /// In en, this message translates to:
  /// **'Request to Join'**
  String get playerDetails_requestToJoinButton;

  /// No description provided for @playerDetails_requestSentToJoinSquadSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Request sent to join {squadName}'**
  String playerDetails_requestSentToJoinSquadSnackbar(String squadName);

  /// No description provided for @mainScreen_navMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get mainScreen_navMatches;

  /// No description provided for @mainScreen_navBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get mainScreen_navBook;

  /// No description provided for @mainScreen_navSquads.
  ///
  /// In en, this message translates to:
  /// **'Squads'**
  String get mainScreen_navSquads;

  /// No description provided for @mainScreen_navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get mainScreen_navProfile;

  /// No description provided for @mainScreen_errorGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {e}'**
  String mainScreen_errorGettingLocation(String e);

  /// No description provided for @joinBookings_joinOpenMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Open Matches'**
  String get joinBookings_joinOpenMatchesTitle;

  /// No description provided for @joinBookings_failedToLoadOpenMatches.
  ///
  /// In en, this message translates to:
  /// **'Failed to load open matches'**
  String get joinBookings_failedToLoadOpenMatches;

  /// No description provided for @joinBookings_filterMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Matches'**
  String get joinBookings_filterMatchesTitle;

  /// No description provided for @joinBookings_locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get joinBookings_locationLabel;

  /// No description provided for @joinBookings_resetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get joinBookings_resetButton;

  /// No description provided for @joinBookings_applyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get joinBookings_applyButton;

  /// No description provided for @joinBookings_noOpenMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No Open Matches'**
  String get joinBookings_noOpenMatchesTitle;

  /// No description provided for @joinBookings_noOpenMatchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'There are no open matches available for this date. Try another date or create your own booking.'**
  String get joinBookings_noOpenMatchesSubtitle;

  /// No description provided for @joinBookings_bookAFieldButton.
  ///
  /// In en, this message translates to:
  /// **'Book a Field'**
  String get joinBookings_bookAFieldButton;

  /// No description provided for @joinBookings_durationInMinutes.
  ///
  /// In en, this message translates to:
  /// **'{duration} mins'**
  String joinBookings_durationInMinutes(int duration);

  /// No description provided for @joinBookings_hostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get joinBookings_hostLabel;

  /// No description provided for @joinBookings_loadingHost.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get joinBookings_loadingHost;

  /// No description provided for @joinBookings_spotsLeft.
  ///
  /// In en, this message translates to:
  /// **'{spotsLeft} Spot(s) Left'**
  String joinBookings_spotsLeft(int spotsLeft);

  /// No description provided for @joinBookings_matchFull.
  ///
  /// In en, this message translates to:
  /// **'Match Full'**
  String get joinBookings_matchFull;

  /// No description provided for @joinBookings_playersLabel.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get joinBookings_playersLabel;

  /// No description provided for @joinBookings_errorFetchingHostInfo.
  ///
  /// In en, this message translates to:
  /// **'Error fetching host info for booking card: {e}'**
  String joinBookings_errorFetchingHostInfo(String e);

  /// No description provided for @joinBookings_successfullyJoinedMatch.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined the match!'**
  String get joinBookings_successfullyJoinedMatch;

  /// No description provided for @joinBookings_failedToJoinMatch.
  ///
  /// In en, this message translates to:
  /// **'Failed to join match. Please try again.'**
  String get joinBookings_failedToJoinMatch;

  /// No description provided for @chooseYourPositionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Position'**
  String get chooseYourPositionTitle;

  /// No description provided for @chooseYourPositionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the position that best matches your playing style'**
  String get chooseYourPositionSubtitle;

  /// No description provided for @positionGoalkeeperTitle.
  ///
  /// In en, this message translates to:
  /// **'Goalkeeper (GK)'**
  String get positionGoalkeeperTitle;

  /// No description provided for @positionGoalkeeperDescription.
  ///
  /// In en, this message translates to:
  /// **'Shot-stopper and play initiator.'**
  String get positionGoalkeeperDescription;

  /// No description provided for @positionLastManDefenderTitle.
  ///
  /// In en, this message translates to:
  /// **'Last Man Defender'**
  String get positionLastManDefenderTitle;

  /// No description provided for @positionLastManDefenderDescription.
  ///
  /// In en, this message translates to:
  /// **'Defensive backbone of the team.'**
  String get positionLastManDefenderDescription;

  /// No description provided for @positionWingerTitle.
  ///
  /// In en, this message translates to:
  /// **'Winger'**
  String get positionWingerTitle;

  /// No description provided for @positionWingerDescription.
  ///
  /// In en, this message translates to:
  /// **'Fast player focused on creating chances.'**
  String get positionWingerDescription;

  /// No description provided for @positionStrikerTitle.
  ///
  /// In en, this message translates to:
  /// **'Striker'**
  String get positionStrikerTitle;

  /// No description provided for @positionStrikerDescription.
  ///
  /// In en, this message translates to:
  /// **'Forward focused on scoring goals.'**
  String get positionStrikerDescription;

  /// No description provided for @positionAllRounderTitle.
  ///
  /// In en, this message translates to:
  /// **'All Rounder'**
  String get positionAllRounderTitle;

  /// No description provided for @positionAllRounderDescription.
  ///
  /// In en, this message translates to:
  /// **'Versatile player for multiple positions.'**
  String get positionAllRounderDescription;

  /// No description provided for @selectYourLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Your Level'**
  String get selectYourLevelTitle;

  /// No description provided for @selectYourLevelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the level that best matches your football skills'**
  String get selectYourLevelSubtitle;

  /// No description provided for @levelExpertLockReason.
  ///
  /// In en, this message translates to:
  /// **'Play {gamesPlayed}/10 matches to unlock'**
  String levelExpertLockReason(int gamesPlayed);

  /// No description provided for @levelUnlockedBadge.
  ///
  /// In en, this message translates to:
  /// **'Unlocked!'**
  String get levelUnlockedBadge;

  /// No description provided for @levelLockedBadge.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get levelLockedBadge;

  /// No description provided for @levelAlmostUnlockedBadge.
  ///
  /// In en, this message translates to:
  /// **'Almost'**
  String get levelAlmostUnlockedBadge;

  /// No description provided for @yourPlayingStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Playing Style'**
  String get yourPlayingStyleTitle;

  /// No description provided for @tellUsAboutYourGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your game'**
  String get tellUsAboutYourGameTitle;

  /// No description provided for @tellUsAboutYourGameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps us match you with the right players and fields'**
  String get tellUsAboutYourGameSubtitle;

  /// No description provided for @preferredPositionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'PREFERRED POSITION'**
  String get preferredPositionSectionTitle;

  /// No description provided for @selectYourPositionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select your position'**
  String get selectYourPositionPlaceholder;

  /// No description provided for @yourLevelSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR LEVEL'**
  String get yourLevelSectionTitle;

  /// No description provided for @selectYourLevelPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select your level'**
  String get selectYourLevelPlaceholder;

  /// No description provided for @selectedPositionCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get selectedPositionCardLabel;

  /// No description provided for @selectedLevelCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Skill Level'**
  String get selectedLevelCardLabel;

  /// No description provided for @errorUpdatingProfileSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Error updating profile: {error}'**
  String errorUpdatingProfileSnackbar(String error);

  /// No description provided for @partner_loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Partner Login'**
  String get partner_loginTitle;

  /// No description provided for @partner_loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your field'**
  String get partner_loginSubtitle;

  /// No description provided for @partner_emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get partner_emailLabel;

  /// No description provided for @partner_emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get partner_emailHint;

  /// No description provided for @partner_passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get partner_passwordLabel;

  /// No description provided for @partner_passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get partner_passwordHint;

  /// No description provided for @partner_signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get partner_signInButton;

  /// No description provided for @partner_signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get partner_signingIn;

  /// No description provided for @partner_selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get partner_selectLanguage;

  /// No description provided for @partner_bookingsTab.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get partner_bookingsTab;

  /// No description provided for @partner_revenueTab.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get partner_revenueTab;

  /// No description provided for @partner_bookings_title.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get partner_bookings_title;

  /// No description provided for @partner_bookings_dateFormat.
  ///
  /// In en, this message translates to:
  /// **'EEE, MMM d, yyyy'**
  String get partner_bookings_dateFormat;

  /// No description provided for @partner_bookings_noTimeslotsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No timeslots configured'**
  String get partner_bookings_noTimeslotsConfigured;

  /// No description provided for @partner_bookings_available.
  ///
  /// In en, this message translates to:
  /// **'Available - Tap to book'**
  String get partner_bookings_available;

  /// No description provided for @partner_bookings_userBooking.
  ///
  /// In en, this message translates to:
  /// **'User Booking'**
  String get partner_bookings_userBooking;

  /// No description provided for @partner_bookings_partnerBooking.
  ///
  /// In en, this message translates to:
  /// **'Partner Booking'**
  String get partner_bookings_partnerBooking;

  /// No description provided for @partner_bookings_price.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get partner_bookings_price;

  /// No description provided for @partner_bookings_egp.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get partner_bookings_egp;

  /// No description provided for @partner_bookings_weekly.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY'**
  String get partner_bookings_weekly;

  /// No description provided for @partner_bookings_daily.
  ///
  /// In en, this message translates to:
  /// **'DAILY'**
  String get partner_bookings_daily;

  /// No description provided for @partner_bookingDetails_title.
  ///
  /// In en, this message translates to:
  /// **'Booking Details'**
  String get partner_bookingDetails_title;

  /// No description provided for @partner_bookingDetails_host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get partner_bookingDetails_host;

  /// No description provided for @partner_bookingDetails_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get partner_bookingDetails_phone;

  /// No description provided for @partner_bookingDetails_price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get partner_bookingDetails_price;

  /// No description provided for @partner_bookingDetails_recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get partner_bookingDetails_recurring;

  /// No description provided for @partner_bookingDetails_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get partner_bookingDetails_notes;

  /// No description provided for @partner_createBooking_title.
  ///
  /// In en, this message translates to:
  /// **'Create Booking'**
  String get partner_createBooking_title;

  /// No description provided for @partner_createBooking_timeAndPrice.
  ///
  /// In en, this message translates to:
  /// **'{time} • EGP {price}'**
  String partner_createBooking_timeAndPrice(String time, int price);

  /// No description provided for @partner_createBooking_customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name *'**
  String get partner_createBooking_customerName;

  /// No description provided for @partner_createBooking_customerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter customer name'**
  String get partner_createBooking_customerNameHint;

  /// No description provided for @partner_createBooking_phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number *'**
  String get partner_createBooking_phoneNumber;

  /// No description provided for @partner_createBooking_phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get partner_createBooking_phoneNumberHint;

  /// No description provided for @partner_createBooking_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get partner_createBooking_notes;

  /// No description provided for @partner_createBooking_notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get partner_createBooking_notesOptional;

  /// No description provided for @partner_createBooking_notesHint.
  ///
  /// In en, this message translates to:
  /// **'Any additional notes'**
  String get partner_createBooking_notesHint;

  /// No description provided for @partner_createBooking_makeRecurring.
  ///
  /// In en, this message translates to:
  /// **'Make this a recurring booking'**
  String get partner_createBooking_makeRecurring;

  /// No description provided for @partner_createBooking_repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get partner_createBooking_repeat;

  /// No description provided for @partner_createBooking_daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get partner_createBooking_daily;

  /// No description provided for @partner_createBooking_weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get partner_createBooking_weekly;

  /// No description provided for @partner_createBooking_endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date (Optional)'**
  String get partner_createBooking_endDate;

  /// No description provided for @partner_createBooking_endDateOptional.
  ///
  /// In en, this message translates to:
  /// **'End Date (Optional)'**
  String get partner_createBooking_endDateOptional;

  /// No description provided for @partner_createBooking_selectEndDate.
  ///
  /// In en, this message translates to:
  /// **'Select end date (continues indefinitely)'**
  String get partner_createBooking_selectEndDate;

  /// No description provided for @partner_createBooking_endDateHint.
  ///
  /// In en, this message translates to:
  /// **'Select end date (continues indefinitely)'**
  String get partner_createBooking_endDateHint;

  /// No description provided for @partner_createBooking_endDateSelected.
  ///
  /// In en, this message translates to:
  /// **'MMM d, yyyy'**
  String get partner_createBooking_endDateSelected;

  /// No description provided for @partner_createBooking_cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get partner_createBooking_cancelButton;

  /// No description provided for @partner_createBooking_create.
  ///
  /// In en, this message translates to:
  /// **'Create Booking'**
  String get partner_createBooking_create;

  /// No description provided for @partner_createBooking_createButton.
  ///
  /// In en, this message translates to:
  /// **'Create Booking'**
  String get partner_createBooking_createButton;

  /// No description provided for @partner_createBooking_fillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get partner_createBooking_fillRequired;

  /// No description provided for @partner_createBooking_createdSuccess.
  ///
  /// In en, this message translates to:
  /// **'Booking created successfully!'**
  String get partner_createBooking_createdSuccess;

  /// No description provided for @partner_createBooking_createdSuccessRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring booking created successfully!'**
  String get partner_createBooking_createdSuccessRecurring;

  /// No description provided for @partner_createBooking_error.
  ///
  /// In en, this message translates to:
  /// **'Error creating booking: {error}'**
  String partner_createBooking_error(String error);

  /// No description provided for @partner_revenue_title.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get partner_revenue_title;

  /// No description provided for @partner_revenue_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get partner_revenue_settings;

  /// No description provided for @partner_revenue_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get partner_revenue_language;

  /// No description provided for @partner_signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get partner_signOut;

  /// No description provided for @partner_signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get partner_signOutConfirm;

  /// No description provided for @partner_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get partner_cancel;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
