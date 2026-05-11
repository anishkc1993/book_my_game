import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  otpSent,
  error,
}

class AuthProvider extends ChangeNotifier {
  final SendOtpUseCase sendOtpUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final SignOutUseCase signOutUseCase;

  AuthProvider({
    required this.sendOtpUseCase,
    required this.verifyOtpUseCase,
    required this.getCurrentUserUseCase,
    required this.signOutUseCase,
  }) {
    _init();
  }

  AuthStatus _status = AuthStatus.initial;
  UserEntity? _user;
  String? _errorMessage;
  String? _verificationId;
  int? _resendToken;
  StreamSubscription<UserEntity?>? _authSubscription;
  bool _initialCheckDone = false;

  AuthStatus get status => _status;
  UserEntity? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get verificationId => _verificationId;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  Future<void> _init() async {
    // First, check the current user synchronously from Firebase cache
    final currentUser = await getCurrentUserUseCase(const NoParams());

    if (currentUser != null) {
      _user = currentUser;
      _status = AuthStatus.authenticated;
      _initialCheckDone = true;
      notifyListeners();
    }

    // Then listen to auth state changes for subsequent updates
    _authSubscription = getCurrentUserUseCase.authStateChanges.listen((user) {
      // Skip the first null emission if we haven't done initial check
      // This prevents logout on app start due to Firebase's delayed session restore
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
        // Only set to unauthenticated if we're not in a loading/otp flow
        if (_status != AuthStatus.loading && _status != AuthStatus.otpSent) {
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

    if (user != null) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
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
        VerifyOtpParams(
          verificationId: _verificationId!,
          otp: otp,
        ),
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

  Future<void> signOut() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await signOutUseCase(const NoParams());
      _user = null;
      _verificationId = null;
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
