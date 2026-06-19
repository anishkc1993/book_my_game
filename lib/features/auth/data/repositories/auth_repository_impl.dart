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
  Future<UserEntity> signInWithPhonePassword({
    required String phoneNumber,
    required String password,
  }) {
    return remoteDataSource.signInWithPhonePassword(
      phoneNumber: phoneNumber,
      password: password,
    );
  }

  @override
  Future<void> linkPasswordToCurrentUser({
    required String phoneNumber,
    required String password,
  }) {
    return remoteDataSource.linkPasswordToCurrentUser(
      phoneNumber: phoneNumber,
      password: password,
    );
  }

  @override
  Future<void> sendEmailLink({required String email}) async {
    await remoteDataSource.sendEmailLink(email: email);
  }

  @override
  Future<UserEntity> verifyEmailLink({
    required String email,
    required String emailLink,
  }) async {
    return await remoteDataSource.verifyEmailLink(
      email: email,
      emailLink: emailLink,
    );
  }

  @override
  bool isSignInWithEmailLink(String link) {
    return remoteDataSource.isSignInWithEmailLink(link);
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }
}
