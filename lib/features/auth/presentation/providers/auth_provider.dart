import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/send_email_link_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/verify_email_link_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  otpSent,
  emailLinkSent,
  emailLinkReceived,
  error,
}

class AuthProvider extends ChangeNotifier {
  final SendOtpUseCase sendOtpUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final SignOutUseCase signOutUseCase;
  final SendEmailLinkUseCase sendEmailLinkUseCase;
  final VerifyEmailLinkUseCase verifyEmailLinkUseCase;
  final SharedPreferences prefs;

  AuthProvider({
    required this.sendOtpUseCase,
    required this.verifyOtpUseCase,
    required this.getCurrentUserUseCase,
    required this.signOutUseCase,
    required this.sendEmailLinkUseCase,
    required this.verifyEmailLinkUseCase,
    required this.prefs,
  }) {
    _init();
  }

  AuthStatus _status = AuthStatus.initial;
  UserEntity? _user;
  String? _errorMessage;
  String? _verificationId;
  int? _resendToken;
  String? _pendingEmail;
  String? _pendingEmailLink;
  StreamSubscription<UserEntity?>? _authSubscription;
  bool _initialCheckDone = false;

  AuthStatus get status => _status;
  UserEntity? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get verificationId => _verificationId;
  String? get pendingEmail => _pendingEmail;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  Future<void> _init() async {
    final currentUser = await getCurrentUserUseCase(const NoParams());

    if (currentUser != null) {
      _user = currentUser;
      _status = AuthStatus.authenticated;
      _initialCheckDone = true;
      notifyListeners();
    }

    _authSubscription = getCurrentUserUseCase.authStateChanges.listen((user) {
      if (!_initialCheckDone && user == null) {
        _initialCheckDone = true;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _initialCheckDone = true;
      _user = user;

      if (user != null) {
        _status = AuthStatus.authenticated;
      } else {
        if (_status != AuthStatus.loading &&
            _status != AuthStatus.otpSent &&
            _status != AuthStatus.emailLinkSent) {
          _status = AuthStatus.unauthenticated;
        }
      }
      notifyListeners();
    });
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final user = await getCurrentUserUseCase(const NoParams());
    _user = user;
    _status = user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Re-fetch the current user from Firestore (e.g., after turf selection
  /// writes turfId/turfName to the user doc).
  Future<void> refreshCurrentUser() async {
    final user = await getCurrentUserUseCase(const NoParams());
    if (user != null) {
      _user = user;
      notifyListeners();
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    await sendOtpUseCase(
      SendOtpParams(
        phoneNumber: phoneNumber,
        resendToken: _resendToken,
        onCodeSent: (verificationId) {
          _verificationId = verificationId;
          _status = AuthStatus.otpSent;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = error;
          _status = AuthStatus.error;
          notifyListeners();
        },
        onAutoVerified: (user) {
          _user = user;
          _status = AuthStatus.authenticated;
          notifyListeners();
        },
      ),
    );
  }

  Future<void> resendOtp(String phoneNumber) async {
    await sendOtp(phoneNumber);
  }

  Future<void> verifyOtp(String otp) async {
    if (_verificationId == null) {
      _errorMessage = 'Verification session expired. Please request a new code.';
      _status = AuthStatus.error;
      notifyListeners();
      return;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await verifyOtpUseCase(
        VerifyOtpParams(verificationId: _verificationId!, otp: otp),
      );
      _user = user;
      _status = AuthStatus.authenticated;
      _verificationId = null;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
    }

    notifyListeners();
  }

  Future<void> sendEmailLink(String email) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await sendEmailLinkUseCase(SendEmailLinkParams(email: email));
      _pendingEmail = email;
      await prefs.setString(AppConstants.pendingEmailKey, email);
      _status = AuthStatus.emailLinkSent;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.error;
    }

    notifyListeners();
  }

  // Called by AppRouter when a deep link matching Firebase email link is received.
  Future<void> handleEmailLink(String link) async {
    final email = _pendingEmail ?? prefs.getString(AppConstants.pendingEmailKey);

    if (email == null) {
      // Store the link and signal the UI to ask for the email again.
      _pendingEmailLink = link;
      _status = AuthStatus.emailLinkReceived;
      notifyListeners();
      return;
    }

    await _doVerifyEmailLink(email, link);
  }

  // Called from the UI when the user re-enters their email after receiving a link.
  Future<void> verifyEmailLinkWithEmail(String email) async {
    if (_pendingEmailLink == null) return;
    await _doVerifyEmailLink(email, _pendingEmailLink!);
  }

  Future<void> _doVerifyEmailLink(String email, String link) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await verifyEmailLinkUseCase(
        VerifyEmailLinkParams(email: email, emailLink: link),
      );
      _user = user;
      _status = AuthStatus.authenticated;
      _pendingEmail = null;
      _pendingEmailLink = null;
      await prefs.remove(AppConstants.pendingEmailKey);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.error;
    }

    notifyListeners();
  }

  Future<void> signOut() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await signOutUseCase(const NoParams());
      _user = null;
      _verificationId = null;
      _pendingEmail = null;
      _pendingEmailLink = null;
      await prefs.remove(AppConstants.pendingEmailKey);
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
    }

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetToPhoneInput() {
    _verificationId = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
