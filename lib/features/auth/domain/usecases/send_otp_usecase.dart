import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SendOtpUseCase implements UseCase<void, SendOtpParams> {
  final AuthRepository repository;

  SendOtpUseCase(this.repository);

  @override
  Future<void> call(SendOtpParams params) async {
    await repository.sendOtp(
      phoneNumber: params.phoneNumber,
      onCodeSent: params.onCodeSent,
      onError: params.onError,
      onAutoVerified: params.onAutoVerified,
      resendToken: params.resendToken,
    );
  }
}

class SendOtpParams extends Equatable {
  final String phoneNumber;
  final Function(String verificationId) onCodeSent;
  final Function(String error) onError;
  final Function(UserEntity user) onAutoVerified;
  final int? resendToken;

  const SendOtpParams({
    required this.phoneNumber,
    required this.onCodeSent,
    required this.onError,
    required this.onAutoVerified,
    this.resendToken,
  });

  @override
  List<Object?> get props => [phoneNumber, resendToken];
}
