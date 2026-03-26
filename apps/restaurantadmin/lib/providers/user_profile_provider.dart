import 'package:flutter/foundation.dart';
import 'package:restaurantadmin/models/profile.dart' as app_profile;

class UserProfileProvider with ChangeNotifier {
  app_profile.Profile? _profile;

  app_profile.Profile? get profile => _profile;

  void setProfile(app_profile.Profile? profile) {
    _profile = profile;
    notifyListeners();
  }

  void clearProfile() {
    _profile = null;
    notifyListeners();
  }
}
