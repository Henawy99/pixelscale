import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';

/// Result from Apple Sign In containing auth response and user's full name
class AppleSignInResult {
  final AuthResponse response;
  final String? fullName;

  AppleSignInResult({
    required this.response,
    this.fullName,
  });
}

/// Supabase Authentication Service
/// Handles all authentication operations using Supabase Auth
class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();
  
  // Web Client ID is required for Supabase authentication
  // This is the OAuth 2.0 Web client ID from Google Cloud Console
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '116429864847-o0mo4cnafkje8aashkfo66ck5k5c683u.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
    ],
  );

  /// Get current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Get current user's UID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ===================================
  // EMAIL/PASSWORD AUTHENTICATION
  // ===================================

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  /// Resend email verification
  Future<void> resendEmailVerification() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && user.email != null) {
        await _supabase.auth.resend(
          type: OtpType.signup,
          email: user.email!,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // ===================================
  // GOOGLE AUTHENTICATION
  // ===================================

  /// Sign in with Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      // Get Google auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Failed to get Google credentials');
      }

      // Sign in to Supabase with Google credentials
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return response;
    } catch (e) {
      // Clean up Google Sign In on error
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  // ===================================
  // APPLE AUTHENTICATION
  // ===================================

  /// Sign in with Apple
  /// Returns both the auth response and the Apple credential with name info
  Future<AppleSignInResult> signInWithApple() async {
    try {
      print('🍎 Starting Apple Sign In...');
      print('   Requesting Apple credentials...');
      
      // Request Apple ID credential with timeout
      final appleIdCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('⏱️ Apple credential request timed out after 60 seconds');
          throw Exception('Apple Sign In timed out. Please try again.');
        },
      );

      print('✅ Apple credential received!');
      print('   User ID: ${appleIdCredential.userIdentifier}');
      print('   Email: ${appleIdCredential.email ?? "N/A"}');
      print('   Given Name: ${appleIdCredential.givenName ?? "N/A"}');
      print('   Family Name: ${appleIdCredential.familyName ?? "N/A"}');
      print('   Has ID Token: ${appleIdCredential.identityToken != null}');

      // Construct full name from Apple
      String? fullName;
      final givenName = appleIdCredential.givenName;
      final familyName = appleIdCredential.familyName;
      
      if (givenName != null && familyName != null) {
        fullName = '$givenName $familyName';
        print('   Constructed full name: $fullName');
      } else if (givenName != null) {
        fullName = givenName;
      }

      final String? idToken = appleIdCredential.identityToken;
      
      if (idToken == null) {
        print('❌ No ID token received from Apple');
        throw Exception('Failed to get Apple ID token');
      }

      print('✅ ID Token received, signing in to Supabase...');
      print('   Token length: ${idToken.length}');

      // Sign in to Supabase with Apple credentials (with timeout)
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ Supabase sign in timed out after 30 seconds');
          throw Exception('Sign in timed out. Please check your internet connection and try again.');
        },
      );

      print('✅ Supabase sign in successful!');
      print('   User ID: ${response.user?.id}');
      print('   Email: ${response.user?.email}');

      return AppleSignInResult(response: response, fullName: fullName);
    } catch (e, stackTrace) {
      print('❌ Apple Sign In Error: $e');
      print('   Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ===================================
  // USER PROFILE MANAGEMENT
  // ===================================

  /// Get or create user profile after authentication
  Future<PlayerProfile?> getOrCreateUserProfile({
    String? displayName,
    String? appleFirstName,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ getOrCreateUserProfile: No current user');
        return null;
      }

      print('✅ Current user: ${user.email} (ID: ${user.id})');

      // Try to get existing profile
      try {
        PlayerProfile? existingProfile = await _supabaseService.getUserProfileByEmail(
          user.email ?? "",
        );

        if (existingProfile != null) {
          print('✅ Found existing profile for: ${existingProfile.email}');
          return existingProfile;
        }
      } catch (e) {
        print('⚠️ Error checking for existing profile: $e');
      }

      print('📝 Creating new profile for: ${user.email}');

      // Get FCM token
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        print('✅ FCM Token obtained');
      } catch (e) {
        print('⚠️ Error getting FCM token: $e');
      }

      // Create new profile
      PlayerProfile newProfile = PlayerProfile(
        id: user.id,
        email: user.email ?? "",
        name: displayName ?? appleFirstName ?? user.userMetadata?['full_name'] ?? "",
        playerId: (DateTime.now().millisecondsSinceEpoch % 10000000).toString().padLeft(7, '0'),
        fcmToken: fcmToken ?? "",
        profilePicture: '',
        joined: DateTime.now().toString(),
        preferredPosition: '',
        personalLevel: '',
        phoneNumber: user.phone ?? "",
        age: '',
        favouriteClub: '',
        friends: [],
        openFriendRequests: [],
        bookings: [],
        nationality: '',
        rank: '',
        teamsJoined: [],
        teamsJoinedHistory: '',
        verifiedEmail: user.emailConfirmedAt != null,
        verified: 'false',
        openBookingRequests: [],
        openTeamsRequests: [],
      );

      // Store in database
      try {
        print('📝 Calling _supabaseService.createUserProfile...');
        final isNew = await _supabaseService.createUserProfile(newProfile.toMap());
        if (isNew) {
          print('✅ Profile created successfully for: ${newProfile.email}');
          print('   This triggered the admin notification!');
        } else {
          print('✅ Profile already existed for: ${newProfile.email}, skipping notification');
        }
      } catch (e) {
        print('❌ Error creating profile in database: $e');
        print('   Stack trace: ${StackTrace.current}');
        throw e;
      }
      
      return newProfile;
    } catch (e, stackTrace) {
      print('❌ Error getting/creating user profile: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Update user profile data
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _supabase.auth.updateUser(
        UserAttributes(
          data: updates,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  // ===================================
  // SIGN OUT
  // ===================================

  /// Sign out current user
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // ===================================
  // ERROR HANDLING
  // ===================================

  /// Convert Supabase auth exception to user-friendly message
  String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      
      if (msg.contains('invalid login credentials') || 
          msg.contains('invalid email or password')) {
        return 'Invalid email or password. Please try again.';
      }
      
      if (msg.contains('email not confirmed')) {
        return 'Please verify your email address before signing in.';
      }
      
      if (msg.contains('user already registered') || 
          msg.contains('email already exists')) {
        return 'This email is already registered. Please login instead.';
      }
      
      if (msg.contains('weak password') || 
          msg.contains('password should be at least')) {
        return 'Password is too weak. Please use at least 6 characters.';
      }
      
      if (msg.contains('invalid email')) {
        return 'Please enter a valid email address.';
      }
      
      if (msg.contains('email rate limit exceeded')) {
        return 'Too many attempts. Please try again later.';
      }
      
      return error.message;
    }
    
    return error.toString();
  }

  /// Check if error is email not verified
  bool isEmailNotVerified(dynamic error) {
    if (error is AuthException) {
      return error.message.toLowerCase().contains('email not confirmed');
    }
    return false;
  }

  /// Check if error is user not found
  bool isUserNotFound(dynamic error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      return msg.contains('invalid login credentials') || 
             msg.contains('user not found');
    }
    return false;
  }

  /// Check if error is wrong password
  bool isWrongPassword(dynamic error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      return msg.contains('invalid login credentials') || 
             msg.contains('invalid email or password') ||
             msg.contains('wrong password');
    }
    return false;
  }

  /// Check if error is email already exists
  bool isEmailAlreadyExists(dynamic error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      return msg.contains('user already registered') || 
             msg.contains('email already exists');
    }
    return false;
  }
}

