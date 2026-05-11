import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase implements UseCase<UserEntity, VerifyOtpParams> {
  final AuthRepository repository;

  VerifyOtpUseCase(this.repository);

  @override
  Future<UserEntity> call(VerifyOtpParams params) async {
    return await repository.verifyOtp(
      verificationId: params.verificationId,
      otp: params.otp,
    );
  }
}

class VerifyOtpParams extends Equatable {
  final String verificationId;
  final String otp;

  const VerifyOtpParams({
    required this.verificationId,
    required this.otp,
  });

  @override
  List<Object?> get props => [verificationId, otp];
}
