import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyEmailLinkUseCase implements UseCase<UserEntity, VerifyEmailLinkParams> {
  final AuthRepository repository;

  VerifyEmailLinkUseCase(this.repository);

  @override
  Future<UserEntity> call(VerifyEmailLinkParams params) async {
    return await repository.verifyEmailLink(
      email: params.email,
      emailLink: params.emailLink,
    );
  }
}

class VerifyEmailLinkParams extends Equatable {
  final String email;
  final String emailLink;

  const VerifyEmailLinkParams({required this.email, required this.emailLink});

  @override
  List<Object?> get props => [email, emailLink];
}
