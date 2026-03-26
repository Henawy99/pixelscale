import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  ProfileModel? _profile;
  bool _loading = true;
  String? _error;

  User? get user => _user;
  ProfileModel? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  /// Admin if profile.role is 'admin' OR if logged-in email is the known admin (fallback when profile missing).
  bool get isAdmin =>
      (_profile?.isAdmin ?? false) || (_user?.email?.toLowerCase() == 'albasset@tennis.com');
  bool get isLoggedIn => _user != null;

  StreamSubscription<AuthState>? _authSub;

  AuthProvider() {
    _authSub = AuthService.authStateChanges.listen(_onAuthStateChange);
  }

  void _onAuthStateChange(AuthState state) {
    _user = state.session?.user;
    if (_user == null) {
      _profile = null;
      notifyListeners();
      _loadProfile();
      return;
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _loading = true;
    notifyListeners();
    try {
      _profile = await AuthService.getProfile().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('AuthProvider: getProfile timed out');
          return null;
        },
      );
    } catch (e) {
      debugPrint('AuthProvider: getProfile failed: $e');
      _profile = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _error = null;
    try {
      await AuthService.signIn(email, password);
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> signUp(String email, String password, String fullName) async {
    _error = null;
    notifyListeners();
    try {
      await AuthService.signUp(email, password, fullName);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  void _handleAuthError(dynamic e) {
      final msg = e.toString();
      if (msg.contains('host lookup') ||
          msg.contains('SocketException') ||
          msg.contains('No address associated with hostname') ||
          msg.contains('SocketFailed') ||
          msg.contains('Failed host lookup')) {
        _error = 'Cannot reach server. Check your internet connection. '
            'If the app worked before, your Supabase project may be paused — open Supabase Dashboard and restore it.';
      } else {
        _error = msg.replaceFirst('Exception: ', '');
      }
      notifyListeners();
      throw e;
    }

  Future<void> signOut() async {
    await AuthService.signOut();
    _profile = null;
    _user = null;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
