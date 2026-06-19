import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;

  Future<UserEntity?> getCurrentUser();

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(UserEntity user) onAutoVerified,
    int? resendToken,
  });

  Future<UserEntity> verifyOtp({
    required String verificationId,
    required String otp,
  });

  /// Sign in an existing user with phone + password.
  /// Throws [AuthException] with code `user-not-found` if no password
  /// account exists yet (treat as signup).
  Future<UserEntity> signInWithPhonePassword({
    required String phoneNumber,
    required String password,
  });

  /// Link an email/password credential to the currently-signed-in Firebase
  /// user. Used right after OTP verification during signup.
  Future<void> linkPasswordToCurrentUser({
    required String phoneNumber,
    required String password,
  });

  Future<void> sendEmailLink({required String email});

  Future<UserEntity> verifyEmailLink({
    required String email,
    required String emailLink,
  });

  bool isSignInWithEmailLink(String link);

  Future<void> signOut();
}
