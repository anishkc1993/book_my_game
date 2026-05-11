import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<UserEntity?> get authStateChanges => remoteDataSource.authStateChanges;

  @override
  Future<UserEntity?> getCurrentUser() async {
    return await remoteDataSource.getCurrentUser();
  }

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(UserEntity user) onAutoVerified,
    int? resendToken,
  }) async {
    await remoteDataSource.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      onAutoVerified: onAutoVerified,
      resendToken: resendToken,
    );
  }

  @override
  Future<UserEntity> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    return await remoteDataSource.verifyOtp(
      verificationId: verificationId,
      otp: otp,
    );
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }
}
