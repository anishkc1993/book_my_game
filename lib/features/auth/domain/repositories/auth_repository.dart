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

  Future<void> signOut();
}
