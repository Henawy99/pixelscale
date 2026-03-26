// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'صانع اللعب';

  @override
  String get next => 'التالي';

  @override
  String get skip => 'تخطي';

  @override
  String get done => 'تم';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get search => 'بحث';

  @override
  String get submit => 'إرسال';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'تسجيل';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get playerDetails => 'تفاصيل اللاعب';

  @override
  String get settings => 'الإعدادات';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get name => 'الاسم';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get age => 'العمر';

  @override
  String get nationality => 'الجنسية';

  @override
  String get playerId => 'معرف اللاعب';

  @override
  String get position => 'المركز';

  @override
  String get level => 'المستوى';

  @override
  String get joined => 'انضم في';

  @override
  String get beginner => 'مبتدئ';

  @override
  String get levelBeginnerDescription => 'جديد في كرة القدم، يتعلم الأساسيات.';

  @override
  String get casual => 'عادي';

  @override
  String get levelCasualDescription => 'يلعب بانتظام، يفهم اللعبة.';

  @override
  String get skilled => 'ماهر';

  @override
  String get levelSkilledDescription => 'مهارات فنية جيدة، وعي تكتيكي.';

  @override
  String get elite => 'نخبة';

  @override
  String get levelEliteDescription => 'لاعب قوي، يحدث تأثيرًا.';

  @override
  String get expert => 'خبير';

  @override
  String get levelExpertDescription =>
      'مهارات عالية المستوى، يسيطر على المباريات.';

  @override
  String get skillLevel => 'مستوى المهارة';

  @override
  String get matches => 'المباريات';

  @override
  String get squads => 'الفرق';

  @override
  String get friends => 'الأصدقاء';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get fields => 'الملاعب';

  @override
  String get enterYourName => 'أدخل اسمك الكامل';

  @override
  String get selectPositionAndLevel => 'اختر المركز والمستوى';

  @override
  String get preferredPosition => 'المركز المفضل';

  @override
  String get completeProfileButton => 'إكمال الملف الشخصي';

  @override
  String playMoreToUnlock(int count) {
    return 'العب $count مباريات لفتح القفل';
  }

  @override
  String get almostUnlocked => 'على وشك الفتح';

  @override
  String get justUnlocked => 'تم الفتح!';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsConditions => 'الشروط والأحكام';

  @override
  String get deleteAccountConfirmation =>
      'هذا الإجراء دائم. سيتم حذف ملفك الشخصي وحجوزاتك وجميع البيانات المرتبطة بشكل دائم.';

  @override
  String typeToConfirm(Object word) {
    return 'اكتب \"$word\" لتأكيد الحذف:';
  }

  @override
  String get languageSettingsTitle => 'إعدادات اللغة';

  @override
  String get rtlLayoutInfo =>
      'سيدعم التطبيق تلقائيًا التخطيط من اليمين إلى اليسار عند تحديد اللغة العربية. يؤثر هذا على جميع الشاشات والمكونات، مما يوفر تجربة سلسة للمستخدمين العرب.';

  @override
  String get birthDateTitle => 'تاريخ الميلاد';

  @override
  String get hintDD => 'يوم';

  @override
  String get hintMM => 'شهر';

  @override
  String get hintYYYY => 'سنة';

  @override
  String get phoneNumberTitle => 'رقم الهاتف';

  @override
  String get hintPhoneNumber => 'رقم الهاتف';

  @override
  String get fullNameTitle => 'الاسم الكامل';

  @override
  String get hintEnterFullName => 'أدخل اسمك الكامل';

  @override
  String get couldNotFetchUpdatedProfile =>
      'لم نتمكن من جلب الملف الشخصي المحدث بعد تحميل الصورة.';

  @override
  String get deleteAccountWarningMessage =>
      'هذا الإجراء دائم. سيتم حذف ملفك الشخصي وحجوزاتك وجميع البيانات المرتبطة بشكل دائم.';

  @override
  String typeToConfirmDeletion(String word) {
    return 'اكتب \"$word\" لتأكيد الحذف:';
  }

  @override
  String pleaseTypeExactly(String word) {
    return 'الرجاء كتابة \"$word\" بالضبط';
  }

  @override
  String get accountDeletedSuccess => 'تم حذف الحساب بنجاح';

  @override
  String errorDeletingAccount(String error) {
    return 'خطأ في حذف الحساب: $error';
  }

  @override
  String get logoutConfirmationMessage =>
      'هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟';

  @override
  String get createProfileTitle => 'إنشاء ملف شخصي';

  @override
  String get signUpToAccessFeatures => 'سجل للدخول إلى جميع الميزات:';

  @override
  String get featureBookFields => 'حجز ملاعب كرة القدم';

  @override
  String get featureJoinCreateSquads => 'الانضمام وإنشاء الفرق';

  @override
  String get featureScheduleMatches => 'جدولة المباريات';

  @override
  String get featureConnectPlayers => 'التواصل مع اللاعبين';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get statGames => 'مباريات';

  @override
  String get statFriends => 'أصدقاء';

  @override
  String get statSquads => 'فرق';

  @override
  String get phoneLabel => 'الهاتف';

  @override
  String get squadsTabTitle => 'الفرق';

  @override
  String get friendsCardTitle => 'الأصدقاء';

  @override
  String get connectWithPlayersSubtitle => 'تواصل مع اللاعبين';

  @override
  String get friendsStatLabel => 'أصدقاء';

  @override
  String get mySquadsCardTitle => 'فرقي';

  @override
  String get mySquadsCardSubtitle => 'عرض وإدارة فرقك';

  @override
  String get teamsStatLabel => 'فرق';

  @override
  String get joinSquadsCardTitle => 'انضم إلى فرق';

  @override
  String get joinSquadsCardSubtitle => 'ابحث وانضم إلى فرق في منطقتك';

  @override
  String get createSquadCardTitle => 'أنشئ فريق';

  @override
  String get createSquadCardSubtitle => 'ابدأ فريقك الخاص وجند لاعبين';

  @override
  String get createAccountDialogTitle => 'أنشئ حساب';

  @override
  String get createAccountDialogMessage =>
      'يرجى إنشاء حساب للوصول إلى هذه الميزة.';

  @override
  String get signUpButton => 'تسجيل';

  @override
  String get playTabTitle => 'العب';

  @override
  String get bookAFieldCardTitle => 'احجز ملعب';

  @override
  String get bookAFieldCardSubtitle => 'ابحث واحجز ملاعب كرة قدم بالقرب منك';

  @override
  String get joinMatchesCardTitle => 'انضم إلى مباريات';

  @override
  String get joinMatchesCardSubtitle => 'العب مع الآخرين في مباريات مجدولة';

  @override
  String get openMatchesStatLabel => 'مباريات متاحة';

  @override
  String get failedToLoadBookingsSnackbar => 'فشل تحميل الحجوزات';

  @override
  String get errorFetchingFieldDetailsSnackbar => 'خطأ في جلب تفاصيل الملعب';

  @override
  String get recentlyPlayedFieldsTitle => 'ملاعب تم اللعب بها مؤخرًا';

  @override
  String get yourFavoritePlacesToPlaySubtitle => 'أماكنك المفضلة للعب';

  @override
  String get bookAgainButton => 'احجز مرة أخرى';

  @override
  String get noRecentlyPlayedFields => 'لا توجد ملاعب تم اللعب بها مؤخرًا';

  @override
  String get errorLoadingFields => 'خطأ في تحميل الملاعب';

  @override
  String get matchDetailsTitle => 'تفاصيل المباراة';

  @override
  String get detailsTab => 'التفاصيل';

  @override
  String get chatTab => 'الدردشة';

  @override
  String get openInGoogleMaps => 'فتح في خرائط جوجل';

  @override
  String get couldNotLaunchGoogleMaps => 'تعذر تشغيل خرائط جوجل';

  @override
  String get openInAppleMaps => 'فتح في خرائط آبل';

  @override
  String get couldNotLaunchAppleMaps => 'تعذر تشغيل خرائط آبل';

  @override
  String get failedToAcceptJoinRequest => 'فشل قبول طلب الانضمام';

  @override
  String get joinRequestPending => 'طلب الانضمام معلق';

  @override
  String get joinMatchButton => 'انضم للمباراة';

  @override
  String get matchInformationSectionTitle => 'معلومات المباراة';

  @override
  String get dateLabel => 'التاريخ';

  @override
  String get timeLabel => 'الوقت';

  @override
  String get hostLabel => 'المضيف';

  @override
  String get youSuffix => 'أنت';

  @override
  String get unableToLoadHost => 'تعذر تحميل المضيف';

  @override
  String get joinRequestsSectionTitle => 'طلبات الانضمام';

  @override
  String get playersSectionTitle => 'اللاعبون';

  @override
  String playersJoinedCount(String count) {
    return '$count انضموا';
  }

  @override
  String playersMaxCount(String current, String max) {
    return '$current / $max';
  }

  @override
  String get addPlayersButton => 'إضافة';

  @override
  String guestLabel(String number) {
    return 'ضيف $number';
  }

  @override
  String get invalidGuestEntry => 'إدخال ضيف غير صالح';

  @override
  String get locationSectionTitle => 'الموقع';

  @override
  String get locationAccessRequired => 'مطلوب الوصول إلى الموقع';

  @override
  String get getDirectionsButton => 'الحصول على الاتجاهات';

  @override
  String get joinMatchSheetTitle => 'الانضمام للمباراة';

  @override
  String get joinAloneOption => 'الانضمام بمفردك';

  @override
  String get joinAloneSubtitle => 'العب مع لاعبين آخرين';

  @override
  String get joinWithGuestsOption => 'الانضمام مع ضيوف';

  @override
  String get joinWithGuestsSubtitle => 'أحضر أصدقائك معك';

  @override
  String get numberOfGuestsLabel => 'عدد الضيوف';

  @override
  String joinWithXGuestsButton(String count) {
    return 'الانضمام مع $count ضيف/ضيوف';
  }

  @override
  String get joinRequestSent => 'تم إرسال طلب الانضمام!';

  @override
  String failedToSendJoinRequest(String error) {
    return 'فشل إرسال طلب الانضمام: $error';
  }

  @override
  String get addPlayersSheetTitle => 'إضافة لاعبين';

  @override
  String get addGuestsOption => 'إضافة ضيوف';

  @override
  String get addGuestsSubtitle => 'إضافة لاعبين ضيوف';

  @override
  String get addFriendsOption => 'إضافة أصدقاء';

  @override
  String get addFriendsSubtitle => 'إضافة من قائمة أصدقائك';

  @override
  String get addSquadOption => 'إضافة فريق';

  @override
  String get addSquadSubtitle => 'إضافة لاعبين من فريقك';

  @override
  String get selectAction => 'اختر إجراء';

  @override
  String addedXGuestsSnackbar(String count) {
    return 'تمت إضافة $count ضيف/ضيوف إلى المباراة';
  }

  @override
  String errorAddingGuestsSnackbar(String error) {
    return 'خطأ في إضافة الضيوف: $error';
  }

  @override
  String addedXPlayersSnackbar(String count) {
    return 'تمت إضافة $count لاعب/لاعبين إلى المباراة';
  }

  @override
  String errorAddingPlayersSnackbar(String error) {
    return 'خطأ في إضافة اللاعبين: $error';
  }

  @override
  String get allSquadMembersAlreadyInMatch =>
      'جميع أعضاء الفريق موجودون بالفعل في المباراة';

  @override
  String cannotAddSquadMembersLimitReached(
      String squadName, String maxPlayers) {
    return 'لا يمكن إضافة أعضاء الفريق من $squadName. تم الوصول إلى الحد الأقصى وهو $maxPlayers.';
  }

  @override
  String sentXFriendJoinRequests(String count) {
    return 'تم إرسال $count طلب/طلبات انضمام صديق';
  }

  @override
  String sentXSquadJoinRequests(String count, String squadName) {
    return 'تم إرسال $count طلب/طلبات انضمام لأعضاء من $squadName';
  }

  @override
  String requestedToAddXGuests(String count) {
    return 'تم طلب إضافة $count ضيف/ضيوف';
  }

  @override
  String failedToSendGuestAddRequest(String error) {
    return 'فشل إرسال طلب إضافة ضيف: $error';
  }

  @override
  String get minsSuffix => 'دقائق';

  @override
  String cannotAcceptRequestMaxPlayers(String count, String maxPlayers) {
    return 'لا يمكن قبول الطلب. إضافة $count لاعب/لاعبين سيتجاوز الحد الأقصى وهو $maxPlayers.';
  }

  @override
  String playerAddedToMatchSnackbar(String playerName) {
    return 'تمت إضافة $playerName إلى المباراة';
  }

  @override
  String playerAddedWithGuestsSnackbar(String playerName, String guestCount) {
    return 'تمت إضافة $playerName إلى المباراة مع $guestCount ضيوف';
  }

  @override
  String guestRequestApprovedSnackbar(String playerName, String guestCount) {
    return 'تمت الموافقة على طلب $playerName لإضافة $guestCount ضيوف';
  }

  @override
  String get declinedJoinRequestSnackbar => 'تم رفض طلب الانضمام';

  @override
  String get failedToDeclineJoinRequestSnackbar => 'فشل رفض طلب الانضمام';

  @override
  String errorParsingJoinRequest(String error) {
    return 'خطأ في تحليل طلب الانضمام: $error';
  }

  @override
  String errorRefreshingBooking(String error) {
    return 'خطأ في إعادة جلب الحجز: $error';
  }

  @override
  String get bookingNotFound => 'الحجز غير موجود';

  @override
  String get youAreNotMemberOfSquads => 'أنت لست عضوا في أي فرق';

  @override
  String get selectSquadToRequestTitle => 'اختر فريقا لطلب الانضمام';

  @override
  String get selectSquadTitle => 'اختر فريق';

  @override
  String get membersSuffix => 'أعضاء';

  @override
  String matchesTab_errorLoadingFields(String e) {
    return 'خطأ في تحميل الملاعب: $e';
  }

  @override
  String get matchesTab_unknownPlayer => 'لاعب غير معروف';

  @override
  String matchesTab_errorFetchingHostInfo(String e) {
    return 'خطأ في جلب معلومات المضيف: $e';
  }

  @override
  String get matchesTab_matchInProgress => 'المباراة جارية';

  @override
  String matchesTab_timeLeftDaysHours(int days, int hours) {
    return 'متبقي $days يوم (أيام), $hours ساعة (ساعات)';
  }

  @override
  String matchesTab_timeLeftHoursMinutes(int hours, int minutes) {
    return 'متبقي $hours ساعة (ساعات), $minutes دقيقة (دقائق)';
  }

  @override
  String matchesTab_timeLeftMinutes(int minutes) {
    return 'متبقي $minutes دقيقة (دقائق)';
  }

  @override
  String get matchesTab_startingSoon => 'تبدأ قريباً';

  @override
  String matchesTab_errorGeneric(String error) {
    return 'خطأ: $error';
  }

  @override
  String get matchesTab_upcoming => 'القادمة';

  @override
  String get matchesTab_past => 'السابقة';

  @override
  String get matchesTab_noMatchesFound => 'لم يتم العثور على مباريات';

  @override
  String get matchesTab_startByJoiningOrBooking =>
      'ابدأ بالانضمام إلى مباراة أو حجز ملعب';

  @override
  String get matchesTab_joinAMatch => 'انضم إلى مباراة';

  @override
  String get matchesTab_loading => 'جاري التحميل...';

  @override
  String get matchesTab_completed => 'مكتملة';

  @override
  String matchesTab_spotsLeft(int spotsLeft) {
    return 'متبقي $spotsLeft مكان/أماكن';
  }

  @override
  String get matchesTab_matchFull => 'المباراة ممتلئة';

  @override
  String fieldBooking_errorParsingRecurringOriginalDate(String date, String e) {
    return 'خطأ في تحليل recurringOriginalDate (\'$date\'): $e';
  }

  @override
  String fieldBooking_errorParsingRecurringEndDate(String date, String e) {
    return 'خطأ في تحليل recurringEndDate (\'$date\'): $e';
  }

  @override
  String get fieldBooking_streetAddressNotAvailable => 'عنوان الشارع غير متوفر';

  @override
  String get fieldBooking_directions => 'الاتجاهات';

  @override
  String fieldBooking_priceRangeEGP(String priceRange) {
    return '$priceRange جنيه مصري';
  }

  @override
  String get fieldBooking_selectDate => 'اختر التاريخ';

  @override
  String get fieldBooking_today => 'اليوم';

  @override
  String get fieldBooking_availableTimeSlots => 'الأوقات المتاحة';

  @override
  String get fieldBooking_noTimeSlotsAvailable => 'لا توجد أوقات متاحة';

  @override
  String get fieldBooking_trySelectingAnotherDate => 'حاول اختيار تاريخ آخر';

  @override
  String fieldBooking_errorParsingTimeSlotForPastCheck(String e) {
    return 'خطأ في تحليل وقت الفترة للتحقق من \'isPast\': $e';
  }

  @override
  String get fieldBooking_booked => 'محجوز';

  @override
  String get fieldBooking_pastTimeSlot => 'فاتت';

  @override
  String get fieldBooking_continueToBooking => 'متابعة إلى الحجز';

  @override
  String get fieldBooking_bookingCreatedSuccessfully => 'تم إنشاء الحجز بنجاح';

  @override
  String get fieldBooking_available => 'متاح';

  @override
  String get fieldBooking_openMatchStatus => 'مباراة مفتوحة';

  @override
  String fieldBooking_durationHours(int duration) {
    return '$duration ساعات';
  }

  @override
  String fieldBooking_durationHoursMinutes(int hours, String minutes) {
    return '$hours:$minutes ساعات';
  }

  @override
  String fieldBooking_priceEGP(dynamic price) {
    return '$price جنيه مصري';
  }

  @override
  String fieldBooking_photoCounter(int current, int totalPhotos) {
    return '$current / $totalPhotos';
  }

  @override
  String get fieldsListView_locationNewCairo => 'القاهرة الجديدة';

  @override
  String get fieldsListView_locationNasrCity => 'مدينة نصر';

  @override
  String get fieldsListView_locationShorouk => 'الشروق';

  @override
  String get fieldsListView_locationMaadi => 'المعادي';

  @override
  String get fieldsListView_locationSheikhZayed => 'الشيخ زايد';

  @override
  String get fieldsListView_locationOctober => 'أكتوبر';

  @override
  String fieldsListView_errorCheckingLocationPermission(String e) {
    return 'خطأ في التحقق من إذن الموقع: $e';
  }

  @override
  String fieldsListView_errorFetchingFields(String e) {
    return 'خطأ في جلب الملاعب: $e';
  }

  @override
  String get fieldsListView_viewMap => 'عرض الخريطة';

  @override
  String get fieldsListView_filter => 'تصفية';

  @override
  String fieldsListView_withinRadiusKm(int radius) {
    return 'في نطاق $radius كم';
  }

  @override
  String get fieldsListView_createAccountToBook => 'يرجى إنشاء حساب لحجز ملعب.';

  @override
  String get fieldsListView_filterFields => 'تصفية الملاعب';

  @override
  String get fieldsListView_location => 'الموقع';

  @override
  String get fieldsListView_distance => 'المسافة';

  @override
  String get fieldsListView_anyDistance => 'أي مسافة';

  @override
  String fieldsListView_radiusKm(int radius) {
    return '$radius كم';
  }

  @override
  String get fieldsListView_minRadius => '1 كم';

  @override
  String get fieldsListView_maxRadius => '20 كم';

  @override
  String get fieldsListView_applyFilters => 'تطبيق الفلاتر';

  @override
  String fieldsListView_distanceMetersAway(String distance) {
    return '$distanceم';
  }

  @override
  String fieldsListView_distanceKmAway(String distance) {
    return '$distanceكم';
  }

  @override
  String fieldsListView_priceRangeEgpHour(String priceRange) {
    return '$priceRange ج.م/ساعة';
  }

  @override
  String get fieldsListView_amenityParking => 'موقف سيارات';

  @override
  String get fieldsListView_amenityRestrooms => 'دورات مياه';

  @override
  String get fieldsListView_amenityCafeteria => 'كافيتريا';

  @override
  String get fieldsListView_amenityFloodlights => 'أضواء كاشفة';

  @override
  String get fieldsListView_amenityRecording => 'تسجيل';

  @override
  String get fieldsListView_noFieldsFound => 'لم يتم العثور على ملاعب';

  @override
  String get fieldsListView_noFieldsFoundSubtitle =>
      'حاول تعديل الفلاتر أو الموقع للعثور على ملاعب متاحة في منطقتك.';

  @override
  String get fieldsListView_refresh => 'تحديث';

  @override
  String bookingDetails_playerLimitReachedSomeAdded(int availableSlots) {
    return 'تم الوصول إلى حد اللاعبين. تمت إضافة $availableSlots أصدقاء فقط.';
  }

  @override
  String bookingDetails_playerLimitReachedNoneAdded(int maxPlayers) {
    return 'تم الوصول إلى حد اللاعبين وهو $maxPlayers. لا يمكن إضافة المزيد من اللاعبين.';
  }

  @override
  String get bookingDetails_matchSettings => 'إعدادات المباراة';

  @override
  String get bookingDetails_matchSettingsSubtitle =>
      'قم بتكوين تفضيلات المباراة الخاصة بك';

  @override
  String get bookingDetails_privateMatch => 'مباراة خاصة';

  @override
  String get bookingDetails_privateMatchSubtitlePrivate =>
      'لا يمكن للاعبين طلب الانضمام. لعبة خاصة';

  @override
  String get bookingDetails_privateMatchSubtitleOpen =>
      'يمكن للاعبين الآخرين طلب الانضمام إلى مباراتك';

  @override
  String get bookingDetails_limitMaxPlayers => 'تحديد الحد الأقصى للاعبين';

  @override
  String get bookingDetails_limitMaxPlayersSubtitleLimit =>
      'حدد الحد الأقصى لعدد اللاعبين';

  @override
  String get bookingDetails_limitMaxPlayersSubtitleNoLimit =>
      'السماح لأي عدد من اللاعبين بالانضمام';

  @override
  String get bookingDetails_cannotDecreaseMaxPlayersTitle =>
      'لا يمكن تقليل الحد الأقصى للاعبين';

  @override
  String get bookingDetails_cannotDecreaseMaxPlayersMessage =>
      'يرجى إزالة بعض اللاعبين لتقليل عدد الحد الأقصى للاعبين.';

  @override
  String get bookingDetails_ok => 'موافق';

  @override
  String get bookingDetails_cameraRecording => 'تسجيل بالكاميرا';

  @override
  String bookingDetails_recordingEnabledPrice(int price) {
    return 'التسجيل مفعل (+$price جنيه مصري)';
  }

  @override
  String bookingDetails_enableRecordingPrice(int price) {
    return 'تفعيل تسجيل المباراة بالكاميرا (+$price جنيه مصري)';
  }

  @override
  String get bookingDetails_inviteFriendsSubtitle =>
      'ادعُ الأصدقاء للانضمام إلى مباراتك';

  @override
  String bookingDetails_playerCountFraction(int current, int max) {
    return '$current / $max لاعبين';
  }

  @override
  String bookingDetails_playerCountAbsolute(int current) {
    return '$current لاعبين';
  }

  @override
  String get bookingDetails_invitePlayers => 'دعوة لاعبين';

  @override
  String bookingDetails_playersInvitedCount(int count) {
    return 'تم دعوة $count لاعبين';
  }

  @override
  String get bookingDetails_tapToInviteFriends =>
      'انقر لدعوة الأصدقاء إلى مباراتك';

  @override
  String get bookingDetails_bringGuests => 'إحضار ضيوف';

  @override
  String get bookingDetails_addPlayersWithoutAccount =>
      'إضافة لاعبين بدون حساب';

  @override
  String get bookingDetails_matchDescription => 'وصف المباراة';

  @override
  String get bookingDetails_matchDescriptionSubtitle =>
      'أضف معلومات للاعبين حول مباراتك';

  @override
  String get bookingDetails_matchDescriptionHint =>
      'مثال: مباراة ودية، جميع مستويات المهارة مرحب بها! أحضروا قمصانًا فاتحة وداكنة.';

  @override
  String get bookingDetails_totalAmount => 'المبلغ الإجمالي';

  @override
  String bookingDetails_priceEgp(int price) {
    return '$price جنيه مصري';
  }

  @override
  String get bookingDetails_continue => 'متابعة';

  @override
  String get bookingDetails_matchType => 'نوع المباراة';

  @override
  String get bookingDetails_matchTypePrivate => 'خاصة';

  @override
  String get bookingDetails_matchTypePrivateSubtitle => 'اللاعبون المدعوون فقط';

  @override
  String get bookingDetails_matchTypeOpen => 'مفتوحة';

  @override
  String get bookingDetails_matchTypeOpenSubtitle => 'يمكن لأي شخص الانضمام';

  @override
  String bookingDetails_durationInMinutes(int duration) {
    return '$duration دقيقة';
  }

  @override
  String bookingDetails_durationHoursOnly(int hours) {
    return '$hours س';
  }

  @override
  String bookingDetails_durationHoursAndMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String get paymob_paymentTitle => 'الدفع';

  @override
  String get paymentScreen_checkoutTitle => 'الدفع';

  @override
  String get paymentScreen_bookingSummaryTitle => 'ملخص الحجز';

  @override
  String get paymentScreen_fieldLabel => 'الملعب';

  @override
  String get paymentScreen_locationLabel => 'الموقع';

  @override
  String get paymentScreen_dateLabel => 'التاريخ';

  @override
  String get paymentScreen_timeLabel => 'الوقت';

  @override
  String get paymentScreen_playersLabel => 'اللاعبون';

  @override
  String paymentScreen_playersCount(int count) {
    return '$count لاعبين';
  }

  @override
  String get paymentScreen_cameraRecordingLabel => 'تسجيل بالكاميرا';

  @override
  String paymentScreen_cameraRecordingEnabledPrice(int price) {
    return 'مفعل (+$price جنيه مصري)';
  }

  @override
  String get paymentScreen_fieldRentalLabel => 'إيجار الملعب';

  @override
  String paymentScreen_priceEGP(dynamic price) {
    return '$price جنيه مصري';
  }

  @override
  String get paymentScreen_totalPriceLabel => 'السعر الإجمالي';

  @override
  String get paymentScreen_paymentMethodSectionTitle => 'طريقة الدفع';

  @override
  String get paymentScreen_paymentMethodSectionSubtitle =>
      'اختر طريقة الدفع المفضلة لديك';

  @override
  String get paymentScreen_creditCardOption => 'بطاقة ائتمان';

  @override
  String get paymentScreen_creditCardSubtitle =>
      'ادفع ببطاقة الائتمان أو الخصم الخاصة بك';

  @override
  String get paymentScreen_cashOption => 'نقداً';

  @override
  String get paymentScreen_cashSubtitle => 'ادفع نقداً في الملعب';

  @override
  String get paymentScreen_mobileWalletOption => 'محفظة الهاتف المحمول';

  @override
  String get paymentScreen_mobileWalletSubtitle =>
      'ادفع بمحفظة الهاتف المحمول الخاصة بك';

  @override
  String get paymentScreen_payNowButton => 'ادفع الآن';

  @override
  String paymentScreen_failedToCreateBooking(String e) {
    return 'فشل إنشاء الحجز: $e';
  }

  @override
  String get paymentScreen_selectMobileWalletTitle =>
      'اختر محفظة الهاتف المحمول';

  @override
  String get paymentScreen_selectMobileWalletSubtitle =>
      'اختر محفظة الدفع المفضلة لديك';

  @override
  String get paymentScreen_vodafoneCash => 'فودافون كاش';

  @override
  String get paymentScreen_etisalatCash => 'اتصالات كاش';

  @override
  String get paymentScreen_orangeCash => 'أورانج كاش';

  @override
  String get paymentScreen_otherWallets => 'محافظ أخرى';

  @override
  String playerDetails_friendRequestSent(String name) {
    return 'تم إرسال طلب صداقة إلى $name';
  }

  @override
  String playerDetails_errorSendingFriendRequest(String e) {
    return 'خطأ في إرسال طلب الصداقة: $e';
  }

  @override
  String get playerDetails_removeFriendTitle => 'إزالة صديق';

  @override
  String playerDetails_removeFriendConfirmation(String name) {
    return 'هل أنت متأكد أنك تريد إزالة $name من قائمة أصدقائك؟';
  }

  @override
  String get playerDetails_removeButton => 'إزالة';

  @override
  String playerDetails_friendRemovedSnackbar(String name) {
    return 'تمت إزالة $name من الأصدقاء';
  }

  @override
  String playerDetails_errorRemovingFriend(String e) {
    return 'خطأ في إزالة الصديق: $e';
  }

  @override
  String get playerDetails_friendsButton => 'أصدقاء';

  @override
  String get playerDetails_requestPendingButton => 'الطلب معلق';

  @override
  String get playerDetails_addFriendButton => 'إضافة صديق';

  @override
  String playerDetails_playerIDLabel(String id) {
    return 'المعرف: $id';
  }

  @override
  String get playerDetails_statMatches => 'مباريات';

  @override
  String get playerDetails_statFriends => 'أصدقاء';

  @override
  String get playerDetails_statSquads => 'فرق';

  @override
  String get playerDetails_playerInfoSectionTitle => 'معلومات اللاعب';

  @override
  String get playerDetails_nationalityLabel => 'الجنسية';

  @override
  String get playerDetails_notSet => 'غير محدد';

  @override
  String get playerDetails_positionLabel => 'المركز';

  @override
  String get playerDetails_ageLabel => 'العمر';

  @override
  String playerDetails_ageValue(String age) {
    return '$age سنوات';
  }

  @override
  String get playerDetails_skillLevelLabel => 'مستوى المهارة';

  @override
  String get playerDetails_memberSinceLabel => 'عضو منذ';

  @override
  String playerDetails_errorParsingJoinedDate(String e) {
    return 'خطأ في تحليل تاريخ الانضمام: $e';
  }

  @override
  String get playerDetails_addFriendDialogTitle => 'إضافة صديق';

  @override
  String playerDetails_addFriendDialogContent(String name) {
    return 'هل تريد إضافة $name كصديق؟';
  }

  @override
  String get playerDetails_addButton => 'إضافة';

  @override
  String get playerDetails_joinSquadDialogTitle => 'الانضمام إلى فريق';

  @override
  String playerDetails_joinSquadDialogContent(String squadName) {
    return 'هل تريد طلب الانضمام إلى فريق $squadName؟';
  }

  @override
  String get playerDetails_requestToJoinButton => 'طلب الانضمام';

  @override
  String playerDetails_requestSentToJoinSquadSnackbar(String squadName) {
    return 'تم إرسال طلب الانضمام إلى $squadName';
  }

  @override
  String get mainScreen_navMatches => 'المباريات';

  @override
  String get mainScreen_navBook => 'احجز';

  @override
  String get mainScreen_navSquads => 'الفرق';

  @override
  String get mainScreen_navProfile => 'الملف الشخصي';

  @override
  String mainScreen_errorGettingLocation(String e) {
    return 'خطأ في الحصول على الموقع: $e';
  }

  @override
  String get joinBookings_joinOpenMatchesTitle =>
      'الانضمام إلى المباريات المفتوحة';

  @override
  String get joinBookings_failedToLoadOpenMatches =>
      'فشل تحميل المباريات المفتوحة';

  @override
  String get joinBookings_filterMatchesTitle => 'تصفية المباريات';

  @override
  String get joinBookings_locationLabel => 'الموقع';

  @override
  String get joinBookings_resetButton => 'إعادة تعيين';

  @override
  String get joinBookings_applyButton => 'تطبيق';

  @override
  String get joinBookings_noOpenMatchesTitle => 'لا توجد مباريات مفتوحة';

  @override
  String get joinBookings_noOpenMatchesSubtitle =>
      'لا توجد مباريات مفتوحة متاحة لهذا التاريخ. حاول تاريخًا آخر أو قم بإنشاء حجز خاص بك.';

  @override
  String get joinBookings_bookAFieldButton => 'احجز ملعبًا';

  @override
  String joinBookings_durationInMinutes(int duration) {
    return '$duration دقيقة';
  }

  @override
  String get joinBookings_hostLabel => 'المضيف';

  @override
  String get joinBookings_loadingHost => 'جاري التحميل...';

  @override
  String joinBookings_spotsLeft(int spotsLeft) {
    return 'متبقي $spotsLeft مكان/أماكن';
  }

  @override
  String get joinBookings_matchFull => 'المباراة ممتلئة';

  @override
  String get joinBookings_playersLabel => 'اللاعبون';

  @override
  String joinBookings_errorFetchingHostInfo(String e) {
    return 'خطأ في جلب معلومات المضيف لبطاقة الحجز: $e';
  }

  @override
  String get joinBookings_successfullyJoinedMatch =>
      'تم الانضمام إلى المباراة بنجاح!';

  @override
  String get joinBookings_failedToJoinMatch =>
      'فشل الانضمام إلى المباراة. يرجى المحاولة مرة أخرى.';

  @override
  String get chooseYourPositionTitle => 'اختر مركزك';

  @override
  String get chooseYourPositionSubtitle =>
      'اختر المركز الذي يناسب أسلوب لعبك بشكل أفضل';

  @override
  String get positionGoalkeeperTitle => 'حارس مرمى (GK)';

  @override
  String get positionGoalkeeperDescription => 'حارس مرمى ومبادر باللعب.';

  @override
  String get positionLastManDefenderTitle => 'آخر مدافع';

  @override
  String get positionLastManDefenderDescription =>
      'العمود الفقري الدفاعي للفريق.';

  @override
  String get positionWingerTitle => 'جناح';

  @override
  String get positionWingerDescription => 'لاعب سريع يركز على خلق الفرص.';

  @override
  String get positionStrikerTitle => 'مهاجم';

  @override
  String get positionStrikerDescription => 'مهاجم يركز على تسجيل الأهداف.';

  @override
  String get positionAllRounderTitle => 'لاعب شامل';

  @override
  String get positionAllRounderDescription =>
      'لاعب متعدد الاستخدامات لعدة مراكز.';

  @override
  String get selectYourLevelTitle => 'اختر مستواك';

  @override
  String get selectYourLevelSubtitle =>
      'اختر المستوى الذي يناسب مهاراتك في كرة القدم بشكل أفضل';

  @override
  String levelExpertLockReason(int gamesPlayed) {
    return 'العب $gamesPlayed/10 مباريات لفتح القفل';
  }

  @override
  String get levelUnlockedBadge => 'تم الفتح!';

  @override
  String get levelLockedBadge => 'مقفل';

  @override
  String get levelAlmostUnlockedBadge => 'وشيك';

  @override
  String get yourPlayingStyleTitle => 'أسلوب لعبك';

  @override
  String get tellUsAboutYourGameTitle => 'أخبرنا عن لعبك';

  @override
  String get tellUsAboutYourGameSubtitle =>
      'يساعدنا هذا في التوفيق بينك وبين اللاعبين والملاعب المناسبة';

  @override
  String get preferredPositionSectionTitle => 'المركز المفضل';

  @override
  String get selectYourPositionPlaceholder => 'اختر مركزك';

  @override
  String get yourLevelSectionTitle => 'مستواك';

  @override
  String get selectYourLevelPlaceholder => 'اختر مستواك';

  @override
  String get selectedPositionCardLabel => 'المركز';

  @override
  String get selectedLevelCardLabel => 'مستوى المهارة';

  @override
  String errorUpdatingProfileSnackbar(String error) {
    return 'خطأ في تحديث الملف الشخصي: $error';
  }

  @override
  String get partner_loginTitle => 'تسجيل دخول الشريك';

  @override
  String get partner_loginSubtitle => 'قم بتسجيل الدخول لإدارة ملعبك';

  @override
  String get partner_emailLabel => 'البريد الإلكتروني';

  @override
  String get partner_emailHint => 'أدخل بريدك الإلكتروني';

  @override
  String get partner_passwordLabel => 'كلمة المرور';

  @override
  String get partner_passwordHint => 'أدخل كلمة المرور';

  @override
  String get partner_signInButton => 'تسجيل الدخول';

  @override
  String get partner_signingIn => 'جاري تسجيل الدخول...';

  @override
  String get partner_selectLanguage => 'اختر اللغة';

  @override
  String get partner_bookingsTab => 'الحجوزات';

  @override
  String get partner_revenueTab => 'الإيرادات';

  @override
  String get partner_bookings_title => 'الحجوزات';

  @override
  String get partner_bookings_dateFormat => 'EEE، d MMM، yyyy';

  @override
  String get partner_bookings_noTimeslotsConfigured => 'لا توجد أوقات محددة';

  @override
  String get partner_bookings_available => 'متاح - اضغط للحجز';

  @override
  String get partner_bookings_userBooking => 'حجز مستخدم';

  @override
  String get partner_bookings_partnerBooking => 'حجز شريك';

  @override
  String get partner_bookings_price => 'جنيه';

  @override
  String get partner_bookings_egp => 'جنيه';

  @override
  String get partner_bookings_weekly => 'أسبوعي';

  @override
  String get partner_bookings_daily => 'يومي';

  @override
  String get partner_bookingDetails_title => 'تفاصيل الحجز';

  @override
  String get partner_bookingDetails_host => 'المضيف';

  @override
  String get partner_bookingDetails_phone => 'الهاتف';

  @override
  String get partner_bookingDetails_price => 'السعر';

  @override
  String get partner_bookingDetails_recurring => 'متكرر';

  @override
  String get partner_bookingDetails_notes => 'ملاحظات';

  @override
  String get partner_createBooking_title => 'إنشاء حجز';

  @override
  String partner_createBooking_timeAndPrice(String time, int price) {
    return '$time • $price جنيه';
  }

  @override
  String get partner_createBooking_customerName => 'اسم العميل *';

  @override
  String get partner_createBooking_customerNameHint => 'أدخل اسم العميل';

  @override
  String get partner_createBooking_phoneNumber => 'رقم الهاتف *';

  @override
  String get partner_createBooking_phoneNumberHint => 'أدخل رقم الهاتف';

  @override
  String get partner_createBooking_notes => 'ملاحظات (اختياري)';

  @override
  String get partner_createBooking_notesOptional => 'ملاحظات (اختياري)';

  @override
  String get partner_createBooking_notesHint => 'أي ملاحظات إضافية';

  @override
  String get partner_createBooking_makeRecurring => 'اجعل هذا حجزًا متكررًا';

  @override
  String get partner_createBooking_repeat => 'تكرار';

  @override
  String get partner_createBooking_daily => 'يومي';

  @override
  String get partner_createBooking_weekly => 'أسبوعي';

  @override
  String get partner_createBooking_endDate => 'تاريخ الانتهاء (اختياري)';

  @override
  String get partner_createBooking_endDateOptional =>
      'تاريخ الانتهاء (اختياري)';

  @override
  String get partner_createBooking_selectEndDate =>
      'اختر تاريخ الانتهاء (يستمر إلى أجل غير مسمى)';

  @override
  String get partner_createBooking_endDateHint =>
      'اختر تاريخ الانتهاء (يستمر إلى أجل غير مسمى)';

  @override
  String get partner_createBooking_endDateSelected => 'd MMM، yyyy';

  @override
  String get partner_createBooking_cancelButton => 'إلغاء';

  @override
  String get partner_createBooking_create => 'إنشاء حجز';

  @override
  String get partner_createBooking_createButton => 'إنشاء حجز';

  @override
  String get partner_createBooking_fillRequired =>
      'يرجى ملء جميع الحقول المطلوبة';

  @override
  String get partner_createBooking_createdSuccess => 'تم إنشاء الحجز بنجاح!';

  @override
  String get partner_createBooking_createdSuccessRecurring =>
      'تم إنشاء الحجز المتكرر بنجاح!';

  @override
  String partner_createBooking_error(String error) {
    return 'خطأ في إنشاء الحجز: $error';
  }

  @override
  String get partner_revenue_title => 'الإيرادات';

  @override
  String get partner_revenue_settings => 'الإعدادات';

  @override
  String get partner_revenue_language => 'اللغة';

  @override
  String get partner_signOut => 'تسجيل الخروج';

  @override
  String get partner_signOutConfirm => 'هل أنت متأكد أنك تريد تسجيل الخروج؟';

  @override
  String get partner_cancel => 'إلغاء';
}
