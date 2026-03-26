// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Playmaker';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get done => 'Done';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get search => 'Search';

  @override
  String get submit => 'Submit';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get logout => 'Logout';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get playerDetails => 'Player Details';

  @override
  String get settings => 'Settings';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get profileUpdated => 'Profile Updated Successfully';

  @override
  String get name => 'Name';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get age => 'Age';

  @override
  String get nationality => 'Nationality';

  @override
  String get playerId => 'Player ID';

  @override
  String get position => 'Position';

  @override
  String get level => 'Level';

  @override
  String get joined => 'Joined';

  @override
  String get beginner => 'Beginner';

  @override
  String get levelBeginnerDescription =>
      'New to football, learning the basics.';

  @override
  String get casual => 'Casual';

  @override
  String get levelCasualDescription => 'Plays regularly, understands the game.';

  @override
  String get skilled => 'Skilled';

  @override
  String get levelSkilledDescription =>
      'Good technical skills, tactical awareness.';

  @override
  String get elite => 'Elite';

  @override
  String get levelEliteDescription => 'Strong player, makes an impact.';

  @override
  String get expert => 'Expert';

  @override
  String get levelExpertDescription => 'High-level skills, dominates matches.';

  @override
  String get skillLevel => 'Skill Level';

  @override
  String get matches => 'Matches';

  @override
  String get squads => 'Squads';

  @override
  String get friends => 'Friends';

  @override
  String get profile => 'Profile';

  @override
  String get fields => 'Fields';

  @override
  String get enterYourName => 'Enter your full name';

  @override
  String get selectPositionAndLevel => 'Select Position & Level';

  @override
  String get preferredPosition => 'Preferred Position';

  @override
  String get completeProfileButton => 'Complete Profile';

  @override
  String playMoreToUnlock(int count) {
    return 'Play $count matches to unlock';
  }

  @override
  String get almostUnlocked => 'Almost';

  @override
  String get justUnlocked => 'Unlocked!';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsConditions => 'Terms & Conditions';

  @override
  String get deleteAccountConfirmation =>
      'This action is permanent. Your profile, bookings, and all associated data will be permanently removed.';

  @override
  String typeToConfirm(Object word) {
    return 'Type \"$word\" to confirm deletion:';
  }

  @override
  String get languageSettingsTitle => 'Language Settings';

  @override
  String get rtlLayoutInfo =>
      'The app will support right-to-left layout automatically when Arabic is selected. This affects all screens and components, providing a seamless experience for Arabic users.';

  @override
  String get birthDateTitle => 'Birth Date';

  @override
  String get hintDD => 'DD';

  @override
  String get hintMM => 'MM';

  @override
  String get hintYYYY => 'YYYY';

  @override
  String get phoneNumberTitle => 'Phone Number';

  @override
  String get hintPhoneNumber => 'Phone number';

  @override
  String get fullNameTitle => 'Full Name';

  @override
  String get hintEnterFullName => 'Enter your full name';

  @override
  String get couldNotFetchUpdatedProfile =>
      'Could not fetch updated profile after image upload.';

  @override
  String get deleteAccountWarningMessage =>
      'This action is permanent. Your profile, bookings, and all associated data will be permanently removed.';

  @override
  String typeToConfirmDeletion(String word) {
    return 'Type \"$word\" to confirm deletion:';
  }

  @override
  String pleaseTypeExactly(String word) {
    return 'Please type exactly \"$word\"';
  }

  @override
  String get accountDeletedSuccess => 'Account successfully deleted';

  @override
  String errorDeletingAccount(String error) {
    return 'Error deleting account: $error';
  }

  @override
  String get logoutConfirmationMessage =>
      'Are you sure you want to log out of your account?';

  @override
  String get createProfileTitle => 'Create Profile';

  @override
  String get signUpToAccessFeatures => 'Sign up to access all features:';

  @override
  String get featureBookFields => 'Book football fields';

  @override
  String get featureJoinCreateSquads => 'Join and create squads';

  @override
  String get featureScheduleMatches => 'Schedule matches';

  @override
  String get featureConnectPlayers => 'Connect with players';

  @override
  String get getStarted => 'Get Started';

  @override
  String get statGames => 'Games';

  @override
  String get statFriends => 'Friends';

  @override
  String get statSquads => 'Squads';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get squadsTabTitle => 'Squads';

  @override
  String get friendsCardTitle => 'Friends';

  @override
  String get connectWithPlayersSubtitle => 'Connect with players';

  @override
  String get friendsStatLabel => 'Friends';

  @override
  String get mySquadsCardTitle => 'My Squads';

  @override
  String get mySquadsCardSubtitle => 'View and manage your teams';

  @override
  String get teamsStatLabel => 'Teams';

  @override
  String get joinSquadsCardTitle => 'Join Squads';

  @override
  String get joinSquadsCardSubtitle => 'Find and join teams in your area';

  @override
  String get createSquadCardTitle => 'Create Squad';

  @override
  String get createSquadCardSubtitle =>
      'Start your own team and recruit players';

  @override
  String get createAccountDialogTitle => 'Create Account';

  @override
  String get createAccountDialogMessage =>
      'Please create an account to access this feature.';

  @override
  String get signUpButton => 'Sign Up';

  @override
  String get playTabTitle => 'Play';

  @override
  String get bookAFieldCardTitle => 'Book a Field';

  @override
  String get bookAFieldCardSubtitle => 'Find and book football fields near you';

  @override
  String get joinMatchesCardTitle => 'Join Matches';

  @override
  String get joinMatchesCardSubtitle => 'Play with others in scheduled matches';

  @override
  String get openMatchesStatLabel => 'Open Matches';

  @override
  String get failedToLoadBookingsSnackbar => 'Failed to load bookings';

  @override
  String get errorFetchingFieldDetailsSnackbar =>
      'Error fetching field details';

  @override
  String get recentlyPlayedFieldsTitle => 'Recently Played Fields';

  @override
  String get yourFavoritePlacesToPlaySubtitle => 'Your favorite places to play';

  @override
  String get bookAgainButton => 'Book Again';

  @override
  String get noRecentlyPlayedFields => 'No recently played fields';

  @override
  String get errorLoadingFields => 'Error loading fields';

  @override
  String get matchDetailsTitle => 'Match Details';

  @override
  String get detailsTab => 'Details';

  @override
  String get chatTab => 'Chat';

  @override
  String get openInGoogleMaps => 'Open in Google Maps';

  @override
  String get couldNotLaunchGoogleMaps => 'Could not launch Google Maps';

  @override
  String get openInAppleMaps => 'Open in Apple Maps';

  @override
  String get couldNotLaunchAppleMaps => 'Could not launch Apple Maps';

  @override
  String get failedToAcceptJoinRequest => 'Failed to accept join request';

  @override
  String get joinRequestPending => 'Join Request Pending';

  @override
  String get joinMatchButton => 'Join Match';

  @override
  String get matchInformationSectionTitle => 'Match Information';

  @override
  String get dateLabel => 'Date';

  @override
  String get timeLabel => 'Time';

  @override
  String get hostLabel => 'Host';

  @override
  String get youSuffix => 'You';

  @override
  String get unableToLoadHost => 'Unable to load host';

  @override
  String get joinRequestsSectionTitle => 'Join Requests';

  @override
  String get playersSectionTitle => 'Players';

  @override
  String playersJoinedCount(String count) {
    return '$count joined';
  }

  @override
  String playersMaxCount(String current, String max) {
    return '$current / $max';
  }

  @override
  String get addPlayersButton => 'Add';

  @override
  String guestLabel(String number) {
    return 'Guest $number';
  }

  @override
  String get invalidGuestEntry => 'Invalid Guest Entry';

  @override
  String get locationSectionTitle => 'Location';

  @override
  String get locationAccessRequired => 'Location access required';

  @override
  String get getDirectionsButton => 'Get Directions';

  @override
  String get joinMatchSheetTitle => 'Join Match';

  @override
  String get joinAloneOption => 'Join Alone';

  @override
  String get joinAloneSubtitle => 'Play with other players';

  @override
  String get joinWithGuestsOption => 'Join with Guests';

  @override
  String get joinWithGuestsSubtitle => 'Bring your friends along';

  @override
  String get numberOfGuestsLabel => 'Number of Guests';

  @override
  String joinWithXGuestsButton(String count) {
    return 'Join with $count Guest(s)';
  }

  @override
  String get joinRequestSent => 'Join request sent!';

  @override
  String failedToSendJoinRequest(String error) {
    return 'Failed to send join request: $error';
  }

  @override
  String get addPlayersSheetTitle => 'Add Players';

  @override
  String get addGuestsOption => 'Add Guests';

  @override
  String get addGuestsSubtitle => 'Add guest players';

  @override
  String get addFriendsOption => 'Add Friends';

  @override
  String get addFriendsSubtitle => 'Add from your friends list';

  @override
  String get addSquadOption => 'Add Squad';

  @override
  String get addSquadSubtitle => 'Add players from your squad';

  @override
  String get selectAction => 'Select Action';

  @override
  String addedXGuestsSnackbar(String count) {
    return 'Added $count guest(s) to the match';
  }

  @override
  String errorAddingGuestsSnackbar(String error) {
    return 'Error adding guests: $error';
  }

  @override
  String addedXPlayersSnackbar(String count) {
    return 'Added $count player(s) to the match';
  }

  @override
  String errorAddingPlayersSnackbar(String error) {
    return 'Error adding players: $error';
  }

  @override
  String get allSquadMembersAlreadyInMatch =>
      'All squad members are already in the match';

  @override
  String cannotAddSquadMembersLimitReached(
      String squadName, String maxPlayers) {
    return 'Cannot add squad members from $squadName. Maximum limit of $maxPlayers reached.';
  }

  @override
  String sentXFriendJoinRequests(String count) {
    return 'Sent $count friend join request(s)';
  }

  @override
  String sentXSquadJoinRequests(String count, String squadName) {
    return 'Sent $count join request(s) for members of $squadName';
  }

  @override
  String requestedToAddXGuests(String count) {
    return 'Requested to add $count guest(s)';
  }

  @override
  String failedToSendGuestAddRequest(String error) {
    return 'Failed to send guest add request: $error';
  }

  @override
  String get minsSuffix => 'mins';

  @override
  String cannotAcceptRequestMaxPlayers(String count, String maxPlayers) {
    return 'Cannot accept request. Adding $count player(s) would exceed the maximum of $maxPlayers.';
  }

  @override
  String playerAddedToMatchSnackbar(String playerName) {
    return '$playerName has been added to the match';
  }

  @override
  String playerAddedWithGuestsSnackbar(String playerName, String guestCount) {
    return '$playerName has been added to the match with $guestCount guests';
  }

  @override
  String guestRequestApprovedSnackbar(String playerName, String guestCount) {
    return '$playerName request to add $guestCount guests approved';
  }

  @override
  String get declinedJoinRequestSnackbar => 'Declined join request';

  @override
  String get failedToDeclineJoinRequestSnackbar =>
      'Failed to decline join request';

  @override
  String errorParsingJoinRequest(String error) {
    return 'Error parsing join request: $error';
  }

  @override
  String errorRefreshingBooking(String error) {
    return 'Error re-fetching booking: $error';
  }

  @override
  String get bookingNotFound => 'Booking not found';

  @override
  String get youAreNotMemberOfSquads => 'You are not a member of any squads';

  @override
  String get selectSquadToRequestTitle => 'Select Squad to Request';

  @override
  String get selectSquadTitle => 'Select Squad';

  @override
  String get membersSuffix => 'members';

  @override
  String matchesTab_errorLoadingFields(String e) {
    return 'Error loading fields: $e';
  }

  @override
  String get matchesTab_unknownPlayer => 'Unknown Player';

  @override
  String matchesTab_errorFetchingHostInfo(String e) {
    return 'Error fetching host info: $e';
  }

  @override
  String get matchesTab_matchInProgress => 'Match in progress';

  @override
  String matchesTab_timeLeftDaysHours(int days, int hours) {
    return '$days day(s), $hours hr(s) left';
  }

  @override
  String matchesTab_timeLeftHoursMinutes(int hours, int minutes) {
    return '$hours hr(s), $minutes min(s) left';
  }

  @override
  String matchesTab_timeLeftMinutes(int minutes) {
    return '$minutes min(s) left';
  }

  @override
  String get matchesTab_startingSoon => 'Starting soon';

  @override
  String matchesTab_errorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get matchesTab_upcoming => 'Upcoming';

  @override
  String get matchesTab_past => 'Past';

  @override
  String get matchesTab_noMatchesFound => 'No matches found';

  @override
  String get matchesTab_startByJoiningOrBooking =>
      'Start by joining a match or booking a field';

  @override
  String get matchesTab_joinAMatch => 'Join a Match';

  @override
  String get matchesTab_loading => 'Loading...';

  @override
  String get matchesTab_completed => 'Completed';

  @override
  String matchesTab_spotsLeft(int spotsLeft) {
    return '$spotsLeft Spot(s) Left';
  }

  @override
  String get matchesTab_matchFull => 'Match Full';

  @override
  String fieldBooking_errorParsingRecurringOriginalDate(String date, String e) {
    return 'Error parsing recurringOriginalDate (\'$date\'): $e';
  }

  @override
  String fieldBooking_errorParsingRecurringEndDate(String date, String e) {
    return 'Error parsing recurringEndDate (\'$date\'): $e';
  }

  @override
  String get fieldBooking_streetAddressNotAvailable =>
      'Street address not available';

  @override
  String get fieldBooking_directions => 'Directions';

  @override
  String fieldBooking_priceRangeEGP(String priceRange) {
    return '$priceRange EGP';
  }

  @override
  String get fieldBooking_selectDate => 'Select Date';

  @override
  String get fieldBooking_today => 'Today';

  @override
  String get fieldBooking_availableTimeSlots => 'Available Time Slots';

  @override
  String get fieldBooking_noTimeSlotsAvailable => 'No time slots available';

  @override
  String get fieldBooking_trySelectingAnotherDate =>
      'Try selecting another date';

  @override
  String fieldBooking_errorParsingTimeSlotForPastCheck(String e) {
    return 'Error parsing timeslot time for \'isPast\' check: $e';
  }

  @override
  String get fieldBooking_booked => 'Booked';

  @override
  String get fieldBooking_pastTimeSlot => 'Past';

  @override
  String get fieldBooking_continueToBooking => 'Continue to Booking';

  @override
  String get fieldBooking_bookingCreatedSuccessfully =>
      'Booking created successfully';

  @override
  String get fieldBooking_available => 'Available';

  @override
  String get fieldBooking_openMatchStatus => 'Open Match';

  @override
  String fieldBooking_durationHours(int duration) {
    return '$duration hours';
  }

  @override
  String fieldBooking_durationHoursMinutes(int hours, String minutes) {
    return '$hours:$minutes hours';
  }

  @override
  String fieldBooking_priceEGP(dynamic price) {
    return '$price EGP';
  }

  @override
  String fieldBooking_photoCounter(int current, int totalPhotos) {
    return '$current / $totalPhotos';
  }

  @override
  String get fieldsListView_locationNewCairo => 'New Cairo';

  @override
  String get fieldsListView_locationNasrCity => 'Nasr City';

  @override
  String get fieldsListView_locationShorouk => 'Shorouk';

  @override
  String get fieldsListView_locationMaadi => 'Maadi';

  @override
  String get fieldsListView_locationSheikhZayed => 'Sheikh Zayed';

  @override
  String get fieldsListView_locationOctober => 'October';

  @override
  String fieldsListView_errorCheckingLocationPermission(String e) {
    return 'Error checking location permission: $e';
  }

  @override
  String fieldsListView_errorFetchingFields(String e) {
    return 'Error fetching fields: $e';
  }

  @override
  String get fieldsListView_viewMap => 'View Map';

  @override
  String get fieldsListView_filter => 'Filter';

  @override
  String fieldsListView_withinRadiusKm(int radius) {
    return 'Within $radius km';
  }

  @override
  String get fieldsListView_createAccountToBook =>
      'Please create an account to book a field.';

  @override
  String get fieldsListView_filterFields => 'Filter Fields';

  @override
  String get fieldsListView_location => 'Location';

  @override
  String get fieldsListView_distance => 'Distance';

  @override
  String get fieldsListView_anyDistance => 'Any Distance';

  @override
  String fieldsListView_radiusKm(int radius) {
    return '$radius km';
  }

  @override
  String get fieldsListView_minRadius => '1 km';

  @override
  String get fieldsListView_maxRadius => '20 km';

  @override
  String get fieldsListView_applyFilters => 'Apply Filters';

  @override
  String fieldsListView_distanceMetersAway(String distance) {
    return '${distance}m away';
  }

  @override
  String fieldsListView_distanceKmAway(String distance) {
    return '${distance}km away';
  }

  @override
  String fieldsListView_priceRangeEgpHour(String priceRange) {
    return '$priceRange EGP/hr';
  }

  @override
  String get fieldsListView_amenityParking => 'Parking';

  @override
  String get fieldsListView_amenityRestrooms => 'Restrooms';

  @override
  String get fieldsListView_amenityCafeteria => 'Cafeteria';

  @override
  String get fieldsListView_amenityFloodlights => 'Floodlights';

  @override
  String get fieldsListView_amenityRecording => 'Recording';

  @override
  String get fieldsListView_noFieldsFound => 'No Fields Found';

  @override
  String get fieldsListView_noFieldsFoundSubtitle =>
      'Try adjusting your filters or location to find available fields in your area.';

  @override
  String get fieldsListView_refresh => 'Refresh';

  @override
  String bookingDetails_playerLimitReachedSomeAdded(int availableSlots) {
    return 'Player limit reached. Only $availableSlots friends were added.';
  }

  @override
  String bookingDetails_playerLimitReachedNoneAdded(int maxPlayers) {
    return 'Player limit of $maxPlayers already reached. Cannot add more players.';
  }

  @override
  String get bookingDetails_matchSettings => 'Match Settings';

  @override
  String get bookingDetails_matchSettingsSubtitle =>
      'Configure your match preferences';

  @override
  String get bookingDetails_privateMatch => 'Private Match';

  @override
  String get bookingDetails_privateMatchSubtitlePrivate =>
      'Players cannot request to join. Private game';

  @override
  String get bookingDetails_privateMatchSubtitleOpen =>
      'Other players can request to join your match';

  @override
  String get bookingDetails_limitMaxPlayers => 'Limit Max Players';

  @override
  String get bookingDetails_limitMaxPlayersSubtitleLimit =>
      'Set a maximum number of players';

  @override
  String get bookingDetails_limitMaxPlayersSubtitleNoLimit =>
      'Allow any number of players to join';

  @override
  String get bookingDetails_cannotDecreaseMaxPlayersTitle =>
      'Cannot Decrease Max Players';

  @override
  String get bookingDetails_cannotDecreaseMaxPlayersMessage =>
      'Please remove some players to decrease the Max Player number.';

  @override
  String get bookingDetails_ok => 'OK';

  @override
  String get bookingDetails_cameraRecording => 'Camera Recording';

  @override
  String bookingDetails_recordingEnabledPrice(int price) {
    return 'Recording enabled (+$price EGP)';
  }

  @override
  String bookingDetails_enableRecordingPrice(int price) {
    return 'Enable camera recording of your match (+$price EGP)';
  }

  @override
  String get bookingDetails_inviteFriendsSubtitle =>
      'Invite friends to join your match';

  @override
  String bookingDetails_playerCountFraction(int current, int max) {
    return '$current / $max Players';
  }

  @override
  String bookingDetails_playerCountAbsolute(int current) {
    return '$current Players';
  }

  @override
  String get bookingDetails_invitePlayers => 'Invite Players';

  @override
  String bookingDetails_playersInvitedCount(int count) {
    return '$count Players Invited';
  }

  @override
  String get bookingDetails_tapToInviteFriends =>
      'Tap to invite friends to your match';

  @override
  String get bookingDetails_bringGuests => 'Bring Guests';

  @override
  String get bookingDetails_addPlayersWithoutAccount =>
      'Add players without an account';

  @override
  String get bookingDetails_matchDescription => 'Match Description';

  @override
  String get bookingDetails_matchDescriptionSubtitle =>
      'Add information for players about your match';

  @override
  String get bookingDetails_matchDescriptionHint =>
      'Example: Friendly match, all skill levels welcome! Bring both light and dark jerseys.';

  @override
  String get bookingDetails_totalAmount => 'Total Amount';

  @override
  String bookingDetails_priceEgp(int price) {
    return '$price EGP';
  }

  @override
  String get bookingDetails_continue => 'Continue';

  @override
  String get bookingDetails_matchType => 'Match Type';

  @override
  String get bookingDetails_matchTypePrivate => 'Private';

  @override
  String get bookingDetails_matchTypePrivateSubtitle => 'Only invited players';

  @override
  String get bookingDetails_matchTypeOpen => 'Open';

  @override
  String get bookingDetails_matchTypeOpenSubtitle => 'Anyone can join';

  @override
  String bookingDetails_durationInMinutes(int duration) {
    return '$duration min';
  }

  @override
  String bookingDetails_durationHoursOnly(int hours) {
    return '${hours}h';
  }

  @override
  String bookingDetails_durationHoursAndMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get paymob_paymentTitle => 'Payment';

  @override
  String get paymentScreen_checkoutTitle => 'Checkout';

  @override
  String get paymentScreen_bookingSummaryTitle => 'Booking Summary';

  @override
  String get paymentScreen_fieldLabel => 'Field';

  @override
  String get paymentScreen_locationLabel => 'Location';

  @override
  String get paymentScreen_dateLabel => 'Date';

  @override
  String get paymentScreen_timeLabel => 'Time';

  @override
  String get paymentScreen_playersLabel => 'Players';

  @override
  String paymentScreen_playersCount(int count) {
    return '$count players';
  }

  @override
  String get paymentScreen_cameraRecordingLabel => 'Camera Recording';

  @override
  String paymentScreen_cameraRecordingEnabledPrice(int price) {
    return 'Enabled (+$price EGP)';
  }

  @override
  String get paymentScreen_fieldRentalLabel => 'Field Rental';

  @override
  String paymentScreen_priceEGP(dynamic price) {
    return '$price EGP';
  }

  @override
  String get paymentScreen_totalPriceLabel => 'Total Price';

  @override
  String get paymentScreen_paymentMethodSectionTitle => 'Payment Method';

  @override
  String get paymentScreen_paymentMethodSectionSubtitle =>
      'Select your preferred payment method';

  @override
  String get paymentScreen_creditCardOption => 'Credit Card';

  @override
  String get paymentScreen_creditCardSubtitle =>
      'Pay with your credit or debit card';

  @override
  String get paymentScreen_cashOption => 'Cash';

  @override
  String get paymentScreen_cashSubtitle => 'Pay cash at the field';

  @override
  String get paymentScreen_mobileWalletOption => 'Mobile Wallet';

  @override
  String get paymentScreen_mobileWalletSubtitle =>
      'Pay with your mobile wallet';

  @override
  String get paymentScreen_payNowButton => 'Pay Now';

  @override
  String paymentScreen_failedToCreateBooking(String e) {
    return 'Failed to create booking: $e';
  }

  @override
  String get paymentScreen_selectMobileWalletTitle => 'Select Mobile Wallet';

  @override
  String get paymentScreen_selectMobileWalletSubtitle =>
      'Choose your preferred payment wallet';

  @override
  String get paymentScreen_vodafoneCash => 'Vodafone Cash';

  @override
  String get paymentScreen_etisalatCash => 'Etisalat Cash';

  @override
  String get paymentScreen_orangeCash => 'Orange Cash';

  @override
  String get paymentScreen_otherWallets => 'Other Wallets';

  @override
  String playerDetails_friendRequestSent(String name) {
    return 'Friend request sent to $name';
  }

  @override
  String playerDetails_errorSendingFriendRequest(String e) {
    return 'Error sending friend request: $e';
  }

  @override
  String get playerDetails_removeFriendTitle => 'Remove Friend';

  @override
  String playerDetails_removeFriendConfirmation(String name) {
    return 'Are you sure you want to remove $name from your friends list?';
  }

  @override
  String get playerDetails_removeButton => 'Remove';

  @override
  String playerDetails_friendRemovedSnackbar(String name) {
    return '$name removed from Friends';
  }

  @override
  String playerDetails_errorRemovingFriend(String e) {
    return 'Error removing friend: $e';
  }

  @override
  String get playerDetails_friendsButton => 'Friends';

  @override
  String get playerDetails_requestPendingButton => 'Request Pending';

  @override
  String get playerDetails_addFriendButton => 'Add Friend';

  @override
  String playerDetails_playerIDLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get playerDetails_statMatches => 'Matches';

  @override
  String get playerDetails_statFriends => 'Friends';

  @override
  String get playerDetails_statSquads => 'Squads';

  @override
  String get playerDetails_playerInfoSectionTitle => 'Player Info';

  @override
  String get playerDetails_nationalityLabel => 'Nationality';

  @override
  String get playerDetails_notSet => 'Not set';

  @override
  String get playerDetails_positionLabel => 'Position';

  @override
  String get playerDetails_ageLabel => 'Age';

  @override
  String playerDetails_ageValue(String age) {
    return '$age years';
  }

  @override
  String get playerDetails_skillLevelLabel => 'Skill Level';

  @override
  String get playerDetails_memberSinceLabel => 'Member Since';

  @override
  String playerDetails_errorParsingJoinedDate(String e) {
    return 'Error parsing joined date: $e';
  }

  @override
  String get playerDetails_addFriendDialogTitle => 'Add Friend';

  @override
  String playerDetails_addFriendDialogContent(String name) {
    return 'Do you want to add $name as a friend?';
  }

  @override
  String get playerDetails_addButton => 'Add';

  @override
  String get playerDetails_joinSquadDialogTitle => 'Join Squad';

  @override
  String playerDetails_joinSquadDialogContent(String squadName) {
    return 'Do you want to ask to join the squad $squadName?';
  }

  @override
  String get playerDetails_requestToJoinButton => 'Request to Join';

  @override
  String playerDetails_requestSentToJoinSquadSnackbar(String squadName) {
    return 'Request sent to join $squadName';
  }

  @override
  String get mainScreen_navMatches => 'Matches';

  @override
  String get mainScreen_navBook => 'Book';

  @override
  String get mainScreen_navSquads => 'Squads';

  @override
  String get mainScreen_navProfile => 'Profile';

  @override
  String mainScreen_errorGettingLocation(String e) {
    return 'Error getting location: $e';
  }

  @override
  String get joinBookings_joinOpenMatchesTitle => 'Join Open Matches';

  @override
  String get joinBookings_failedToLoadOpenMatches =>
      'Failed to load open matches';

  @override
  String get joinBookings_filterMatchesTitle => 'Filter Matches';

  @override
  String get joinBookings_locationLabel => 'Location';

  @override
  String get joinBookings_resetButton => 'Reset';

  @override
  String get joinBookings_applyButton => 'Apply';

  @override
  String get joinBookings_noOpenMatchesTitle => 'No Open Matches';

  @override
  String get joinBookings_noOpenMatchesSubtitle =>
      'There are no open matches available for this date. Try another date or create your own booking.';

  @override
  String get joinBookings_bookAFieldButton => 'Book a Field';

  @override
  String joinBookings_durationInMinutes(int duration) {
    return '$duration mins';
  }

  @override
  String get joinBookings_hostLabel => 'Host';

  @override
  String get joinBookings_loadingHost => 'Loading...';

  @override
  String joinBookings_spotsLeft(int spotsLeft) {
    return '$spotsLeft Spot(s) Left';
  }

  @override
  String get joinBookings_matchFull => 'Match Full';

  @override
  String get joinBookings_playersLabel => 'Players';

  @override
  String joinBookings_errorFetchingHostInfo(String e) {
    return 'Error fetching host info for booking card: $e';
  }

  @override
  String get joinBookings_successfullyJoinedMatch =>
      'Successfully joined the match!';

  @override
  String get joinBookings_failedToJoinMatch =>
      'Failed to join match. Please try again.';

  @override
  String get chooseYourPositionTitle => 'Choose Your Position';

  @override
  String get chooseYourPositionSubtitle =>
      'Select the position that best matches your playing style';

  @override
  String get positionGoalkeeperTitle => 'Goalkeeper (GK)';

  @override
  String get positionGoalkeeperDescription =>
      'Shot-stopper and play initiator.';

  @override
  String get positionLastManDefenderTitle => 'Last Man Defender';

  @override
  String get positionLastManDefenderDescription =>
      'Defensive backbone of the team.';

  @override
  String get positionWingerTitle => 'Winger';

  @override
  String get positionWingerDescription =>
      'Fast player focused on creating chances.';

  @override
  String get positionStrikerTitle => 'Striker';

  @override
  String get positionStrikerDescription => 'Forward focused on scoring goals.';

  @override
  String get positionAllRounderTitle => 'All Rounder';

  @override
  String get positionAllRounderDescription =>
      'Versatile player for multiple positions.';

  @override
  String get selectYourLevelTitle => 'Select Your Level';

  @override
  String get selectYourLevelSubtitle =>
      'Choose the level that best matches your football skills';

  @override
  String levelExpertLockReason(int gamesPlayed) {
    return 'Play $gamesPlayed/10 matches to unlock';
  }

  @override
  String get levelUnlockedBadge => 'Unlocked!';

  @override
  String get levelLockedBadge => 'Locked';

  @override
  String get levelAlmostUnlockedBadge => 'Almost';

  @override
  String get yourPlayingStyleTitle => 'Your Playing Style';

  @override
  String get tellUsAboutYourGameTitle => 'Tell us about your game';

  @override
  String get tellUsAboutYourGameSubtitle =>
      'This helps us match you with the right players and fields';

  @override
  String get preferredPositionSectionTitle => 'PREFERRED POSITION';

  @override
  String get selectYourPositionPlaceholder => 'Select your position';

  @override
  String get yourLevelSectionTitle => 'YOUR LEVEL';

  @override
  String get selectYourLevelPlaceholder => 'Select your level';

  @override
  String get selectedPositionCardLabel => 'Position';

  @override
  String get selectedLevelCardLabel => 'Skill Level';

  @override
  String errorUpdatingProfileSnackbar(String error) {
    return 'Error updating profile: $error';
  }

  @override
  String get partner_loginTitle => 'Partner Login';

  @override
  String get partner_loginSubtitle => 'Sign in to manage your field';

  @override
  String get partner_emailLabel => 'Email';

  @override
  String get partner_emailHint => 'Enter your email';

  @override
  String get partner_passwordLabel => 'Password';

  @override
  String get partner_passwordHint => 'Enter your password';

  @override
  String get partner_signInButton => 'Sign In';

  @override
  String get partner_signingIn => 'Signing in...';

  @override
  String get partner_selectLanguage => 'Select Language';

  @override
  String get partner_bookingsTab => 'Bookings';

  @override
  String get partner_revenueTab => 'Revenue';

  @override
  String get partner_bookings_title => 'Bookings';

  @override
  String get partner_bookings_dateFormat => 'EEE, MMM d, yyyy';

  @override
  String get partner_bookings_noTimeslotsConfigured =>
      'No timeslots configured';

  @override
  String get partner_bookings_available => 'Available - Tap to book';

  @override
  String get partner_bookings_userBooking => 'User Booking';

  @override
  String get partner_bookings_partnerBooking => 'Partner Booking';

  @override
  String get partner_bookings_price => 'EGP';

  @override
  String get partner_bookings_egp => 'EGP';

  @override
  String get partner_bookings_weekly => 'WEEKLY';

  @override
  String get partner_bookings_daily => 'DAILY';

  @override
  String get partner_bookingDetails_title => 'Booking Details';

  @override
  String get partner_bookingDetails_host => 'Host';

  @override
  String get partner_bookingDetails_phone => 'Phone';

  @override
  String get partner_bookingDetails_price => 'Price';

  @override
  String get partner_bookingDetails_recurring => 'Recurring';

  @override
  String get partner_bookingDetails_notes => 'Notes';

  @override
  String get partner_createBooking_title => 'Create Booking';

  @override
  String partner_createBooking_timeAndPrice(String time, int price) {
    return '$time • EGP $price';
  }

  @override
  String get partner_createBooking_customerName => 'Customer Name *';

  @override
  String get partner_createBooking_customerNameHint => 'Enter customer name';

  @override
  String get partner_createBooking_phoneNumber => 'Phone Number *';

  @override
  String get partner_createBooking_phoneNumberHint => 'Enter phone number';

  @override
  String get partner_createBooking_notes => 'Notes (Optional)';

  @override
  String get partner_createBooking_notesOptional => 'Notes (Optional)';

  @override
  String get partner_createBooking_notesHint => 'Any additional notes';

  @override
  String get partner_createBooking_makeRecurring =>
      'Make this a recurring booking';

  @override
  String get partner_createBooking_repeat => 'Repeat';

  @override
  String get partner_createBooking_daily => 'Daily';

  @override
  String get partner_createBooking_weekly => 'Weekly';

  @override
  String get partner_createBooking_endDate => 'End Date (Optional)';

  @override
  String get partner_createBooking_endDateOptional => 'End Date (Optional)';

  @override
  String get partner_createBooking_selectEndDate =>
      'Select end date (continues indefinitely)';

  @override
  String get partner_createBooking_endDateHint =>
      'Select end date (continues indefinitely)';

  @override
  String get partner_createBooking_endDateSelected => 'MMM d, yyyy';

  @override
  String get partner_createBooking_cancelButton => 'Cancel';

  @override
  String get partner_createBooking_create => 'Create Booking';

  @override
  String get partner_createBooking_createButton => 'Create Booking';

  @override
  String get partner_createBooking_fillRequired =>
      'Please fill in all required fields';

  @override
  String get partner_createBooking_createdSuccess =>
      'Booking created successfully!';

  @override
  String get partner_createBooking_createdSuccessRecurring =>
      'Recurring booking created successfully!';

  @override
  String partner_createBooking_error(String error) {
    return 'Error creating booking: $error';
  }

  @override
  String get partner_revenue_title => 'Revenue';

  @override
  String get partner_revenue_settings => 'Settings';

  @override
  String get partner_revenue_language => 'Language';

  @override
  String get partner_signOut => 'Sign Out';

  @override
  String get partner_signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get partner_cancel => 'Cancel';
}
