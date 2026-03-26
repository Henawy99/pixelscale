import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:playmakerappstart/custom_dialoag.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:playmakerappstart/main_screen.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_auth_service.dart';
import 'package:playmakerappstart/playerprofile_form.dart';
import 'package:playmakerappstart/widgets/beautiful_dialog.dart';

enum AuthenticationStatus { authenticated, unauthenticated, unknown }

class AuthenticationState {
  final AuthenticationStatus status;
  final PlayerProfile? userProfile;
  final String? errorMessage;

  AuthenticationState(this.status, {this.userProfile, this.errorMessage});
}

class AuthenticationBloc extends Cubit<AuthenticationState> {
  AuthenticationBloc() : super(AuthenticationState(AuthenticationStatus.unknown));
  final SupabaseAuthService _authService = SupabaseAuthService();

  Future<void> handleEmailSignIn(BuildContext context, String email, String password) async {
    // Show loading dialog
    BeautifulDialog.showLoading(context, message: 'Signing in...');

    try {
      // Validate email format
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw 'Please enter a valid email address';
      }

      // Validate password length
      if (password.length < 6) {
        throw 'Password must be at least 6 characters';
      }

      // Sign in with Supabase
      final response = await _authService.signInWithEmail(
        email: email.trim(),
        password: password,
      );

      if (!context.mounted) return;
      BeautifulDialog.dismissLoading(context); // Dismiss loading dialog

      final user = response.user;
      if (user != null) {
        // Check if email is verified
        if (user.emailConfirmedAt == null) {
          await BeautifulDialog.showError(
            context,
            title: 'Email Not Verified',
            message: 'Please verify your email address. Check your inbox for the verification link.',
            buttonText: 'Resend Email',
            onPressed: () => _resendVerificationEmail(context),
          );
          await _authService.signOut();
          return;
        }

        // Get or create user profile
        PlayerProfile? existingProfile = await _authService.getOrCreateUserProfile();

        if (existingProfile != null) {
          // Check if profile is complete (name, position, and level are required)
          final isProfileIncomplete = existingProfile.name.isEmpty || 
                                       existingProfile.preferredPosition.isEmpty || 
                                       existingProfile.personalLevel.isEmpty;
          
          if (isProfileIncomplete) {
            // Navigate to profile form to complete profile
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PlayerProfileFormScreen(
                    userModel: existingProfile,
                  ),
                ),
              );
            }
          } else {
            // Profile is complete, navigate to main screen
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MainScreen(userModel: existingProfile),
                ),
              );
            }
          }
          
          emit(AuthenticationState(
            AuthenticationStatus.authenticated,
            userProfile: existingProfile,
          ));
        } else {
          await BeautifulDialog.showError(
            context,
            title: 'Profile Error',
            message: 'Failed to load your profile. Please try again.',
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      BeautifulDialog.dismissLoading(context); // Dismiss loading dialog

      final errorMessage = _authService.getErrorMessage(e);
      
      await BeautifulDialog.showError(
        context,
        title: 'Sign In Failed',
        message: errorMessage,
      );
      
      emit(AuthenticationState(
        AuthenticationStatus.unauthenticated,
        errorMessage: errorMessage,
      ));
    }
  }

  Future<void> _resendVerificationEmail(BuildContext context) async {
    try {
      await _authService.resendEmailVerification();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Please check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending verification email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> resetPassword(BuildContext context) async {
    final TextEditingController emailController = TextEditingController();
    
    // First show the email input dialog
    bool? shouldReset = await CustomDialog.show(
      context: context,
      title: 'Reset Password',
      message: 'Enter your email address and we\'ll send you instructions to reset your password.',
      confirmText: 'Send Reset Link',
      cancelText: 'Cancel',
      icon: Icons.lock_reset_rounded,
      builder: (dialogContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: TextField(
          controller: emailController,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );

    if (shouldReset == true && emailController.text.isNotEmpty) {
      try {
        await _authService.resetPassword(emailController.text);
        
        // Show success dialog
        await CustomDialog.show(
          context: context,
          title: 'Reset Link Sent',
          message: 'Check your email at ${emailController.text} for instructions to reset your password.',
          confirmText: 'OK',
          cancelText: null,
          icon: Icons.mark_email_read_rounded,
        );
      } catch (e) {
        // Show error dialog
        await CustomDialog.show(
          context: context,
          title: 'Error',
          message: _authService.getErrorMessage(e),
          confirmText: 'OK',
          cancelText: null,
          icon: Icons.error_outline_rounded,
          isDestructive: true,
        );
      }
    }
  }



  Future<void> handleSignInWithApple(BuildContext context) async {
    BeautifulDialog.showLoading(context, message: 'Signing in with Apple...');
    
    try {
      // Sign in with Apple using Supabase
      final result = await _authService.signInWithApple();
      final response = result.response;
      final fullName = result.fullName;
      
      if (!context.mounted) return;
      BeautifulDialog.dismissLoading(context); // Dismiss loading dialog
      
      final user = response.user;
      if (user != null) {
        // Get or create user profile with Apple full name
        PlayerProfile? userProfile = await _authService.getOrCreateUserProfile(
          appleFirstName: fullName,
        );
        
        if (userProfile != null) {
          // Check if profile is complete (name, position, and level are required)
          final isProfileIncomplete = userProfile.name.isEmpty || 
                                       userProfile.preferredPosition.isEmpty || 
                                       userProfile.personalLevel.isEmpty;
          
          if (isProfileIncomplete) {
            // Navigate to profile form to complete profile
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PlayerProfileFormScreen(
                    userModel: userProfile,
                    appleSignIn: true,
                  ),
                ),
              );
            }
          } else {
            // Profile is complete, navigate to main screen
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MainScreen(userModel: userProfile),
                ),
              );
            }
          }
          
          emit(AuthenticationState(
            AuthenticationStatus.authenticated,
            userProfile: userProfile,
          ));
        } else {
          // User profile creation failed
          if (context.mounted) {
            await BeautifulDialog.showError(
              context,
              title: 'Profile Error',
              message: 'Failed to create your profile. Please try again.',
            );
          }
          
          emit(AuthenticationState(
            AuthenticationStatus.unauthenticated,
            errorMessage: 'Failed to create user profile',
          ));
        }
      } else {
        // User is null after sign in
        if (context.mounted) {
          await BeautifulDialog.showError(
            context,
            title: 'Sign In Failed',
            message: 'Could not complete Apple Sign In. Please try again.',
          );
        }
        
        emit(AuthenticationState(
          AuthenticationStatus.unauthenticated,
          errorMessage: 'Apple Sign In failed',
        ));
      }
    } catch (e) {
      if (!context.mounted) return;
      BeautifulDialog.dismissLoading(context); // Dismiss loading dialog
      
      final errorMessage = _authService.getErrorMessage(e);
      
      // Don't show error if user cancelled
      if (!errorMessage.toLowerCase().contains('cancel')) {
        await BeautifulDialog.showError(
          context,
          title: 'Apple Sign In Failed',
          message: errorMessage,
        );
      }
      
      emit(AuthenticationState(
        AuthenticationStatus.unauthenticated,
        errorMessage: errorMessage,
      ));
    }
  }


  // Facebook authentication removed - not requested by user
  // If needed in the future, implement using Supabase OAuth

  Future<void> handleSignInWithGoogle(BuildContext context) async {
    BeautifulDialog.showLoading(context, message: 'Signing in with Google...');
    
    try {
      // Sign in with Google using Supabase
      final response = await _authService.signInWithGoogle();
      
      if (!context.mounted) return;
      BeautifulDialog.dismissLoading(context); // Dismiss loading dialog
      
      final user = response.user;
      if (user != null) {
        // Get or create user profile
        PlayerProfile? userProfile = await _authService.getOrCreateUserProfile(
          displayName: user.userMetadata?['full_name'] ?? user.email?.split('@')[0],
        );
        
        if (userProfile != null) {
          // Check if profile is complete (name, position, and level are required)
          final isProfileIncomplete = userProfile.name.isEmpty || 
                                       userProfile.preferredPosition.isEmpty || 
                                       userProfile.personalLevel.isEmpty;
          
          if (isProfileIncomplete) {
            // Navigate to profile form to complete profile
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PlayerProfileFormScreen(
                    userModel: userProfile,
                  ),
                ),
              );
            }
          } else {
            // Profile is complete, navigate to main screen
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MainScreen(userModel: userProfile),
                ),
              );
            }
          }
          
          emit(AuthenticationState(
            AuthenticationStatus.authenticated,
            userProfile: userProfile,
          ));
        } else {
          // User profile creation failed
          if (context.mounted) {
            await BeautifulDialog.showError(
              context,
              title: 'Profile Error',
              message: 'Failed to create your profile. Please try again.',
            );
          }
          
          emit(AuthenticationState(
            AuthenticationStatus.unauthenticated,
            errorMessage: 'Failed to create user profile',
          ));
        }
      } else {
        // User is null after sign in
        if (context.mounted) {
          await BeautifulDialog.showError(
            context,
            title: 'Sign In Failed',
            message: 'Could not complete Google Sign In. Please try again.',
          );
        }
        
        emit(AuthenticationState(
          AuthenticationStatus.unauthenticated,
          errorMessage: 'Google Sign In failed',
        ));
      }
    } catch (e) {
      if (!context.mounted) return;
      BeautifulDialog.dismissLoading(context); // Dismiss loading dialog
      
      final errorMessage = _authService.getErrorMessage(e);
      
      // Don't show error if user cancelled
      if (!errorMessage.toLowerCase().contains('cancel')) {
        await BeautifulDialog.showError(
          context,
          title: 'Google Sign In Failed',
          message: errorMessage,
        );
      }
      
      emit(AuthenticationState(
        AuthenticationStatus.unauthenticated,
        errorMessage: errorMessage,
      ));
    }
  }

  Future<void> logOut(BuildContext context) async {
    try {
      await _authService.signOut();
      
      emit(AuthenticationState(AuthenticationStatus.unauthenticated));
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginWithPasswordScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  
}
